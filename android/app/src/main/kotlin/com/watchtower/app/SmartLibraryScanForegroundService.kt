package com.watchtower.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

/**
 * SmartLibraryScanForegroundService — keeps the Smart Library scan alive while
 * the user is elsewhere.
 *
 * The scan walks the whole device and can take minutes. Without a Foreground
 * Service, Android (Doze, app-standby, RAM pressure) suspends the app process
 * as soon as the screen is off or the app is backgrounded, which froze the
 * scan and the progress notification.
 *
 * Life-cycle:
 *   start()  → called by LocalIndexerNotificationService when a scan begins.
 *   stop()   → called when the scan finishes or fails.
 *
 * The visible progress notification itself is posted from Dart (flutter_local
 * _notifications), so this service only guarantees the process keeps running
 * and shows a minimal ongoing entry as required by Android for a foreground
 * service. It is START_NOT_STICKY: a scan that was interrupted is not silently
 * resumed from a stale state.
 */
class SmartLibraryScanForegroundService : Service() {

    companion object {
        /**
         * Same channel and id as the Dart-side progress notification
         * (LocalIndexerNotificationService): the foreground-service entry and
         * the progress update are the same notification, so the user sees one
         * entry whose bar advances, not two.
         */
        private const val CHANNEL_ID = "watchtower_local_indexer"
        private const val NOTIF_ID = 9903

        const val ACTION_START = "com.watchtower.app.SMART_SCAN_START"
        const val ACTION_STOP = "com.watchtower.app.SMART_SCAN_STOP"

        const val EXTRA_TITLE = "title"

        fun start(context: Context, title: String) {
            val i = Intent(context, SmartLibraryScanForegroundService::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_TITLE, title)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(i)
            } else {
                context.startService(i)
            }
        }

        fun stop(context: Context) {
            val i = Intent(context, SmartLibraryScanForegroundService::class.java).apply {
                action = ACTION_STOP
            }
            context.startService(i)
        }
    }

    private lateinit var nm: NotificationManager

    override fun onCreate() {
        super.onCreate()
        nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ch = NotificationChannel(
                CHANNEL_ID,
                "Bibliothèque locale",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Progression de l’analyse de la bibliothèque locale"
                setShowBadge(false)
            }
            nm.createNotificationChannel(ch)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopForegroundCompat()
                stopSelf()
                return START_NOT_STICKY
            }
            else -> {
                val title = intent?.getStringExtra(EXTRA_TITLE) ?: "Analyse en cours…"
                val notification = buildNotification(title)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    startForeground(
                        NOTIF_ID,
                        notification,
                        ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
                    )
                } else {
                    startForeground(NOTIF_ID, notification)
                }
                return START_NOT_STICKY
            }
        }
    }

    /** Detach from the notification without cancelling it. */
    private fun stopForegroundCompat() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_DETACH)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(false)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun buildNotification(title: String) = NotificationCompat.Builder(this, CHANNEL_ID)
        .setContentTitle(title)
        .setContentText("Analyse de la bibliothèque locale…")
        .setSmallIcon(android.R.drawable.stat_sys_download)
        .setPriority(NotificationCompat.PRIORITY_LOW)
        .setOngoing(true)
        .setSilent(true)
        .setContentIntent(launchIntent())
        .build()

    /** Tapping the notification reopens the app instead of doing nothing. */
    private fun launchIntent(): PendingIntent? {
        val launch = packageManager.getLaunchIntentForPackage(packageName) ?: return null
        launch.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        else PendingIntent.FLAG_UPDATE_CURRENT
        return PendingIntent.getActivity(this, 0, launch, flags)
    }
}
