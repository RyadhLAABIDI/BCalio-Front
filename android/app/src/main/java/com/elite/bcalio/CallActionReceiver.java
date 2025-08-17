package com.elite.bcalio;

import android.app.AlarmManager;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.graphics.Bitmap;
import android.os.Build;
import android.os.Bundle;

import androidx.core.app.NotificationCompat;

import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URL;

public class CallActionReceiver extends BroadcastReceiver {

    @Override
    public void onReceive(Context ctx, Intent intent) {
        if (intent == null || intent.getAction() == null) return;

        String action = intent.getAction();
        Bundle extras = intent.getExtras() != null ? intent.getExtras() : new Bundle();

        String callId     = extras.getString("callId", "");
        String callerId   = extras.getString("callerId", "");
        String callerName = extras.getString("callerName", "Unknown");
        String avatarUrl  = extras.getString("avatarUrl", "");

        String displayName = (callerName != null && !callerName.trim().isEmpty())
                ? callerName : callerId;

        int notifId = callId.hashCode();
        NotificationManager nm = (NotificationManager) ctx.getSystemService(Context.NOTIFICATION_SERVICE);

        if (MyFirebaseMessagingService.ACTION_ACCEPT.equals(action)) {
            // On n’utilise plus le receiver pour ACCEPT via notif,
            // mais on garde ce chemin si jamais on l’appelle depuis ailleurs.
            cancelTimeoutAlarm(ctx, callId);
            nm.cancel(notifId);

            Bundle b = new Bundle(extras);
            b.putBoolean("autoAccept", true);
            Intent open = new Intent(ctx, IncomingCallActivity.class);
            open.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
            open.putExtras(b);
            ctx.startActivity(open);

        } else if (MyFirebaseMessagingService.ACTION_REJECT.equals(action)) {
            cancelTimeoutAlarm(ctx, callId);

            NotificationCompat.Builder nb = new NotificationCompat.Builder(ctx, MyFirebaseMessagingService.CHANNEL_ID)
                    .setSmallIcon(android.R.drawable.stat_sys_phone_call)
                    .setContentTitle("Appel refusé")
                    .setContentText(displayName)
                    .setPriority(NotificationCompat.PRIORITY_HIGH)
                    .setCategory(NotificationCompat.CATEGORY_CALL)
                    .setOngoing(false)
                    .setAutoCancel(true)
                    .setVisibility(NotificationCompat.VISIBILITY_PUBLIC);

            nm.notify(notifId, nb.build());

            Bundle b = new Bundle(extras);
            b.putBoolean("autoReject", true);
            Intent open = new Intent(ctx, MainActivity.class);
            open.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_SINGLE_TOP);
            open.putExtras(b);
            ctx.startActivity(open);

        } else if (MyFirebaseMessagingService.ACTION_TIMEOUT.equals(action)) {
            NotificationCompat.Builder nb = new NotificationCompat.Builder(ctx, MyFirebaseMessagingService.CHANNEL_ID)
                    .setSmallIcon(android.R.drawable.stat_notify_missed_call)
                    .setContentTitle("Appel manqué")
                    .setContentText(displayName)
                    .setPriority(NotificationCompat.PRIORITY_DEFAULT)
                    .setCategory(NotificationCompat.CATEGORY_CALL)
                    .setOngoing(false)
                    .setAutoCancel(true)
                    .setVisibility(NotificationCompat.VISIBILITY_PUBLIC);

            Bitmap large = tryLoadBitmap(avatarUrl);
            if (large != null) nb.setLargeIcon(large);

            nm.notify(notifId, nb.build());
        }
    }

    private void cancelTimeoutAlarm(Context ctx, String callId) {
        if (callId == null || callId.isEmpty()) return;
        Intent i = new Intent(ctx, CallActionReceiver.class)
                .setAction(MyFirebaseMessagingService.ACTION_TIMEOUT);
        PendingIntent pi = PendingIntent.getBroadcast(
                ctx,
                requestCodeFor(callId, 99),
                i,
                pendingIntentFlagsCompat()
        );
        AlarmManager am = (AlarmManager) ctx.getSystemService(Context.ALARM_SERVICE);
        if (am != null) am.cancel(pi);
    }

    private int requestCodeFor(String callId, int salt) {
        int base = (callId == null ? 0 : callId.hashCode());
        return base ^ (salt * 31);
    }

    private int pendingIntentFlagsCompat() {
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.M
                ? PendingIntent.FLAG_IMMUTABLE
                : 0;
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
                return android.graphics.BitmapFactory.decodeStream(is);
            }
        } catch (Exception ignored) {
        } finally {
            if (conn != null) conn.disconnect();
        }
        return null;
    }
}
