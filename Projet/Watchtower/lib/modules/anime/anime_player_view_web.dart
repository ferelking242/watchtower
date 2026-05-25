// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/main.dart' show isar;

class AnimePlayerView extends ConsumerStatefulWidget {
  final int episodeId;
  const AnimePlayerView({super.key, required this.episodeId});

  @override
  ConsumerState<AnimePlayerView> createState() => _AnimePlayerViewState();
}

class _AnimePlayerViewState extends ConsumerState<AnimePlayerView> {
  // Static caches – survive widget rebuilds / re-navigation
  static final _registeredViews = <String>{};
  static final _videoElements = <String, html.VideoElement>{};

  html.VideoElement? _video;
  String _viewType = '';

  // ── Player state ──────────────────────────────────────────────────────────
  bool _showControls = true;
  bool _isPlaying = false;
  bool _showLangPanel = false;
  bool _subtitlesEnabled = true;
  String _selectedAudio = 'Original Audio';
  String _selectedSubtitle = 'Français';
  double _currentSec = 0;
  double _totalSec = 1;
  String _title = '';
  String _coverUrl = '';
  bool _loaded = false;
  String? _error;

  static const _teal = Color(0xFF1DB954);

  final _audioTracks = const [
    'Original Audio',
    'French dub',
    'Spanish dub',
    'Arabic dub',
    'Portuguese dub',
  ];
  final _subtitleTracks = const [
    'Français',
    'English',
    'العربية',
    'Español',
    'Português',
  ];

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _viewType = 'watchtower-video-${widget.episodeId}';
    _initPlayer();
  }

  void _initPlayer() {
    try {
      final chapter = isar.chapters.getSync(widget.episodeId);
      final manga = chapter?.manga.value;

      var videoUrl = chapter?.url ?? '';
      if (videoUrl.isEmpty) videoUrl = chapter?.archivePath ?? '';

      _title = [
        manga?.name ?? '',
        if (chapter != null && chapter.name != manga?.name) chapter.name,
      ].where((s) => s.isNotEmpty).join(' — ');
      _coverUrl = manga?.imageUrl ?? '';

      if (videoUrl.isEmpty) {
        setState(() => _error = 'Aucune URL vidéo trouvée pour cet épisode.');
        return;
      }

      // Reuse or create the VideoElement
      if (_videoElements.containsKey(_viewType)) {
        _video = _videoElements[_viewType]!;
        if (_video!.src != videoUrl) _video!.src = videoUrl;
      } else {
        final el = html.VideoElement()
          ..src = videoUrl
          ..preload = 'auto'
          ..poster = _coverUrl
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.objectFit = 'contain'
          ..style.background = '#000000';
        _video = el;
        _videoElements[_viewType] = el;
      }

      // ── Event listeners ────────────────────────────────────────────────
      _video!.onTimeUpdate.listen((_) {
        if (!mounted) return;
        final d = _video!.duration;
        setState(() {
          _currentSec = _video!.currentTime.toDouble();
          _totalSec = (d.isNaN || d.isInfinite || d <= 0) ? 1 : d.toDouble();
        });
      });

      _video!.onPlay.listen((_) {
        if (mounted) setState(() => _isPlaying = true);
      });
      _video!.onPause.listen((_) {
        if (mounted) setState(() => _isPlaying = false);
      });
      _video!.onEnded.listen((_) {
        if (mounted) setState(() => _isPlaying = false);
      });
      _video!.onError.listen((_) {
        if (mounted) {
          setState(
            () => _error =
                'Impossible de lire la vidéo.\nVérifiez votre connexion internet.',
          );
        }
      });

      // Register the platform view factory once per viewType
      if (!_registeredViews.contains(_viewType)) {
        // ignore: undefined_prefixed_name
        ui_web.platformViewRegistry.registerViewFactory(
          _viewType,
          (int id) => _videoElements[_viewType] ?? html.VideoElement(),
        );
        _registeredViews.add(_viewType);
      }

      setState(() => _loaded = true);
    } catch (e) {
      setState(() => _error = 'Erreur d\'initialisation du lecteur :\n$e');
    }
  }

  // ── Controls ──────────────────────────────────────────────────────────────

  void _togglePlay() {
    if (_video == null) return;
    if (_video!.paused) {
      _video!.play();
    } else {
      _video!.pause();
    }
  }

  void _skipBy(double seconds) {
    if (_video == null) return;
    final maxT = _video!.duration.isNaN ? 0.0 : _video!.duration;
    _video!.currentTime = (_video!.currentTime + seconds).clamp(0.0, maxT);
  }

  void _seekTo(double fraction) {
    if (_video == null) return;
    final maxT = _video!.duration.isNaN ? 0.0 : _video!.duration;
    _video!.currentTime = (fraction * maxT).clamp(0.0, maxT);
  }

  String _fmt(double sec) {
    if (sec.isNaN || sec.isInfinite || sec < 0) return '--:--';
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toInt().toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _video?.pause();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _error != null
            ? _buildError()
            : !_loaded
                ? _buildLoading()
                : _buildPlayer(isLandscape),
      ),
    );
  }

  // ── State screens ─────────────────────────────────────────────────────────

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: _teal),
          SizedBox(height: 16),
          Text(
            'Chargement du lecteur…',
            style: TextStyle(color: Colors.white54),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 52),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _teal,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                setState(() {
                  _error = null;
                  _loaded = false;
                });
                _initPlayer();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Player ────────────────────────────────────────────────────────────────

  Widget _buildPlayer(bool isLandscape) {
    return Stack(
      children: [
        // ── Video surface ──────────────────────────────────────────────
        Positioned.fill(
          child: HtmlElementView(viewType: _viewType),
        ),

        // ── Controls overlay ───────────────────────────────────────────
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => setState(() => _showControls = !_showControls),
            onDoubleTapDown: (d) {
              final half = MediaQuery.of(context).size.width / 2;
              _skipBy(d.localPosition.dx < half ? -10 : 10);
            },
            child: AnimatedOpacity(
              opacity: _showControls ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !_showControls,
                child: _buildControls(isLandscape),
              ),
            ),
          ),
        ),

        // ── Language / Audio panel ─────────────────────────────────────
        if (_showLangPanel)
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: isLandscape ? 280 : 260,
            child: _buildLangPanel(),
          ),
      ],
    );
  }

  Widget _buildControls(bool isLandscape) {
    final progress =
        _totalSec > 0 ? (_currentSec / _totalSec).clamp(0.0, 1.0) : 0.0;

    return Column(
      children: [
        // ── Top bar ────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xCC000000), Colors.transparent],
            ),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new,
                    color: Colors.white, size: 20),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              Expanded(
                child: Text(
                  _title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.language,
                  color: _showLangPanel ? _teal : Colors.white,
                  size: 22,
                ),
                tooltip: 'Audio / Sous-titres',
                onPressed: () =>
                    setState(() => _showLangPanel = !_showLangPanel),
              ),
            ],
          ),
        ),

        // ── Centre (big play button) ───────────────────────────────────
        Expanded(
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: IconButton(
                key: ValueKey(_isPlaying),
                icon: Icon(
                  _isPlaying
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_filled,
                  color: Colors.white,
                  size: 72,
                ),
                onPressed: _togglePlay,
              ),
            ),
          ),
        ),

        // ── Bottom bar ─────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Color(0xCC000000), Colors.transparent],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.replay_10,
                        color: Colors.white, size: 26),
                    onPressed: () => _skipBy(-10),
                    tooltip: '-10s',
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6),
                        overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 12),
                        activeTrackColor: _teal,
                        inactiveTrackColor: Colors.white24,
                        thumbColor: Colors.white,
                        overlayColor: _teal.withOpacity(0.25),
                      ),
                      child: Slider(
                        value: progress.toDouble(),
                        onChanged: _seekTo,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.forward_10,
                        color: Colors.white, size: 26),
                    onPressed: () => _skipBy(10),
                    tooltip: '+10s',
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    Text(
                      '${_fmt(_currentSec)} / ${_fmt(_totalSec)}',
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12),
                    ),
                    const Spacer(),
                    _Chip('1080p'),
                    const SizedBox(width: 6),
                    _Chip('MP4'),
                    if (_subtitlesEnabled) ...[
                      const SizedBox(width: 6),
                      _Chip('ST $_selectedSubtitle',
                          color: _teal.withOpacity(0.2)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Language panel ────────────────────────────────────────────────────────

  Widget _buildLangPanel() {
    return Container(
      color: const Color(0xF0101010),
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Audio & Sous-titres',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close,
                      color: Colors.white54, size: 18),
                  onPressed: () =>
                      setState(() => _showLangPanel = false),
                ),
              ],
            ),
            const Divider(color: Colors.white12),
            const SizedBox(height: 4),
            _sectionLabel('PISTE AUDIO'),
            const SizedBox(height: 4),
            ..._audioTracks.map(
              (t) => _LangTile(
                label: t,
                selected: t == _selectedAudio,
                onTap: () => setState(() => _selectedAudio = t),
              ),
            ),
            const SizedBox(height: 12),
            _sectionLabel('SOUS-TITRES'),
            const SizedBox(height: 4),
            _LangTile(
              label: 'Désactivés',
              selected: !_subtitlesEnabled,
              icon: Icons.subtitles_off_outlined,
              onTap: () => setState(() => _subtitlesEnabled = false),
            ),
            ..._subtitleTracks.map(
              (t) => _LangTile(
                label: t,
                selected: _subtitlesEnabled && t == _selectedSubtitle,
                onTap: () => setState(() {
                  _subtitlesEnabled = true;
                  _selectedSubtitle = t;
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) => Text(
        label,
        style: const TextStyle(
          color: Colors.white38,
          fontSize: 10,
          letterSpacing: 1.4,
          fontWeight: FontWeight.w600,
        ),
      );
}

// ── Small helpers ─────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final String label;
  final Color? color;
  const _Chip(this.label, {this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color ?? Colors.white10,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white70, fontSize: 10),
      ),
    );
  }
}

class _LangTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  const _LangTile({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  static const _teal = Color(0xFF1DB954);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
        child: Row(
          children: [
            Icon(
              icon ??
                  (selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off),
              size: 16,
              color: selected ? _teal : Colors.white38,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white60,
                fontSize: 13,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}