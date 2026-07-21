import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:watchtower/services/extension_diagnostics.dart';

class DiagVideoPreview extends StatefulWidget {
  final List<DiagMediaUrl> urls;
  final ColorScheme cs;

  const DiagVideoPreview({required this.urls, required this.cs, super.key});

  @override
  State<DiagVideoPreview> createState() => _DiagVideoPreviewState();
}

class _DiagVideoPreviewState extends State<DiagVideoPreview> {
  Player? _player;
  VideoController? _controller;
  bool _loading = false;
  bool _playing = false;
  String? _error;
  int _selectedIdx = 0;

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  Future<void> _play(int idx) async {
    setState(() {
      _loading = true;
      _error = null;
      _selectedIdx = idx;
      _playing = false;
    });
    try {
      _player?.dispose();
      _player = Player();
      _controller = VideoController(_player!);
      final url = widget.urls[idx];
      await _player!.open(Media(url.url, httpHeaders: url.headers ?? {}));
      if (mounted) setState(() { _loading = false; _playing = true; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final urls = widget.urls;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Quality chips
        if (urls.length > 1) ...[
          SizedBox(
            height: 28,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: urls.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final u = urls[i];
                final sel = _selectedIdx == i && _playing;
                return GestureDetector(
                  onTap: () => _play(i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: sel ? cs.primaryContainer : cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: sel ? cs.primary : cs.outlineVariant),
                    ),
                    child: Text(
                      u.quality.isNotEmpty ? u.quality : 'Source ${i + 1}',
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600,
                          color: sel ? cs.primary : cs.onSurfaceVariant),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],

        // Player
        AspectRatio(
          aspectRatio: 16 / 9,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              color: Colors.black,
              child: _playing && _controller != null
                  ? Video(controller: _controller!, fit: BoxFit.contain)
                  : _error != null
                      ? Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline_rounded, color: cs.error, size: 32),
                              const SizedBox(height: 8),
                              Text(_error!,
                                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                                  textAlign: TextAlign.center),
                            ],
                          ),
                        )
                      : Center(
                          child: _loading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : GestureDetector(
                                  onTap: () => _play(0),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.15),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.play_arrow_rounded,
                                            color: Colors.white, size: 40),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        '${urls[0].quality.isNotEmpty ? urls[0].quality : "Source 1"} — Toucher pour lire',
                                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                        ),
            ),
          ),
        ),
      ],
    );
  }
}
