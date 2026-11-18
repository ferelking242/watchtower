package com.watchtower.app.glance

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import com.watchtower.app.R
import org.json.JSONObject

class HomePlayerWidgetReceiver : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (id in appWidgetIds) {
            updateWidget(context, appWidgetManager, id)
        }
    }

    companion object {
        private const val PREFS = "HomeWidgetPreferences"

        fun updateWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int,
        ) {
            val prefs: SharedPreferences =
                context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

            var trackName  = "Watchtower Music"
            var artistName = "Tap to open"

            val rawTrack = prefs.getString("activeTrack", null)
            if (rawTrack != null) {
                try {
                    val j = JSONObject(rawTrack)
                    trackName = j.optString("name", trackName)
                    val artists = j.optJSONArray("artists")
                    if (artists != null && artists.length() > 0) {
                        artistName = artists.getJSONObject(0).optString("name", "")
                    }
                } catch (_: Exception) {}
            }

            val views = RemoteViews(context.packageName, R.layout.home_player_widget)
            views.setTextViewText(R.id.widget_track_name, trackName)
            views.setTextViewText(R.id.widget_artist_name, artistName)

            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            if (launchIntent != null) {
                val pi = PendingIntent.getActivity(
                    context, 0, launchIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )
                views.setOnClickPendingIntent(R.id.widget_container, pi)
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
