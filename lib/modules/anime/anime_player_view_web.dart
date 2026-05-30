import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AnimePlayerView extends ConsumerStatefulWidget {
  final int episodeId;
  const AnimePlayerView({super.key, required this.episodeId});

  @override
  ConsumerState<AnimePlayerView> createState() => _AnimePlayerViewState();
}

class _AnimePlayerViewState extends ConsumerState<AnimePlayerView> {
  bool _showControls = true;
  bool _isPlaying = false;
  bool _showLangPanel = false;
  bool _subtitlesEnabled = true;
  bool _bilingueEnabled = false;
  String _selectedAudio = 'Original Audio';
  String _selectedSubtitle = 'Français';
  double _currentPosition = 151.0;
  static const double _duration = 1382.0;

  static const _bg = Color(0xFF0A0A0A);
  static const _teal = Color(0xFF1DB954);
  static const _overlay = Color(0x99000000);

  final List<String> _audioTracks = [
    'Original Audio',
    'French dub',
    'Spanish dub',
    'esla dub',
    'ptbr dub',
  ];
  final List<String> _subtitleTracks = [
    'Français',
    'العربية',
    'বাংলা',
    'English',
    'Indonesian',
  ];

  String _formatTime(double seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toInt().toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: _bg,
      body: GestureDetector(
        onTap: () {
          if (_showLangPanel) {
            setState(() => _showLangPanel = false);
          } else {
            setState(() => _showControls = !_showControls);
          }
        },
        child: Stack(
          children: [
            _buildVideoArea(isLandscape),
            if (_showControls && !_showLangPanel)
              _buildControlsOverlay(isLandscape),
            if (_showLangPanel) _buildLanguagePanel(),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoArea(bool isLandscape) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: _bg,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isPlaying ? Icons.play_circle_outline : Icons.pause_circle_outline,
              size: 64,
              color: Colors.white.withValues(alpha: 0.08),
            ),
            const SizedBox(height: 12),
            Text(
              'Lecture non disponible sur web',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.15),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlsOverlay(bool isLandscape) {
    return Positioned.fill(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xCC000000),
              Color(0x00000000),
              Color(0x00000000),
              Color(0xCC000000),
            ],
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
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          children: [
            // Bouton retour "<" collé au lecteur
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => Navigator.of(context).pop(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  child: const Icon(Icons.chevron_left,
                      color: Colors.white, size: 28),
                ),
              ),
            ),
            // Bouton Aide — collé directement après "<"
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {},
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 8),
                  child: const Text(
                    'Aide',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: const Text(
                'Le Monde Incroyable de Gumball S01 E01 · The DVD',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined,
                  color: Colors.white, size: 20),
              onPressed: () {},
              tooltip: 'Paramètres',
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
        Padding(
          padding: const EdgeInsets.only(right: 40),
          child: Column(
            children: [
              Icon(Icons.lock_open_outlined,
                  color: Colors.white70, size: 20),
              const SizedBox(height: 4),
              const Text(
                'Verrouiller',
                style: TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
        ),
        _SeekButton(seconds: -10, onTap: () {
          setState(() => _currentPosition =
              (_currentPosition - 10).clamp(0.0, _duration));
        }),
        const SizedBox(width: 32),
        GestureDetector(
          onTap: () => setState(() => _isPlaying = !_isPlaying),
          child: Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(shape: BoxShape.circle),
            child: Icon(
              _isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
              size: 36,
            ),
          ),
        ),
        const SizedBox(width: 32),
        _SeekButton(seconds: 10, onTap: () {
          setState(() =>
              _currentPosition = (_currentPosition + 10).clamp(0.0, _duration));
        }),
        const SizedBox(width: 40),
        const SizedBox(width: 20),
      ],
    );
  }

  Widget _buildProgressBar() {
    final progress = _currentPosition / _duration;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 2.5,
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape:
                  const RoundSliderOverlayShape(overlayRadius: 12),
              activeTrackColor: _teal,
              inactiveTrackColor: Colors.white24,
              thumbColor: Colors.white,
              overlayColor: Colors.white24,
            ),
            child: Slider(
              value: progress,
              onChanged: (v) =>
                  setState(() => _currentPosition = v * _duration),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          IconButton(
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.pause, color: Colors.white, size: 22),
            onPressed: () => setState(() => _isPlaying = !_isPlaying),
          ),
          const SizedBox(width: 4),
          IconButton(
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.skip_next, color: Colors.white, size: 22),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
          Text(
            '${_formatTime(_currentPosition)} — ${_formatTime(_duration)}',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const Spacer(),
          _BottomBarButton(label: 'Ajuster', onTap: () {}),
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
      width: 180,
      height: 360,
      color: const Color(0xCC1A0808),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              'Audio',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            track,
                            style: TextStyle(
                              color: selected ? _teal : Colors.white,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        if (selected)
                          const Icon(Icons.check,
                              color: _teal, size: 16),
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
      width: 180,
      height: 360,
      color: const Color(0xCC080808),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                const Text(
                  'Sous-titre',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Switch(
                  value: _subtitlesEnabled,
                  onChanged: (v) =>
                      setState(() => _subtitlesEnabled = v),
                  activeColor: _teal,
                  materialTapTargetSize:
                      MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text('Bilingue',
                    style: TextStyle(
                        color: Colors.white70, fontSize: 13)),
                const Spacer(),
                Switch(
                  value: _bilingueEnabled,
                  onChanged: _subtitlesEnabled
                      ? (v) => setState(() => _bilingueEnabled = v)
                      : null,
                  activeColor: _teal,
                  materialTapTargetSize:
                      MaterialTapTargetSize.shrinkWrap,
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
                final selected =
                    track == _selectedSubtitle && _subtitlesEnabled;
                return InkWell(
                  onTap: _subtitlesEnabled
                      ? () => setState(() => _selectedSubtitle = track)
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            track,
                            style: TextStyle(
                              color: _subtitlesEnabled
                                  ? (selected ? _teal : Colors.white)
                                  : Colors.white30,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.download_outlined,
                          color: _subtitlesEnabled
                              ? Colors.white54
                              : Colors.white12,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(color: Colors.white12, height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.text_format,
                      size: 14, color: Colors.white54),
                  label: const Text('Style',
                      style: TextStyle(
                          color: Colors.white54, fontSize: 12)),
                  style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0)),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.schedule,
                      size: 14, color: Colors.white54),
                  label: const Text('Délai',
                      style: TextStyle(
                          color: Colors.white54, fontSize: 12)),
                  style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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
        width: 52,
        height: 52,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              isForward
                  ? Icons.rotate_right_outlined
                  : Icons.rotate_left_outlined,
              color: Colors.white,
              size: 40,
            ),
            Positioned(
              bottom: 10,
              child: Text(
                '${seconds.abs()}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
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
          color: Colors.white12,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 11),
        ),
      ),
    );
  }
}

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
    this.fit = false,
    this.brightness = 0,
    this.volume = 100,
    this.playbackSpeed = 1.0,
    this.skipButton = true,
    this.autoPlay = true,
  });
}

Widget seekIndicatorTextWidget(Duration duration, Duration currentPosition) {
  return const SizedBox.shrink();
}
