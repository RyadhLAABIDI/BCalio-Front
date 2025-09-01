package com.elite.bcalio.app;

import android.app.Activity;
import android.app.AlarmManager;
import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Color;
import android.media.AudioAttributes;
import android.media.Ringtone;
import android.media.RingtoneManager;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;

import androidx.annotation.NonNull;
import androidx.core.app.NotificationCompat;

import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

/**
 * Corrigé :
 * - reset des canaux/états statiques lors du detach de l’engine (cleanUpFlutterEngine)
 * - flag engineReady
 * - mise en file si pas prêt + try/catch autour des invokeMethod
 * - filtrage des appels "morts" (timeout/rejected/accepted ou stale > 45s) pour éviter l’ouverture d’UI fantôme
 * - méthode 'is_call_dead' exposée au canal natif
 */
public class MainActivity extends FlutterActivity {

    public static final String CHANNEL = "incoming_calls";
    public static final String CHAT_CHANNEL = "chat_notifications";
    private static final String CALLS_CHANNEL_ID = "calls";

    private static MethodChannel channel;
    private static MethodChannel chatChannel;

    private static final List<Bundle> pendingCalls = new ArrayList<>();
    private static final List<Bundle> pendingChats = new ArrayList<>();

    private static final Set<String> handledCallIds = new HashSet<>();

    // --- états runtime ---
    private static volatile boolean inForeground = false;
    public  static boolean isInForeground() { return inForeground; }

    // engine prêt ?
    private static volatile boolean engineReady = false;

    // Dart prêt côté chat ?
    private static volatile boolean chatDartReady = false;

    // ---- statut local pour bloquer les "manqués" tardifs (appels) ----
    private static final String PREFS_CALLS = "bcalio_calls";
    private static String KEY_STATUS(String callId) { return "s_" + callId; }
    private static String KEY_TS(String callId)     { return "t_" + callId; }   // 👈 timestamp d’arrivée
    private static final String STATUS_ACCEPTED = "accepted";
    private static final String STATUS_REJECTED = "rejected";
    private static final String STATUS_TIMEOUT  = "timeout";
    private static final long   RING_STALE_MS   = 45_000L;                       // 👈 au-delà → considéré mort

    // Contexte application statique
    private static volatile Context appCtx;

    private static void markAccepted(Context ctx, String callId) {
        if (callId == null || callId.isEmpty()) return;
        ctx.getSharedPreferences(PREFS_CALLS, Context.MODE_PRIVATE)
                .edit().putString(KEY_STATUS(callId), STATUS_ACCEPTED).apply();
    }
    private static void markRejected(Context ctx, String callId) {
        if (callId == null || callId.isEmpty()) return;
        ctx.getSharedPreferences(PREFS_CALLS, Context.MODE_PRIVATE)
                .edit().putString(KEY_STATUS(callId), STATUS_REJECTED).apply();
    }

    private static String extractCallId(Bundle b) {
        return b != null ? b.getString("callId", "") : "";
    }

    /** Vérifie si l’appel est déjà terminé (timeout/rejected/accepted) OU trop ancien (>45s). */
    private static boolean isCallDead(String callId) {
        if (appCtx == null || callId == null || callId.isEmpty()) return false;
        SharedPreferences sp = appCtx.getSharedPreferences(PREFS_CALLS, Context.MODE_PRIVATE);

        // 1) statut explicite
        String st = sp.getString(KEY_STATUS(callId), "");
        if (STATUS_ACCEPTED.equals(st) || STATUS_REJECTED.equals(st) || STATUS_TIMEOUT.equals(st)) {
            return true;
        }

        // 2) stale par âge (si on a le timestamp)
        long ts = sp.getLong(KEY_TS(callId), 0L);
        if (ts > 0L) {
            long age = System.currentTimeMillis() - ts;
            if (age > RING_STALE_MS) {
                // marque timeout pour bloquer définitivement
                sp.edit().putString(KEY_STATUS(callId), STATUS_TIMEOUT).apply();
                return true;
            }
        }
        return false;
    }

    /* ====================== APPELS ====================== */

    private static void deliverToFlutter(Bundle bundle) {
        if (bundle == null) return;
        String callId = extractCallId(bundle);
        if (callId.isEmpty()) return;

        // bloque si "mort/stale"
        if (isCallDead(callId)) {
            if (appCtx != null) cancelIncomingById(appCtx, callId);
            return;
        }

        synchronized (handledCallIds) {
            boolean isAction = bundle.getBoolean("autoAccept", false) || bundle.getBoolean("autoReject", false);
            if (handledCallIds.contains(callId) && !isAction) return;
            handledCallIds.add(callId);
        }

        Map<String, Object> args = new HashMap<>();
        args.put("callerName", bundle.getString("callerName", "Unknown"));
        args.put("callerId",   bundle.getString("callerId", ""));
        args.put("callId",     callId);
        args.put("callType",   bundle.getString("callType", "audio"));
        args.put("avatarUrl",  bundle.getString("avatarUrl", ""));
        args.put("recipientID",bundle.getString("recipientID", ""));
        args.put("isGroup",    bundle.getBoolean("isGroup", false));
        args.put("members",    bundle.getString("members", "[]"));
        args.put("autoAccept", bundle.getBoolean("autoAccept", false));
        args.put("autoReject", bundle.getBoolean("autoReject", false));
        args.put("callerPhone",bundle.getString("callerPhone",""));

        if (!engineReady || channel == null) {
            synchronized (pendingCalls) { pendingCalls.add(bundle); }
            return;
        }
        try {
            channel.invokeMethod("incoming_call", args);
        } catch (Throwable t) {
            synchronized (pendingCalls) { pendingCalls.add(bundle); }
        }
    }

    public static void enqueueIncomingCall(Bundle bundle) {
        if (bundle == null) return;
        String callId = extractCallId(bundle);

        // bloque si "mort/stale"
        if (isCallDead(callId)) {
            if (appCtx != null) cancelIncomingById(appCtx, callId);
            return;
        }

        if (!engineReady || channel == null) {
            synchronized (pendingCalls) {
                for (Bundle b : pendingCalls) {
                    if (extractCallId(b).equals(callId)) return;
                }
                pendingCalls.add(bundle);
            }
            return;
        }
        deliverToFlutter(bundle);
    }

    private static void flushPendingCalls() {
        List<Bundle> copy;
        synchronized (pendingCalls) {
            copy = new ArrayList<>(pendingCalls);
            pendingCalls.clear();
        }
        for (Bundle b : copy) deliverToFlutter(b);
    }

    /* ====================== CHAT ====================== */

    private static void deliverChatToFlutter(Bundle bundle) {
        if (bundle == null) return;
        if (!engineReady || chatChannel == null || !chatDartReady) {
            synchronized (pendingChats) { pendingChats.add(bundle); }
            return;
        }
        Map<String, Object> args = new HashMap<>();
        args.put("roomId",     bundle.getString("roomId", ""));
        args.put("messageId",  bundle.getString("messageId", ""));
        args.put("fromId",     bundle.getString("fromId", ""));
        args.put("fromName",   bundle.getString("fromName", ""));
        args.put("avatarUrl",  bundle.getString("avatarUrl", ""));
        args.put("text",       bundle.getString("text", ""));
        args.put("contentType",bundle.getString("contentType", "text"));
        args.put("isGroup",    bundle.getBoolean("isGroup", false));

        try {
            chatChannel.invokeMethod("open_chat_from_push", args);
        } catch (Throwable t) {
            synchronized (pendingChats) { pendingChats.add(bundle); }
        }
    }

    private static void flushPendingChats() {
        List<Bundle> copy;
        synchronized (pendingChats) {
            copy = new ArrayList<>(pendingChats);
            pendingChats.clear();
        }
        for (Bundle b : copy) deliverChatToFlutter(b);
    }

    /* ======== Sonnerie native pour le destinataire ======== */
    private static Ringtone sIncomingTone;

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        engineReady = true;

        // Canal APPELS
        channel = new MethodChannel(
                flutterEngine.getDartExecutor().getBinaryMessenger(),
                CHANNEL
        );
        channel.setMethodCallHandler(new MethodChannel.MethodCallHandler() {
            @Override
            @SuppressWarnings("unchecked")
            public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
                if ("show_call_notification".equals(call.method)) {
                    try {
                        Map<String, Object> m = (Map<String, Object>) call.arguments;
                        Bundle b = new Bundle();
                        b.putString("callId",      safeStr(m.get("callId")));
                        b.putString("callerId",    safeStr(m.get("callerId")));
                        b.putString("callerName",  safeStr(m.get("callerName")));
                        b.putString("callType",    safeStr(m.get("callType")));
                        b.putString("avatarUrl",   safeStr(m.get("avatarUrl")));
                        b.putString("callerPhone", safeStr(m.get("callerPhone")));
                        b.putBoolean("isGroup",   "1".equals(safeStr(m.get("isGroup"))) || Boolean.TRUE.equals(m.get("isGroup")));
                        b.putString("members",    safeStr(m.get("members")));
                        b.putString("recipientID",safeStr(m.get("recipientID")));

                        if (MainActivity.isInForeground()) {
                            enqueueIncomingCall(b);
                            result.success(true);
                            return;
                        }

                        showIncomingCallNotification(MainActivity.this, b);
                        enqueueIncomingCall(b);
                        result.success(true);
                    } catch (Exception e) {
                        result.error("ERR", e.getMessage(), null);
                    }
                    return;
                }

                if ("ui_accept".equals(call.method)) {
                    try {
                        Map<String, Object> m = (Map<String, Object>) call.arguments;
                        String callId = safeStr(m.get("callId"));
                        markAccepted(MainActivity.this, callId);
                        cancelIncomingById(MainActivity.this, callId);
                        result.success(true);
                    } catch (Exception e) {
                        result.error("ERR", e.getMessage(), null);
                    }
                    return;
                }

                if ("ui_reject".equals(call.method)) {
                    try {
                        Map<String, Object> m = (Map<String, Object>) call.arguments;
                        String callId = safeStr(m.get("callId"));
                        String callerId = safeStr(m.get("callerId"));
                        String callerName = safeStr(m.get("callerName"));
                        String avatarUrl = safeStr(m.get("avatarUrl"));
                        String callerPhone = safeStr(m.get("callerPhone"));

                        markRejected(MainActivity.this, callId);
                        cancelIncomingById(MainActivity.this, callId);

                        if (!MainActivity.isInForeground()) {
                            Bundle b = new Bundle();
                            b.putString("callId", callId);
                            b.putString("callerId", callerId);
                            b.putString("callerName", callerName);
                            b.putString("avatarUrl", avatarUrl);
                            b.putString("callerPhone", callerPhone);

                            Intent br = new Intent(MainActivity.this, CallActionReceiver.class)
                                    .setAction(MyFirebaseMessagingService.ACTION_REJECT)
                                    .putExtras(b);
                            sendBroadcast(br);
                        }

                        result.success(true);
                    } catch (Exception e) {
                        result.error("ERR", e.getMessage(), null);
                    }
                    return;
                }

                if ("ui_timeout".equals(call.method)) {
                    try {
                        Map<String, Object> m = (Map<String, Object>) call.arguments;
                        String callId = safeStr(m.get("callId"));
                        cancelIncomingById(MainActivity.this, callId);
                        result.success(true);
                    } catch (Exception e) {
                        result.error("ERR", e.getMessage(), null);
                    }
                    return;
                }

                if ("cancel_incoming".equals(call.method)) {
                    try {
                        Map<String, Object> m = (Map<String, Object>) call.arguments;
                        String callId = safeStr(m.get("callId"));
                        cancelIncomingById(MainActivity.this, callId);
                        result.success(true);
                    } catch (Exception e) {
                        result.error("ERR", e.getMessage(), null);
                    }
                    return;
                }

                // 👇 NEW: exposer un check côté natif
                if ("is_call_dead".equals(call.method)) {
                    try {
                        @SuppressWarnings("unchecked")
                        Map<String, Object> m = (Map<String, Object>) call.arguments;
                        String callId = safeStr(m.get("callId"));
                        boolean dead = isCallDead(callId);
                        result.success(dead);
                    } catch (Exception e) {
                        result.success(false);
                    }
                    return;
                }

                result.notImplemented();
            }
        });

        // Canal sonnerie TEL
        MethodChannel callSounds = new MethodChannel(
                flutterEngine.getDartExecutor().getBinaryMessenger(),
                "call_sounds"
        );
        callSounds.setMethodCallHandler((call, result) -> {
            try {
                if ("playIncoming".equals(call.method)) {
                    try {
                        if (sIncomingTone != null) {
                            try { sIncomingTone.stop(); } catch (Exception ignored) {}
                            sIncomingTone = null;
                        }
                        Uri ringUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE);
                        sIncomingTone = RingtoneManager.getRingtone(getApplicationContext(), ringUri);
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                            sIncomingTone.setAudioAttributes(
                                    new AudioAttributes.Builder()
                                            .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                                            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                                            .build()
                            );
                        }
                        sIncomingTone.play();
                    } catch (Exception ignored) {}
                    result.success(true);
                    return;
                }
                if ("stopIncoming".equals(call.method)) {
                    try {
                        if (sIncomingTone != null) {
                            sIncomingTone.stop();
                            sIncomingTone = null;
                        }
                    } catch (Exception ignored) {}
                    result.success(true);
                    return;
                }
                result.notImplemented();
            } catch (Exception e) {
                result.error("ERR", e.getMessage(), null);
            }
        });

        // Canal CHAT
        chatChannel = new MethodChannel(
                flutterEngine.getDartExecutor().getBinaryMessenger(),
                CHAT_CHANNEL
        );
        chatChannel.setMethodCallHandler((call, result) -> {
            if ("chat_ready".equals(call.method)) {
                chatDartReady = true;
                flushPendingChats();
                result.success(true);
                return;
            }
            result.notImplemented();
        });

        flushPendingCalls(); // engine prêt → vider la file appels
        // pendingChats vidé à "chat_ready"
    }

    @Override
    public void cleanUpFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.cleanUpFlutterEngine(flutterEngine);
        engineReady   = false;
        chatDartReady = false;
        channel       = null;
        chatChannel   = null;
    }

    private static String safeStr(Object o) { return (o == null) ? "" : String.valueOf(o); }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        chatDartReady = false;
        appCtx = getApplicationContext();

        Intent it = getIntent();
        if (it != null) {
            maybeDeliverChatFromIntent(it);
            if (it.getExtras() != null && it.getExtras().containsKey("callId")) {
                enqueueIncomingCall(it.getExtras());
            }
        }
    }

    @Override protected void onResume() { super.onResume(); inForeground = true; }
    @Override protected void onPause()  { inForeground = false; super.onPause(); }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        if (intent != null) {
            maybeDeliverChatFromIntent(intent);
            Bundle extras = intent.getExtras();
            if (extras != null && extras.containsKey("callId")) {
                enqueueIncomingCall(extras);
            }
        }
    }

    /* chat: si l’intent vient d’une notif, forward à Flutter (ou queue si pas prêt) */
    private void maybeDeliverChatFromIntent(Intent intent) {
        if (intent == null) return;
        String kind = intent.getStringExtra("push_kind");
        if (!"chat".equals(kind)) return;

        Bundle b = new Bundle();
        b.putString("roomId",     intent.getStringExtra("roomId"));
        b.putString("messageId",  intent.getStringExtra("messageId"));
        b.putString("fromId",     intent.getStringExtra("fromId"));
        b.putString("fromName",   intent.getStringExtra("fromName"));
        b.putString("avatarUrl",  intent.getStringExtra("avatarUrl"));
        b.putString("text",       intent.getStringExtra("text"));
        b.putString("contentType",intent.getStringExtra("contentType"));
        b.putBoolean("isGroup",   intent.getBooleanExtra("isGroup", false));

        deliverChatToFlutter(b);
    }

    private static int notificationIdFor(String callId) {
        return (callId == null) ? 0 : callId.hashCode();
    }

    private static int requestCodeFor(String callId, int salt) {
        int base = (callId == null ? 0 : callId.hashCode());
        return base ^ (salt * 31);
    }

    /** Annule le timer de timeout + la notification "ringing" pour ce callId. */
    static void cancelIncomingById(Context ctx, String callId) {
        if (callId == null || callId.isEmpty()) return;

        Intent i = new Intent(ctx, CallActionReceiver.class)
                .setAction(MyFirebaseMessagingService.ACTION_TIMEOUT);
        PendingIntent pi = PendingIntent.getBroadcast(
                ctx,
                requestCodeFor(callId, 99),
                i,
                (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
                        ? (PendingIntent.FLAG_CANCEL_CURRENT | PendingIntent.FLAG_IMMUTABLE)
                        : PendingIntent.FLAG_CANCEL_CURRENT
        );
        AlarmManager am = (AlarmManager) ctx.getSystemService(Context.ALARM_SERVICE);
        if (am != null) am.cancel(pi);

        NotificationManager nm = (NotificationManager) ctx.getSystemService(Context.NOTIFICATION_SERVICE);
        nm.cancel(notificationIdFor(callId));
    }

    private static void ensureCallsChannelWithRingtone(Activity act) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationManager nm = (NotificationManager) act.getSystemService(Context.NOTIFICATION_SERVICE);
            NotificationChannel existing = nm.getNotificationChannel(CALLS_CHANNEL_ID);
            if (existing != null) nm.deleteNotificationChannel(CALLS_CHANNEL_ID);

            Uri ringUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE);
            AudioAttributes attrs = new AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build();

            NotificationChannel ch = new NotificationChannel(
                    CALLS_CHANNEL_ID, "Incoming Calls", NotificationManager.IMPORTANCE_HIGH
            );
            ch.setDescription("Incoming call notifications");
            ch.enableLights(true);
            ch.setLightColor(Color.GREEN);
            ch.enableVibration(true);
            ch.setLockscreenVisibility(Notification.VISIBILITY_PUBLIC);
            ch.setSound(ringUri, attrs);
            nm.createNotificationChannel(ch);
        }
    }

    private static Bitmap tryLoadBitmapLocal(Context ctx, String uriOrPath) {
        if (uriOrPath == null || uriOrPath.trim().isEmpty()) return null;
        try {
            if (uriOrPath.startsWith("content://")) {
                Uri u = Uri.parse(uriOrPath);
                try (InputStream is = ctx.getContentResolver().openInputStream(u)) {
                    if (is != null) return BitmapFactory.decodeStream(is);
                }
                return null;
            }
            if (uriOrPath.startsWith("file://")) {
                return BitmapFactory.decodeFile(Uri.parse(uriOrPath).getPath());
            }
            if (uriOrPath.startsWith("/")) {
                return BitmapFactory.decodeFile(uriOrPath);
            }
        } catch (Throwable ignored) {}
        return null;
    }

    private static Bitmap tryLoadBitmapRemote(String url) {
        if (url == null || url.trim().isEmpty()) return null;
        HttpURLConnection conn = null;
        try {
            URL u = new URL(url);
            conn = (HttpURLConnection) u.openConnection();
            conn.setConnectTimeout(2500);
            conn.setReadTimeout(2500);
            conn.connect();
            if (conn.getResponseCode() == HttpURLConnection.HTTP_OK) {
                InputStream is = conn.getInputStream();
                return BitmapFactory.decodeStream(is);
            }
        } catch (Exception ignored) {
        } finally {
            if (conn != null) conn.disconnect();
        }
        return null;
    }

    private static void applyLargeIconIfAny(Activity act, String avatarUrl, int notifId, NotificationCompat.Builder nb) {
        if (avatarUrl == null || avatarUrl.trim().isEmpty()) return;

        Bitmap local = tryLoadBitmapLocal(act, avatarUrl);
        if (local != null) {
            nb.setLargeIcon(local);
            NotificationManager nm = (NotificationManager) act.getSystemService(Context.NOTIFICATION_SERVICE);
            nm.notify(notifId, nb.build());
            return;
        }

        if (avatarUrl.startsWith("http")) {
            new Thread(() -> {
                Bitmap remote = tryLoadBitmapRemote(avatarUrl);
                if (remote != null) {
                    NotificationManager nm = (NotificationManager) act.getSystemService(Context.NOTIFICATION_SERVICE);
                    nb.setLargeIcon(remote);
                    nm.notify(notifId, nb.build());
                }
            }).start();
        }
    }

    private static void showIncomingCallNotification(Activity activity, Bundle b) {
        ensureCallsChannelWithRingtone(activity);

        String callId      = b.getString("callId", "");
        String callerName  = b.getString("callerName", "Unknown");
        String avatarUrl   = b.getString("avatarUrl", "");
        String callerPhone = b.getString("callerPhone", "");

        String displayName = (callerName == null || callerName.trim().isEmpty()) ? "Inconnu" : callerName;
        String phoneOrId   = (callerPhone == null || callerPhone.trim().isEmpty())
                ? b.getString("callerId", "")
                : callerPhone;

        Intent inCall = new Intent(activity, IncomingCallActivity.class);
        inCall.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
        inCall.putExtras(b);

        PendingIntent fsPending = PendingIntent.getActivity(
                activity,
                (callId.hashCode() ^ (1 * 31)),
                inCall,
                (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
                        ? (PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE)
                        : PendingIntent.FLAG_UPDATE_CURRENT
        );
        PendingIntent tapPending = PendingIntent.getActivity(
                activity,
                (callId.hashCode() ^ (2 * 31)),
                inCall,
                (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
                        ? (PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE)
                        : PendingIntent.FLAG_UPDATE_CURRENT
        );

        NotificationCompat.Builder nb = new NotificationCompat.Builder(activity, CALLS_CHANNEL_ID)
                .setSmallIcon(android.R.drawable.stat_sys_phone_call)
                .setContentTitle("Appel entrant")
                .setContentText(displayName)
                .setStyle(new NotificationCompat.BigTextStyle().bigText(displayName + "\n" + phoneOrId))
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setCategory(NotificationCompat.CATEGORY_CALL)
                .setOngoing(true)
                .setAutoCancel(false)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setFullScreenIntent(fsPending, true)
                .setContentIntent(tapPending);

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            Uri ringUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE);
            nb.setSound(ringUri);
        }

        int notifId = notificationIdFor(callId);
        Notification n = nb.build();
        NotificationManager nm = (NotificationManager) activity.getSystemService(Context.NOTIFICATION_SERVICE);
        nm.notify(notifId, n);

        applyLargeIconIfAny(activity, avatarUrl, notifId, nb);
    }
}
