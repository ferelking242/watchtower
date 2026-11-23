import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:watchtower/eval/model/m_bridge.dart';
import 'package:watchtower/services/app_updater/app_update_service.dart'
    if (dart.library.js_interop) 'package:watchtower/services/app_updater/app_update_service_web.dart';
import 'package:watchtower/services/app_updater/update_models.dart';

/// Single update screen: changelog, centered download button, background
/// download, "later" and the history of previous releases.
class UpdatePage extends StatefulWidget {
  const UpdatePage({super.key, required this.initial});

  final UpdateInfoView initial;

  @override
  State<UpdatePage> createState() => _UpdatePageState();
}

class _UpdatePageState extends State<UpdatePage> {
  late UpdateInfoView _info = widget.initial;
  StreamSubscription<UpdateInfoView>? _subscription;
  late final Future<List<UpdateHistoryEntry>> _history =
      AppUpdateService.instance.history();
  bool _busy = false;

  bool get _isFrench => Localizations.localeOf(context).languageCode == 'fr';

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
    super.dispose();
  }

  Future<void> _download() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final state = await AppUpdateService.instance.downloadNow();
      if (!mounted) return;
      if (state.phase == 'failed') {
        botToast(_isFrench
            ? 'Téléchargement impossible'
            : 'Download failed');
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
      if (!started) {
        botToast(_isFrench
            ? 'Installation impossible'
            : 'Installation failed');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _downloadInBackground() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await AppUpdateService.instance.checkAndDownload();
      if (!mounted) return;
      Navigator.of(context).pop();
      botToast(_isFrench
          ? 'Téléchargement en arrière-plan'
          : 'Downloading in the background');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF161B22) : Colors.white;
    final border = cs.outlineVariant.withValues(alpha: 0.35);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          _isFrench ? 'Mise à jour' : 'Update',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
        children: [
          _header(cs, surface, border),
          const SizedBox(height: 16),
          _notesCard(cs, surface, border),
          const SizedBox(height: 20),
          _primaryAction(cs),
          const SizedBox(height: 10),
          if (!_info.isReady && !_info.isDownloading)
            OutlinedButton.icon(
              onPressed: _busy ? null : _downloadInBackground,
              icon: const Icon(Icons.cloud_download_outlined, size: 18),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              label: Text(
                _isFrench
                    ? 'Télécharger en arrière-plan'
                    : 'Download in the background',
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              _isFrench ? 'Plus tard' : 'Later',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: cs.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          const SizedBox(height: 18),
          _historySection(cs, surface, border),
        ],
      ),
    );
  }

  Widget _header(ColorScheme cs, Color surface, Color border) {
    final latest = _info.latestVersion ?? '';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.system_update_alt_rounded,
                color: cs.primary, size: 30),
          ),
          const SizedBox(height: 12),
          Text(
            _isFrench ? 'Nouvelle version disponible' : 'New version available',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _pill(
                _isFrench
                    ? 'Actuelle ${_info.currentVersion}'
                    : 'Current ${_info.currentVersion}',
                cs.onSurface.withValues(alpha: 0.55),
                cs,
              ),
              Icon(Icons.arrow_forward_rounded,
                  size: 16, color: cs.onSurface.withValues(alpha: 0.4)),
              _pill(
                _isFrench ? 'Nouvelle $latest' : 'New $latest',
                cs.primary,
                cs,
                filled: true,
              ),
            ],
          ),
          if (_info.sizeBytes != null || _info.publishedAt != null) ...[
            const SizedBox(height: 10),
            Text(
              [
                if (_info.sizeBytes != null) _formatBytes(_info.sizeBytes!),
                if (_info.publishedAt != null) _formatDate(_info.publishedAt!),
              ].join(' · '),
              style: GoogleFonts.inter(
                fontSize: 11.5,
                color: cs.onSurface.withValues(alpha: 0.45),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _pill(String text, Color color, ColorScheme cs, {bool filled = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: filled ? color.withValues(alpha: 0.14) : null,
        border: Border.all(color: color.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: filled ? color : color,
        ),
      ),
    );
  }

  Widget _notesCard(ColorScheme cs, Color surface, Color border) {
    final notes = (_info.releaseNotes ?? '').trim();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isFrench ? 'Nouveautés' : "What's new",
            style: GoogleFonts.inter(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          SelectableText(
            notes.isEmpty
                ? (_isFrench
                    ? 'Pas de notes de version pour cette build.'
                    : 'No release notes for this build.')
                : notes,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              height: 1.45,
              color: cs.onSurface.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }

  Widget _primaryAction(ColorScheme cs) {
    if (_info.isReady) {
      return FilledButton.icon(
        onPressed: _busy ? null : _install,
        icon: const Icon(Icons.install_mobile_rounded, size: 20),
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        label: Text(
          _isFrench ? 'Installer' : 'Install',
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    if (_info.isDownloading) {
      final progress = _info.progress;
      return Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.primary.withValues(alpha: 0.35)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 150,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: cs.primary.withValues(alpha: 0.15),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              progress == null
                  ? (_isFrench ? 'Téléchargement…' : 'Downloading…')
                  : '${(progress * 100).round()} %',
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: cs.primary,
              ),
            ),
          ],
        ),
      );
    }

    final size = _info.sizeBytes;
    return FilledButton.icon(
      onPressed: _busy ? null : _download,
      icon: const Icon(Icons.download_rounded, size: 20),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      label: Text(
        size == null
            ? (_isFrench ? 'Télécharger' : 'Download')
            : (_isFrench
                ? 'Télécharger (${_formatBytes(size)})'
                : 'Download (${_formatBytes(size)})'),
        style: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _historySection(ColorScheme cs, Color surface, Color border) {
    return FutureBuilder<List<UpdateHistoryEntry>>(
      future: _history,
      builder: (context, snapshot) {
        final entries = snapshot.data ?? const <UpdateHistoryEntry>[];
        if (entries.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isFrench ? 'Historique' : 'History',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: cs.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: border),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < entries.length; i++) ...[
                    if (i > 0) const Divider(height: 1, indent: 14),
                    _historyTile(entries[i], cs),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _historyTile(UpdateHistoryEntry entry, ColorScheme cs) {
    final notes = (entry.notes ?? '').trim();
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 14),
      childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      shape: const Border(),
      collapsedShape: const Border(),
      title: Row(
        children: [
          Text(
            entry.version,
            style: GoogleFonts.inter(
              fontSize: 13,
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
                color: cs.onSurface.withValues(alpha: 0.45),
              ),
            ),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            notes.isEmpty
                ? (_isFrench ? 'Pas de notes.' : 'No notes.')
                : notes,
            style: GoogleFonts.inter(
              fontSize: 12,
              height: 1.4,
              color: cs.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ),
      ],
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} Mo';
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
