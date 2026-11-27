import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:watchtower/eval/model/m_bridge.dart';
import 'package:watchtower/services/app_updater/app_update_service.dart'
    if (dart.library.js_interop) 'package:watchtower/services/app_updater/app_update_service_web.dart';
import 'package:watchtower/services/app_updater/update_models.dart';

const String _kReleaseFallbackUrl =
    'https://github.com/ferelking242/watchtower/releases';

/// Full-screen update sheet: changelog rendered like Mihon's update screen,
/// download / later actions pinned at the bottom and the release history.
class UpdatePage extends StatefulWidget {
  const UpdatePage({super.key, required this.initial});

  final UpdateInfoView initial;

  @override
  State<UpdatePage> createState() => _UpdatePageState();
}

class _UpdatePageState extends State<UpdatePage>
    with SingleTickerProviderStateMixin {
  static const _historyPreview = 4;

  late UpdateInfoView _info = widget.initial;
  StreamSubscription<UpdateInfoView>? _subscription;
  late final Future<List<UpdateHistoryEntry>> _history = AppUpdateService
      .instance
      .history();
  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat(reverse: true);

  bool _busy = false;
  bool _showAllHistory = false;

  bool get _isFrench => Localizations.localeOf(context).languageCode == 'fr';
  bool get _hasUpdate =>
      _info.updateAvailable || _info.isReady || _info.isDownloading;

  @override
  void initState() {
    super.initState();
    _subscription = AppUpdateService.instance.updates.listen((view) {
      if (mounted) setState(() => _info = view);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _glow.dispose();
    super.dispose();
  }

  Future<void> _download() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final state = await AppUpdateService.instance.downloadNow();
      if (!mounted) return;
      if (state.phase == 'failed') {
        botToast(_isFrench ? 'Téléchargement impossible' : 'Download failed');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _install() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final started = await AppUpdateService.instance.installNow();
      if (!mounted) return;
      if (started) {
        botToast(_isFrench ? 'Installation lancée' : 'Installation started');
      } else {
        botToast(
          _isFrench
              ? 'Autorisez « Installer des applications inconnues » pour Watchtower'
              : 'Allow "Install unknown apps" for Watchtower',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _recheck() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final view = await AppUpdateService.instance.checkNow();
      if (!mounted) return;
      setState(() => _info = view);
      if (!view.updateAvailable) {
        botToast(
          _isFrench ? 'Watchtower est à jour' : 'Watchtower is up to date',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Leaves the screen while the transfer keeps running in the service.
  void _sendToBackground() {
    Navigator.of(context).pop();
    botToast(
      _isFrench
          ? 'Téléchargement en arrière-plan'
          : 'Downloading in the background',
    );
  }

  Future<void> _openReleasePage() async {
    final url = _info.releaseUrl ?? _kReleaseFallbackUrl;
    try {
      await launchUrlString(url, mode: LaunchMode.externalApplication);
    } catch (_) {
      botToast(_isFrench ? 'Lien indisponible' : 'Link unavailable');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark
        ? const Color(0xFF0F1216)
        : cs.surfaceContainerLowest;

    return Scaffold(
      backgroundColor: background,
      body: Stack(
        children: [
          Positioned.fill(child: _aurora(cs, isDark)),
          SafeArea(
            bottom: false,
            child: Stack(
              children: [
                ListView(
                  padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
                  children: [
                    _header(cs),
                    const SizedBox(height: 22),
                    _downloadedFile(cs),
                    _notes(cs),
                    const SizedBox(height: 24),
                    _historySection(cs),
                  ],
                ),
                Positioned(
                  top: 4,
                  right: 6,
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: _isFrench ? 'Fermer' : 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _bottomBar(cs, isDark),
    );
  }

  /// Two soft light blobs drifting behind the content.
  Widget _aurora(ColorScheme cs, bool isDark) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _glow,
        builder: (context, _) {
          final t = Curves.easeInOut.transform(_glow.value);
          return Stack(
            children: [
              Positioned(
                top: -120 + (t * 40),
                left: -80 + (t * 30),
                child: _blob(
                  cs.primary.withValues(alpha: isDark ? 0.20 : 0.14),
                  320,
                ),
              ),
              Positioned(
                top: 160 - (t * 50),
                right: -110 + (t * 20),
                child: _blob(
                  cs.tertiary.withValues(alpha: isDark ? 0.12 : 0.10),
                  280,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _blob(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    );
  }

  Widget _header(ColorScheme cs) {
    final latest = _info.latestVersion ?? _info.currentVersion;
    final details = [
      if (_info.sizeBytes != null) _formatBytes(_info.sizeBytes!),
      if (_info.publishedAt != null) _formatDate(_info.publishedAt!),
    ].join('  ·  ');

    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedBuilder(
            animation: _glow,
            builder: (context, child) {
              final t = Curves.easeInOut.transform(_glow.value);
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: cs.primary.withValues(alpha: 0.22 + (t * 0.22)),
                      blurRadius: 22 + (t * 18),
                      spreadRadius: 1 + (t * 3),
                    ),
                  ],
                ),
                child: child,
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                'assets/app_icons/icon.png',
                width: 64,
                height: 64,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 64,
                  height: 64,
                  color: cs.primary.withValues(alpha: 0.16),
                  child: Icon(Icons.verified_rounded, color: cs.primary),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _hasUpdate
                ? (_isFrench ? 'Mise à jour disponible !' : 'Update available!')
                : (_isFrench ? 'Vous êtes à jour !' : 'You are up to date!'),
            style: GoogleFonts.inter(
              fontSize: 27,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.6,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'v$latest',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface.withValues(alpha: 0.55),
                ),
              ),
              Text(
                '   ·   ',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: cs.onSurface.withValues(alpha: 0.25),
                ),
              ),
              Text(
                _isFrench
                    ? 'installée : ${_info.currentVersion}'
                    : 'installed: ${_info.currentVersion}',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: cs.onSurface.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              details,
              style: GoogleFonts.inter(
                fontSize: 11.5,
                color: cs.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
          const SizedBox(height: 18),
          Divider(color: cs.outlineVariant.withValues(alpha: 0.35), height: 1),
        ],
      ),
    );
  }

  /// Where the downloaded APK lives, so the user can find it with a file
  /// manager instead of wondering where 55 MB went.
  Widget _downloadedFile(ColorScheme cs) {
    final path = _info.filePath;
    if (path == null || !_info.isReady) return const SizedBox.shrink();
    final name = path.split('/').last;
    final folder = path.substring(0, path.length - name.length);
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(Icons.download_done_rounded, size: 20, color: cs.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isFrench ? 'Fichier prêt' : 'File ready',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: cs.onSurface.withValues(alpha: 0.75),
                  ),
                ),
                Text(
                  folder,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    color: cs.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: _isFrench ? 'Supprimer le fichier' : 'Delete the file',
            icon: Icon(
              Icons.delete_outline_rounded,
              size: 20,
              color: cs.onSurface.withValues(alpha: 0.6),
            ),
            onPressed: _busy ? null : _discardDownload,
          ),
        ],
      ),
    );
  }

  Future<void> _discardDownload() async {
    setState(() => _busy = true);
    try {
      final path = _info.filePath;
      await AppUpdateService.instance.clearPending();
      if (path != null) {
        try {
          await File(path).delete();
        } catch (_) {
          // Already gone: the marker is what matters.
        }
      }
      await _recheck();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _notes(ColorScheme cs) {
    final notes = cleanReleaseNotes(_info.releaseNotes ?? '');
    if (notes.isEmpty) {
      return Text(
        _isFrench
            ? 'Pas de notes de version pour cette build.'
            : 'No release notes for this build.',
        style: GoogleFonts.inter(
          fontSize: 13,
          height: 1.5,
          color: cs.onSurface.withValues(alpha: 0.55),
        ),
      );
    }
    return _NotesMarkdown(data: notes, cs: cs);
  }

  Widget _bottomBar(ColorScheme cs, bool isDark) {
    final downloading = _info.isDownloading;
    final secondaryLabel = downloading
        ? (_isFrench ? 'Mettre en arrière-plan' : 'Send to background')
        : (_isFrench ? 'Pas maintenant' : 'Not now');

    return Container(
      decoration: BoxDecoration(
        color: (isDark ? const Color(0xFF0F1216) : cs.surface).withValues(
          alpha: 0.96,
        ),
        border: Border(
          top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.25)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _primaryAction(cs),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: downloading
                          ? _sendToBackground
                          : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        side: BorderSide(
                          color: cs.outlineVariant.withValues(alpha: 0.6),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        secondaryLabel,
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 56,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: _openReleasePage,
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        side: BorderSide(
                          color: cs.outlineVariant.withValues(alpha: 0.6),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Tooltip(
                        message: _isFrench
                            ? 'Voir la release sur GitHub'
                            : 'View the release on GitHub',
                        child: Icon(
                          Icons.open_in_new_rounded,
                          size: 19,
                          color: cs.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _primaryAction(ColorScheme cs) {
    if (_info.phase == 'installed') {
      return _roundButton(
        onPressed: null,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_rounded, size: 19),
            const SizedBox(width: 8),
            Text(
              _isFrench ? 'Installation lancée' : 'Installation started',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    if (_info.isReady) {
      return _roundButton(
        onPressed: _busy ? null : _install,
        child: Text(
          _isFrench ? 'Installer' : 'Install',
          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      );
    }

    if (_info.isDownloading) {
      final progress = _info.progress;
      final total = _info.sizeBytes;
      final received = (total != null && progress != null)
          ? (progress * total).round()
          : null;
      final label = total != null && received != null
          ? '${_formatBytes(received)} / ${_formatBytes(total)}'
                '  ·  ${(progress! * 100).round()} %'
          : (_isFrench ? 'Téléchargement…' : 'Downloading…');

      return ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: SizedBox(
          height: 50,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: cs.primary.withValues(alpha: 0.12)),
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: (progress ?? 0).clamp(0.015, 1),
                child: ColoredBox(color: cs.primary.withValues(alpha: 0.55)),
              ),
              Center(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: cs.onPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!_hasUpdate) {
      return _roundButton(
        onPressed: _busy ? null : _recheck,
        child: Text(
          _isFrench ? 'Vérifier à nouveau' : 'Check again',
          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      );
    }

    return _roundButton(
      onPressed: _busy ? null : _download,
      child: Text(
        _isFrench ? 'Télécharger' : 'Download',
        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _roundButton({
    required VoidCallback? onPressed,
    required Widget child,
  }) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
      ),
      child: child,
    );
  }

  Widget _historySection(ColorScheme cs) {
    return FutureBuilder<List<UpdateHistoryEntry>>(
      future: _history,
      builder: (context, snapshot) {
        final all = snapshot.data ?? const <UpdateHistoryEntry>[];
        if (all.isEmpty) return const SizedBox.shrink();
        final visible = _showAllHistory
            ? all
            : all.take(_historyPreview).toList();
        final hidden = all.length - visible.length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isFrench ? 'Versions précédentes' : 'Previous versions',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                color: cs.onSurface.withValues(alpha: 0.45),
              ),
            ),
            const SizedBox(height: 6),
            for (var i = 0; i < visible.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  color: cs.outlineVariant.withValues(alpha: 0.25),
                ),
              _historyTile(visible[i], cs),
            ],
            if (hidden > 0 || _showAllHistory)
              TextButton(
                onPressed: () =>
                    setState(() => _showAllHistory = !_showAllHistory),
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                child: Text(
                  _showAllHistory
                      ? (_isFrench ? 'Réduire' : 'Show less')
                      : (_isFrench
                            ? 'Afficher tout ($hidden)'
                            : 'Show all ($hidden)'),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: cs.primary,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _historyTile(UpdateHistoryEntry entry, ColorScheme cs) {
    final notes = cleanReleaseNotes(entry.notes ?? '');
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 12),
      shape: const Border(),
      collapsedShape: const Border(),
      minTileHeight: 50,
      title: Row(
        children: [
          Text(
            entry.version,
            style: GoogleFonts.inter(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (entry.isCurrent) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _isFrench ? 'installée' : 'installed',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: cs.primary,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: entry.publishedAt == null
          ? null
          : Text(
              _formatDate(entry.publishedAt!),
              style: GoogleFonts.inter(
                fontSize: 11,
                color: cs.onSurface.withValues(alpha: 0.4),
              ),
            ),
      children: [
        if (notes.isEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _isFrench ? 'Pas de notes.' : 'No notes.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: cs.onSurface.withValues(alpha: 0.5),
              ),
            ),
          )
        else
          _NotesMarkdown(data: notes, cs: cs, compact: true),
      ],
    );
  }

  String _formatBytes(int bytes) {
    final separator = _isFrench ? ',' : '.';
    if (bytes >= 1024 * 1024) {
      final value = (bytes / (1024 * 1024)).toStringAsFixed(1);
      return '${value.replaceAll('.', separator)} Mo';
    }
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)} Ko';
    return '$bytes o';
  }

  static String _formatDate(DateTime date) {
    final local = date.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year}';
  }
}

/// Drops the technical trailer CI appends to the release body (APK name,
/// checksum, size, compare link) and the duplicated section heading, so the
/// update screen only shows the changelog itself.
@visibleForTesting
String cleanReleaseNotes(String raw) {
  final lines = raw.split('\n');
  final kept = <String>[];
  for (final line in lines) {
    final trimmed = line.trim().toLowerCase();
    if (trimmed.startsWith('apk android') ||
        trimmed.startsWith('sha-256') ||
        trimmed.startsWith('sha256') ||
        trimmed.startsWith('taille :') ||
        trimmed.startsWith('taille attendue') ||
        trimmed.startsWith('**comparaison**') ||
        trimmed.startsWith('build automatique') ||
        trimmed.startsWith('built automatically')) {
      continue;
    }
    kept.add(line);
  }
  var text = kept.join('\n').trim();
  text = text.replaceFirst(
    RegExp(
      r'^#{1,3}\s*(nouveautés|what.?s new|changes?)\s*\n+',
      caseSensitive: false,
    ),
    '',
  );
  text = text.replaceFirst(
    RegExp(r'^#\s*Watchtower\s+[\d.]+\s*\n+', caseSensitive: false),
    '',
  );
  return text.trim();
}

class _NotesMarkdown extends StatelessWidget {
  const _NotesMarkdown({
    required this.data,
    required this.cs,
    this.compact = false,
  });

  final String data;
  final ColorScheme cs;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final body = cs.onSurface.withValues(alpha: 0.82);
    final heading = cs.onSurface.withValues(alpha: 0.95);
    final size = compact ? 12.0 : 13.0;
    final mono = GoogleFonts.jetBrainsMono(
      fontSize: size - 1,
      color: cs.primary,
      backgroundColor: cs.primary.withValues(alpha: 0.08),
    );

    return MarkdownBody(
      data: data,
      selectable: false,
      styleSheet: MarkdownStyleSheet(
        p: GoogleFonts.inter(fontSize: size, height: 1.55, color: body),
        pPadding: EdgeInsets.zero,
        a: GoogleFonts.inter(
          fontSize: size,
          height: 1.55,
          color: cs.primary,
          decoration: TextDecoration.underline,
        ),
        strong: GoogleFonts.inter(
          fontSize: size,
          height: 1.55,
          fontWeight: FontWeight.w700,
          color: heading,
        ),
        em: GoogleFonts.inter(
          fontSize: size,
          height: 1.55,
          fontStyle: FontStyle.italic,
          color: body,
        ),
        code: mono,
        h1: GoogleFonts.inter(
          fontSize: size + 6,
          fontWeight: FontWeight.w600,
          color: heading,
          letterSpacing: -0.3,
        ),
        h2: GoogleFonts.inter(
          fontSize: size + 3,
          fontWeight: FontWeight.w600,
          color: heading,
          letterSpacing: -0.2,
        ),
        h3: GoogleFonts.inter(
          fontSize: size + 1,
          fontWeight: FontWeight.w700,
          color: heading,
        ),
        h1Padding: const EdgeInsets.only(top: 12, bottom: 4),
        h2Padding: const EdgeInsets.only(top: 14, bottom: 4),
        h3Padding: const EdgeInsets.only(top: 10, bottom: 2),
        listBullet: GoogleFonts.inter(
          fontSize: size,
          height: 1.55,
          color: cs.onSurface.withValues(alpha: 0.5),
        ),
        listIndent: 18,
        blockSpacing: 8,
        codeblockPadding: const EdgeInsets.all(10),
        codeblockDecoration: BoxDecoration(
          color: cs.onSurface.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
        ),
        blockquoteDecoration: BoxDecoration(
          color: cs.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
        ),
        blockquotePadding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        horizontalRuleDecoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.4)),
          ),
        ),
      ),
    );
  }
}
