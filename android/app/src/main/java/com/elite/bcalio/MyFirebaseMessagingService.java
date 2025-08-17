package com.elite.bcalio;

import android.app.AlarmManager;
import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
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

    public static final String ACTION_ACCEPT  = "com.elite.bcalio.ACTION_ACCEPT_CALL";
    public static final String ACTION_REJECT  = "com.elite.bcalio.ACTION_REJECT_CALL";
    public static final String ACTION_TIMEOUT = "com.elite.bcalio.ACTION_TIMEOUT_CALL";

    private static final long MISSED_CALL_AFTER_MS = 30_000L;

    @Override
    public void onMessageReceived(RemoteMessage msg) {
        if (msg.getData() == null || msg.getData().isEmpty()) return;

        String type = msg.getData().get("type");
        if (type == null) return;

        if ("incoming_call".equals(type)) {
            handleIncomingCall(msg);
        } else if ("call_cancel".equals(type)) {
            String callId = orEmpty(msg.getData().get("callId"));
            cancelTimeoutAlarm(callId);
            cancelNotification(callId);
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

        Intent inCall = new Intent(this, IncomingCallActivity.class);
        inCall.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
        inCall.putExtras(b);

        // Full screen / tap => IMMUTABLE
        PendingIntent fullScreenPI = PendingIntent.getActivity(
                this,
                requestCodeFor(callId, 1),
                inCall,
                piFlagsImmutable()
        );
        PendingIntent contentPI = PendingIntent.getActivity(
                this,
                requestCodeFor(callId, 2),
                inCall,
                piFlagsImmutable()
        );

        // ✅ Actions => ouvrir directement IncomingCallActivity avec autoAccept/autoReject
        Intent acceptIntent = new Intent(this, IncomingCallActivity.class)
                .setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP)
                .putExtras(b);
        acceptIntent.putExtra("autoAccept", true);
        PendingIntent acceptPI = PendingIntent.getActivity(
                this,
                requestCodeFor(callId, 10),
                acceptIntent,
                piFlagsImmutable()
        );

        Intent rejectIntent = new Intent(this, IncomingCallActivity.class)
                .setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP)
                .putExtras(b);
        rejectIntent.putExtra("autoReject", true);
        PendingIntent rejectPI = PendingIntent.getActivity(
                this,
                requestCodeFor(callId, 20),
                rejectIntent,
                piFlagsImmutable()
        );

        Bitmap large = tryLoadBitmap(avatarUrl);
        Uri ringUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE);

        String displayName = (callerName == null || callerName.trim().isEmpty())
                ? "Inconnu"
                : callerName;

        NotificationCompat.Builder nb = new NotificationCompat.Builder(this, CHANNEL_ID)
                .setSmallIcon(android.R.drawable.stat_sys_phone_call)
                .setContentTitle("Appel entrant")
                .setContentText(displayName)
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setCategory(NotificationCompat.CATEGORY_CALL)
                .setOngoing(true)
                .setAutoCancel(false)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setFullScreenIntent(fullScreenPI, true)
                .setContentIntent(contentPI)
                .addAction(new NotificationCompat.Action(
                        android.R.drawable.ic_menu_call, "ACCEPTER", acceptPI))
                .addAction(new NotificationCompat.Action(
                        android.R.drawable.ic_menu_close_clear_cancel, "REFUSER", rejectPI));

        if (large != null) nb.setLargeIcon(large);
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            nb.setSound(ringUri);
        }

        Notification n = nb.build();
        NotificationManager nm = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
        nm.notify(notificationId(callId), n);

        // timeout local 30s → "Appel manqué"
        scheduleTimeoutAlarm(callId, b);

        // push aussi à Flutter (si au 1er plan)
        MainActivity.enqueueIncomingCall(b);
    }

    private void scheduleTimeoutAlarm(String callId, Bundle b) {
        if (callId == null || callId.isEmpty()) return;
        Intent i = new Intent(this, CallActionReceiver.class).setAction(ACTION_TIMEOUT);
        i.putExtras(b);
        PendingIntent pi = PendingIntent.getBroadcast(
                this,
                requestCodeFor(callId, 99),
                i,
                PendingIntent.FLAG_UPDATE_CURRENT | pendingIntentFlagsCompat()
        );
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
                this,
                requestCodeFor(callId, 99),
                i,
                PendingIntent.FLAG_CANCEL_CURRENT | pendingIntentFlagsCompat()
        );
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

    // Immutable par défaut pour activité
    private int piFlagsImmutable() {
        int flags = PendingIntent.FLAG_UPDATE_CURRENT;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            flags |= PendingIntent.FLAG_IMMUTABLE;
        }
        return flags;
    }

    private int pendingIntentFlagsCompat() {
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.M
                ? PendingIntent.FLAG_IMMUTABLE
                : 0;
    }

    private String orEmpty(String s) {
        return s == null ? "" : s;
    }

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
            if (existing != null) {
                nm.deleteNotificationChannel(id);
            }

            NotificationChannel ch = new NotificationChannel(
                    id, "Incoming Calls", NotificationManager.IMPORTANCE_HIGH
            );
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
}
