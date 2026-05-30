// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/chapter.dart';

class AnimePlayerView extends ConsumerStatefulWidget {
  final int episodeId;
  const AnimePlayerView({super.key, required this.episodeId});

  @override
  ConsumerState<AnimePlayerView> createState() => _AnimePlayerViewState();
}

class _AnimePlayerViewState extends ConsumerState<AnimePlayerView> {
  bool _showControls = true;
  bool _isPlaying = true;
  bool _showLangPanel = false;
  bool _subtitlesEnabled = true;
  bool _bilingueEnabled = false;
  String _selectedAudio = 'Original Audio';
  String _selectedSubtitle = 'Français';
  double _currentPosition = 0.0;
  double _duration = 1.0;
  bool _videoReady = false;

  static const _bg = Color(0xFF0A0A0A);
  static const _teal = Color(0xFF1DB954);

  final List<String> _audioTracks = [
    'Original Audio', 'French dub', 'Spanish dub', 'esla dub', 'ptbr dub',
  ];
  final List<String> _subtitleTracks = [
    'Français', 'العربية', 'বাংলা', 'English', 'Indonesian',
  ];

  late final String _viewType;
  html.VideoElement? _video;
  Chapter? _chapter;

  @override
  void initState() {
    super.initState();
    _viewType = 'wt-video-${widget.episodeId}';
    _loadChapter();
  }

  void _loadChapter() {
    final ch = isar.chapters
        .filter()
        .idEqualTo(widget.episodeId)
        .findFirstSync();
    if (ch == null) return;
    _chapter = ch;

    final url = ch.url ?? '';
    if (url.isEmpty) return;

    _video = html.VideoElement()
      ..src = url
      ..autoplay = true
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = 'contain'
      ..style.background = '#000';

    _video!.onLoadedMetadata.listen((_) {
      if (mounted) setState(() {
        _duration = _video!.duration.isNaN ? 1.0 : _video!.duration.toDouble();
        _videoReady = true;
      });
    });

    _video!.onTimeUpdate.listen((_) {
      if (mounted) setState(() {
        _currentPosition = _video!.currentTime.toDouble();
      });
    });

    _video!.onPlay.listen((_) {
      if (mounted) setState(() => _isPlaying = true);
    });
    _video!.onPause.listen((_) {
      if (mounted) setState(() => _isPlaying = false);
    });

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (_) => _video!);

    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _video?.pause();
    super.dispose();
  }

  String _fmt(double s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toInt().toString().padLeft(2, '0');
    return '$m:$sec';
  }

  void _togglePlay() {
    if (_video == null) return;
    if (_isPlaying) {
      _video!.pause();
    } else {
      _video!.play();
    }
  }

  void _seek(double delta) {
    if (_video == null) return;
    final next = (_video!.currentTime + delta).clamp(0.0, _duration);
    _video!.currentTime = next;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (_showLangPanel) {
            setState(() => _showLangPanel = false);
          } else {
            setState(() => _showControls = !_showControls);
          }
        },
        child: Stack(
          children: [
            // ── Video area ──────────────────────────────────────────────────
            _buildVideoArea(),
            // ── Controls overlay ────────────────────────────────────────────
            if (_showControls && !_showLangPanel)
              _buildControlsOverlay(),
            // ── Lang panel ──────────────────────────────────────────────────
            if (_showLangPanel) _buildLanguagePanel(),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoArea() {
    if (_video == null) {
      return Container(
        color: _bg,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white38, strokeWidth: 2),
        ),
      );
    }
    return SizedBox.expand(
      child: HtmlElementView(viewType: _viewType),
    );
  }

  Widget _buildControlsOverlay() {
    return Positioned.fill(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xCC000000), Color(0x00000000), Color(0x00000000), Color(0xCC000000)],
            stops: [0.0, 0.2, 0.7, 1.0],
          ),
        ),
        child: Column(
          children: [
            _buildTopBar(),
            const Spacer(),
            _buildCenterControls(),
            const Spacer(),
            _buildProgressBar(),
            _buildBottomBar(),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final title = _chapter?.name ?? 'Watchtower';
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          children: [
            // "<" retour collé au lecteur
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => Navigator.of(context).pop(),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Icon(Icons.chevron_left, color: Colors.white, size: 28),
                ),
              ),
            ),
            // "Aide" collé directement après
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {},
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Text('Aide',
                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined, color: Colors.white, size: 20),
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _SeekButton(seconds: -10, onTap: () => _seek(-10)),
        const SizedBox(width: 32),
        GestureDetector(
          onTap: _togglePlay,
          child: Container(
            width: 56, height: 56,
            decoration: const BoxDecoration(shape: BoxShape.circle),
            child: Icon(
              _isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white, size: 38,
            ),
          ),
        ),
        const SizedBox(width: 32),
        _SeekButton(seconds: 10, onTap: () => _seek(10)),
      ],
    );
  }

  Widget _buildProgressBar() {
    final progress = _duration > 0 ? (_currentPosition / _duration).clamp(0.0, 1.0) : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SliderTheme(
        data: SliderThemeData(
          trackHeight: 2.5,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
          activeTrackColor: _teal,
          inactiveTrackColor: Colors.white24,
          thumbColor: Colors.white,
          overlayColor: Colors.white24,
        ),
        child: Slider(
          value: progress,
          onChanged: (v) {
            final target = v * _duration;
            if (_video != null) _video!.currentTime = target;
            setState(() => _currentPosition = target);
          },
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: _togglePlay,
            child: Icon(_isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Text(
            '${_fmt(_currentPosition)} — ${_fmt(_duration)}',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const Spacer(),
          _BottomBarButton(
            label: 'Langue',
            onTap: () => setState(() => _showLangPanel = true),
          ),
          _BottomBarButton(label: '1x', onTap: () {}),
          _BottomBarButton(label: '720P', onTap: () {}),
        ],
      ),
    );
  }

  Widget _buildLanguagePanel() {
    return Positioned.fill(
      child: GestureDetector(
        onTap: () => setState(() => _showLangPanel = false),
        child: Container(
          color: Colors.black54,
          child: Center(
            child: GestureDetector(
              onTap: () {},
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildAudioPanel(),
                  Container(width: 1, height: 360, color: Colors.white12),
                  _buildSubtitlePanel(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAudioPanel() {
    return Container(
      width: 180, height: 360,
      color: const Color(0xCC1A0808),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text('Audio',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
          ),
          const Divider(color: Colors.white12, height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: _audioTracks.length,
              itemBuilder: (_, i) {
                final track = _audioTracks[i];
                final selected = track == _selectedAudio;
                return InkWell(
                  onTap: () => setState(() => _selectedAudio = track),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(track,
                              style: TextStyle(
                                  color: selected ? _teal : Colors.white, fontSize: 13)),
                        ),
                        if (selected) const Icon(Icons.check, color: _teal, size: 16),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubtitlePanel() {
    return Container(
      width: 180, height: 360,
      color: const Color(0xCC080808),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                const Text('Sous-titre',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                const Spacer(),
                Switch(
                  value: _subtitlesEnabled,
                  onChanged: (v) => setState(() => _subtitlesEnabled = v),
                  activeColor: _teal,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text('Bilingue',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                const Spacer(),
                Switch(
                  value: _bilingueEnabled,
                  onChanged: _subtitlesEnabled
                      ? (v) => setState(() => _bilingueEnabled = v)
                      : null,
                  activeColor: _teal,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: _subtitleTracks.length,
              itemBuilder: (_, i) {
                final track = _subtitleTracks[i];
                final selected = track == _selectedSubtitle && _subtitlesEnabled;
                return InkWell(
                  onTap: _subtitlesEnabled
                      ? () => setState(() => _selectedSubtitle = track)
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(track,
                              style: TextStyle(
                                color: _subtitlesEnabled
                                    ? (selected ? _teal : Colors.white)
                                    : Colors.white30,
                                fontSize: 13,
                              )),
                        ),
                        Icon(Icons.download_outlined,
                            color: _subtitlesEnabled ? Colors.white54 : Colors.white12,
                            size: 16),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

class _SeekButton extends StatelessWidget {
  final int seconds;
  final VoidCallback onTap;
  const _SeekButton({required this.seconds, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isForward = seconds > 0;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 52, height: 52,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              isForward ? Icons.rotate_right_outlined : Icons.rotate_left_outlined,
              color: Colors.white, size: 40,
            ),
            Positioned(
              bottom: 10,
              child: Text('${seconds.abs()}',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomBarButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _BottomBarButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(left: 8),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white12, borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
      ),
    );
  }
}

// ── Route entry point ─────────────────────────────────────────────────────────

class AnimeStreamPage extends ConsumerWidget {
  final int episodeId;
  const AnimeStreamPage({super.key, required this.episodeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AnimePlayerView(episodeId: episodeId);
  }
}

class VideoPrefs {
  final bool fit;
  final double brightness;
  final double volume;
  final double playbackSpeed;
  final bool skipButton;
  final bool autoPlay;
  const VideoPrefs({
    this.fit = false, this.brightness = 0, this.volume = 100,
    this.playbackSpeed = 1.0, this.skipButton = true, this.autoPlay = true,
  });
}

Widget seekIndicatorTextWidget(Duration duration, Duration currentPosition) =>
    const SizedBox.shrink();
