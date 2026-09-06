// ignore_for_file: depend_on_referenced_packages
import 'dart:async';
import 'dart:ui';
import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/modules/anime/anime_player_view.dart';
import 'package:watchtower/modules/anime/providers/anime_player_controller_provider.dart';
import 'package:watchtower/modules/anime/widgets/custom_seekbar.dart';
import 'package:watchtower/modules/anime/widgets/indicator_builder.dart';
import 'package:watchtower/widgets/watchtower_loader.dart';
import 'package:watchtower/modules/anime/widgets/subtitle_view.dart';
import 'package:watchtower/modules/manga/reader/providers/push_router.dart';
import 'package:watchtower/modules/more/settings/player/providers/player_state_provider.dart';
import 'package:watchtower/modules/anime/widgets/play_or_pause_button.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:media_kit_video/media_kit_video_controls/src/controls/extensions/duration.dart';

class MobileControllerWidget extends ConsumerStatefulWidget {
  final Function(bool?) doubleSpeed;
  final AnimeStreamController streamController;
  final VideoController videoController;
  final Widget topButtonBarWidget;
  final GlobalKey<VideoState> videoStatekey;
  final Widget bottomButtonBarWidget;
  final ValueNotifier<List<(String, int)>> chapterMarks;
  final Widget? leftSideWidget;
  final Widget? rightSideWidget;
  const MobileControllerWidget({
    super.key,
    required this.videoController,
    required this.topButtonBarWidget,
    required this.bottomButtonBarWidget,
    required this.streamController,
    required this.videoStatekey,
    required this.doubleSpeed,
    required this.chapterMarks,
    this.leftSideWidget,
    this.rightSideWidget,
  });

  @override
  ConsumerState<MobileControllerWidget> createState() =>
      _MobileControllerWidgetState();
}

class _MobileControllerWidgetState
    extends ConsumerState<MobileControllerWidget> {
  bool mount = true;
  bool visible = true;
  Duration controlsTransitionDuration = const Duration(milliseconds: 300);
  Color backdropColor = const Color(0x66000000);
  Timer? _timer;
  late final skipDuration = ref.watch(
    defaultDoubleTapToSkipLengthStateProvider,
  );
  final ValueNotifier<double> _brightnessValue = ValueNotifier(0.0);
  final ValueNotifier<bool> _brightnessIndicator = ValueNotifier(false);
  StreamSubscription<double>? _brightnessSubscription;
  Timer? _brightnessTimer;

  final ValueNotifier<double> _volumeValue = ValueNotifier(0.0);
  final ValueNotifier<bool> _volumeIndicator = ValueNotifier(false);
  Timer? _volumeTimer;
  // The default event stream in package:volume_controller is buggy.
  bool _volumeInterceptEventStream = false;

  Offset _dragInitialDelta =
      Offset.zero; // Initial position for horizontal drag
  int swipeDuration = 0; // Duration to seek in video
  bool showSwipeDuration = false; // Whether to show the seek duration overlay
  double previousPlaybackSpeed = -1;

  late bool buffering = widget.videoController.player.state.buffering;
  final controlsHoverDuration = const Duration(seconds: 3);
  bool _mountSeekBackwardButton = false;
  bool _mountSeekForwardButton = false;
  bool _hideSeekBackwardButton = false;
  bool _hideSeekForwardButton = false;

  // GlobalKeys allow us to call increment() on a live indicator widget —
  // this is the key to unbounded counter accumulation without resetting.
  final GlobalKey<_BackwardSeekIndicatorState> _backwardKey = GlobalKey();
  final GlobalKey<_ForwardSeekIndicatorState> _forwardKey = GlobalKey();
  double buttonBarHeight = 100;
  final bottomButtonBarMargin = const EdgeInsets.only(left: 16.0, right: 8.0);

  Duration? _seekBarDeltaValueNotifier;
  // Accumulated seconds shown in the top-center tap-seek overlay (neg = backward)
  int _tapSeekDisplaySeconds = 0;

  final List<StreamSubscription> subscriptions = [];
  Offset? _tapPosition;

  void _handleTapDown(TapDownDetails details) {
    setState(() {
      _tapPosition = details.localPosition;
    });
  }

  @override
  void setState(VoidCallback fn) {
    if (mounted) {
      super.setState(fn);
    }
  }

  final horizontalGestureSensitivity = 7500;
  final verticalGestureSensitivity = 500;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (subscriptions.isEmpty) {
      subscriptions.addAll([
        widget.videoController.player.stream.buffering.listen((event) {
          setState(() {
            buffering = event;
            if (event) {
              _mountSeekBackwardButton = false;
              _mountSeekForwardButton = false;
              _hideSeekBackwardButton = false;
              _hideSeekForwardButton = false;
            }
          });
        }),
      ]);

      _timer = Timer(controlsHoverDuration, () {
        if (mounted) {
          setState(() {
            visible = false;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    for (final subscription in subscriptions) {
      subscription.cancel();
    }
    _timer?.cancel();
    _volumeTimer?.cancel();
    _brightnessTimer?.cancel();
    _volumeValue.dispose();
    _volumeIndicator.dispose();
    _brightnessValue.dispose();
    _brightnessIndicator.dispose();
    _brightnessSubscription?.cancel();
    _volumeController.removeListener();

    // package:screen_brightness
    Future.microtask(() async {
      try {
        await ScreenBrightness.instance.resetApplicationScreenBrightness();
      } catch (_) {}
    });
    super.dispose();
  }

  void onTap() {
    // Never dismiss controls while a seek indicator is animating —
    // double-tap must always take priority over single-tap so the overlay
    // never accidentally closes mid-sequence.
    if (_mountSeekBackwardButton || _mountSeekForwardButton) return;
    if (!visible) {
      setState(() {
        mount = true;
        visible = true;
      });

      _timer?.cancel();
      _timer = Timer(controlsHoverDuration, () {
        if (mounted) {
          setState(() {
            visible = false;
          });
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
        }
      });
    } else {
      setState(() {
        visible = false;
      });
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
      _timer?.cancel();
    }
  }

  void onDoubleTapSeekBackward() {
    // Cancel auto-hide while indicator is active (prevents overlay from closing).
    _timer?.cancel();
    if (_mountSeekBackwardButton && !_hideSeekBackwardButton) {
      // Indicator already shown: increment the SAME instance (no counter reset).
      _backwardKey.currentState?.increment();
    } else {
      setState(() {
        _mountSeekBackwardButton = true;
        _hideSeekBackwardButton = false;
        _mountSeekForwardButton = false;
        _tapSeekDisplaySeconds = -skipDuration;
      });
    }
  }

  void onDoubleTapSeekForward() {
    _timer?.cancel();
    if (_mountSeekForwardButton && !_hideSeekForwardButton) {
      _forwardKey.currentState?.increment();
    } else {
      setState(() {
        _mountSeekForwardButton = true;
        _hideSeekForwardButton = false;
        _mountSeekBackwardButton = false;
        _tapSeekDisplaySeconds = skipDuration;
      });
    }
  }

  void onHorizontalDragUpdate(DragUpdateDetails details) {
    if (_dragInitialDelta == Offset.zero) {
      _dragInitialDelta = details.localPosition;
      return;
    }

    final diff = _dragInitialDelta.dx - details.localPosition.dx;
    final duration = widget.videoController.player.state.duration.inSeconds;
    final position = widget.videoController.player.state.position.inSeconds;

    final seconds = -(diff * duration / horizontalGestureSensitivity).round();
    final relativePosition = position + seconds;

    if (relativePosition <= duration && relativePosition >= 0) {
      setState(() {
        swipeDuration = seconds;
        showSwipeDuration = true;
        _seekBarDeltaValueNotifier = Duration(
          seconds:
              widget.videoController.player.state.position.inSeconds + seconds,
        );
      });
    }
  }

  void onHorizontalDragEnd() {
    if (swipeDuration != 0) {
      Duration newPosition =
          widget.videoController.player.state.position +
          Duration(seconds: swipeDuration);
      newPosition = newPosition.clamp(
        Duration.zero,
        widget.videoController.player.state.duration,
      );
      widget.videoController.player.seek(newPosition);
    }

    setState(() {
      _dragInitialDelta = Offset.zero;
      showSwipeDuration = false;
      _seekBarDeltaValueNotifier = null;
    });
  }

  late final VolumeController _volumeController;
  @override
  void initState() {
    super.initState();
    _volumeController = VolumeController.instance;

    Future.microtask(() async {
      try {
        _volumeController.showSystemUI = false;
        _volumeValue.value = await _volumeController.getVolume();
        _volumeController.addListener((value) {
          if (mounted && !_volumeInterceptEventStream) {
            _volumeValue.value = value;
          }
        });
      } catch (_) {}
    });

    Future.microtask(() async {
      try {
        _brightnessValue.value = await ScreenBrightness.instance.application;
        _brightnessSubscription = ScreenBrightness
            .instance
            .onApplicationScreenBrightnessChanged
            .listen((value) {
              if (mounted) {
                _brightnessValue.value = value;
              }
            });
      } catch (_) {}
    });
  }

  Future<void> setVolume(double value) async {
    try {
      _volumeController.showSystemUI = false;
      _volumeController.setVolume(value);
    } catch (_) {}
    _volumeValue.value = value;
    _volumeIndicator.value = true;
    _volumeInterceptEventStream = true;
    _volumeTimer?.cancel();
    _volumeTimer = Timer(const Duration(milliseconds: 200), () {
      if (mounted) {
        _volumeIndicator.value = false;
        _volumeInterceptEventStream = false;
      }
    });
  }

  Future<void> setBrightness(double value) async {
    // package:screen_brightness
    try {
      await ScreenBrightness.instance.setApplicationScreenBrightness(value);
    } catch (_) {}
    _brightnessIndicator.value = true;
    _brightnessTimer?.cancel();
    _brightnessTimer = Timer(const Duration(milliseconds: 200), () {
      if (mounted) {
        _brightnessIndicator.value = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Consumer(
          builder: (context, ref, _) => ref.read(useLibassStateProvider)
              ? const SizedBox.shrink()
              : Positioned(
                  child: CustomSubtitleView(
                    controller: widget.videoController,
                    configuration: SubtitleViewConfiguration(
                      style: subtileTextStyle(ref),
                    ),
                  ),
                ),
        ),
        Focus(
          autofocus: true,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // // Controls:
              AnimatedOpacity(
                curve: Curves.easeInOut,
                opacity: visible ? 1.0 : 0.0,
                duration: controlsTransitionDuration,
                onEnd: () {
                  setState(() {
                    if (!visible) {
                      mount = false;
                    }
                  });
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                        child: Container(color: backdropColor),
                      ),
                    ),
                    // We are adding 16.0 boundary around the actual controls (which contain the vertical drag gesture detectors).
                    // This will make the hit-test on edges (e.g. swiping to: show status-bar, show navigation-bar, go back in navigation) not activate the swipe gesture annoyingly.
                    Positioned.fill(
                      left: 16.0,
                      top: 16.0,
                      right: 16.0,
                      bottom: 16.0,
                      child: GestureDetector(
                        onTap: onTap,
                        onDoubleTapDown: _handleTapDown,
                        onDoubleTap: () {
                          if (_tapPosition != null &&
                              _tapPosition!.dx >
                                  MediaQuery.of(context).size.width / 2) {
                            onDoubleTapSeekForward();
                          } else {
                            onDoubleTapSeekBackward();
                          }
                        },
                        onLongPressStart: (e) {
                          previousPlaybackSpeed =
                              widget.videoController.player.state.rate;
                          widget.videoController.player.setRate(
                            previousPlaybackSpeed * 2,
                          );
                          widget.doubleSpeed(true);
                        },
                        onLongPressEnd: (e) {
                          if (previousPlaybackSpeed != -1) {
                            widget.videoController.player.setRate(
                              previousPlaybackSpeed,
                            );
                            previousPlaybackSpeed = -1;
                            widget.doubleSpeed(false);
                          }
                        },
                        onHorizontalDragUpdate: (details) {
                          onHorizontalDragUpdate(details);
                        },
                        onHorizontalDragEnd: (details) {
                          onHorizontalDragEnd();
                        },
                        onVerticalDragUpdate: (e) async {
                          final delta = e.delta.dy;
                          final Offset position = e.localPosition;

                          if (position.dx <=
                              MediaQuery.of(context).size.width / 2) {
                            // Left side of screen swiped

                            final brightness =
                                _brightnessValue.value -
                                delta / verticalGestureSensitivity;
                            final result = brightness.clamp(0.0, 1.0);
                            setBrightness(result);
                          } else {
                            // Right side of screen swiped

                            final volume =
                                _volumeValue.value -
                                delta / verticalGestureSensitivity;
                            final result = volume.clamp(0.0, 1.0);
                            setVolume(result);
                          }
                        },
                        child: Container(color: const Color(0x00000000)),
                      ),
                    ),
                    if (mount)
                      Padding(
                        padding:
                            (
                            // Add padding in fullscreen!
                            isFullscreen(context)
                            ? MediaQuery.of(context).padding
                            : (!kIsWeb && Platform.isIOS)
                            ? EdgeInsets.only(
                                bottom: MediaQuery.of(context).padding.bottom,
                              )
                            : EdgeInsets.zero),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            AnimatedOpacity(
                              opacity: visible ? 1.0 : 0.0,
                              duration: Duration.zero,
                              child: widget.topButtonBarWidget,
                            ),
                            // Only display [primaryButtonBar] if [buffering] is false.
                            Expanded(
                              child: AnimatedOpacity(
                                curve: Curves.easeInOut,
                                opacity: buffering
                                    ? 0.0
                                    : showSwipeDuration
                                    ? 0.0
                                    : 1.0,
                                duration: controlsTransitionDuration,
                                child: Stack(
                                  children: [
                                    Center(
                                      child: Row(
                                        children: mobilePrimaryButtonBar(
                                          context,
                                          widget.videoStatekey,
                                          widget.streamController,
                                          widget.videoController,
                                        ),
                                      ),
                                    ),
                                    if (widget.leftSideWidget != null)
                                      Positioned(
                                        left: 8,
                                        top: 0,
                                        bottom: 0,
                                        child: Center(
                                          child: widget.leftSideWidget!,
                                        ),
                                      ),
                                    if (widget.rightSideWidget != null)
                                      Positioned(
                                        right: 8,
                                        top: 0,
                                        bottom: 0,
                                        child: Center(
                                          child: widget.rightSideWidget!,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            Stack(
                              alignment: Alignment.bottomCenter,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: CustomSeekBar(
                                    onSeekStart: (value) {
                                      setState(() {
                                        swipeDuration = value.inSeconds;
                                        showSwipeDuration = true;
                                      });
                                      _timer?.cancel();
                                    },
                                    onSeekEnd: (value) {
                                      _timer = Timer(controlsHoverDuration, () {
                                        if (mounted) {
                                          setState(() {
                                            visible = false;
                                          });
                                        }
                                      });
                                      setState(() {
                                        showSwipeDuration = false;
                                      });
                                    },
                                    player: widget.videoController.player,
                                    chapterMarks: widget.chapterMarks,
                                  ),
                                ),
                                widget.bottomButtonBarWidget,
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              // // Double-Tap Seek Seek-Bar:
              if (!mount)
                if (_mountSeekBackwardButton ||
                    _mountSeekForwardButton ||
                    showSwipeDuration)
                  Column(
                    children: [
                      const Spacer(),
                      Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: CustomSeekBar(
                              delta: _seekBarDeltaValueNotifier,
                              player: widget.videoController.player,
                              chapterMarks: widget.chapterMarks,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
              // // Buffering Indicator.
              IgnorePointer(
                child: Padding(
                  padding:
                      (
                      // Add padding in fullscreen!
                      isFullscreen(context)
                      ? MediaQuery.of(context).padding
                      : EdgeInsets.zero),
                  child: Column(
                    children: [
                      Container(
                        height: buttonBarHeight,
                        margin: const EdgeInsets.all(0),
                      ),
                      Expanded(
                        child: Center(
                          child: TweenAnimationBuilder<double>(
                            tween: Tween<double>(
                              begin: 0.0,
                              end: buffering ? 1.0 : 0.0,
                            ),
                            duration: controlsTransitionDuration,
                            builder: (context, value, child) {
                              // Only mount the buffering indicator if the opacity is greater than 0.0.
                              // This has been done to prevent redundant resource usage in [CircularProgressIndicator].
                              if (value > 0.0) {
                                return Opacity(opacity: value, child: child!);
                              }
                              return const SizedBox.shrink();
                            },
                            child: const JumpingDotsLoader(),
                          ),
                        ),
                      ),
                      Container(
                        height: buttonBarHeight,
                        margin: bottomButtonBarMargin,
                      ),
                    ],
                  ),
                ),
              ),
              // // Volume Indicator — portrait: top-center, landscape: LEFT (crossed).
              IgnorePointer(
                child: ValueListenableBuilder(
                  valueListenable: _volumeIndicator,
                  builder: (context, value, child) => AnimatedOpacity(
                    curve: Curves.easeInOut,
                    opacity: value ? 1.0 : 0.0,
                    duration: controlsTransitionDuration,
                    child: Builder(builder: (ctx) {
                      final isLandscape =
                          MediaQuery.of(ctx).orientation ==
                          Orientation.landscape;
                      return Align(
                        alignment: isLandscape
                            ? Alignment.centerLeft
                            : Alignment.topCenter,
                        child: Padding(
                          padding: isLandscape
                              ? const EdgeInsets.only(left: 20)
                              : const EdgeInsets.only(top: 72),
                          child: MediaIndicatorBuilder(
                            value: _volumeValue,
                            isVolumeIndicator: true,
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
              // // Brightness Indicator — portrait: top-center, landscape: RIGHT (crossed).
              IgnorePointer(
                child: ValueListenableBuilder(
                  valueListenable: _brightnessIndicator,
                  builder: (context, value, child) => AnimatedOpacity(
                    curve: Curves.easeInOut,
                    opacity: value ? 1.0 : 0.0,
                    duration: controlsTransitionDuration,
                    child: Builder(builder: (ctx) {
                      final isLandscape =
                          MediaQuery.of(ctx).orientation ==
                          Orientation.landscape;
                      return Align(
                        alignment: isLandscape
                            ? Alignment.centerRight
                            : Alignment.topCenter,
                        child: Padding(
                          padding: isLandscape
                              ? const EdgeInsets.only(right: 20)
                              : const EdgeInsets.only(top: 72),
                          child: MediaIndicatorBuilder(
                            value: _brightnessValue,
                            isVolumeIndicator: false,
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
              // // Top-center tap-seek label overlay.
              if (_mountSeekBackwardButton || _mountSeekForwardButton)
                IgnorePointer(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 56),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 140),
                        transitionBuilder: (child, anim) =>
                            ScaleTransition(scale: anim, child: child),
                        child: _tapSeekDisplaySeconds != 0
                            ? Container(
                                key: ValueKey(_tapSeekDisplaySeconds),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 22, vertical: 9),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.65),
                                  borderRadius: BorderRadius.circular(28),
                                  border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.12),
                                      width: 0.8),
                                ),
                                child: Text(
                                  _tapSeekDisplaySeconds < 0
                                      ? '${_tapSeekDisplaySeconds}s'
                                      : '+${_tapSeekDisplaySeconds}s',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
              // Seek Indicator.
              IgnorePointer(
                child: AnimatedOpacity(
                  duration: controlsTransitionDuration,
                  opacity: showSwipeDuration ? 1 : 0,
                  child: seekIndicatorTextWidget(
                    Duration(seconds: swipeDuration),
                    widget.videoController.player.state.position,
                  ),
                ),
              ),

              // Double-Tap Seek Button(s):
              if (_mountSeekBackwardButton || _mountSeekForwardButton)
                Positioned.fill(
                  child: Row(
                    children: [
                      Expanded(
                        child: _mountSeekBackwardButton
                            ? TweenAnimationBuilder<double>(
                                tween: Tween<double>(
                                  begin: 0.0,
                                  end: _hideSeekBackwardButton ? 0.0 : 1.0,
                                ),
                                duration: const Duration(milliseconds: 200),
                                builder: (context, value, child) =>
                                    Opacity(opacity: value, child: child),
                                onEnd: () {
                                  if (_hideSeekBackwardButton) {
                                    setState(() {
                                      _hideSeekBackwardButton = false;
                                      _mountSeekBackwardButton = false;
                                      _tapSeekDisplaySeconds = 0;
                                    });
                                    // Resume auto-hide timer after indicator dismisses.
                                    if (mounted && visible) {
                                      _timer?.cancel();
                                      _timer = Timer(controlsHoverDuration, () {
                                        if (mounted) {
                                          setState(() { visible = false; });
                                        }
                                      });
                                    }
                                  }
                                },
                                child: _BackwardSeekIndicator(
                                  key: _backwardKey,
                                  onChanged: (value) {
                                    setState(() {
                                      _seekBarDeltaValueNotifier =
                                          widget
                                              .videoController
                                              .player
                                              .state
                                              .position -
                                          value;
                                      _tapSeekDisplaySeconds = -value.inSeconds;
                                    });
                                  },
                                  onSubmitted: (value) {
                                    setState(() {
                                      _hideSeekBackwardButton = true;
                                    });
                                    var result =
                                        widget
                                            .videoController
                                            .player
                                            .state
                                            .position -
                                        value;
                                    result = result.clamp(
                                      Duration.zero,
                                      widget
                                          .videoController
                                          .player
                                          .state
                                          .duration,
                                    );
                                    widget.videoController.player.seek(result);
                                  },
                                  skipDuration: skipDuration,
                                ),
                              )
                            : const SizedBox(),
                      ),
                      Expanded(
                        child: _mountSeekForwardButton
                            ? TweenAnimationBuilder<double>(
                                tween: Tween<double>(
                                  begin: 0.0,
                                  end: _hideSeekForwardButton ? 0.0 : 1.0,
                                ),
                                duration: const Duration(milliseconds: 200),
                                builder: (context, value, child) =>
                                    Opacity(opacity: value, child: child),
                                onEnd: () {
                                  if (_hideSeekForwardButton) {
                                    setState(() {
                                      _hideSeekForwardButton = false;
                                      _mountSeekForwardButton = false;
                                      _tapSeekDisplaySeconds = 0;
                                    });
                                    if (mounted && visible) {
                                      _timer?.cancel();
                                      _timer = Timer(controlsHoverDuration, () {
                                        if (mounted) {
                                          setState(() { visible = false; });
                                        }
                                      });
                                    }
                                  }
                                },
                                child: _ForwardSeekIndicator(
                                  key: _forwardKey,
                                  onChanged: (value) {
                                    setState(() {
                                      _seekBarDeltaValueNotifier =
                                          widget
                                              .videoController
                                              .player
                                              .state
                                              .position +
                                          value;
                                      _tapSeekDisplaySeconds = value.inSeconds;
                                    });
                                  },
                                  onSubmitted: (value) {
                                    setState(() {
                                      _hideSeekForwardButton = true;
                                    });
                                    var result =
                                        widget
                                            .videoController
                                            .player
                                            .state
                                            .position +
                                        value;
                                    result = result.clamp(
                                      Duration.zero,
                                      widget
                                          .videoController
                                          .player
                                          .state
                                          .duration,
                                    );
                                    widget.videoController.player.seek(result);
                                  },
                                  skipDuration: skipDuration,
                                ),
                              )
                            : const SizedBox(),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BackwardSeekIndicator extends StatefulWidget {
  final void Function(Duration) onChanged;
  final void Function(Duration) onSubmitted;
  final int skipDuration;
  const _BackwardSeekIndicator({
    super.key,
    required this.onChanged,
    required this.onSubmitted,
    required this.skipDuration,
  });

  @override
  State<_BackwardSeekIndicator> createState() => _BackwardSeekIndicatorState();
}

class _BackwardSeekIndicatorState extends State<_BackwardSeekIndicator>
    with SingleTickerProviderStateMixin {
  late Duration value = Duration(seconds: widget.skipDuration);
  Timer? timer;
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
    value: 1.0,
  );

  @override
  void setState(VoidCallback fn) {
    if (mounted) super.setState(fn);
  }

  @override
  void initState() {
    super.initState();
    _scheduleSubmit();
  }

  void _scheduleSubmit() {
    timer?.cancel();
    timer = Timer(const Duration(milliseconds: 900), () {
      widget.onSubmitted.call(value);
    });
  }

  @override
  void dispose() {
    _fade.dispose();
    timer?.cancel();
    super.dispose();
  }

  void increment() {
    timer?.cancel();
    setState(() {
      value = Duration(milliseconds: value.inMilliseconds * 2);
    });
    widget.onChanged.call(value);
    _scheduleSubmit();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: increment,
      behavior: HitTestBehavior.translucent,
      child: Container(color: const Color(0x00000000)),
    );
  }
}

class _ForwardSeekIndicator extends StatefulWidget {
  final void Function(Duration) onChanged;
  final void Function(Duration) onSubmitted;
  final int skipDuration;
  const _ForwardSeekIndicator({
    super.key,
    required this.onChanged,
    required this.onSubmitted,
    required this.skipDuration,
  });

  @override
  State<_ForwardSeekIndicator> createState() => _ForwardSeekIndicatorState();
}

class _ForwardSeekIndicatorState extends State<_ForwardSeekIndicator>
    with SingleTickerProviderStateMixin {
  late Duration value = Duration(seconds: widget.skipDuration);
  Timer? timer;
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
    value: 1.0,
  );

  @override
  void setState(VoidCallback fn) {
    if (mounted) super.setState(fn);
  }

  @override
  void initState() {
    super.initState();
    _scheduleSubmit();
  }

  void _scheduleSubmit() {
    timer?.cancel();
    timer = Timer(const Duration(milliseconds: 900), () {
      widget.onSubmitted.call(value);
    });
  }

  @override
  void dispose() {
    _fade.dispose();
    timer?.cancel();
    super.dispose();
  }

  void increment() {
    timer?.cancel();
    setState(() {
      value = Duration(milliseconds: value.inMilliseconds * 2);
    });
    widget.onChanged.call(value);
    _scheduleSubmit();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: increment,
      behavior: HitTestBehavior.translucent,
      child: Container(color: const Color(0x00000000)),
    );
  }
}

List<Widget> mobilePrimaryButtonBar(
  BuildContext context,
  GlobalKey<VideoState> key,
  AnimeStreamController streamController,
  VideoController controller,
) {
  bool hasPrevEpisode =
      streamController.getEpisodeIndex().$1 + 1 !=
      streamController.getEpisodesLength(streamController.getEpisodeIndex().$2);
  bool hasNextEpisode = streamController.getEpisodeIndex().$1 != 0;
  final isFullScreen = isFullscreen(context);
  return [
    const Spacer(flex: 2),
    IconButton(
      onPressed: hasPrevEpisode
          ? () {
              if (isFullScreen) {
                key.currentState?.exitFullscreen();
              }
              pushReplacementMangaReaderView(
                context: context,
                chapter: streamController.getPrevEpisode(),
              );
            }
          : null,
      icon: Icon(
        Icons.skip_previous,
        size: 44,
        color: hasPrevEpisode ? Colors.white : Colors.grey,
      ),
    ),
    const Spacer(),
    // ── Skip −15 s — landscape (fullscreen) only ───────────────────────────
    if (isFullScreen) _SkipSecondsButton(seconds: -15, player: controller.player),
    if (isFullScreen) const SizedBox(width: 4),
    CustomPlayOrPauseButton(controller: controller, isDesktop: false),
    if (isFullScreen) const SizedBox(width: 4),
    // ── Skip +15 s — landscape (fullscreen) only ───────────────────────────
    if (isFullScreen) _SkipSecondsButton(seconds: 15, player: controller.player),
    const Spacer(),
    IconButton(
      onPressed: hasNextEpisode
          ? () {
              if (isFullScreen) {
                key.currentState?.exitFullscreen();
              }
              pushReplacementMangaReaderView(
                context: context,
                chapter: streamController.getNextEpisode(),
              );
            }
          : null,
      icon: Icon(
        Icons.skip_next,
        size: 44,
        color: hasNextEpisode ? Colors.white : Colors.grey,
      ),
    ),
    const Spacer(flex: 2),
  ];
}

// ── Skip ±N seconds button ────────────────────────────────────────────────────

class _SkipSecondsButton extends StatefulWidget {
  final int seconds;
  final dynamic player; // Player from media_kit
  const _SkipSecondsButton({required this.seconds, required this.player});

  @override
  State<_SkipSecondsButton> createState() => _SkipSecondsButtonState();
}

class _SkipSecondsButtonState extends State<_SkipSecondsButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _onTap() {
    _anim.forward(from: 0).then((_) => _anim.reverse());
    final pos = widget.player.state.position as Duration;
    final dur = widget.player.state.duration as Duration;
    final newPos = (pos + Duration(seconds: widget.seconds))
        .clamp(Duration.zero, dur);
    widget.player.seek(newPos);
  }

  @override
  Widget build(BuildContext context) {
    final isBackward = widget.seconds < 0;
    final label = '${widget.seconds.abs()}s';
    return GestureDetector(
      onTap: _onTap,
      child: AnimatedBuilder(
        animation: _anim,
        builder: (context, child) => Transform.scale(
          scale: 1.0 - 0.08 * _anim.value,
          child: child,
        ),
        child: Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.18),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isBackward
                    ? Icons.replay_rounded
                    : Icons.forward_rounded,
                color: Colors.white,
                size: 21,
              ),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
