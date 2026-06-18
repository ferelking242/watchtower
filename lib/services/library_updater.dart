import 'dart:math' show min;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:watchtower/eval/model/m_bridge.dart';
import 'package:watchtower/modules/manga/detail/providers/update_manga_detail_providers.dart';
import 'package:watchtower/modules/more/settings/appearance/providers/theme_mode_state_provider.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/utils/extensions/build_context_extensions.dart';
import 'package:watchtower/utils/log/logger.dart';
import 'package:watchtower/models/manga.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Library updater — source-parallel, per-source sequential
//
// Architecture:
//   • Manga are grouped by source key (source name + lang).
//   • All source groups run in PARALLEL via Future.wait.
//   • Within each source group entries are processed SEQUENTIALLY (1-by-1).
//     This avoids triggering Cloudflare / rate limits on the same host.
//   • An error from one source (block, timeout, etc.) is caught locally and
//     does NOT propagate to other source groups.
//   • Global concurrency is capped at [_maxParallelSources] to avoid
//     opening too many network connections at once.
//   • Progress counter is shared across groups; Dart's single-threaded event
//     loop guarantees no race when mutating plain ints in `then` callbacks.
// ─────────────────────────────────────────────────────────────────────────────

/// Max number of source groups processed at the same time.
const int _maxParallelSources = 8;

Future<void> updateLibrary({
  required WidgetRef ref,
  required BuildContext context,
  required List<Manga> mangaList,
  required ItemType itemType,
}) async {
  final typeLabel =
      itemType.name[0].toUpperCase() + itemType.name.substring(1);

  AppLogger.log('Starting $typeLabel library update (${mangaList.length} items)…');

  if (mangaList.isEmpty) {
    AppLogger.log('$typeLabel library is empty. Nothing to update.');
    return;
  }

  final isDark = ref.read(themeModeStateProvider);

  // ── Show initial toast ──────────────────────────────────────────────────────
  void showProgress(int done, int failed, int total) {
    if (!context.mounted) return;
    botToast(
      context.l10n.updating_library(done, failed, total),
      fontSize: 13,
      second: 15,
      alignY: !context.isTablet ? 0.85 : 1,
      animationDuration: 0,
      dismissDirections: [DismissDirection.none],
      onlyOne: false,
      themeDark: isDark,
    );
  }

  botToast(
    context.l10n.updating_library(0, 0, mangaList.length),
    fontSize: 13,
    second: 30,
    alignY: !context.isTablet ? 0.85 : 1,
    themeDark: isDark,
  );

  // ── Group by source ─────────────────────────────────────────────────────────
  // Key = "${source}_${lang}" so entries on different sources are independent.
  final bySource = <String, List<Manga>>{};
  for (final m in mangaList) {
    final key = '${m.source ?? 'unknown'}_${m.lang ?? 'unknown'}';
    bySource.putIfAbsent(key, () => []).add(m);
  }

  final sourceGroups = bySource.values.toList();
  final total = mangaList.length;

  // Shared mutable counters — safe because Dart event loop is single-threaded.
  var done = 0;
  var failed = 0;
  final failedNames = <String>[];

  // ── Run source groups in parallel, capped at _maxParallelSources ────────────
  await _runWithPool<List<Manga>>(
    sourceGroups,
    _maxParallelSources,
    (sourceMangas) async {
      // Each source is processed sequentially (1 entry at a time).
      for (final manga in sourceMangas) {
        if (!context.mounted) break;
        try {
          await ref.read(
            updateMangaDetailProvider(
              mangaId: manga.id,
              isInit: false,
              showToast: false,
            ).future,
          );
        } catch (e) {
          AppLogger.log(
            'Failed to update ${manga.name ?? manga.id}: $e',
            logLevel: LogLevel.error,
          );
          failed++;
          failedNames.add(manga.name ?? 'Unknown $typeLabel');
        }
        done++;
        showProgress(done, failed, total);
      }
    },
  );

  // ── Final toast ─────────────────────────────────────────────────────────────
  await Future.delayed(const Duration(seconds: 1));
  if (context.mounted && failedNames.isNotEmpty) {
    final plural = failed == 1 ? typeLabel : '${typeLabel}s';
    final list = failedNames.map((m) => '• $m').join('\n');
    botToast(
      'Failed to update $failed $plural:\n$list',
      fontSize: 13,
      second: 12,
      alignY: !context.isTablet ? 0.85 : 1,
      themeDark: isDark,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bounded concurrency pool
//
// Runs [task] on each item in [items] with at most [maxConcurrent] tasks
// active at the same time. Uses a "worker race" pattern — each worker pulls
// the next item from the shared index until the list is exhausted.
// This is allocation-efficient and avoids explicit mutexes.
// ─────────────────────────────────────────────────────────────────────────────

Future<void> _runWithPool<T>(
  List<T> items,
  int maxConcurrent,
  Future<void> Function(T item) task,
) async {
  if (items.isEmpty) return;

  var index = 0; // shared index, safe — single-threaded event loop

  Future<void> worker() async {
    while (true) {
      final i = index++;
      if (i >= items.length) return;
      await task(items[i]);
    }
  }

  final workerCount = min(maxConcurrent, items.length);
  await Future.wait(List.generate(workerCount, (_) => worker()));
}
