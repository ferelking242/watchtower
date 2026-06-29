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
  // Position before drag started — used to cancel if needed
  Duration? _positionBeforeDrag;

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

  @override
  Widget build(BuildContext context) {
    final displayPos = widget.delta ?? tempPosition ?? position;
    final maxValue = max(duration.inMilliseconds.toDouble(), 0).toDouble();
    final rawValue = displayPos.inMilliseconds.toDouble();
    final clampedValue = rawValue.clamp(0, maxValue).toDouble();
    final remaining = duration > displayPos ? duration - displayPos : Duration.zero;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // ── Seek preview tooltip (shown during drag on mobile) ──────────────
        if (_isDragging && !isDesktop)
          Positioned(
            top: -58,
            left: 70,
            right: 70,
            child: AnimatedOpacity(
              opacity: _isDragging ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 120),
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
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
                          fontSize: 16,
                          height: 1.1,
                        ),
                      ),
                      Text(
                        '-${remaining.label(reference: duration)}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 11,
                          height: 1.2,
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
                          tempPosition = Duration(milliseconds: value.toInt());
                        });
                      }
                    },
                    onChangeEnd: (value) async {
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
