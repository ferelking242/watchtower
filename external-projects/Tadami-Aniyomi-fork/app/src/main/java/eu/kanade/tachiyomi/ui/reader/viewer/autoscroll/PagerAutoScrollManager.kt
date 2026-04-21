package eu.kanade.tachiyomi.ui.reader.viewer.autoscroll

import android.os.CountDownTimer
import eu.kanade.tachiyomi.ui.reader.viewer.pager.PagerViewer
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import tachiyomi.core.common.util.system.logcat

/**
 * Auto-scroll manager for [PagerViewer] that uses a [CountDownTimer] to advance pages
 * at regular intervals based on the configured speed.
 *
 * @property viewer The [PagerViewer] instance to control.
 */
class PagerAutoScrollManager(
    private val viewer: PagerViewer,
) : AutoScrollManager {

    private val _state = MutableStateFlow(AutoScrollState())
    override val state: StateFlow<AutoScrollState> = _state.asStateFlow()

    private var countDownTimer: CountDownTimer? = null

    /**
     * Calculates the page delay in milliseconds based on the speed setting.
     * Higher speed values result in shorter delays.
     *
     * @param speed The speed value (1-100).
     * @return The delay in milliseconds before advancing to the next page.
     */
    private fun calculatePageDelay(speed: Int): Long {
        // Map speed (1-100) to delay (10000ms - 2000ms)
        // Speed 1 = 10000ms (10s, very slow), Speed 50 = 6000ms (6s, medium)
        // Speed 100 = 2000ms (2s, fast)
        val clampedSpeed = speed.coerceIn(1, 100)
        return (10000 - (clampedSpeed - 1) * 80).toLong()
    }

    override fun start(speed: Int?) {
        if (speed != null) {
            _state.update { it.copy(speed = speed.coerceIn(1, 100)) }
        }

        if (_state.value.isActive) {
            // Already active, just restart timer with potentially new speed
            stopTimer()
        }

        _state.update { it.copy(isActive = true, isPaused = false) }
        startTimer()
        logcat { "PagerAutoScrollManager started with speed ${_state.value.speed}" }
    }

    override fun stop() {
        stopTimer()
        _state.update { it.copy(isActive = false, isPaused = false) }
        logcat { "PagerAutoScrollManager stopped" }
    }

    override fun pause() {
        if (!_state.value.isActive || _state.value.isPaused) return

        stopTimer()
        _state.update { it.copy(isPaused = true) }
        logcat { "PagerAutoScrollManager paused" }
    }

    override fun resume() {
        if (!_state.value.isActive || !_state.value.isPaused) return

        _state.update { it.copy(isPaused = false) }
        startTimer()
        logcat { "PagerAutoScrollManager resumed" }
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

        // Restart timer if currently running to apply new speed
        if (isRunning) {
            stopTimer()
            startTimer()
        }
        logcat { "PagerAutoScrollManager speed set to $clampedSpeed" }
    }

    override fun destroy() {
        stop()
    }

    /**
     * Starts the countdown timer with the current speed setting.
     */
    private fun startTimer() {
        val pageDelay = calculatePageDelay(_state.value.speed)

        countDownTimer = object : CountDownTimer(Long.MAX_VALUE, pageDelay) {
            override fun onTick(millisUntilFinished: Long) {
                // Advance to next page on each tick
                viewer.moveToNext()
            }

            override fun onFinish() {
                // Timer finished (shouldn't happen with Long.MAX_VALUE)
                // Restart if still active
                if (_state.value.isActive && !_state.value.isPaused) {
                    startTimer()
                }
            }
        }.start()
    }

    /**
     * Stops and cleans up the current countdown timer.
     */
    private fun stopTimer() {
        countDownTimer?.cancel()
        countDownTimer = null
    }
}
