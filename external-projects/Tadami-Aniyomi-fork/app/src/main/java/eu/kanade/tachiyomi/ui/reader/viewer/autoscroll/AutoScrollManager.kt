package eu.kanade.tachiyomi.ui.reader.viewer.autoscroll

import kotlinx.coroutines.flow.StateFlow

/**
 * Interface for auto-scroll managers that control automatic page advancement or scrolling
 * in the reader. Implementations handle the specific behavior for different viewer types
 * (pager vs webtoon).
 */
interface AutoScrollManager {

    /**
     * Flow of the current auto-scroll state. Observe this to react to state changes.
     */
    val state: StateFlow<AutoScrollState>

    /**
     * Whether auto-scroll is currently active and running (not paused).
     */
    val isRunning: Boolean
        get() = state.value.isActive && !state.value.isPaused

    /**
     * Starts auto-scroll with the current or specified speed.
     *
     * @param speed The scroll speed (1-100). If null, uses the current speed from state.
     */
    fun start(speed: Int? = null)

    /**
     * Stops auto-scroll completely. Resets the active state to false.
     */
    fun stop()

    /**
     * Pauses auto-scroll temporarily without stopping it. The scroll can be resumed
     * by calling [resume] or [start].
     */
    fun pause()

    /**
     * Resumes auto-scroll from a paused state.
     */
    fun resume()

    /**
     * Toggles the pause state of auto-scroll. If not active, this may start auto-scroll.
     */
    fun togglePause()

    /**
     * Sets the scroll speed without changing the active/paused state.
     *
     * @param speed The new scroll speed (1-100).
     */
    fun setSpeed(speed: Int)

    /**
     * Cleans up any resources used by the auto-scroll manager.
     * Should be called when the viewer is destroyed.
     */
    fun destroy()
}
