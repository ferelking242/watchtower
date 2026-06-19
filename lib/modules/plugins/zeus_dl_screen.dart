import 'dart:async';
  import 'dart:convert';
  import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
  import 'package:flutter/material.dart';
  import 'package:flutter/services.dart';
  import 'package:path_provider/path_provider.dart';
  import 'package:watchtower/services/download_manager/engines/zeus_dl_binary_manager.dart';
  import 'package:watchtower/utils/log/logger.dart';

  enum _Format { video, audio, playlist }

  enum _DlState { checking, unavailable, idle, fetching, downloading, complete, error }

  class _HistoryItem {
    final String url;
    final String displayTitle;
    final _Format format;
    final bool success;
    const _HistoryItem({
      required this.url,
      required this.displayTitle,
      required this.format,
      required this.success,
    });
  }

  class ZeusDlScreen extends StatefulWidget {
    const ZeusDlScreen({super.key});

    @override
    State<ZeusDlScreen> createState() => _ZeusDlScreenState();
  }

  class _ZeusDlScreenState extends State<ZeusDlScreen> {
    final _urlController = TextEditingController();
    final _urlFocus = FocusNode();

    _Format _format = _Format.video;
    _DlState _dlState = _DlState.checking;

    double _progress = 0.0;
    String _speed = '';
    String _eta = '';
    String? _statusText;
    String? _errorText;

    ZeusDlExecutionContext? _ctx;
    Process? _process;
    final List<_HistoryItem> _history = [];

    @override
    void initState() {
      super.initState();
      _checkBinary();
    }

    @override
    void dispose() {
      _urlController.dispose();
      _urlFocus.dispose();
      _process?.kill();
      super.dispose();
    }

    // ── Binary availability ───────────────────────────────────────────────────

    Future<void> _checkBinary() async {
      setState(() => _dlState = _DlState.checking);
      try {
        final ctx = await ZeusDlBinaryManager.instance.resolveExecutionContext();
        if (!mounted) return;
        setState(() {
          _ctx = ctx;
          _dlState = ctx != null ? _DlState.idle : _DlState.unavailable;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _ctx = null;
          _dlState = _DlState.unavailable;
        });
      }
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    String get _urlText => _urlController.text.trim();
    bool get _hasUrl => _urlText.isNotEmpty;
    bool get _isActive =>
        _dlState == _DlState.fetching || _dlState == _DlState.downloading;

    Future<void> _paste() async {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data?.text != null && mounted) {
        _urlController.text = data!.text!.trim();
        setState(() {});
      }
    }

    void _resetToIdle() {
      _process?.kill();
      _process = null;
      _urlController.clear();
      setState(() {
        _dlState = _ctx != null ? _DlState.idle : _DlState.unavailable;
        _progress = 0.0;
        _speed = '';
        _eta = '';
        _statusText = null;
        _errorText = null;
      });
    }

    void _cancel() {
      _process?.kill();
      _process = null;
      if (!mounted) return;
      setState(() {
        _dlState = _DlState.idle;
        _progress = 0.0;
        _speed = '';
        _eta = '';
        _statusText = 'Annulé';
        _errorText = null;
      });
    }

    // ── Download logic ────────────────────────────────────────────────────────

    Future<void> _startDownload() async {
      if (!_hasUrl || _ctx == null || _isActive) return;
      final url = _urlText;

      if (!url.startsWith('http')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('URL invalide — ex: https://youtu.be/...')),
        );
        return;
      }

      setState(() {
        _dlState = _DlState.fetching;
        _statusText = 'Récupération des infos…';
        _progress = 0.0;
        _speed = '';
        _eta = '';
        _errorText = null;
      });

      try {
        final supportDir = await getApplicationSupportDirectory();
        final dlDir = Directory('${supportDir.path}/downloads');
        await dlDir.create(recursive: true);

        final tmpDir = Directory('${supportDir.path}/tmp');
        await tmpDir.create(recursive: true);

        final ctx = _ctx!;
        final args = _buildArgs(url, dlDir.path);
        final fullArgs = [...ctx.prependArgs, ...args];

        final env = Map<String, String>.from(ctx.extraEnv);
        env['TMPDIR'] = tmpDir.path;
        env['STATICX_TMPDIR'] = tmpDir.path;

        AppLogger.log('[ZeusDL] ${ctx.executable} ${fullArgs.join(" ")}',
            tag: LogTag.zeus, logLevel: LogLevel.debug);

        _process = await Process.start(ctx.executable, fullArgs, environment: env);

        if (!mounted) return;
        setState(() {
          _dlState = _DlState.downloading;
          _statusText = 'Téléchargement…';
        });

        _process!.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen(_onProgressLine);

        _process!.stderr
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen((line) {
          if (line.trim().isNotEmpty) {
            AppLogger.log('[ZeusDL] $line',
                tag: LogTag.zeus, logLevel: LogLevel.debug);
          }
        });

        final exitCode = await _process!.exitCode;
        if (!mounted) return;

        final displayTitle = url.length > 45
            ? '${url.substring(0, 45)}…'
            : url;

        if (exitCode == 0) {
          setState(() {
            _dlState = _DlState.complete;
            _progress = 1.0;
            _speed = '';
            _eta = '';
            _statusText = 'Terminé ✓  →  ${dlDir.path}';
            _history.insert(0, _HistoryItem(
              url: url,
              displayTitle: displayTitle,
              format: _format,
              success: true,
            ));
          });
        } else {
          setState(() {
            _dlState = _DlState.error;
            _errorText = "Échec (code $exitCode). Vérifiez l'URL ou le format.";
            _history.insert(0, _HistoryItem(
              url: url,
              displayTitle: displayTitle,
              format: _format,
              success: false,
            ));
          });
        }
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _dlState = _DlState.error;
          _errorText = 'Erreur: $e';
        });
      } finally {
        _process = null;
      }
    }

    List<String> _buildArgs(String url, String outputDir) {
      return <String>[
        '-o', '$outputDir/%(title)s.%(ext)s',
        '--newline',
        '--progress',
        '--progress-template',
        '%(progress._percent_str)s|%(progress._speed_str)s|%(progress._eta_str)s',
        '--no-warnings',
        if (_format == _Format.playlist) '--yes-playlist' else '--no-playlist',
        if (_format == _Format.audio) ...['-x', '--audio-format', 'mp3', '--audio-quality', '0'],
        url,
      ];
    }

    void _onProgressLine(String line) {
      final parts = line.split('|');
      final percentStr = parts[0].trim().replaceAll('%', '').trim();
      final percent = double.tryParse(percentStr);
      if (percent != null && mounted) {
        setState(() {
          _progress = (percent / 100).clamp(0.0, 1.0);
          _speed = parts.length >= 2 ? parts[1].trim() : '';
          _eta = parts.length >= 3 ? parts[2].trim() : '';
          if (_dlState != _DlState.downloading) _dlState = _DlState.downloading;
        });
      }
    }

    // ── UI ────────────────────────────────────────────────────────────────────

    @override
    Widget build(BuildContext context) {
      final cs = Theme.of(context).colorScheme;

      return Scaffold(
        backgroundColor: cs.surface,
        appBar: AppBar(
          title: const Text('ZeusDL'),
          centerTitle: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Vérifier le binaire',
              onPressed: _isActive ? null : _checkBinary,
            ),
          ],
        ),
        body: _dlState == _DlState.checking
            ? const Center(child: CircularProgressIndicator())
            : _dlState == _DlState.unavailable
                ? _buildUnavailable(cs)
                : _buildMain(cs),
      );
    }

    Widget _buildUnavailable(ColorScheme cs) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.download_for_offline_outlined,
                  size: 64, color: cs.onSurfaceVariant.withValues(alpha: 0.3)),
              const SizedBox(height: 20),
              Text(
                'Binaire ZeusDL indisponible',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                "Le binaire ZeusDL n'a pas pu être chargé.\n"
                'Vérifiez Paramètres > Avancé > ZeusDL.',
                style: TextStyle(
                    fontSize: 14,
                    color: cs.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _checkBinary,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    Widget _buildMain(ColorScheme cs) {
      final showProgress = _dlState != _DlState.idle;

      return Column(
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
                  if (_history.isNotEmpty) ...[
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
                  if (_history.isEmpty && !showProgress) ...[
                    _buildEmptyState(cs),
                  ],
                ],
              ),
            ),
          ),
          _buildBottomBar(cs),
        ],
      );
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
                enabled: !_isActive,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Coller un lien (YouTube, TikTok, Instagram…)',
                  hintStyle: TextStyle(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.55)),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                ),
                style: const TextStyle(fontSize: 15),
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.go,
                onSubmitted: (_) => _startDownload(),
              ),
            ),
            if (_hasUrl && !_isActive)
              IconButton(
                onPressed: _resetToIdle,
                icon: const Icon(Icons.cancel_outlined),
                iconSize: 20,
                color: cs.onSurfaceVariant,
              )
            else if (!_hasUrl && !_isActive)
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
              onSelected: _isActive ? null : (_) => setState(() => _format = e.$1),
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
      final isDone = _dlState == _DlState.complete;
      final isError = _dlState == _DlState.error;
      final isFetching = _dlState == _DlState.fetching;
      final isDownloading = _dlState == _DlState.downloading;

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDone
                ? Colors.green.withValues(alpha: 0.4)
                : isError
                    ? cs.error.withValues(alpha: 0.4)
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
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
                  )
                else
                  Icon(
                    isDone
                        ? Icons.check_circle_rounded
                        : isError
                            ? Icons.error_outline_rounded
                            : Icons.download_for_offline_rounded,
                    color: isDone
                        ? Colors.green
                        : isError
                            ? cs.error
                            : cs.primary,
                    size: 20,
                  ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isError
                        ? (_errorText ?? 'Erreur inconnue')
                        : (_statusText ?? ''),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isError ? cs.error : cs.onSurface,
                    ),
                  ),
                ),
                if (_isActive)
                  TextButton(
                    onPressed: _cancel,
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
              Row(
                children: [
                  Text(
                    '${(_progress * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface),
                  ),
                  if (_speed.isNotEmpty && _speed != 'N/A') ...[
                    Text('  ·  $_speed',
                        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                  ],
                  if (_eta.isNotEmpty && _eta != 'N/A') ...[
                    Text('  ·  ETA $_eta',
                        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                  ],
                ],
              ),
            ],
          ],
        ),
      );
    }

    Widget _buildEmptyState(ColorScheme cs) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            children: [
              Icon(
                Icons.download_for_offline_outlined,
                size: 60,
                color: cs.onSurfaceVariant.withValues(alpha: 0.2),
              ),
              const SizedBox(height: 12),
              Text(
                'Colle un lien et appuie sur Télécharger',
                style: TextStyle(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                    fontSize: 14),
              ),
              const SizedBox(height: 6),
              Text(
                'YouTube · TikTok · Twitter · Instagram · +1 000 sites',
                style: TextStyle(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.35),
                    fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    Widget _buildHistoryList(ColorScheme cs) {
      return Column(
        children: _history.take(10).map((item) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: item.success
                        ? cs.primaryContainer.withValues(alpha: 0.5)
                        : cs.errorContainer.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    item.format == _Format.audio
                        ? Icons.music_note_outlined
                        : item.format == _Format.playlist
                            ? Icons.playlist_play_rounded
                            : Icons.videocam_outlined,
                    size: 18,
                    color: item.success ? cs.primary : cs.error,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.displayTitle,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  item.success
                      ? Icons.check_circle_outline_rounded
                      : Icons.cancel_outlined,
                  size: 16,
                  color: item.success ? Colors.green : cs.error,
                ),
              ],
            ),
          );
        }).toList(),
      );
    }

    Widget _buildBottomBar(ColorScheme cs) {
      final label = switch (_dlState) {
        _DlState.fetching => 'Analyse…',
        _DlState.downloading => 'Téléchargement… ${(_progress * 100).toStringAsFixed(0)}%',
        _DlState.complete => 'Nouveau téléchargement',
        _DlState.error => 'Réessayer',
        _ => 'Télécharger',
      };

      final icon = switch (_dlState) {
        _DlState.complete => Icons.add_rounded,
        _DlState.error => Icons.refresh_rounded,
        _ => Icons.download_rounded,
      };

      final onPressed = _isActive
          ? null
          : _dlState == _DlState.complete
              ? _resetToIdle
              : _dlState == _DlState.error
                  ? () {
                      setState(() {
                        _dlState = _DlState.idle;
                        _errorText = null;
                        _statusText = null;
                      });
                    }
                  : _hasUrl
                      ? _startDownload
                      : null;

      return SafeArea(
        top: false,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          decoration: BoxDecoration(
            color: cs.surface,
            border: Border(
              top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.4)),
            ),
          ),
          child: FilledButton.icon(
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(label),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      );
    }
  }
  