import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum _Format { video, audio, playlist }

enum _DlState { idle, fetching, downloading, complete, error }

class ZeusDlScreen extends StatefulWidget {
  const ZeusDlScreen({super.key});

  @override
  State<ZeusDlScreen> createState() => _ZeusDlScreenState();
}

class _ZeusDlScreenState extends State<ZeusDlScreen> {
  final _urlController = TextEditingController();
  final _urlFocus = FocusNode();
  _Format _format = _Format.video;
  _DlState _dlState = _DlState.idle;
  double _progress = 0.0;
  String? _statusText;
  Timer? _progressTimer;
  final List<Map<String, dynamic>> _history = [];

  @override
  void dispose() {
    _urlController.dispose();
    _urlFocus.dispose();
    _progressTimer?.cancel();
    super.dispose();
  }

  String get _urlText => _urlController.text.trim();
  bool get _hasUrl => _urlText.isNotEmpty;

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && mounted) {
      _urlController.text = data!.text!.trim();
      setState(() {});
    }
  }

  void _clear() {
    _urlController.clear();
    _progressTimer?.cancel();
    setState(() {
      _dlState = _DlState.idle;
      _progress = 0.0;
      _statusText = null;
    });
  }

  void _download() {
    if (!_hasUrl) return;
    final url = _urlText;
    if (!url.startsWith('http')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('URL invalide. Exemple : https://youtu.be/...')),
      );
      return;
    }
    setState(() {
      _dlState = _DlState.fetching;
      _statusText = 'Analyse de la vidéo…';
      _progress = 0.0;
    });
    Future.delayed(const Duration(milliseconds: 1300), () {
      if (!mounted) return;
      setState(() {
        _dlState = _DlState.downloading;
        _statusText = 'Téléchargement en cours…';
      });
      _progressTimer =
          Timer.periodic(const Duration(milliseconds: 70), (t) {
        if (!mounted) {
          t.cancel();
          return;
        }
        setState(() => _progress += 0.012);
        if (_progress >= 1.0) {
          t.cancel();
          if (mounted) {
            setState(() {
              _dlState = _DlState.complete;
              _progress = 1.0;
              _statusText = 'yt-dlp requis pour le téléchargement réel';
              _history.insert(0, {
                'url': url,
                'title': url.length > 40 ? url.substring(0, 40) + '…' : url,
                'format': _format,
              });
            });
          }
        }
      });
    });
  }

  Widget _buildUrlField(ColorScheme cs) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _urlController,
              focusNode: _urlFocus,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Coller un lien vidéo ici',
                hintStyle: TextStyle(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.55)),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              ),
              style: const TextStyle(fontSize: 15),
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.go,
              onSubmitted: (_) => _download(),
            ),
          ),
          if (_hasUrl)
            IconButton(
              onPressed: _clear,
              icon: const Icon(Icons.cancel_outlined),
              iconSize: 20,
              color: cs.onSurfaceVariant,
            )
          else
            IconButton(
              onPressed: _paste,
              icon: const Icon(Icons.content_paste_rounded),
              iconSize: 20,
              color: cs.onSurfaceVariant,
              tooltip: 'Coller',
            ),
        ],
      ),
    );
  }

  Widget _buildFormatBar(ColorScheme cs) {
    const items = [
      (_Format.video, Icons.videocam_outlined, 'Vidéo'),
      (_Format.audio, Icons.music_note_outlined, 'Audio'),
      (_Format.playlist, Icons.playlist_play_rounded, 'Playlist'),
    ];
    return Row(
      children: items.map((e) {
        final selected = _format == e.$1;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            avatar: Icon(e.$2, size: 16),
            label: Text(e.$3),
            selected: selected,
            onSelected: (_) => setState(() => _format = e.$1),
            showCheckmark: false,
            labelStyle: TextStyle(
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              fontSize: 13,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildProgressCard(ColorScheme cs) {
    final isDownloading = _dlState == _DlState.downloading;
    final isDone = _dlState == _DlState.complete;
    final isFetching = _dlState == _DlState.fetching;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDone
              ? Colors.green.withValues(alpha: 0.4)
              : cs.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isFetching)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: cs.primary),
                )
              else
                Icon(
                  isDone
                      ? Icons.check_circle_rounded
                      : Icons.download_for_offline_rounded,
                  color: isDone ? Colors.green : cs.primary,
                  size: 20,
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _statusText ?? '',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                  ),
                ),
              ),
              if (isDownloading || isFetching)
                TextButton(
                  onPressed: _clear,
                  style: TextButton.styleFrom(
                    foregroundColor: cs.error,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text('Annuler'),
                ),
            ],
          ),
          if (isDownloading || isDone) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _progress,
                minHeight: 5,
                backgroundColor: cs.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isDone
                  ? 'yt-dlp requis pour le téléchargement réel'
                  : '${(_progress * 100).toInt()}%',
              style:
                  TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHistoryList(ColorScheme cs) {
    if (_history.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            children: [
              Icon(
                Icons.download_for_offline_outlined,
                size: 60,
                color: cs.onSurfaceVariant.withValues(alpha: 0.25),
              ),
              const SizedBox(height: 12),
              Text(
                'Aucun téléchargement récent',
                style: TextStyle(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      children: _history.map((item) {
        final fmt = item['format'] as _Format;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  fmt == _Format.audio
                      ? Icons.music_note_outlined
                      : Icons.videocam_outlined,
                  size: 20,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item['title'] as String,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(
                Icons.check_circle_outline_rounded,
                size: 18,
                color: Colors.green,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final showProgress = _dlState != _DlState.idle;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('ZeusDL'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open_outlined),
            tooltip: 'Téléchargements',
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Paramètres',
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildUrlField(cs),
                  const SizedBox(height: 14),
                  _buildFormatBar(cs),
                  const SizedBox(height: 20),
                  if (showProgress) ...[
                    _buildProgressCard(cs),
                    const SizedBox(height: 20),
                  ],
                  if (!showProgress) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'RÉCENTS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                    _buildHistoryList(cs),
                  ],
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded,
                            size: 17, color: cs.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'ZeusDL utilise yt-dlp. Supporte YouTube, '
                            'Twitter, TikTok, Instagram et +1000 sites.',
                            style: TextStyle(
                                fontSize: 12, color: cs.onPrimaryContainer),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              decoration: BoxDecoration(
                color: cs.surface,
                border: Border(
                  top: BorderSide(
                      color: cs.outlineVariant.withValues(alpha: 0.4)),
                ),
              ),
              child: FilledButton.icon(
                onPressed:
                    _hasUrl && _dlState == _DlState.idle ? _download : null,
                icon: const Icon(Icons.download_rounded),
                label: Text(
                  switch (_dlState) {
                    _DlState.fetching => 'Analyse…',
                    _DlState.downloading => 'Téléchargement…',
                    _DlState.complete => 'Terminé ✓',
                    _ => 'Télécharger',
                  },
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
