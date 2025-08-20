package com.elite.bcalio;

import android.app.AlarmManager;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;

import androidx.core.app.NotificationCompat;

import java.io.InputStream;

public class CallActionReceiver extends BroadcastReceiver {

    private static final String MISSED_CHANNEL_ID = "calls_missed";

    private static final String PREFS_CALLS = "bcalio_calls";
    private static String KEY_ID(String callId)   { return "id_" + callId; }
    private static String KEY_NAME(String callId) { return "n_" + callId; }
    private static String KEY_AVA(String callId)  { return "a_" + callId; }

    @Override
    public void onReceive(Context ctx, Intent intent) {
        if (intent == null || intent.getAction() == null) return;

        String action = intent.getAction();
        Bundle extras = intent.getExtras() != null ? intent.getExtras() : new Bundle();

        String callId     = extras.getString("callId", "");
        String callerId   = extras.getString("callerId", "");
        String callerName = extras.getString("callerName", "Unknown");
        String avatarUrl  = extras.getString("avatarUrl", "");

        if (isEmpty(callerId) || isEmpty(callerName) || isEmpty(avatarUrl)) {
            SharedPreferences sp = ctx.getSharedPreferences(PREFS_CALLS, Context.MODE_PRIVATE);
            if (isEmpty(callerId))   callerId   = orEmpty(sp.getString(KEY_ID(callId),   ""));
            if (isEmpty(callerName)) callerName = orEmpty(sp.getString(KEY_NAME(callId), ""));
            if (isEmpty(avatarUrl))  avatarUrl  = orEmpty(sp.getString(KEY_AVA(callId),  ""));
        }

        String displayName = (!isEmpty(callerName)) ? callerName : callerId;

        int notifId = callId.hashCode();
        NotificationManager nm = (NotificationManager) ctx.getSystemService(Context.NOTIFICATION_SERVICE);

        if (MyFirebaseMessagingService.ACTION_ACCEPT.equals(action)) {
            cancelTimeoutAlarm(ctx, callId);
            nm.cancel(notifId);

            Bundle b = new Bundle(extras);
            b.putBoolean("autoAccept", true);
            Intent open = new Intent(ctx, IncomingCallActivity.class)
                    .setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP)
                    .putExtras(b);
            ctx.startActivity(open);
            return;
        }

        if (MyFirebaseMessagingService.ACTION_REJECT.equals(action)) {
            cancelTimeoutAlarm(ctx, callId);
            nm.cancel(notifId);
            ensureMissedChannel(ctx);

            NotificationCompat.Builder nb = new NotificationCompat.Builder(ctx, MISSED_CHANNEL_ID)
                    .setSmallIcon(android.R.drawable.stat_sys_phone_call)
                    .setContentTitle("Appel refusé")
                    .setContentText(displayName)
                    .setOnlyAlertOnce(true)
                    .setPriority(NotificationCompat.PRIORITY_DEFAULT)
                    .setCategory(NotificationCompat.CATEGORY_CALL)
                    .setOngoing(false)
                    .setAutoCancel(true)
                    .setVisibility(NotificationCompat.VISIBILITY_PUBLIC);

            Bitmap large = tryLoadBitmapLocal(ctx, avatarUrl);
            if (large != null) nb.setLargeIcon(large);

            nm.notify(notifId, nb.build());

            Bundle b = new Bundle(extras);
            b.putBoolean("autoReject", true);
            Intent open = new Intent(ctx, MainActivity.class)
                    .setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_SINGLE_TOP)
                    .putExtras(b);
            ctx.startActivity(open);
            return;
        }

        // 👇 NEW: “swipe to dismiss” de la notif d’appel entrant → compter comme manqué
        if (MyFirebaseMessagingService.ACTION_INCOMING_DELETE.equals(action)
                || MyFirebaseMessagingService.ACTION_TIMEOUT.equals(action)) {
            nm.cancel(notifId);
            ensureMissedChannel(ctx);

            NotificationCompat.Builder nb = new NotificationCompat.Builder(ctx, MISSED_CHANNEL_ID)
                    .setSmallIcon(android.R.drawable.stat_notify_missed_call)
                    .setContentTitle("Appel manqué")
                    .setContentText(displayName)
                    .setOnlyAlertOnce(true)
                    .setPriority(NotificationCompat.PRIORITY_DEFAULT)
                    .setCategory(NotificationCompat.CATEGORY_CALL)
                    .setOngoing(false)
                    .setAutoCancel(true)
                    .setVisibility(NotificationCompat.VISIBILITY_PUBLIC);

            Bitmap large = tryLoadBitmapLocal(ctx, avatarUrl);
            if (large != null) nb.setLargeIcon(large);

            nm.notify(notifId, nb.build());
            clearMeta(ctx, callId);
        }
    }

    private static void ensureMissedChannel(Context ctx) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationManager nm = (NotificationManager) ctx.getSystemService(Context.NOTIFICATION_SERVICE);
            NotificationChannel ch = nm.getNotificationChannel(MISSED_CHANNEL_ID);
            if (ch == null) {
                ch = new NotificationChannel(
                        MISSED_CHANNEL_ID, "Missed Calls", NotificationManager.IMPORTANCE_DEFAULT);
                ch.setDescription("Missed/Refused call notifications (silent)");
                ch.setSound(null, null);
                ch.enableVibration(false);
                nm.createNotificationChannel(ch);
            }
        }
    }

    private static void cancelTimeoutAlarm(Context ctx, String callId) {
        if (isEmpty(callId)) return;
        Intent i = new Intent(ctx, CallActionReceiver.class)
                .setAction(MyFirebaseMessagingService.ACTION_TIMEOUT);
        PendingIntent pi = PendingIntent.getBroadcast(
                ctx, requestCodeFor(callId, 99), i, pendingIntentFlagsCompat());
        AlarmManager am = (AlarmManager) ctx.getSystemService(Context.ALARM_SERVICE);
        if (am != null) am.cancel(pi);
    }

    /** Avatar: UNIQUEMENT si local (content://, file://, /…). */
    private static Bitmap tryLoadBitmapLocal(Context ctx, String uriOrPath) {
        if (isEmpty(uriOrPath)) return null;
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
            return null; // pas de DL réseau ici
        } catch (Throwable ignored) {
            return null;
        }
    }

    private static int requestCodeFor(String callId, int salt) {
        int base = (callId == null ? 0 : callId.hashCode());
        return base ^ (salt * 31);
    }

    private static int pendingIntentFlagsCompat() {
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.M
                ? PendingIntent.FLAG_IMMUTABLE
                : 0;
    }

    private static void clearMeta(Context ctx, String callId) {
        if (isEmpty(callId)) return;
        SharedPreferences sp = ctx.getSharedPreferences(PREFS_CALLS, Context.MODE_PRIVATE);
        sp.edit()
                .remove(KEY_ID(callId))
                .remove(KEY_NAME(callId))
                .remove(KEY_AVA(callId))
                .apply();
    }

    private static String orEmpty(String s) { return s == null ? "" : s; }
    private static boolean isEmpty(String s) { return s == null || s.trim().isEmpty(); }
}
