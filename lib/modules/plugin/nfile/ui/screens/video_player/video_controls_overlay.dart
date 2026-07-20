import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class VideoControlsOverlay extends StatelessWidget {
  final String title;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final double sliderValue;
  final double playbackSpeed;
  final bool isFullScreen;
  final bool isLocked;
  final bool isMuted;
  final int repeatMode; // 0=none, 1=one, 2=all
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;
  final ValueChanged<double> onChangeStart;
  final VoidCallback onPlayPause;
  final VoidCallback onRewind;
  final VoidCallback onFastForward;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onToggleFullScreen;
  final ValueChanged<double> onSelectSpeed;
  final VoidCallback onToggleLock;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleRepeat;
  final VoidCallback onCopyUrl;
  final VoidCallback onInteract;

  const VideoControlsOverlay({
    super.key,
    required this.title,
    required this.isPlaying,
    required this.position,
    required this.duration,
    required this.sliderValue,
    required this.playbackSpeed,
    required this.isFullScreen,
    required this.isLocked,
    required this.isMuted,
    required this.repeatMode,
    required this.onChanged,
    required this.onChangeEnd,
    required this.onChangeStart,
    required this.onPlayPause,
    required this.onRewind,
    required this.onFastForward,
    this.onPrevious,
    this.onNext,
    required this.onToggleFullScreen,
    required this.onSelectSpeed,
    required this.onToggleLock,
    required this.onToggleMute,
    required this.onToggleRepeat,
    required this.onCopyUrl,
    required this.onInteract,
  });

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = theme.colorScheme.primary;

    final maxMs = duration.inMilliseconds.toDouble();
    final safeMax = maxMs > 0 ? maxMs : 1.0;
    final safeVal = sliderValue.clamp(0.0, safeMax);
    final itemsColor = Colors.white.withOpacity(0.9);

    if (isLocked) {
      return Positioned(
        top: 32,
        left: 24,
        child: SafeArea(
          child: GestureDetector(
            onTap: onToggleLock,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.75),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.25), width: 1.5),
                boxShadow: [
                  BoxShadow(color: accentColor.withOpacity(0.4), blurRadius: 16),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CupertinoIcons.lock_fill, color: accentColor, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Slide / Tap to Unlock',
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Stack(
      children: [
        // Darkened Background Mask for better visibility of controls
        Positioned.fill(
          child: IgnorePointer(
            child: Container(color: Colors.black.withOpacity(0.35)),
          ),
        ),

        // TOP ROW HEADER
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black87, Colors.transparent],
              ),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  // Back button — chevron iOS style
                  IconButton(
                    icon: Icon(CupertinoIcons.back, color: itemsColor, size: 26),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: TextStyle(color: itemsColor, fontSize: 16, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: accentColor.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: accentColor, width: 0.8),
                              ),
                              child: const Text(
                                'HW Dec',
                                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'AVC / AAC • 1080p',
                              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Speed Selector — gauge icon (iOS style)
                  PopupMenuButton<double>(
                    tooltip: 'Playback Speed',
                    icon: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(CupertinoIcons.gauge, color: itemsColor, size: 15),
                          const SizedBox(width: 6),
                          Text(
                            '${playbackSpeed}x',
                            style: TextStyle(color: itemsColor, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    color: const Color(0xFF1E1E2E),
                    onSelected: onSelectSpeed,
                    itemBuilder: (_) => [0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0]
                        .map((v) => PopupMenuItem(
                              value: v,
                              child: Text(
                                '${v}x',
                                style: TextStyle(
                                  color: playbackSpeed == v ? accentColor : Colors.white,
                                  fontWeight: playbackSpeed == v ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                  const SizedBox(width: 8),
                  // Lock Toggle Button
                  IconButton(
                    icon: Icon(CupertinoIcons.lock_open, color: itemsColor, size: 22),
                    tooltip: 'Lock Controls',
                    onPressed: onToggleLock,
                  ),
                ],
              ),
            ),
          ),
        ),

        // CENTER PLAYBACK CONTROLS
        Center(
          child: SafeArea(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                const SizedBox(),
                // Previous Button
                Opacity(
                  opacity: onPrevious != null ? 1.0 : 0.35,
                  child: Container(
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.35), shape: BoxShape.circle),
                    child: IconButton(
                      iconSize: 30,
                      padding: const EdgeInsets.all(14),
                      icon: Icon(CupertinoIcons.backward_end_fill, color: itemsColor),
                      onPressed: onPrevious != null ? () {
                        onInteract();
                        onPrevious?.call();
                      } : null,
                    ),
                  ),
                ),
                // Play / Pause Premium Circle
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: accentColor.withOpacity(isPlaying ? 0.5 : 0.2), blurRadius: 28, spreadRadius: 4),
                    ],
                    border: Border.all(color: Colors.white.withOpacity(0.15), width: 1.5),
                  ),
                  child: IconButton(
                    iconSize: 50,
                    padding: const EdgeInsets.all(20),
                    icon: Icon(
                      isPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
                      color: itemsColor,
                    ),
                    onPressed: () {
                      onInteract();
                      onPlayPause();
                    },
                  ),
                ),
                // Next Button
                Opacity(
                  opacity: onNext != null ? 1.0 : 0.35,
                  child: Container(
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.35), shape: BoxShape.circle),
                    child: IconButton(
                      iconSize: 30,
                      padding: const EdgeInsets.all(14),
                      icon: Icon(CupertinoIcons.forward_end_fill, color: itemsColor),
                      onPressed: onNext != null ? () {
                        onInteract();
                        onNext?.call();
                      } : null,
                    ),
                  ),
                ),
                const SizedBox(),
              ],
            ),
          ),
        ),

        // BOTTOM ROW CONTROLS
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 36, 20, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black87, Colors.transparent],
              ),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Full Width Seek Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3.5,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
                        activeTrackColor: Colors.white,
                        inactiveTrackColor: Colors.white.withOpacity(0.25),
                        thumbColor: Colors.white,
                        overlayColor: Colors.white.withOpacity(0.2),
                      ),
                      child: Slider(
                        value: safeVal,
                        max: safeMax,
                        onChangeStart: (_) {
                          onInteract();
                          onChangeStart(safeVal);
                        },
                        onChanged: onChanged,
                        onChangeEnd: (_) {
                          onInteract();
                          onChangeEnd(safeVal);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Bottom Bar Utilities & Timers
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Current / Total Time Chip
                      Text(
                        '${_formatDuration(position)} / ${_formatDuration(duration)}',
                        style: TextStyle(
                          color: itemsColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                      // Action Icons Row
                      Row(
                        children: [
                          // Repeat Button
                          IconButton(
                            padding: const EdgeInsets.all(8),
                            constraints: const BoxConstraints(),
                            icon: Icon(
                              repeatMode == 1
                                  ? CupertinoIcons.repeat_1
                                  : CupertinoIcons.repeat,
                              color: repeatMode != 0 ? accentColor : itemsColor.withOpacity(0.65),
                              size: 20,
                            ),
                            tooltip: 'Repeat Mode',
                            onPressed: () {
                              onInteract();
                              onToggleRepeat();
                            },
                          ),
                          const SizedBox(width: 4),
                          // Mute Button
                          IconButton(
                            padding: const EdgeInsets.all(8),
                            constraints: const BoxConstraints(),
                            icon: Icon(
                              isMuted ? CupertinoIcons.speaker_slash_fill : CupertinoIcons.speaker_3_fill,
                              color: itemsColor,
                              size: 20,
                            ),
                            tooltip: isMuted ? 'Unmute' : 'Mute',
                            onPressed: () {
                              onInteract();
                              onToggleMute();
                            },
                          ),
                          const SizedBox(width: 4),
                          // Copy Link
                          IconButton(
                            padding: const EdgeInsets.all(8),
                            constraints: const BoxConstraints(),
                            icon: Icon(CupertinoIcons.doc_on_clipboard, color: itemsColor, size: 19),
                            tooltip: 'Copy URL',
                            onPressed: () {
                              onInteract();
                              onCopyUrl();
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: const Text('Media path copied to clipboard.'),
                                backgroundColor: accentColor,
                              ));
                            },
                          ),
                          const SizedBox(width: 4),
                          // Full Screen — iOS arrow style
                          IconButton(
                            padding: const EdgeInsets.all(8),
                            constraints: const BoxConstraints(),
                            icon: Icon(
                              isFullScreen
                                  ? CupertinoIcons.arrow_down_right_arrow_up_left
                                  : CupertinoIcons.arrow_up_left_and_arrow_down_right,
                              color: itemsColor,
                              size: 22,
                            ),
                            tooltip: isFullScreen ? 'Exit Full Screen' : 'Full Screen',
                            onPressed: () {
                              onInteract();
                              onToggleFullScreen();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
