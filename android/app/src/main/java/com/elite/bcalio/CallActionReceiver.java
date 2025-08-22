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

/**
 * Remplace la notif "Appel entrant" par:
 *  - "Appel refusé" (ACTION_REJECT)
 *  - "Appel manqué" (ACTION_TIMEOUT / call_cancel)
 * Coupe la sonnerie en annulant la notif en cours et bascule sur un channel silencieux.
 * Avatar: uniquement si déjà en cache local (content://, file://, chemin absolu). AUCUN DL réseau.
 */
public class CallActionReceiver extends BroadcastReceiver {

    // Channel silencieux pour "Appel manqué" / "Appel refusé"
    private static final String MISSED_CHANNEL_ID = "calls_missed";

    // Méta pour rappel des infos si l’app est tuée
    private static final String PREFS_CALLS = "bcalio_calls";
    private static String KEY_ID(String callId)     { return "id_" + callId; }
    private static String KEY_NAME(String callId)   { return "n_" + callId; }
    private static String KEY_AVA(String callId)    { return "a_" + callId; }
    private static String KEY_PHONE(String callId)  { return "p_" + callId; }
    private static String KEY_STATUS(String callId) { return "s_" + callId; }
    private static final String STATUS_ACCEPTED = "accepted";
    private static final String STATUS_REJECTED = "rejected";
    private static final String STATUS_TIMEOUT  = "timeout";

    /** ID utilisé pour la notif "ringing" (même que le service) */
    private static int ringingId(String callId) {
        return (callId == null) ? 0 : callId.hashCode();
    }

    /** ID séparé pour les notifs "manqué/refusé" → évite les cancel involontaires */
    private static int missedId(String callId) {
        return (callId == null) ? 1 : (callId.hashCode() ^ 0x5A5A5A5A);
    }

    @Override
    public void onReceive(Context ctx, Intent intent) {
        if (intent == null || intent.getAction() == null) return;

        String action = intent.getAction();
        Bundle extras = intent.getExtras() != null ? intent.getExtras() : new Bundle();

        String callId      = extras.getString("callId", "");
        String callerId    = extras.getString("callerId", "");
        String callerName  = extras.getString("callerName", "Unknown");
        String avatarUrl   = extras.getString("avatarUrl", "");
        String callerPhone = extras.getString("callerPhone", "");

        // Fallback depuis prefs si extras incomplets
        if (isEmpty(callerId) || isEmpty(callerName) || isEmpty(avatarUrl) || isEmpty(callerPhone)) {
            SharedPreferences sp = ctx.getSharedPreferences(PREFS_CALLS, Context.MODE_PRIVATE);
            if (isEmpty(callerId))     callerId     = orEmpty(sp.getString(KEY_ID(callId),   ""));
            if (isEmpty(callerName))   callerName   = orEmpty(sp.getString(KEY_NAME(callId), ""));
            if (isEmpty(avatarUrl))    avatarUrl    = orEmpty(sp.getString(KEY_AVA(callId),  ""));
            if (isEmpty(callerPhone))  callerPhone  = orEmpty(sp.getString(KEY_PHONE(callId),""));
        }

        String displayName = (!isEmpty(callerName)) ? callerName : callerId;
        String line2 = (!isEmpty(callerPhone)) ? callerPhone : callerId;

        NotificationManager nm = (NotificationManager) ctx.getSystemService(Context.NOTIFICATION_SERVICE);

        if (MyFirebaseMessagingService.ACTION_ACCEPT.equals(action)) {
            // marquer accepté (anti "Appel manqué" ultérieur)
            ctx.getSharedPreferences(PREFS_CALLS, Context.MODE_PRIVATE)
               .edit().putString(KEY_STATUS(callId), STATUS_ACCEPTED).apply();

            // coupe timer + ferme la notif "ringing"
            cancelTimeoutAlarm(ctx, callId);
            nm.cancel(ringingId(callId));
            return;
        }

        if (MyFirebaseMessagingService.ACTION_REJECT.equals(action)) {
            // marquer rejeté (anti "manqué" doublon)
            ctx.getSharedPreferences(PREFS_CALLS, Context.MODE_PRIVATE)
               .edit().putString(KEY_STATUS(callId), STATUS_REJECTED).apply();

            // 1) coupe le timer
            cancelTimeoutAlarm(ctx, callId);
            // 2) ferme la notif "ringing" (coupe la sonnerie)
            nm.cancel(ringingId(callId));
            // 3) affiche "Appel refusé" (silencieux) avec **ID distinct**
            ensureMissedChannel(ctx);

            NotificationCompat.Builder nb = new NotificationCompat.Builder(ctx, MISSED_CHANNEL_ID)
                    .setSmallIcon(android.R.drawable.stat_sys_phone_call)
                    .setContentTitle("Appel refusé")
                    .setContentText(displayName)
                    .setStyle(new NotificationCompat.BigTextStyle().bigText(displayName + "\n" + line2))
                    .setOnlyAlertOnce(true)
                    .setPriority(NotificationCompat.PRIORITY_DEFAULT)
                    .setCategory(NotificationCompat.CATEGORY_CALL)
                    .setOngoing(false)
                    .setAutoCancel(true)
                    .setVisibility(NotificationCompat.VISIBILITY_PUBLIC);

            Bitmap large = tryLoadBitmapLocal(ctx, avatarUrl);
            if (large != null) nb.setLargeIcon(large);

            nm.notify(missedId(callId), nb.build());
            return;
        }

        if (MyFirebaseMessagingService.ACTION_TIMEOUT.equals(action)) {
            // Marque l'appel comme "terminé (timeout)"
            ctx.getSharedPreferences(PREFS_CALLS, Context.MODE_PRIVATE)
               .edit().putString(KEY_STATUS(callId), STATUS_TIMEOUT).apply();

            // 1) ferme la notif "ringing"
            nm.cancel(ringingId(callId));
            // 2) affiche "Appel manqué" (silencieux) avec **ID distinct**
            ensureMissedChannel(ctx);

            NotificationCompat.Builder nb = new NotificationCompat.Builder(ctx, MISSED_CHANNEL_ID)
                    .setSmallIcon(android.R.drawable.stat_notify_missed_call)
                    .setContentTitle("Appel manqué")
                    .setContentText(displayName)
                    .setStyle(new NotificationCompat.BigTextStyle().bigText(displayName + "\n" + line2))
                    .setOnlyAlertOnce(true)
                    .setPriority(NotificationCompat.PRIORITY_DEFAULT)
                    .setCategory(NotificationCompat.CATEGORY_CALL)
                    .setOngoing(false)
                    .setAutoCancel(true)
                    .setVisibility(NotificationCompat.VISIBILITY_PUBLIC);

            Bitmap large = tryLoadBitmapLocal(ctx, avatarUrl);
            if (large != null) nb.setLargeIcon(large);

            nm.notify(missedId(callId), nb.build());

            // Nettoyage partiel (on conserve le STATUS)
            SharedPreferences sp = ctx.getSharedPreferences(PREFS_CALLS, Context.MODE_PRIVATE);
            sp.edit()
              .remove(KEY_ID(callId))
              .remove(KEY_NAME(callId))
              .remove(KEY_AVA(callId))
              .remove(KEY_PHONE(callId))
              .apply();
        }
    }

    /* ============================================================
     * Helpers
     * ============================================================ */

    /** Crée (au besoin) le channel silencieux pour les "missed/refused". */
    private static void ensureMissedChannel(Context ctx) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationManager nm = (NotificationManager) ctx.getSystemService(Context.NOTIFICATION_SERVICE);
            NotificationChannel ch = nm.getNotificationChannel(MISSED_CHANNEL_ID);
            if (ch == null) {
                ch = new NotificationChannel(
                        MISSED_CHANNEL_ID,
                        "Missed Calls",
                        NotificationManager.IMPORTANCE_DEFAULT
                );
                ch.setDescription("Missed/Refused call notifications (silent)");
                ch.setSound(null, null);
                ch.enableVibration(false);
                nm.createNotificationChannel(ch);
            }
        }
    }

    /** Annule l’AlarmManager du timeout pour ce callId. */
    private static void cancelTimeoutAlarm(Context ctx, String callId) {
        if (isEmpty(callId)) return;
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

    /** Charge un bitmap UNIQUEMENT si l’URI est locale (content://, file://, /…). Pas de réseau. */
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
            return null;
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

    private static String orEmpty(String s) { return s == null ? "" : s; }
    private static boolean isEmpty(String s) { return s == null || s.trim().isEmpty(); }
}
