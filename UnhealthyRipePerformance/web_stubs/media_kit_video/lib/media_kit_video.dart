import 'dart:async';
  import 'dart:ui_web' as ui_web;
  import 'dart:js_interop';
  import 'package:flutter/material.dart';
  import 'package:media_kit/media_kit.dart';
  import 'package:web/web.dart' as web;

  export 'media_kit_video_controls/src/controls/extensions/duration.dart';

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

  Widget seekIndicatorTextWidget(Duration duration, Duration currentPosition) =>
      const SizedBox.shrink();

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
    late final String _viewType;
    late final web.HTMLVideoElement _videoEl;
    StreamSubscription<String>? _urlSub;
    bool _hasVideo = false;

    @override
    void initState() {
      super.initState();
      _viewType = 'watchtower-video-${identityHashCode(this)}';

      // Create the HTML5 <video> element
      _videoEl = web.document.createElement('video') as web.HTMLVideoElement;
      _videoEl.setAttribute('playsinline', '');
      _videoEl.controls = true;
      _videoEl.style.width = '100%';
      _videoEl.style.height = '100%';
      _videoEl.style.objectFit = 'contain';
      _videoEl.style.background = 'black';

      // Wire the element into the Player bridge so play()/pause()/seek() work
      Player.webRegister(_videoEl);

      // Register the Flutter platform view factory
      ui_web.platformViewRegistry.registerViewFactory(
        _viewType,
        (int id) => _videoEl,
      );

      // React to Player.open(Media(url)) calls
      _urlSub = Player.webVideoStream.listen((url) {
        _videoEl.src = url;
        unawaited(_videoEl.play().toDart);
        if (mounted) setState(() => _hasVideo = true);
      });
    }

    @override
    void dispose() {
      _urlSub?.cancel();
      Player.webUnregister();
      super.dispose();
    }

    /// Browser file picker for local video files
    void _pickLocalFile() {
      final input = web.document.createElement('input') as web.HTMLInputElement;
      input.type = 'file';
      input.accept = 'video/*';
      input.style.display = 'none';
      web.document.body!.appendChild(input);
      input.addEventListener(
        'change',
        ((web.Event _ev) {
          final files = input.files;
          if (files != null && files.length > 0) {
            final file = files.item(0);
            if (file != null) {
              final url = web.URL.createObjectURL(file);
              _videoEl.src = url;
              unawaited(_videoEl.play().toDart);
              if (mounted) setState(() => _hasVideo = true);
            }
          }
          input.remove();
        }).toJS,
      );
      input.click();
    }

    @override
    Widget build(BuildContext context) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: ColoredBox(
          color: widget.fill,
          child: Stack(
            children: [
              // HTML5 video surface
              Positioned.fill(child: HtmlElementView(viewType: _viewType)),
              // Flutter overlay (topButtonBar, bottom controls, etc.)
              if (widget.controls != null)
                Positioned.fill(child: widget.controls!(context)),
              // "Open local file" button shown when no video is loaded yet
              if (!_hasVideo)
                Positioned(
                  bottom: 80,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: ElevatedButton.icon(
                      onPressed: _pickLocalFile,
                      icon: const Icon(Icons.folder_open),
                      label: const Text('Ouvrir une vidéo locale'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black87,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 14),
                        textStyle: const TextStyle(fontSize: 15),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }
  }
  