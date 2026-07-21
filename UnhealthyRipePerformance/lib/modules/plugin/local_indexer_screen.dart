// lib/modules/plugin/local_indexer_screen.dart
// Écran de gestion de l'indexeur local Watchtower.

import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/local_indexer/local_indexer.dart';

// ── Screen ────────────────────────────────────────────────────────────────────

class LocalIndexerScreen extends ConsumerStatefulWidget {
  const LocalIndexerScreen({super.key});

  @override
  ConsumerState<LocalIndexerScreen> createState() => _LocalIndexerScreenState();
}

class _LocalIndexerScreenState extends ConsumerState<LocalIndexerScreen> {
  bool _scanning = false;

  Future<void> _startScan() async {
    if (_scanning) return;

    // ── 1. Ensure storage permissions are granted ─────────────────────────
    bool storageOk = false;
    try {
      if (Platform.isAndroid) {
        final status = await Permission.storage.status;
        if (status.isDenied || status.isPermanentlyDenied) {
          final result = await Permission.storage.request();
          storageOk = result.isGranted;
          if (!result.isGranted) {
            // Try broader media permissions (Android 13+)
            final media = await [
              Permission.photos,
              Permission.videos,
            ].request();
            storageOk = media.values.any((s) => s.isGranted);
          }
        } else {
          storageOk = status.isGranted;
        }
      } else {
        storageOk = true;
      }
    } catch (_) {
      storageOk = true;
    }

    if (!storageOk && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Permission de stockage requise pour indexer les fichiers locaux.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // ── 2. Build root paths ───────────────────────────────────────────────
    final roots = <String>[];
    try {
      if (Platform.isAndroid) {
        // Internal storage
        roots.add('/storage/emulated/0');
        // External SD cards (best-effort)
        for (final d in ['/storage/sdcard1', '/storage/extSdCard']) {
          if (Directory(d).existsSync()) roots.add(d);
        }
      } else if (Platform.isIOS) {
        roots.add(Directory.current.path);
      }
    } catch (_) {}

    if (roots.isEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de trouver les répertoires de stockage.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // ── 3. Trigger scan via Riverpod notifier ─────────────────────────────
    setState(() => _scanning = true);
    try {
      await ref.read(localIndexerScanProvider.notifier).scan(roots);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Reactive counts
    final countAsync = ref.watch(localIndexedCountProvider);
    final countByKindAsync = ref.watch(localIndexedCountByKindProvider);
    final scanState = ref.watch(localIndexerScanProvider);
    final statusStream = ref.watch(indexerStatusProvider);

    final totalCount = countAsync.valueOrNull ?? 0;
    final isScanLoading = scanState.isLoading || _scanning;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF5C6BC0), Color(0xFF3F4DB8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF5C6BC0).withValues(alpha: 0.30),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(Broken.hierarchy_3, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Local Indexer',
                            style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                        Text(
                          'Indexation automatique de vos fichiers locaux',
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.55),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Stats cards ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _StatCard(
                    icon: Broken.document_1,
                    label: 'Fichiers indexés',
                    value: '$totalCount',
                    cs: cs,
                  ),
                  const SizedBox(width: 12),
                  _StatCard(
                    icon: Broken.video_octagon,
                    label: 'Anime / Série',
                    value: countByKindAsync.valueOrNull
                            ?.entries
                            .where((e) =>
                                e.key.name.toLowerCase().contains('anime') ||
                                e.key.name.toLowerCase().contains('video'))
                            .fold(0, (a, b) => a + b.value)
                            .toString() ??
                        '—',
                    cs: cs,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Explanation panel ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: isDark ? 0.10 : 0.07),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: cs.primary.withValues(alpha: 0.15)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Broken.info_circle, size: 18, color: cs.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'L\'indexeur parcourt votre stockage interne et externe pour '
                        'lister automatiquement les fichiers multimédias locaux '
                        '(épisodes téléchargés, chapitres, e-books…). '
                        'Le résultat est disponible dans chaque bibliothèque.',
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.72),
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Live status ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: statusStream.when(
                data: (status) => _StatusRow(status: status, cs: cs),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),

            // ── Scan result ───────────────────────────────────────────────
            if (scanState.hasValue && scanState.value != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: _ScanResultCard(
                  stats: scanState.value!,
                  cs: cs,
                  tt: tt,
                ),
              ),

            const Spacer(),

            // ── Action button ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: isScanLoading ? null : _startScan,
                  icon: isScanLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Broken.refresh, size: 18),
                  label: Text(
                    isScanLoading
                        ? 'Indexation en cours…'
                        : 'Lancer l\'indexation',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Status row ─────────────────────────────────────────────────────────────────

class _StatusRow extends StatelessWidget {
  final IndexerStatus status;
  final ColorScheme cs;

  const _StatusRow({required this.status, required this.cs});

  @override
  Widget build(BuildContext context) {
    final (icon, label, color) = switch (status.type) {
      IndexerStatusType.idle    => (Broken.pause_circle,  'En attente',       cs.onSurface.withValues(alpha: 0.4)),
      IndexerStatusType.scanning => (Broken.activity,     'Scan en cours…',   cs.primary),
      IndexerStatusType.done    => (Broken.tick_circle,   'Terminé',          Colors.green),
      IndexerStatusType.error   => (Broken.close_circle,  'Erreur',           cs.error),
    };
    return Row(
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            )),
        if (status.type == IndexerStatusType.scanning) ...[
          const SizedBox(width: 8),
          SizedBox(
            width: 100,
            child: LinearProgressIndicator(
              value: (status.analyzed != null && (status.discovered ?? 0) > 0)
                  ? status.analyzed! / (status.discovered ?? 1)
                  : null,
              borderRadius: BorderRadius.circular(4),
              minHeight: 4,
            ),
          ),
        ],
      ],
    );
  }
}

// ── Scan result card ───────────────────────────────────────────────────────────

class _ScanResultCard extends StatelessWidget {
  final IndexerStats stats;
  final ColorScheme cs;
  final TextTheme tt;

  const _ScanResultCard({required this.stats, required this.cs, required this.tt});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Résultats du dernier scan',
              style: tt.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface.withValues(alpha: 0.7))),
          const SizedBox(height: 8),
          _ResultRow(icon: Broken.document_1, label: 'Fichiers découverts', value: '${stats.discovered}'),
          _ResultRow(icon: Broken.tick_square, label: 'Nouveaux indexés', value: '${stats.indexed}'),
          _ResultRow(icon: Broken.refresh_square_2, label: 'Mis à jour', value: '${stats.updated}'),
          _ResultRow(icon: Broken.copy, label: 'Doublons ignorés', value: '${stats.skipped}'),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ResultRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 13, color: cs.onSurface.withValues(alpha: 0.45)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 12, color: cs.onSurface.withValues(alpha: 0.65))),
          ),
          Text(value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// ── Stat card ──────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final ColorScheme cs;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: cs.outlineVariant.withValues(alpha: 0.20)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: cs.primary),
            const SizedBox(height: 8),
            Text(value,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurface.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
