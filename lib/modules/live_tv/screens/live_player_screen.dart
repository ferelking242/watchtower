import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/modules/live_tv/models/live_provider.dart';

/// Full-screen live player.
///
/// media_kit rather than a webview: the sources are HLS streams, and a native
/// player handles them on every platform, including the desktop builds where no
/// browser engine exists. On web media_kit falls back to the HTML video element.
class LivePlayerScreen extends StatefulWidget {
  const LivePlayerScreen({super.key, required this.channel});

  final LiveChannel channel;

  @override
  State<LivePlayerScreen> createState() => _LivePlayerScreenState();
}

class _LivePlayerScreenState extends State<LivePlayerScreen> {
  late final Player _player;
  late final VideoController _controller;

  int _urlIndex = 0;
  bool _isBuffering = true;
  String? _error;
  bool _controlsVisible = true;

  /// Mirrors that failed, so a retry starts from the next candidate instead of
  /// replaying a URL already known to be dead.
  final Set<int> _failedUrls = {};

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);
    _player.stream.buffering.listen((value) {
      if (!mounted) return;
      setState(() => _isBuffering = value);
    });
    _player.stream.error.listen((message) {
      if (!mounted) return;
      _handleFailure(message);
    });
    _openCurrentUrl();
  }

  Future<void> _openCurrentUrl() async {
    final urls = widget.channel.urls;
    if (urls.isEmpty) {
      setState(() => _error = 'Aucun flux pour cette chaîne.');
      return;
    }
    final url = urls[_urlIndex];
    setState(() {
      _isBuffering = true;
      _error = null;
    });
    try {
      await _player.open(Media(url));
    } catch (error) {
      _handleFailure('$error');
    }
  }

  /// Moves to the next mirror, or reports a final error once all have failed.
  void _handleFailure(String message) {
    if (!mounted) return;
    _failedUrls.add(_urlIndex);
    final next = _nextHealthyUrl();
    if (next == null) {
      setState(() {
        _isBuffering = false;
        _error = 'Cette chaîne ne répond pas.';
      });
      return;
    }
    _urlIndex = next;
    _openCurrentUrl();
  }

  int? _nextHealthyUrl() {
    for (var i = 0; i < widget.channel.urls.length; i++) {
      if (!_failedUrls.contains(i)) return i;
    }
    return null;
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () =>
                    setState(() => _controlsVisible = !_controlsVisible),
                child: _error != null
                    ? _buildError()
                    : Video(controller: _controller, controls: NoVideoControls),
              ),
            ),
            if (_isBuffering && _error == null)
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            AnimatedOpacity(
              opacity: _controlsVisible ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              child: _buildOverlay(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Broken.video_slash, color: Colors.white54, size: 46),
            const SizedBox(height: 16),
            Text(
              widget.channel.name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white60, fontSize: 14),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: () {
                _failedUrls.clear();
                _urlIndex = 0;
                _openCurrentUrl();
              },
              icon: const Icon(Broken.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverlay(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: IgnorePointer(
        ignoring: !_controlsVisible,
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 20),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black87, Colors.transparent],
            ),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Broken.arrow_left_2, color: Colors.white),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.channel.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (widget.channel.group != null)
                      Text(
                        widget.channel.group!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              if (widget.channel.urls.length > 1)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(
                    '${_urlIndex + 1}/${widget.channel.urls.length}',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
