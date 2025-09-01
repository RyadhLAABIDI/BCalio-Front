package com.elite.bcalio.app;

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
import android.media.RingtoneManager;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;

import androidx.core.app.NotificationCompat;

import com.google.firebase.messaging.FirebaseMessagingService;
import com.google.firebase.messaging.RemoteMessage;

import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;
import java.util.TimeZone;

/**
 * ⚠️ Ne pas toucher à la logique de base — correctif: marquage "timeout" persistant
 * + timestamp d'arrivée pour empêcher l’ouverture d’UI fantôme après cancel/timeout.
 */
public class MyFirebaseMessagingService extends FirebaseMessagingService {

    /* ======== CANAUX ======== */
    static final String CHANNEL_ID_CALLS = "calls";
    static final String CHANNEL_ID_MSG   = "messages";
    private static boolean callChannelEnsured = false;
    private static boolean msgChannelEnsured  = false;

    /* ======== INTENTS APPELS ======== */
    public static final String ACTION_ACCEPT          = "com.elite.bcalio.app.ACTION_ACCEPT_CALL";
    public static final String ACTION_REJECT          = "com.elite.bcalio.app.ACTION_REJECT_CALL";
    public static final String ACTION_TIMEOUT         = "com.elite.bcalio.app.ACTION_TIMEOUT_CALL";
    public static final String ACTION_INCOMING_DELETE = "com.elite.bcalio.app.ACTION_INCOMING_DELETE";

    private static final long MISSED_CALL_AFTER_MS = 30_000L;

    private static final String PREFS_CALLS = "bcalio_calls";
    private static String KEY_ID(String callId)     { return "id_" + callId; }
    private static String KEY_NAME(String callId)   { return "n_" + callId; }
    private static String KEY_AVA(String callId)    { return "a_" + callId; }
    private static String KEY_PHONE(String callId)  { return "p_" + callId; }
    private static String KEY_STATUS(String callId) { return "s_" + callId; }
    private static String KEY_TS(String callId)     { return "t_" + callId; } // 👈 NEW
    private static final String STATUS_ACCEPTED = "accepted";
    private static final String STATUS_REJECTED = "rejected";
    private static final String STATUS_TIMEOUT  = "timeout";

    @Override
    public void onMessageReceived(RemoteMessage msg) {
        if (msg.getData() == null || msg.getData().isEmpty()) return;

        String type = msg.getData().get("type");
        if (type == null) return;

        switch (type) {
            case "incoming_call":
                handleIncomingCall(msg);
                break;
            case "call_cancel":
            case "call_timeout":
                handleCallCancelOrTimeout(msg);
                break;
            case "chat_message":
                handleChatMessage(msg);
                break;
        }
    }

    /* =========================================================
     * ======================  CALLS  ==========================
     * ========================================================= */
    private void handleIncomingCall(RemoteMessage msg) {
        String callId      = orEmpty(msg.getData().get("callId"));
        String callerId    = orEmpty(msg.getData().get("callerId"));
        String callerName  = orEmpty(msg.getData().get("callerName"));
        String callType    = orEmpty(msg.getData().get("callType"));
        String avatarUrl   = orEmpty(msg.getData().get("avatarUrl"));
        String callerPhone = orEmpty(msg.getData().get("callerPhone"));
        boolean isGroup    = "1".equals(msg.getData().get("isGroup")) || "true".equalsIgnoreCase(orEmpty(msg.getData().get("isGroup")));
        String members     = orEmpty(msg.getData().get("members"));

        saveCallMeta(callId, callerId, callerName, avatarUrl, callerPhone);

        Bundle b = new Bundle();
        b.putString("callId", callId);
        b.putString("callerId", callerId);
        b.putString("callerName", callerName);
        b.putString("callType", callType);
        b.putString("avatarUrl", avatarUrl);
        b.putString("callerPhone", callerPhone);
        b.putBoolean("isGroup", isGroup);
        b.putString("members", members);
        b.putString("recipientID", "");

        if (MainActivity.isInForeground()) {
            MainActivity.enqueueIncomingCall(b);
            return;
        }

        ensureCallsChannelWithRingtone(CHANNEL_ID_CALLS);

        Intent inCall = new Intent(this, IncomingCallActivity.class)
                .setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP)
                .putExtras(b);

        PendingIntent fullScreenPI = PendingIntent.getActivity(
                this, requestCodeFor(callId, 1), inCall, piFlagsImmutable());
        PendingIntent contentPI    = PendingIntent.getActivity(
                this, requestCodeFor(callId, 2), inCall, piFlagsImmutable());

        Intent del = new Intent(this, CallActionReceiver.class)
                .setAction(ACTION_INCOMING_DELETE)
                .putExtras(b);
        PendingIntent deletePI = PendingIntent.getBroadcast(
                this, requestCodeFor(callId, 3), del, piFlagsImmutable());

        Bitmap large  = tryLoadBitmap(avatarUrl);
        Uri ringUri   = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE);
        String title  = "Appel entrant";
        String displayName = (callerName == null || callerName.trim().isEmpty()) ? "Inconnu" : callerName;
        String phoneOrId   = (callerPhone == null || callerPhone.trim().isEmpty()) ? callerId : callerPhone;

        NotificationCompat.Builder nb = new NotificationCompat.Builder(this, CHANNEL_ID_CALLS)
                .setSmallIcon(android.R.drawable.stat_sys_phone_call)
                .setContentTitle(title)
                .setContentText(displayName)
                .setStyle(new NotificationCompat.BigTextStyle().bigText(displayName + "\n" + phoneOrId))
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setCategory(NotificationCompat.CATEGORY_CALL)
                .setOngoing(true)
                .setAutoCancel(false)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setFullScreenIntent(fullScreenPI, true)
                .setContentIntent(contentPI)
                .setDeleteIntent(deletePI)
                .setTimeoutAfter(MISSED_CALL_AFTER_MS + 1500);

        if (large != null) nb.setLargeIcon(large);
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) nb.setSound(ringUri);

        NotificationManager nm = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
        nm.notify(notificationId(callId), nb.build());

        scheduleTimeoutAlarm(callId, b);
        MainActivity.enqueueIncomingCall(b);
    }

    private void handleCallCancelOrTimeout(RemoteMessage msg) {
        String callId = orEmpty(msg.getData().get("callId"));
        if (callId.isEmpty()) return;

        cancelTimeoutAlarm(callId);

        SharedPreferences sp = getSharedPreferences(PREFS_CALLS, MODE_PRIVATE);
        String st = sp.getString(KEY_STATUS(callId), "");
        if (STATUS_ACCEPTED.equals(st) || STATUS_REJECTED.equals(st)) {
            cancelNotification(callId);
            clearCallMeta(callId);
            return;
        }

        String callerId    = orEmpty(msg.getData().get("callerId"));
        String callerName  = orEmpty(msg.getData().get("callerName"));
        String avatarUrl   = orEmpty(msg.getData().get("avatarUrl"));
        String callerPhone = orEmpty(msg.getData().get("callerPhone"));
        if (callerId.isEmpty() || callerName.isEmpty() || avatarUrl.isEmpty() || callerPhone.isEmpty()) {
            if (callerId.isEmpty())    callerId    = orEmpty(sp.getString(KEY_ID(callId),   ""));
            if (callerName.isEmpty())  callerName  = orEmpty(sp.getString(KEY_NAME(callId), ""));
            if (avatarUrl.isEmpty())   avatarUrl   = orEmpty(sp.getString(KEY_AVA(callId),  ""));
            if (callerPhone.isEmpty()) callerPhone = orEmpty(sp.getString(KEY_PHONE(callId),""));
        }

        cancelNotification(callId);

        // ✅ Marque "timeout" pour bloquer toute ouverture d’UI ultérieure
        sp.edit().putString(KEY_STATUS(callId), STATUS_TIMEOUT).apply();

        Bundle b = new Bundle();
        b.putString("callId", callId);
        b.putString("callerId", callerId);
        b.putString("callerName", callerName);
        b.putString("avatarUrl", avatarUrl);
        b.putString("callerPhone", callerPhone);

        Intent br = new Intent(this, CallActionReceiver.class)
                .setAction(ACTION_TIMEOUT)
                .putExtras(b);
        sendBroadcast(br);

        // Nettoyage partiel — on garde le STATUS
        clearCallMetaExceptStatus(callId);
    }

    private void scheduleTimeoutAlarm(String callId, Bundle b) {
        if (callId == null || callId.isEmpty()) return;
        Intent i = new Intent(this, CallActionReceiver.class).setAction(ACTION_TIMEOUT);
        i.putExtras(b);
        PendingIntent pi = PendingIntent.getBroadcast(
                this, requestCodeFor(callId, 99), i,
                PendingIntent.FLAG_UPDATE_CURRENT | pendingIntentFlagsCompat());
        long triggerAt = System.currentTimeMillis() + MISSED_CALL_AFTER_MS;

        AlarmManager am = (AlarmManager) getSystemService(Context.ALARM_SERVICE);
        if (am == null) return;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pi);
        } else {
            am.setExact(AlarmManager.RTC_WAKEUP, triggerAt, pi);
        }
    }

    private void cancelTimeoutAlarm(String callId) {
        if (callId == null || callId.isEmpty()) return;
        Intent i = new Intent(this, CallActionReceiver.class).setAction(ACTION_TIMEOUT);
        PendingIntent pi = PendingIntent.getBroadcast(
                this, requestCodeFor(callId, 99), i,
                PendingIntent.FLAG_CANCEL_CURRENT | pendingIntentFlagsCompat());
        AlarmManager am = (AlarmManager) getSystemService(Context.ALARM_SERVICE);
        if (am != null) am.cancel(pi);
    }

    /* =========================================================
     * ===================  CHAT MESSAGES  =====================
     * ========================================================= */
    private void handleChatMessage(RemoteMessage msg) {
        if (MainActivity.isInForeground()) return;

        String roomId      = orEmpty(msg.getData().get("roomId"));
        String messageId   = orEmpty(msg.getData().get("messageId"));
        String fromId      = orEmpty(msg.getData().get("fromId"));
        String fromName    = orEmpty(msg.getData().get("fromName"));
        String avatarUrl   = orEmpty(msg.getData().get("avatarUrl"));
        String text        = orEmpty(msg.getData().get("text"));
        String sentAt      = orEmpty(msg.getData().get("sentAt"));
        String contentType = orEmpty(msg.getData().get("contentType"));
        boolean isGroup    = "1".equals(orEmpty(msg.getData().get("isGroup"))) || "true".equalsIgnoreCase(orEmpty(msg.getData().get("isGroup")));

        ensureMessagesChannel(CHANNEL_ID_MSG);

        Intent openChat = new Intent(this, MainActivity.class)
                .setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
        openChat.putExtra("push_kind", "chat");
        openChat.putExtra("roomId", roomId);
        openChat.putExtra("messageId", messageId);
        openChat.putExtra("fromId", fromId);
        openChat.putExtra("fromName", fromName);
        openChat.putExtra("avatarUrl", avatarUrl);
        openChat.putExtra("text", text);
        openChat.putExtra("contentType", contentType);
        openChat.putExtra("isGroup", isGroup);

        PendingIntent contentPI = PendingIntent.getActivity(
                this,
                roomId.hashCode() ^ 777,
                openChat,
                (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
                        ? (PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE)
                        : PendingIntent.FLAG_UPDATE_CURRENT
        );

        String title = (fromName == null || fromName.trim().isEmpty()) ? "Nouveau message" : fromName;
        String displayContent;
        switch ((contentType == null ? "" : contentType)) {
            case "image": displayContent = "📷 Photo"; break;
            case "audio": displayContent = "🎤 Message vocal"; break;
            case "video": displayContent = "🎬 Vidéo"; break;
            default:
                displayContent = (text == null || text.trim().isEmpty()) ? "Nouveau message" : text;
        }

        NotificationCompat.Builder nb = new NotificationCompat.Builder(this, CHANNEL_ID_MSG)
                .setSmallIcon(getSmallIconForMessages())
                .setContentTitle(title)
                .setContentText(displayContent)
                .setCategory(NotificationCompat.CATEGORY_MESSAGE)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
                .setAutoCancel(true)
                .setContentIntent(contentPI);

        Bitmap large = tryLoadBitmap(avatarUrl);
        if (large != null) nb.setLargeIcon(large);

        if ("image".equals(contentType)) {
            Bitmap picture = tryLoadBitmap(text);
            if (picture != null) {
                nb.setStyle(new NotificationCompat.BigPictureStyle()
                        .bigPicture(picture)
                        .bigLargeIcon((Bitmap) null)
                        .setSummaryText(title));
            } else {
                nb.setStyle(new NotificationCompat.BigTextStyle().bigText(displayContent));
            }
        } else if ("text".equals(contentType) || contentType.isEmpty()) {
            nb.setStyle(new NotificationCompat.BigTextStyle().bigText(displayContent));
        }

        long when = parseIsoWhen(sentAt);
        if (when > 0L) {
            nb.setWhen(when);
            nb.setShowWhen(true);
        }

        nb.setGroup("chat_" + roomId);

        NotificationManager nm = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
        nm.notify(notificationId("chat:" + roomId), nb.build());
    }

    /* ====================== Helpers communs ====================== */

    private void ensureCallsChannelWithRingtone(String id) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            if (callChannelEnsured) return;
            NotificationManager nm = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
            Uri ringUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE);
            AudioAttributes attrs = new AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build();

            NotificationChannel existing = nm.getNotificationChannel(id);
            if (existing != null) nm.deleteNotificationChannel(id);

            NotificationChannel ch = new NotificationChannel(
                    id, "Incoming Calls", NotificationManager.IMPORTANCE_HIGH);
            ch.setDescription("Incoming call notifications");
            ch.enableLights(true);
            ch.setLightColor(Color.GREEN);
            ch.enableVibration(true);
            ch.setLockscreenVisibility(Notification.VISIBILITY_PUBLIC);
            ch.setSound(ringUri, attrs);

            nm.createNotificationChannel(ch);
            callChannelEnsured = true;
        }
    }

    private void ensureMessagesChannel(String id) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            if (msgChannelEnsured) return;
            NotificationManager nm = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);

            NotificationChannel ch = new NotificationChannel(
                    id, "Messages", NotificationManager.IMPORTANCE_HIGH);
            ch.setDescription("Notifications de messages");
            ch.enableLights(true);
            ch.setLightColor(Color.CYAN);
            ch.enableVibration(true);
            ch.setLockscreenVisibility(Notification.VISIBILITY_PRIVATE); // 👈 corrige (Notification, pas Compat)
            Uri def = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION);
            AudioAttributes attrs = new AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION_COMMUNICATION_INSTANT)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build();
            ch.setSound(def, attrs);

            nm.createNotificationChannel(ch);
            msgChannelEnsured = true;
        }
    }

    private int getSmallIconForMessages() {
        return getApplicationInfo().icon != 0 ? getApplicationInfo().icon : android.R.drawable.stat_notify_more;
    }

    private Bitmap tryLoadBitmap(String url) {
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

    private void cancelNotification(String callId) {
        if (callId == null || callId.isEmpty()) return;
        NotificationManager nm = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
        nm.cancel(notificationId(callId));
    }

    private int notificationId(String key) {
        return key == null ? 0 : key.hashCode();
    }

    private int requestCodeFor(String callId, int salt) {
        int base = (callId == null ? 0 : callId.hashCode());
        return base ^ (salt * 31);
    }

    private int piFlagsImmutable() {
        int flags = PendingIntent.FLAG_UPDATE_CURRENT;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) flags |= PendingIntent.FLAG_IMMUTABLE;
        return flags;
    }

    private int pendingIntentFlagsCompat() {
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.M ? PendingIntent.FLAG_IMMUTABLE : 0;
    }

    private String orEmpty(String s) { return s == null ? "" : s; }

    private void saveCallMeta(String callId, String callerId, String callerName, String avatarUrl, String callerPhone) {
        if (callId == null || callId.isEmpty()) return;
        SharedPreferences sp = getSharedPreferences(PREFS_CALLS, MODE_PRIVATE);
        sp.edit()
          .putString(KEY_ID(callId),    callerId    == null ? "" : callerId)
          .putString(KEY_NAME(callId),  callerName  == null ? "" : callerName)
          .putString(KEY_AVA(callId),   avatarUrl   == null ? "" : avatarUrl)
          .putString(KEY_PHONE(callId), callerPhone == null ? "" : callerPhone)
          .putLong  (KEY_TS(callId),    System.currentTimeMillis()) // 👈 NEW
          .apply();
    }

    private void clearCallMeta(String callId) {
        if (callId == null || callId.isEmpty()) return;
        SharedPreferences sp = getSharedPreferences(PREFS_CALLS, MODE_PRIVATE);
        sp.edit()
          .remove(KEY_ID(callId))
          .remove(KEY_NAME(callId))
          .remove(KEY_AVA(callId))
          .remove(KEY_STATUS(callId))
          .remove(KEY_PHONE(callId))
          .remove(KEY_TS(callId)) // 👈 NEW
          .apply();
    }

    /** Nettoyage partiel: conserve KEY_STATUS pour bloquer l’UI future */
    private void clearCallMetaExceptStatus(String callId) {
        if (callId == null || callId.isEmpty()) return;
        SharedPreferences sp = getSharedPreferences(PREFS_CALLS, MODE_PRIVATE);
        sp.edit()
          .remove(KEY_ID(callId))
          .remove(KEY_NAME(callId))
          .remove(KEY_AVA(callId))
          .remove(KEY_PHONE(callId))
          .remove(KEY_TS(callId)) // 👈 NEW
          .apply();
    }

    /* ===================== Date parsing sans javax.xml.bind ===================== */

    private long parseIsoWhen(String sentAt) {
        try {
            if (sentAt == null) return 0L;
            String s = sentAt.trim();
            if (s.isEmpty()) return 0L;

            try {
                long v = Long.parseLong(s);
                if (v > 100000000000L) return v;       // ms
                if (v > 0L) return v * 1000L;          // s
            } catch (NumberFormatException ignore) {}

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                try {
                    java.time.OffsetDateTime odt = java.time.OffsetDateTime.parse(s);
                    return odt.toInstant().toEpochMilli();
                } catch (Throwable t) {
                    try {
                        java.time.ZonedDateTime zdt = java.time.ZonedDateTime.parse(s);
                        return zdt.toInstant().toEpochMilli();
                    } catch (Throwable ignore) {}
                }
            }

            return parseIsoCompat(s);
        } catch (Throwable t) {
            return 0L;
        }
    }

    private long parseIsoCompat(String iso) {
        try {
            String s = iso.trim();
            if (s.matches(".*[+-]\\d\\d:\\d\\d$")) {
                s = s.replaceAll("([+-]\\d\\d):(\\d\\d)$", "$1$2");
            }

            boolean endsWithZ  = s.endsWith("Z");
            boolean hasMillis  = s.contains(".");

            SimpleDateFormat fmt;
            if (endsWithZ) {
                fmt = new SimpleDateFormat(hasMillis ? "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'" : "yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US);
                fmt.setTimeZone(TimeZone.getTimeZone("UTC"));
            } else {
                fmt = new SimpleDateFormat(hasMillis ? "yyyy-MM-dd'T'HH:mm:ss.SSSZ" : "yyyy-MM-dd'T'HH:mm:ssZ", Locale.US);
            }

            Date d = fmt.parse(s);
            return d != null ? d.getTime() : 0L;
        } catch (Throwable t) {
            return 0L;
        }
    }
}
