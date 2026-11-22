import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/modules/live_tv/epg/epg_models.dart';
import 'package:watchtower/modules/live_tv/epg/epg_providers.dart';
import 'package:watchtower/modules/live_tv/models/live_provider.dart';
import 'package:watchtower/modules/live_tv/widgets/live_common.dart';

/// Full-screen live player.
///
/// media_kit rather than a webview: the sources are HLS streams, and a native
/// player handles them on every platform, including the desktop builds where no
/// browser engine exists. On web media_kit falls back to the HTML video element.
///
/// Plays a list, not a single channel: the guide and the channel list both open
/// it with everything they show, so zapping up and down stays inside what the
/// user was browsing instead of jumping to an arbitrary order.
class LivePlayerScreen extends ConsumerStatefulWidget {
  LivePlayerScreen({
    super.key,
    LiveChannel? channel,
    List<LiveChannel>? channels,
    this.initialIndex = 0,
  }) : channels = channels ?? (channel == null ? const [] : [channel]);

  final List<LiveChannel> channels;
  final int initialIndex;

  @override
  ConsumerState<LivePlayerScreen> createState() => _LivePlayerScreenState();
}

class _LivePlayerScreenState extends ConsumerState<LivePlayerScreen> {
  late final Player _player;
  late final VideoController _controller;

  late int _index = widget.initialIndex.clamp(
    0,
    widget.channels.isEmpty ? 0 : widget.channels.length - 1,
  );

  int _urlIndex = 0;
  bool _isBuffering = true;
  String? _error;
  bool _controlsVisible = true;
  Timer? _hideTimer;

  /// Mirrors that failed for the current channel, so a retry starts from the
  /// next candidate instead of replaying a URL already known to be dead.
  Set<int> _failedUrls = {};

  LiveChannel get _channel => widget.channels[_index];

  bool get _canZap => widget.channels.length > 1;

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
    _scheduleHide();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _player.dispose();
    super.dispose();
  }

  /// Hides the overlay after a few idle seconds, like a TV remote would.
  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _error == null) setState(() => _controlsVisible = false);
    });
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) _scheduleHide();
  }

  Future<void> _openCurrentUrl() async {
    final urls = _channel.urls;
    if (urls.isEmpty) {
      setState(() => _error = 'Aucun flux pour cette chaîne.');
      return;
    }
    final url = urls[_urlIndex.clamp(0, urls.length - 1)];
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
    for (var i = 0; i < _channel.urls.length; i++) {
      if (!_failedUrls.contains(i)) return i;
    }
    return null;
  }

  /// Switches to another channel in the list, resetting per-channel state.
  void _zap(int delta) {
    if (!_canZap) return;
    final next = (_index + delta) % widget.channels.length;
    setState(() {
      _index = next < 0 ? next + widget.channels.length : next;
      _urlIndex = 0;
      _failedUrls = {};
      _error = null;
    });
    _openCurrentUrl();
    _scheduleHide();
  }

  @override
  Widget build(BuildContext context) {
    final guide = ref.watch(epgProvider.select((state) => state.guide));
    final matcher = ref.watch(epgMatcherProvider);
    final now = DateTime.now();
    EpgProgramme? current;
    EpgProgramme? next;
    if (guide != null && matcher != null) {
      final guideId = matcher.guideIdFor(_channel);
      if (guideId != null) {
        current = guide.currentOn(guideId, now);
        next = guide.nextOn(guideId, now);
      }
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: _toggleControls,
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
              child: IgnorePointer(
                ignoring: !_controlsVisible,
                child: _buildOverlay(context, current, next, now),
              ),
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
              _channel.name,
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
                _failedUrls = {};
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

  Widget _buildOverlay(
    BuildContext context,
    EpgProgramme? current,
    EpgProgramme? next,
    DateTime now,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 24),
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
                      _channel.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      [
                        if (_channel.group != null) _channel.group!,
                        if (_canZap) '${_index + 1}/${widget.channels.length}',
                      ].join(' · '),
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
              if (_channel.urls.length > 1)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(
                    '${_urlIndex + 1}/${_channel.urls.length}',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
        const Spacer(),
        if (current != null || next != null)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.62),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (current != null) ...[
                  Row(
                    children: [
                      const Text(
                        'EN DIRECT',
                        style: TextStyle(
                          color: Color(0xFF7CC4FF),
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          current.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${clockLabel(current.start)} – '
                    '${clockLabel(current.stop)} · '
                    '${scheduleLabel(current, now)}',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: current.progressAt(now),
                      minHeight: 3,
                      backgroundColor: Colors.white24,
                    ),
                  ),
                ],
                if (next != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Ensuite · ${clockLabel(next.start)} ${next.title}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
        if (_canZap)
          Padding(
            padding: const EdgeInsets.only(bottom: 22),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ZapButton(
                  icon: Broken.arrow_down_2,
                  flipped: true,
                  label: 'Précédente',
                  onPressed: () => _zap(-1),
                ),
                const SizedBox(width: 18),
                _ZapButton(
                  icon: Broken.arrow_down_2,
                  label: 'Suivante',
                  onPressed: () => _zap(1),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ZapButton extends StatelessWidget {
  const _ZapButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.flipped = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool flipped;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Material(
        color: Colors.white.withValues(alpha: 0.12),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: RotatedBox(
              quarterTurns: flipped ? 2 : 0,
              child: Icon(icon, color: Colors.white, size: 20),
            ),
          ),
        ),
      ),
    );
  }
}
