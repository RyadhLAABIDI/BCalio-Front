package com.elite.bcalio;

import android.app.Activity;
import android.app.AlarmManager;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.os.Build;
import android.os.Bundle;

public class IncomingCallActivity extends Activity {

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        // enlever l’anim pour éviter tout flash
        overridePendingTransition(0, 0);

        super.onCreate(savedInstanceState);

        Bundle extras = getIntent() != null ? getIntent().getExtras() : null;

        if (extras != null) {
            String callId = extras.getString("callId", "");

            // ✅ annule le timer "missed call" + coupe la notif "ringing"
            if (!callId.isEmpty()) {
                cancelTimeoutAlarm(this, callId);
                NotificationManager nm = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
                nm.cancel(callId.hashCode());
            }

            // Pousser l’événement vers Flutter (queue si pas prêt)
            MainActivity.enqueueIncomingCall(extras);
        }

        // Réveille / ramène l’app Flutter (elle affichera l’écran d’appel via MethodChannel)
        Intent i = new Intent(this, MainActivity.class);
        i.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_SINGLE_TOP);
        if (extras != null) i.putExtras(extras);
        startActivity(i);

        // Cette activité est juste un “pont”, on la ferme
        finish();
        overridePendingTransition(0, 0);
    }

    // ------ helper pour annuler l’AlarmManager du timeout ------
    private void cancelTimeoutAlarm(Context ctx, String callId) {
        Intent i = new Intent(ctx, CallActionReceiver.class)
                .setAction(MyFirebaseMessagingService.ACTION_TIMEOUT);
        PendingIntent pi = PendingIntent.getBroadcast(
                ctx,
                requestCodeFor(callId, 99),
                i,
                (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
                        ? PendingIntent.FLAG_IMMUTABLE
                        : 0
        );
        AlarmManager am = (AlarmManager) ctx.getSystemService(Context.ALARM_SERVICE);
        if (am != null) am.cancel(pi);
    }

    private int requestCodeFor(String callId, int salt) {
        int base = (callId == null ? 0 : callId.hashCode());
        return base ^ (salt * 31);
    }
}
