package dev.beamlak.flixquest_v2.links

import android.content.Intent
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Hands the addresses Android delivers to this app over to Flutter.
 *
 * A link is often the reason the app is starting, which means it arrives before there is any Dart to
 * receive it. Those wait in [pending] until Flutter asks for them, and everything after that is
 * pushed straight across.
 *
 * Nothing is interpreted here beyond pulling the text out of the intent. Which site a link belongs
 * to, what it names and which screen answers it is one decision made in one place, in Dart, where
 * both the browser's links and the share sheet's text end up.
 */
class MediaLinkBridge(
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, METHOD_CHANNEL)
    private val pending = mutableListOf<String>()
    private var listening = false

    init {
        channel.setMethodCallHandler(this)
    }

    /**
     * Reads whatever address [intent] is asking for, if it is asking for one.
     *
     * Called on the main thread with the intent the activity started on, and again with each one
     * delivered to it afterwards.
     */
    fun onIntent(intent: Intent?) {
        val link = intent?.let { linkOf(it) } ?: return
        if (listening) {
            channel.invokeMethod(METHOD_ON_LINK, link)
        } else {
            pending.add(link)
        }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        pending.clear()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            METHOD_DRAIN -> {
                // Flutter is up: from here on links go straight across rather than into the queue.
                listening = true
                val waiting = pending.toList()
                pending.clear()
                result.success(waiting)
            }
            else -> result.notImplemented()
        }
    }

    /**
     * A tapped link arrives as the intent's own data. A shared one arrives as text with the address
     * somewhere inside it — the IMDb app sends the title and the year in front of its URL — so the
     * whole text is passed along and Dart finds the address in it.
     */
    private fun linkOf(intent: Intent): String? {
        // Coming back to the app from the recents list redelivers the intent it was started with, and
        // that is not a request to open anything a second time.
        if (intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY != 0) return null
        val value = when (intent.action) {
            Intent.ACTION_VIEW,
            "es.antonborri.home_widget.action.LAUNCH" -> intent.dataString
            Intent.ACTION_SEND -> intent.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString()
            else -> null
        }
        return value?.takeIf { it.isNotBlank() }
    }

    private companion object {
        const val METHOD_CHANNEL = "dev.beamlak.flixquest/media_links"
        const val METHOD_DRAIN = "drainLinks"
        const val METHOD_ON_LINK = "onLink"
    }
}
