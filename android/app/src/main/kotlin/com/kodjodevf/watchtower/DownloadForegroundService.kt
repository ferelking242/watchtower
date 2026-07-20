package com.kodjodevf.watchtower

import android.app.Notification
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
 * DownloadForegroundService — keeps Watchtower's download queue alive
 * even when the user switches away from the app.
 *
 * Android kills background processes aggressively (RAM pressure, Doze, app
 * standby buckets).  A Foreground Service with an ongoing notification is the
 * only reliable way to prevent this without rooting the device.
 *
 * Life-cycle:
 *   start()  → called by BackgroundKeepAlive when the queue becomes active.
 *   update() → called periodically with the current active-download count.
 *   stop()   → called when the queue drains to zero.
 *
 * The service is START_STICKY so it restarts automatically if the OS kills it
 * while downloads are still pending.
 */
class DownloadForegroundService : Service() {

    companion object {
        private const val CHANNEL_ID  = "watchtower_downloads"
        private const val NOTIF_ID    = 7001

        const val ACTION_START  = "com.kodjodevf.watchtower.DOWNLOAD_START"
        const val ACTION_STOP   = "com.kodjodevf.watchtower.DOWNLOAD_STOP"
        const val ACTION_UPDATE = "com.kodjodevf.watchtower.DOWNLOAD_UPDATE"

        const val EXTRA_COUNT    = "count"
        const val EXTRA_TITLE    = "notif_title"
        const val EXTRA_SUBTITLE = "notif_subtitle"
        const val EXTRA_PROGRESS = "notif_progress"  // 0-100, -1 = indeterminate

        // ── Static helpers called from MainActivity MethodChannel ─────────────

        fun start(context: Context, count: Int = 0, title: String = "Téléchargement en cours…",
                  subtitle: String = "", progress: Int = -1) {
            val i = intent(context, ACTION_START).apply {
                putExtra(EXTRA_COUNT,    count)
                putExtra(EXTRA_TITLE,   title)
                putExtra(EXTRA_SUBTITLE, subtitle)
                putExtra(EXTRA_PROGRESS, progress)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                context.startForegroundService(i)
            else
                context.startService(i)
        }

        fun update(context: Context, count: Int, title: String = "Téléchargement en cours…",
                   subtitle: String = "", progress: Int = -1) {
            val i = intent(context, ACTION_UPDATE).apply {
                putExtra(EXTRA_COUNT,    count)
                putExtra(EXTRA_TITLE,   title)
                putExtra(EXTRA_SUBTITLE, subtitle)
                putExtra(EXTRA_PROGRESS, progress)
            }
            context.startService(i)
        }

        fun stop(context: Context) {
            context.startService(intent(context, ACTION_STOP))
        }

        private fun intent(context: Context, action: String) =
            Intent(context, DownloadForegroundService::class.java).also { it.action = action }
    }

    private lateinit var nm: NotificationManager

    override fun onCreate() {
        super.onCreate()
        nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ch = NotificationChannel(
                CHANNEL_ID,
                "Téléchargements Watchtower",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Garde les téléchargements actifs en arrière-plan"
                setShowBadge(false)
            }
            nm.createNotificationChannel(ch)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                val count    = intent.getIntExtra(EXTRA_COUNT, 0)
                val title    = intent.getStringExtra(EXTRA_TITLE)    ?: "Téléchargement en cours…"
                val subtitle = intent.getStringExtra(EXTRA_SUBTITLE) ?: ""
                val progress = intent.getIntExtra(EXTRA_PROGRESS, -1)
                val notif = buildNotif(count, title, subtitle, progress)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                    // Android 14+ requires the foreground service type to be declared
                    startForeground(NOTIF_ID, notif, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
                } else {
                    startForeground(NOTIF_ID, notif)
                }
            }
            ACTION_UPDATE -> {
                val count    = intent.getIntExtra(EXTRA_COUNT, 0)
                val title    = intent.getStringExtra(EXTRA_TITLE)    ?: "Téléchargement en cours…"
                val subtitle = intent.getStringExtra(EXTRA_SUBTITLE) ?: ""
                val progress = intent.getIntExtra(EXTRA_PROGRESS, -1)
                nm.notify(NOTIF_ID, buildNotif(count, title, subtitle, progress))
            }
            ACTION_STOP -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N)
                    stopForeground(STOP_FOREGROUND_REMOVE)
                else
                    @Suppress("DEPRECATION")
                    stopForeground(true)
                stopSelf()
            }
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun buildNotif(count: Int, title: String, subtitle: String = "", progress: Int = -1): Notification {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pi = PendingIntent.getActivity(
            this, 0, launchIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        // Body line: show subtitle if provided, otherwise fall back to count string.
        val body = subtitle.ifEmpty {
            when {
                count > 1  -> "$count téléchargements en cours"
                count == 1 -> "1 téléchargement en cours"
                else       -> "En attente…"
            }
        }
        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(body)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setOngoing(true)
            .setSilent(true)
            .setContentIntent(pi)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            // Show a determinate progress bar when we know the percentage,
            // or an indeterminate spinner while the download is starting up.
            .setProgress(
                100,
                if (progress in 0..100) progress else 0,
                progress < 0   // indeterminate when progress == -1
            )

        // BigText style: show full chapter name even when it's long.
        if (title.isNotEmpty && title != "Téléchargement en cours…") {
            builder.setStyle(
                NotificationCompat.BigTextStyle()
                    .bigText(body)
                    .setBigContentTitle(title)
            )
        }

        return builder.build()
    }
}
