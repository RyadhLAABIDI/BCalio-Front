package com.elite.bcalio;

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

public class MyFirebaseMessagingService extends FirebaseMessagingService {

    static final String CHANNEL_ID = "calls";
    private static boolean channelEnsured = false;

    public static final String ACTION_ACCEPT          = "com.elite.bcalio.ACTION_ACCEPT_CALL";
    public static final String ACTION_REJECT          = "com.elite.bcalio.ACTION_REJECT_CALL";
    public static final String ACTION_TIMEOUT         = "com.elite.bcalio.ACTION_TIMEOUT_CALL";
    // 👇 NEW: utilisé quand l’utilisateur “swipe” pour fermer la notif d’appel entrant
    public static final String ACTION_INCOMING_DELETE = "com.elite.bcalio.ACTION_INCOMING_DELETE";

    private static final long MISSED_CALL_AFTER_MS = 30_000L;

    private static final String PREFS_CALLS = "bcalio_calls";
    private static String KEY_ID(String callId)   { return "id_" + callId; }
    private static String KEY_NAME(String callId) { return "n_" + callId; }
    private static String KEY_AVA(String callId)  { return "a_" + callId; }

    @Override
    public void onMessageReceived(RemoteMessage msg) {
        if (msg.getData() == null || msg.getData().isEmpty()) return;

        String type = msg.getData().get("type");
        if (type == null) return;

        if ("incoming_call".equals(type)) {
            handleIncomingCall(msg);
        } else if ("call_cancel".equals(type)) {
            handleCallCancelOrTimeout(msg);   // ← transforme en “Appel manqué”
        } else if ("call_timeout".equals(type)) {
            handleCallCancelOrTimeout(msg);   // ← idem
        }
    }

    private void handleIncomingCall(RemoteMessage msg) {
        String callId     = orEmpty(msg.getData().get("callId"));
        String callerId   = orEmpty(msg.getData().get("callerId"));
        String callerName = orEmpty(msg.getData().get("callerName"));
        String callType   = orEmpty(msg.getData().get("callType"));
        String avatarUrl  = orEmpty(msg.getData().get("avatarUrl"));
        boolean isGroup   = "1".equals(msg.getData().get("isGroup"));
        String members    = orEmpty(msg.getData().get("members"));

        // mémorise pour fallback (si “cancel/timeout/delete” push arrive sans détails)
        saveCallMeta(callId, callerId, callerName, avatarUrl);

        Bundle b = new Bundle();
        b.putString("callId", callId);
        b.putString("callerId", callerId);
        b.putString("callerName", callerName);
        b.putString("callType", callType);
        b.putString("avatarUrl", avatarUrl);
        b.putBoolean("isGroup", isGroup);
        b.putString("members", members);
        b.putString("recipientID", "");

        ensureCallsChannelWithRingtone(CHANNEL_ID);

        Intent inCall = new Intent(this, IncomingCallActivity.class)
                .setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP)
                .putExtras(b);

        PendingIntent fullScreenPI = PendingIntent.getActivity(
                this, requestCodeFor(callId, 1), inCall, piFlagsImmutable());
        PendingIntent contentPI    = PendingIntent.getActivity(
                this, requestCodeFor(callId, 2), inCall, piFlagsImmutable());

        // 👇 deleteIntent: si l’utilisateur “swipe” la notif, on poste un “Appel manqué”
        Intent del = new Intent(this, CallActionReceiver.class)
                .setAction(ACTION_INCOMING_DELETE)
                .putExtras(b);
        PendingIntent deletePI = PendingIntent.getBroadcast(
                this, requestCodeFor(callId, 3), del, piFlagsImmutable());

        Bitmap large  = tryLoadBitmap(avatarUrl); // OK si l’image répond vite ; sinon, enlève-le.
        Uri ringUri   = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE);
        String title  = "Appel entrant";
        String text   = (callerName == null || callerName.trim().isEmpty()) ? "Inconnu" : callerName;

        NotificationCompat.Builder nb = new NotificationCompat.Builder(this, CHANNEL_ID)
                .setSmallIcon(android.R.drawable.stat_sys_phone_call)
                .setContentTitle(title)
                .setContentText(text)
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setCategory(NotificationCompat.CATEGORY_CALL)
                .setOngoing(true)
                .setAutoCancel(false)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setFullScreenIntent(fullScreenPI, true)
                .setContentIntent(contentPI)
                .setDeleteIntent(deletePI)                              // 👈 important
                .setTimeoutAfter(MISSED_CALL_AFTER_MS + 1500);         // filet de sécu

        if (large != null) nb.setLargeIcon(large);
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) nb.setSound(ringUri);

        Notification n = nb.build();
        NotificationManager nm = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
        nm.notify(notificationId(callId), n);

        // timer local → ACTION_TIMEOUT (affiche “Appel manqué” + coupe la sonnerie)
        scheduleTimeoutAlarm(callId, b);

        // remonte aussi vers Flutter si l’app est/front
        MainActivity.enqueueIncomingCall(b);
    }

    /** Transforme la notif courante en "Appel manqué" et coupe la sonnerie. */
    private void handleCallCancelOrTimeout(RemoteMessage msg) {
        String callId = orEmpty(msg.getData().get("callId"));
        if (callId.isEmpty()) return;

        cancelTimeoutAlarm(callId);

        String callerId   = orEmpty(msg.getData().get("callerId"));
        String callerName = orEmpty(msg.getData().get("callerName"));
        String avatarUrl  = orEmpty(msg.getData().get("avatarUrl"));
        if (callerId.isEmpty() || callerName.isEmpty() || avatarUrl.isEmpty()) {
            SharedPreferences sp = getSharedPreferences(PREFS_CALLS, MODE_PRIVATE);
            if (callerId.isEmpty())   callerId   = orEmpty(sp.getString(KEY_ID(callId),   ""));
            if (callerName.isEmpty()) callerName = orEmpty(sp.getString(KEY_NAME(callId), ""));
            if (avatarUrl.isEmpty())  avatarUrl  = orEmpty(sp.getString(KEY_AVA(callId),  ""));
        }

        cancelNotification(callId);

        Bundle b = new Bundle();
        b.putString("callId", callId);
        b.putString("callerId", callerId);
        b.putString("callerName", callerName);
        b.putString("avatarUrl", avatarUrl);

        Intent br = new Intent(this, CallActionReceiver.class)
                .setAction(ACTION_TIMEOUT)
                .putExtras(b);
        sendBroadcast(br);

        clearCallMeta(callId);
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

    private int notificationId(String callId) {
        return callId == null ? 0 : callId.hashCode();
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

    private void ensureCallsChannelWithRingtone(String id) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            if (channelEnsured) return;
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
            channelEnsured = true;
        }
    }

    private void saveCallMeta(String callId, String callerId, String callerName, String avatarUrl) {
        if (callId == null || callId.isEmpty()) return;
        SharedPreferences sp = getSharedPreferences(PREFS_CALLS, MODE_PRIVATE);
        sp.edit()
          .putString(KEY_ID(callId),   callerId   == null ? "" : callerId)
          .putString(KEY_NAME(callId), callerName == null ? "" : callerName)
          .putString(KEY_AVA(callId),  avatarUrl  == null ? "" : avatarUrl)
          .apply();
    }

    private void clearCallMeta(String callId) {
        if (callId == null || callId.isEmpty()) return;
        SharedPreferences sp = getSharedPreferences(PREFS_CALLS, MODE_PRIVATE);
        sp.edit()
          .remove(KEY_ID(callId))
          .remove(KEY_NAME(callId))
          .remove(KEY_AVA(callId))
          .apply();
    }
}
