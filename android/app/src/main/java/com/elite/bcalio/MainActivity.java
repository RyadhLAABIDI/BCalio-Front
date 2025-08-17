package com.elite.bcalio;

import android.app.Activity;
import android.app.AlarmManager;
import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.graphics.Color;
import android.media.AudioAttributes;
import android.media.RingtoneManager;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;

import androidx.annotation.NonNull;
import androidx.core.app.NotificationCompat;

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

public class MainActivity extends FlutterActivity {

    public static final String CHANNEL = "incoming_calls";
    private static final String CALLS_CHANNEL_ID = "calls";

    private static MethodChannel channel;
    private static final List<Bundle> pendingCalls = new ArrayList<>();
    private static final Set<String> handledCallIds = new HashSet<>();

    private static volatile boolean inForeground = false;
    public static boolean isInForeground() { return inForeground; }

    private static String extractCallId(Bundle b) {
        return b != null ? b.getString("callId", "") : "";
    }

    private static void deliverToFlutter(Bundle bundle) {
        if (bundle == null) return;
        String callId = extractCallId(bundle);
        if (callId.isEmpty()) return;

        synchronized (handledCallIds) {
            boolean isAction = bundle.getBoolean("autoAccept", false) || bundle.getBoolean("autoReject", false);
            if (handledCallIds.contains(callId) && !isAction) {
                return;
            }
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

        if (channel != null) {
            channel.invokeMethod("incoming_call", args);
        }
    }

    public static void enqueueIncomingCall(Bundle bundle) {
        if (bundle == null) return;
        String callId = extractCallId(bundle);

        if (channel == null) {
            synchronized (pendingCalls) {
                for (Bundle b : pendingCalls) {
                    if (extractCallId(b).equals(callId)) {
                        return;
                    }
                }
                pendingCalls.add(bundle);
            }
            return;
        }
        deliverToFlutter(bundle);
    }

    private static void flushPending() {
        List<Bundle> copy;
        synchronized (pendingCalls) {
            copy = new ArrayList<>(pendingCalls);
            pendingCalls.clear();
        }
        for (Bundle b : copy) deliverToFlutter(b);
    }

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
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
                        b.putString("callId",     safeStr(m.get("callId")));
                        b.putString("callerId",   safeStr(m.get("callerId")));
                        b.putString("callerName", safeStr(m.get("callerName")));
                        b.putString("callType",   safeStr(m.get("callType")));
                        b.putString("avatarUrl",  safeStr(m.get("avatarUrl")));
                        b.putBoolean("isGroup",   "1".equals(safeStr(m.get("isGroup"))) || Boolean.TRUE.equals(m.get("isGroup")));
                        b.putString("members",    safeStr(m.get("members")));
                        b.putString("recipientID",safeStr(m.get("recipientID")));

                        showIncomingCallNotification(MainActivity.this, b);
                        enqueueIncomingCall(b);

                        result.success(true);
                    } catch (Exception e) {
                        result.error("ERR", e.getMessage(), null);
                    }
                    return;
                }

                // 👉 actions déclenchées depuis l’UI Flutter
                if ("ui_accept".equals(call.method)) {
                    try {
                        Map<String, Object> m = (Map<String, Object>) call.arguments;
                        String callId = safeStr(m.get("callId"));
                        cancelIncomingById(MainActivity.this, callId); // stop timer + dismiss notif
                        result.success(true);
                    } catch (Exception e) {
                        result.error("ERR", e.getMessage(), null);
                    }
                    return;
                }

                if ("ui_reject".equals(call.method)) {
                    try {
                        Map<String, Object> m = (Map<String, Object>) call.arguments;
                        Bundle b = new Bundle();
                        b.putString("callId",     safeStr(m.get("callId")));
                        b.putString("callerId",   safeStr(m.get("callerId")));
                        b.putString("callerName", safeStr(m.get("callerName")));
                        b.putString("avatarUrl",  safeStr(m.get("avatarUrl")));

                        // On continue d'utiliser le receiver pour l'affichage "Appel refusé"
                        Intent br = new Intent(MainActivity.this, CallActionReceiver.class)
                                .setAction(MyFirebaseMessagingService.ACTION_REJECT)
                                .putExtras(b);
                        sendBroadcast(br);
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

                result.notImplemented();
            }
        });

        flushPending();
    }

    private static String safeStr(Object o) {
        return (o == null) ? "" : String.valueOf(o);
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        Intent it = getIntent();
        if (it != null && it.getExtras() != null) enqueueIncomingCall(it.getExtras());
    }

    @Override
    protected void onResume() {
        super.onResume();
        inForeground = true;
    }

    @Override
    protected void onPause() {
        inForeground = false;
        super.onPause();
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        Bundle extras = intent.getExtras();
        if (extras != null) enqueueIncomingCall(extras);
    }

    private static int notificationIdFor(String callId) {
        return (callId == null) ? 0 : callId.hashCode();
    }

    // ===== Helpers notif / timer =====

    private static int requestCodeFor(String callId, int salt) {
        int base = (callId == null ? 0 : callId.hashCode());
        return base ^ (salt * 31);
    }

    /** Annule le timer de timeout + la notification "ringing" pour ce callId. */
    private static void cancelIncomingById(Context ctx, String callId) {
        if (callId == null || callId.isEmpty()) return;

        // Annuler l'AlarmManager (ACTION_TIMEOUT)
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

        // Fermer la notif "ringing"
        NotificationManager nm = (NotificationManager) ctx.getSystemService(Context.NOTIFICATION_SERVICE);
        nm.cancel(notificationIdFor(callId));
    }

    private static void ensureCallsChannelWithRingtone(Context ctx) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationManager nm = (NotificationManager) ctx.getSystemService(Context.NOTIFICATION_SERVICE);
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

    /** Notif locale (quand Socket reçoit en background). */
    private static void showIncomingCallNotification(Activity activity, Bundle b) {
        ensureCallsChannelWithRingtone(activity);

        String callId     = b.getString("callId", "");
        String callerName = b.getString("callerName", "Unknown");

        Intent inCall = new Intent(activity, IncomingCallActivity.class);
        inCall.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
        inCall.putExtras(b);

        // Full screen & tap => IMMUTABLE
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

        // ✅ Actions => ouvrir IncomingCallActivity avec autoAccept/autoReject
        Intent accept = new Intent(activity, IncomingCallActivity.class)
                .setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP)
                .putExtras(b);
        accept.putExtra("autoAccept", true);
        PendingIntent acceptPI = PendingIntent.getActivity(
                activity,
                (callId.hashCode() ^ (10 * 31)),
                accept,
                (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
                        ? (PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE)
                        : PendingIntent.FLAG_UPDATE_CURRENT
        );

        Intent reject = new Intent(activity, IncomingCallActivity.class)
                .setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP)
                .putExtras(b);
        reject.putExtra("autoReject", true);
        PendingIntent rejectPI = PendingIntent.getActivity(
                activity,
                (callId.hashCode() ^ (20 * 31)),
                reject,
                (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
                        ? (PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE)
                        : PendingIntent.FLAG_UPDATE_CURRENT
        );

        NotificationCompat.Builder nb = new NotificationCompat.Builder(activity, CALLS_CHANNEL_ID)
                .setSmallIcon(android.R.drawable.stat_sys_phone_call)
                .setContentTitle("Appel entrant")
                .setContentText(callerName.isEmpty() ? "Inconnu" : callerName)
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setCategory(NotificationCompat.CATEGORY_CALL)
                .setOngoing(true)
                .setAutoCancel(false)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setFullScreenIntent(fsPending, true)
                .setContentIntent(tapPending)
                .addAction(new NotificationCompat.Action(
                        android.R.drawable.ic_menu_call, "ACCEPTER", acceptPI))
                .addAction(new NotificationCompat.Action(
                        android.R.drawable.ic_menu_close_clear_cancel, "REFUSER", rejectPI));

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            Uri ringUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE);
            nb.setSound(ringUri);
        }

        Notification n = nb.build();
        NotificationManager nm = (NotificationManager) activity.getSystemService(Context.NOTIFICATION_SERVICE);
        nm.notify(notificationIdFor(callId), n);
    }
}
