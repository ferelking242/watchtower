package eu.kanade.tachiyomi.ui.reader.viewer.autoscroll

import android.animation.ValueAnimator
import android.view.animation.LinearInterpolator
import eu.kanade.tachiyomi.ui.reader.viewer.webtoon.WebtoonRecyclerView
import eu.kanade.tachiyomi.ui.reader.viewer.webtoon.WebtoonViewer
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import tachiyomi.core.common.util.system.logcat

/**
 * Auto-scroll manager for [WebtoonViewer] that uses a [ValueAnimator] to smoothly scroll
 * the webtoon content at a continuous rate based on the configured speed.
 *
 * @property viewer The [WebtoonViewer] instance to control.
 */
class WebtoonAutoScrollManager(
    private val viewer: WebtoonViewer,
) : AutoScrollManager {

    private val _state = MutableStateFlow(AutoScrollState())
    override val state: StateFlow<AutoScrollState> = _state.asStateFlow()

    private var valueAnimator: ValueAnimator? = null

    /**
     * The recycler view from the webtoon viewer that will be scrolled.
     */
    private val recyclerView: WebtoonRecyclerView
        get() = viewer.recycler

    /**
     * Calculates the scroll speed in pixels per frame based on the speed setting.
     * Higher speed values result in faster scrolling.
     *
     * @param speed The speed value (1-100).
     * @return The scroll speed in pixels per frame (at 60fps).
     */
    private fun calculateScrollSpeed(speed: Int): Float {
        // Map speed (1-100) to pixels per frame at 60fps
        // Speed 1 = 1.5 px/frame = 90 px/s
        // Speed 100 = 10 px/frame = 600 px/s
        val clampedSpeed = speed.coerceIn(1, 100)
        return 1.5f + (clampedSpeed - 1) * (8.5f / 99f)
    }

    override fun start(speed: Int?) {
        if (speed != null) {
            _state.update { it.copy(speed = speed.coerceIn(1, 100)) }
        }

        if (_state.value.isActive) {
            // Already active, stop current animator to restart with new speed
            stopAnimator()
        }

        _state.update { it.copy(isActive = true, isPaused = false) }
        startAnimator()
        logcat { "WebtoonAutoScrollManager started with speed ${_state.value.speed}" }
    }

    override fun stop() {
        stopAnimator()
        _state.update { it.copy(isActive = false, isPaused = false) }
        logcat { "WebtoonAutoScrollManager stopped" }
    }

    override fun pause() {
        if (!_state.value.isActive || _state.value.isPaused) return

        stopAnimator()
        _state.update { it.copy(isPaused = true) }
        logcat { "WebtoonAutoScrollManager paused" }
    }

    override fun resume() {
        if (!_state.value.isActive || !_state.value.isPaused) return

        _state.update { it.copy(isPaused = false) }
        startAnimator()
        logcat { "WebtoonAutoScrollManager resumed" }
    }

    override fun togglePause() {
        when {
            !_state.value.isActive -> start()
            _state.value.isPaused -> resume()
            else -> pause()
        }
    }

    override fun setSpeed(speed: Int) {
        val clampedSpeed = speed.coerceIn(1, 100)
        _state.update { it.copy(speed = clampedSpeed) }

        // Restart animator if currently running to apply new speed
        if (isRunning) {
            stopAnimator()
            startAnimator()
        }
        logcat { "WebtoonAutoScrollManager speed set to $clampedSpeed" }
    }

    override fun destroy() {
        stop()
    }

    /**
     * Starts the value animator with the current speed setting.
     * Uses an infinite animation that scrolls the recycler view smoothly.
     */
    private fun startAnimator() {
        val scrollSpeed = calculateScrollSpeed(_state.value.speed)

        // Use a simple frame-based animation
        // We'll animate a counter and scroll by fixed amount each frame
        valueAnimator = ValueAnimator.ofInt(0, Int.MAX_VALUE).apply {
            duration = Long.MAX_VALUE
            interpolator = LinearInterpolator()

            addUpdateListener { animator ->
                // Calculate scroll amount based on animation progress
                // At 60fps, each frame is ~16.67ms
                val deltaY = scrollSpeed.toInt()

                if (deltaY > 0) {
                    recyclerView.scrollBy(0, deltaY)
                }

                // Check if we've reached the end
                if (!recyclerView.canScrollVertically(1)) {
                    // Reached the end, stop auto-scroll
                    stop()
                }
            }

            start()
        }
    }

    /**
     * Stops and cleans up the current value animator.
     */
    private fun stopAnimator() {
        valueAnimator?.cancel()
        valueAnimator = null
    }
}
