import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

export 'media_kit_video_controls/src/controls/extensions/duration.dart';

/// Web stub for NoVideoControls — on real media_kit_video this is a top-level
/// function passed as `controls:` to hide all playback controls.
Widget NoVideoControls(BuildContext context) => const SizedBox.shrink();

class SubtitleViewConfiguration {
  final TextStyle style;
  final TextStyle textStyle;
  final TextAlign textAlign;
  final EdgeInsets padding;
  final TextScaler? textScaler;
  final bool visible;
  const SubtitleViewConfiguration({
    this.style = const TextStyle(
      height: 1.4,
      fontSize: 48.0,
      color: Color(0xffffffff),
      fontWeight: FontWeight.normal,
      backgroundColor: Color(0xaa000000),
    ),
    TextStyle? textStyle,
    this.textAlign = TextAlign.center,
    this.padding = EdgeInsets.zero,
    this.textScaler,
    this.visible = true,
  }) : textStyle = textStyle ?? style;
}

bool isFullscreen(BuildContext context) => false;

Widget seekIndicatorTextWidget(Duration duration, Duration currentPosition) {
  return const SizedBox.shrink();
}

class SubtitleView extends StatelessWidget {
  final VideoController controller;
  final SubtitleViewConfiguration configuration;
  const SubtitleView({
    super.key,
    required this.controller,
    this.configuration = const SubtitleViewConfiguration(),
  });

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class VideoControllerConfiguration {
  final bool enableHardwareAcceleration;
  const VideoControllerConfiguration({this.enableHardwareAcceleration = true});
}

class VideoController {
  final Player player;
  final VideoControllerConfiguration configuration;

  VideoController(
    this.player, {
    this.configuration = const VideoControllerConfiguration(),
  });

  Future<void> get waitUntilFirstFrameRendered => Future.value();
}

class Video extends StatefulWidget {
  final VideoController? controller;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Color fill;
  final Alignment alignment;
  final double? aspectRatio;
  final FilterQuality filterQuality;
  final Widget Function(BuildContext)? controls;
  final bool wakelock;
  final bool pauseUponEnteringBackgroundMode;
  final bool resumeUponEnteringForegroundMode;
  final SubtitleViewConfiguration? subtitleViewConfiguration;
  final bool onEnterFullscreen;

  const Video({
    super.key,
    this.controller,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.fill = const Color(0xFF000000),
    this.alignment = Alignment.center,
    this.aspectRatio,
    this.filterQuality = FilterQuality.low,
    this.controls,
    this.wakelock = true,
    this.pauseUponEnteringBackgroundMode = true,
    this.resumeUponEnteringForegroundMode = true,
    this.subtitleViewConfiguration,
    this.onEnterFullscreen = false,
  });

  @override
  VideoState createState() => VideoState();
}

class VideoState extends State<Video> {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      color: widget.fill,
      child: const Center(
        child: Text(
          'Video playback not supported on web',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
