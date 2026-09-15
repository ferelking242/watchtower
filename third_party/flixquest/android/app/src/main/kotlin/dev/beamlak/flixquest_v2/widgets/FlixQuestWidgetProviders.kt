package dev.beamlak.flixquest_v2.widgets

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.content.res.ColorStateList
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import dev.beamlak.flixquest_v2.MainActivity
import dev.beamlak.flixquest_v2.R
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider
import java.time.LocalDate
import kotlin.math.roundToInt
import org.json.JSONObject

private const val TAG = "FlixQuestWidget"

/** Under this width the poster column is dropped and everything stacks vertically. */
private const val COMPACT_WIDTH_DP = 190

/**
 * Widget bitmaps are parcelled across to the launcher and the whole RemoteViews payload has to fit
 * in roughly a megabyte of Binder buffer, so each image is decoded down to the size its view
 * actually needs. The hero sits under a scrim where RGB_565 banding is invisible; the poster is the
 * focal artwork and stays ARGB_8888.
 */
private const val HERO_TARGET_PX = 420
private const val POSTER_TARGET_PX = 240

private const val HOME_DEEP_LINK = "flixquest://home"

/**
 * The only copy that lives on this side of the bridge: it shows when the app has never filled the
 * widget in. Every other string is written by [HomeWidgetService] so it exists in exactly one place.
 */
private const val SYNC_TITLE = "Open FlixQuest"
private const val SYNC_SUBTITLE = "Tap to sync this widget"

private const val ON_HERO_TITLE = 0xFFFFFFFF.toInt()
private const val ON_HERO_SUBTITLE = 0xE6FFFFFF.toInt()
private const val ON_HERO_META = 0xB3FFFFFF.toInt()

private const val DEFAULT_PRIMARY = 0xFFF57C00.toInt()
private const val DEFAULT_SURFACE = 0xFF1D2023.toInt()
private const val DEFAULT_FOREGROUND = 0xFFFFFFFF.toInt()
private const val DEFAULT_MUTED = 0xA6FFFFFF.toInt()

/**
 * One slot of the widget carries one fact. No field may restate a value another field already
 * shows, and none may repeat what [eyebrow] says: [subtitle] and [meta] are separate facts, and
 * [progress] is the only place a completion ratio is expressed.
 */
data class WidgetContent(
    val eyebrow: String,
    val title: String,
    val subtitle: String = "",
    val meta: String = "",
    /** Sharp thumbnail of the poster art. */
    val posterPath: String? = null,
    /** Full-bleed backdrop behind the text. A different image from [posterPath], never a copy. */
    val heroPath: String? = null,
    val deepLink: String,
    val progress: Int? = null,
)

abstract class FlixQuestWidgetProvider : HomeWidgetProvider() {
    abstract fun content(widgetData: SharedPreferences): WidgetContent

    private data class WidgetTheme(
        val primary: Int,
        val surface: Int,
        val foreground: Int,
        val muted: Int,
    )

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        onUpdate(
            context,
            appWidgetManager,
            intArrayOf(appWidgetId),
            HomeWidgetPlugin.getData(context),
        )
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val content = content(widgetData)
        val theme = WidgetTheme(
            primary = widgetData.safeInt("theme_primary", DEFAULT_PRIMARY),
            surface = widgetData.safeInt("theme_surface", DEFAULT_SURFACE),
            foreground = widgetData.safeInt("theme_foreground", DEFAULT_FOREGROUND),
            muted = widgetData.safeInt("theme_muted", DEFAULT_MUTED),
        )
        // Only the width bucket changes what is rendered, so decode the bitmaps once per bucket
        // instead of once per placed widget.
        val byBucket = HashMap<Boolean, RemoteViews>(2)
        appWidgetIds.forEach { widgetId ->
            try {
                val width = appWidgetManager
                    .getAppWidgetOptions(widgetId)
                    .getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 320)
                val compact = width < COMPACT_WIDTH_DP
                val views = byBucket.getOrPut(compact) {
                    buildViews(context, content, theme, compact)
                }
                appWidgetManager.updateAppWidget(widgetId, views)
            } catch (error: Exception) {
                Log.e(TAG, "Could not update widget $widgetId", error)
            }
        }
    }

    private fun buildViews(
        context: Context,
        content: WidgetContent,
        theme: WidgetTheme,
        compact: Boolean,
    ): RemoteViews {
        val layout = if (compact) R.layout.flixquest_widget_compact else R.layout.flixquest_widget
        return RemoteViews(context.packageName, layout).apply {
            // The rounded card behind everything, tinted to whatever theme the app is running.
            setInt(R.id.widget_surface, "setColorFilter", theme.surface)

            val hero = content.heroPath?.let { decodeScaled(it, HERO_TARGET_PX, Bitmap.Config.RGB_565) }
            if (hero == null) {
                setViewVisibility(R.id.widget_hero, View.GONE)
                setViewVisibility(R.id.widget_scrim, View.GONE)
                setTextColor(R.id.widget_title, theme.foreground)
                setTextColor(R.id.widget_subtitle, theme.muted)
                setTextColor(R.id.widget_meta, theme.muted)
            } else {
                setImageViewBitmap(R.id.widget_hero, hero)
                setViewVisibility(R.id.widget_hero, View.VISIBLE)
                setViewVisibility(R.id.widget_scrim, View.VISIBLE)
                // Theme colours stop being legible over artwork, so pin to the scrim's own ramp.
                setTextColor(R.id.widget_title, ON_HERO_TITLE)
                setTextColor(R.id.widget_subtitle, ON_HERO_SUBTITLE)
                setTextColor(R.id.widget_meta, ON_HERO_META)
            }
            // The accent reads on both the themed surface and the scrim, so it never changes.
            setTextColor(R.id.widget_eyebrow, theme.primary)

            if (!compact) {
                val poster = content.posterPath
                    ?.let { decodeScaled(it, POSTER_TARGET_PX, Bitmap.Config.ARGB_8888) }
                if (poster == null) {
                    setViewVisibility(R.id.widget_poster, View.GONE)
                } else {
                    setImageViewBitmap(R.id.widget_poster, poster)
                    setViewVisibility(R.id.widget_poster, View.VISIBLE)
                    setContentDescription(
                        R.id.widget_poster,
                        context.getString(R.string.widget_poster_description, content.title),
                    )
                }
            }

            setTextViewText(R.id.widget_eyebrow, content.eyebrow)
            setTextViewText(R.id.widget_title, content.title)
            setOptionalText(R.id.widget_subtitle, content.subtitle)
            setOptionalText(R.id.widget_meta, content.meta)

            // A bar at zero is noise rather than information, so it only appears once there is
            // something to show. It is also the only place a percentage is expressed.
            val progress = content.progress?.takeIf { it > 0 }
            if (progress == null) {
                setViewVisibility(R.id.widget_progress, View.GONE)
            } else {
                setProgressBar(R.id.widget_progress, 100, progress.coerceAtMost(100), false)
                setViewVisibility(R.id.widget_progress, View.VISIBLE)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    setColorStateList(
                        R.id.widget_progress,
                        "setProgressTintList",
                        ColorStateList.valueOf(theme.primary),
                    )
                }
            }

            setOnClickPendingIntent(
                R.id.widget_container,
                HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse(content.deepLink),
                ),
            )
        }
    }

    /** Blank means "this widget has nothing to say here", which is quieter than an empty line. */
    private fun RemoteViews.setOptionalText(viewId: Int, value: String) {
        if (value.isBlank()) {
            setViewVisibility(viewId, View.GONE)
        } else {
            setTextViewText(viewId, value)
            setViewVisibility(viewId, View.VISIBLE)
        }
    }

    private fun decodeScaled(path: String, targetWidth: Int, config: Bitmap.Config): Bitmap? {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(path, bounds)
        if (bounds.outWidth <= 0) return null
        val options = BitmapFactory.Options().apply {
            inSampleSize = (bounds.outWidth / targetWidth).coerceAtLeast(1)
            inPreferredConfig = config
        }
        val decoded = BitmapFactory.decodeFile(path, options) ?: return null
        if (decoded.width <= targetWidth) return decoded
        val targetHeight = (decoded.height * (targetWidth.toFloat() / decoded.width))
            .roundToInt()
            .coerceAtLeast(1)
        return Bitmap.createScaledBitmap(decoded, targetWidth, targetHeight, true).also {
            if (it !== decoded) decoded.recycle()
        }
    }
}

/** home_widget can land an int in preferences as a Long, so never call getInt bare. */
private fun SharedPreferences.safeInt(key: String, fallback: Int): Int =
    try {
        getInt(key, fallback)
    } catch (_: ClassCastException) {
        (all[key] as? Number)?.toInt() ?: fallback
    }

private fun SharedPreferences.nonBlank(key: String): String? =
    getString(key, null)?.takeIf { it.isNotBlank() && it != "null" }

private fun JSONObject.optNonBlank(key: String): String? =
    optString(key).takeIf { it.isNotBlank() && it != "null" }

/**
 * Movie / TV pick of the day. The app writes a week of picks ahead of time so the widget keeps
 * rotating on its own while the app is closed; the day's entry is chosen by epoch-day offset.
 */
abstract class DailyPickWidgetProvider : FlixQuestWidgetProvider() {
    abstract val scheduleKey: String
    abstract val eyebrow: String

    override fun content(widgetData: SharedPreferences): WidgetContent {
        val payload = widgetData.nonBlank(scheduleKey) ?: return syncPrompt(eyebrow)
        return try {
            val root = JSONObject(payload)
            val items = root.getJSONArray("items")
            val startDay = root.getLong("startDay")
            val today = LocalDate.now().toEpochDay()
            val index = Math.floorMod((today - startDay).toInt(), items.length())
            val item = items.getJSONObject(index)
            WidgetContent(
                eyebrow = eyebrow,
                title = item.optNonBlank("title") ?: return syncPrompt(eyebrow),
                subtitle = item.optString("subtitle"),
                meta = item.optString("meta"),
                posterPath = item.optNonBlank("poster"),
                heroPath = item.optNonBlank("hero"),
                deepLink = item.optNonBlank("deepLink") ?: HOME_DEEP_LINK,
            )
        } catch (error: Exception) {
            Log.e(TAG, "Malformed schedule in $scheduleKey", error)
            syncPrompt(eyebrow)
        }
    }
}

/**
 * Widgets whose every string is composed on the Dart side. This class deliberately holds no copy of
 * its own beyond the sync prompt, which is what stops the two sides from drifting apart.
 */
abstract class StoredWidgetProvider : FlixQuestWidgetProvider() {
    abstract val prefix: String
    abstract val fallbackEyebrow: String
    abstract val fallbackDeepLink: String

    /** Widgets that never express a ratio leave the bar out entirely. */
    open val showsProgress: Boolean = false

    override fun content(widgetData: SharedPreferences): WidgetContent {
        val title = widgetData.nonBlank("${prefix}_title")
            ?: return syncPrompt(fallbackEyebrow, fallbackDeepLink)
        return WidgetContent(
            eyebrow = widgetData.nonBlank("${prefix}_eyebrow") ?: fallbackEyebrow,
            title = title,
            subtitle = widgetData.getString("${prefix}_subtitle", null).orEmpty(),
            meta = widgetData.getString("${prefix}_meta", null).orEmpty(),
            posterPath = widgetData.nonBlank("${prefix}_poster"),
            heroPath = widgetData.nonBlank("${prefix}_hero"),
            deepLink = widgetData.nonBlank("${prefix}_deep_link") ?: fallbackDeepLink,
            progress = if (showsProgress) widgetData.safeInt("${prefix}_progress", 0) else null,
        )
    }
}

private fun syncPrompt(eyebrow: String, deepLink: String = HOME_DEEP_LINK) = WidgetContent(
    eyebrow = eyebrow,
    title = SYNC_TITLE,
    subtitle = SYNC_SUBTITLE,
    deepLink = deepLink,
)

class MovieOfDayWidgetProvider : DailyPickWidgetProvider() {
    override val scheduleKey = "movie_daily_schedule"
    override val eyebrow = "MOVIE OF THE DAY"
}

class TvShowOfDayWidgetProvider : DailyPickWidgetProvider() {
    override val scheduleKey = "tv_daily_schedule"
    override val eyebrow = "TV SHOW OF THE DAY"
}

class WellnessWidgetProvider : StoredWidgetProvider() {
    override val prefix = "wellness"
    override val fallbackEyebrow = "VIEWING INSIGHTS"
    override val fallbackDeepLink = "flixquest://wellness"
    override val showsProgress = true
}

class ContinueWatchingWidgetProvider : StoredWidgetProvider() {
    override val prefix = "continue"
    override val fallbackEyebrow = "CONTINUE WATCHING"
    override val fallbackDeepLink = HOME_DEEP_LINK
    override val showsProgress = true
}

class MyListWidgetProvider : StoredWidgetProvider() {
    override val prefix = "my_list"
    override val fallbackEyebrow = "MY LIST"
    override val fallbackDeepLink = "flixquest://my-list"
}
