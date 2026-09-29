import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:watchtower/modules/anime/widgets/custom_track_shape.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video_controls/src/controls/extensions/duration.dart';

class CustomSeekBar extends StatefulWidget {
  final Player player;
  final Duration? delta;
  final Function(Duration)? onSeekStart;
  final Function(Duration)? onSeekEnd;
  final ValueNotifier<List<(String, int)>> chapterMarks;

  const CustomSeekBar({
    super.key,
    this.onSeekStart,
    this.onSeekEnd,
    required this.player,
    this.delta,
    required this.chapterMarks,
  });

  @override
  CustomSeekBarState createState() => CustomSeekBarState();
}

class CustomSeekBarState extends State<CustomSeekBar> {
  Duration? tempPosition;
  late Player player = widget.player;
  Duration position = Duration.zero;
  late Duration duration = player.state.duration;
  Duration buffer = Duration.zero;
  bool _isDragging = false;
  // Position before drag started — used to cancel seek on double-tap
  Duration? _positionBeforeDrag;
  // When true, onChangeEnd skips the actual seek (double-tap cancel)
  bool _cancelDrag = false;

  @override
  void initState() {
    super.initState();
    player.stream.position.listen((event) {
      if (mounted && !_isDragging) {
        setState(() {
          position = event;
        });
      }
    });
    player.stream.duration.listen((event) {
      if (mounted) {
        setState(() {
          duration = event;
        });
      }
    });
    player.stream.buffer.listen((event) {
      if (mounted) {
        setState(() {
          buffer = event;
        });
      }
    });
    position = player.state.position;
    duration = player.state.duration;
    buffer = player.state.buffer;
  }

  final isDesktop =
      !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);

  /// Called by a double-tap on the seekbar area while dragging.
  /// Cancels the seek and reverts to the position before drag started.
  void _cancelCurrentDrag() {
    if (!_isDragging) return;
    if (mounted) {
      setState(() {
        _cancelDrag = true;
        _isDragging = false;
        tempPosition = null;
        _positionBeforeDrag = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayPos = widget.delta ?? tempPosition ?? position;
    final maxValue = max(duration.inMilliseconds.toDouble(), 0).toDouble();
    final rawValue = displayPos.inMilliseconds.toDouble();
    final clampedValue = rawValue.clamp(0, maxValue).toDouble();
    final remaining =
        duration > displayPos ? duration - displayPos : Duration.zero;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // ── Seek preview tooltip (shown during drag on mobile) ──────────────
        if (_isDragging && !isDesktop)
          Positioned(
            top: -70,
            left: 70,
            right: 70,
            child: AnimatedOpacity(
              opacity: _isDragging ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 100),
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.45),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        displayPos.label(reference: duration),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        '-${remaining.label(reference: duration)}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.60),
                          fontSize: 11.5,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Double-tap pour annuler',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.35),
                          fontSize: 9.5,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // ── Seekbar row ─────────────────────────────────────────────────────
        SizedBox(
          height: 20,
          child: Row(
            children: [
              if (!isDesktop)
                SizedBox(
                  width: 70,
                  child: Center(
                    child: Text(
                      displayPos.label(reference: duration),
                      style: const TextStyle(
                        height: 1.0,
                        fontSize: 12.0,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: isDesktop ? null : 3,
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 5.0),
                    trackShape: CustomTrackShape(
                      currentPosition: clampedValue,
                      bufferPosition:
                          max(buffer.inMilliseconds.toDouble(), 0),
                      maxValue: maxValue < 1 ? 1 : maxValue,
                      minValue: 0,
                      chapterMarks: widget.chapterMarks.value,
                      chapterMarkWidth: 10,
                    ),
                  ),
                  // GestureDetector wraps the Slider to detect double-tap cancel
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onDoubleTap: _cancelCurrentDrag,
                    child: Slider(
                      max: maxValue,
                      value: clampedValue,
                      secondaryTrackValue:
                          max(buffer.inMilliseconds.toDouble(), 0),
                      onChanged: (value) {
                        // ── PREVIEW ONLY during drag — no seek ────────────────
                        // Seeking on every onChanged event caused 60fps lag.
                        // We only update the visual position here; the real seek
                        // happens in onChangeEnd when the finger is released.
                        if (!_isDragging) {
                          _positionBeforeDrag = position;
                          widget.onSeekStart?.call(
                            Duration(
                              milliseconds:
                                  value.toInt() - position.inMilliseconds,
                            ),
                          );
                        }
                        if (mounted) {
                          setState(() {
                            _isDragging = true;
                            tempPosition =
                                Duration(milliseconds: value.toInt());
                          });
                        }
                      },
                      onChangeEnd: (value) async {
                        // ── If double-tap cancelled drag, skip actual seek ─────
                        if (_cancelDrag) {
                          _cancelDrag = false;
                          widget.onSeekEnd?.call(Duration.zero);
                          if (mounted) {
                            setState(() {
                              _isDragging = false;
                              tempPosition = null;
                              _positionBeforeDrag = null;
                            });
                          }
                          return;
                        }
                        // ── Real seek only on finger release ──────────────────
                        widget.onSeekEnd?.call(
                          Duration(
                            milliseconds:
                                value.toInt() - position.inMilliseconds,
                          ),
                        );
                        widget.player
                            .seek(Duration(milliseconds: value.toInt()));
                        if (mounted) {
                          setState(() {
                            _isDragging = false;
                            tempPosition = null;
                            _positionBeforeDrag = null;
                          });
                        }
                      },
                    ),
                  ),
                ),
              ),
              if (!isDesktop)
                SizedBox(
                  width: 70,
                  child: Center(
                    child: Text(
                      duration.label(reference: duration),
                      style: const TextStyle(
                        height: 1.0,
                        fontSize: 12.0,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
