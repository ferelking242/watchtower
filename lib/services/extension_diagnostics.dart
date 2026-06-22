import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:isar_community/isar.dart';
import 'package:path/path.dart' as p;
import 'package:watchtower/eval/model/m_manga.dart';
import 'package:watchtower/eval/model/m_pages.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/providers/storage_provider.dart';
import 'package:watchtower/services/isolate_service.dart';
import 'package:watchtower/utils/log/logger.dart';

enum DiagStep { popular, latest, detail, media }

// ─── Media preview URL ────────────────────────────────────────────────────────

class DiagMediaUrl {
  final String url;
  final Map<String, String>? headers;
  final String quality;
  const DiagMediaUrl({required this.url, this.headers, this.quality = ''});
}

// ─── Step result ──────────────────────────────────────────────────────────────

class DiagStepResult {
  final bool ok;
  final String? error;
  final int? count;
  final int ms;
  const DiagStepResult({
    required this.ok,
    this.error,
    this.count,
    required this.ms,
  });
}

// ─── Extension result ─────────────────────────────────────────────────────────

class ExtDiagResult {
  final Source source;
  final Map<DiagStep, DiagStepResult> steps;
  final int totalMs;
  final List<DiagMediaUrl> previewUrls;

  bool get allOk => steps.values.every((s) => s.ok);
  bool get anyFailed => steps.values.any((s) => !s.ok);
  int get okCount => steps.values.where((s) => s.ok).length;
  int get failCount => steps.values.where((s) => !s.ok).length;

  const ExtDiagResult({
    required this.source,
    required this.steps,
    this.totalMs = 0,
    this.previewUrls = const [],
  });
}

typedef OnExtResult = void Function(ExtDiagResult result);

String _nowTime() {
  final n = DateTime.now();
  return '${n.hour.toString().padLeft(2, "0")}:${n.minute.toString().padLeft(2, "0")}:${n.second.toString().padLeft(2, "0")}';
}

// ─── Semaphore for concurrency control ────────────────────────────────────────

class _Semaphore {
  final int maxConcurrent;
  int _running = 0;
  final List<Completer<void>> _queue = [];

  _Semaphore(this.maxConcurrent);

  Future<void> acquire() async {
    if (_running < maxConcurrent) {
      _running++;
      return;
    }
    final completer = Completer<void>();
    _queue.add(completer);
    await completer.future;
    _running++;
  }

  void release() {
    _running--;
    if (_queue.isNotEmpty) {
      final next = _queue.removeAt(0);
      next.complete();
    }
  }
}

// ─── Legacy runner (parallel, no logs) ───────────────────────────────────────

Future<List<ExtDiagResult>> runExtensionDiagnosticsFull(
  ItemType itemType, {
  OnExtResult? onResult,
}) async {
  final sources = isar.sources
      .filter()
      .idIsNotNull()
      .and()
      .isAddedEqualTo(true)
      .and()
      .itemTypeEqualTo(itemType)
      .findAllSync()
      .where((s) => !(s.name == 'local' && (s.lang?.isEmpty ?? true)))
      .toList();

  AppLogger.log(
    '🔬 Diagnostics started — type=${itemType.name} | count=${sources.length}',
    logLevel: LogLevel.info,
    tag: kLogTagExt,
  );

  final results = <ExtDiagResult>[];
  final sem = _Semaphore(4);
  final futures = sources.map((src) async {
    await sem.acquire();
    try {
      final result = await _diagnoseSource(src, itemType);
      results.add(result);
      onResult?.call(result);
      AppLogger.log(
        '${result.allOk ? "✅" : "❌"} ${src.name} [${src.lang}]',
        logLevel: result.anyFailed ? LogLevel.warning : LogLevel.info,
        tag: kLogTagExt,
      );
      return result;
    } finally {
      sem.release();
    }
  }).toList();
  await Future.wait(futures);

  final ok = results.where((r) => r.allOk).length;
  AppLogger.log(
    '🔬 Done — ok=$ok | failed=${results.length - ok}',
    logLevel: (results.length - ok) > 0 ? LogLevel.warning : LogLevel.info,
    tag: kLogTagExt,
  );
  return results;
}

// ─── Scoped runner with pool + logs ──────────────────────────────────────────

Future<List<ExtDiagResult>> runDiagnosticsForSources(
  List<Source> sources,
  ItemType itemType, {
  OnExtResult? onResult,
  void Function(String line)? onLog,
  int concurrency = 4,
}) async {
  final sw = Stopwatch()..start();
  onLog?.call('${_nowTime()}  ┌─ START ─── ${sources.length} extension(s) · pool=$concurrency');

  final results = <ExtDiagResult>[];
  final sem = _Semaphore(concurrency.clamp(1, 8));

  var _logChain = Future<void>.value();
  void safeLog(String line) {
    _logChain = _logChain.then((_) async {
      onLog?.call(line);
    });
  }

  final futures = sources.map((src) async {
    await sem.acquire();
    try {
      safeLog('${_nowTime()}  ├─ [RUN] "${src.name}" [${(src.lang ?? "?").toUpperCase()}]…');
      final result = await _diagnoseSourceWithLog(src, itemType, safeLog);
      results.add(result);
      onResult?.call(result);
      final bar = _progressBar(result.okCount, result.steps.length);
      safeLog(
        '${_nowTime()}  │   ${result.allOk ? "✅" : "❌"} "${src.name}"'
        ' $bar ${result.okCount}/${result.steps.length} · ${result.totalMs}ms',
      );
      return result;
    } finally {
      sem.release();
    }
  }).toList();

  await Future.wait(futures);
  await _logChain;

  sw.stop();
  final ok = results.where((r) => r.allOk).length;
  final failed = results.length - ok;
  final rate = results.isEmpty ? 0 : (ok * 100 ~/ results.length);
  onLog?.call('${_nowTime()}  └─ DONE ── $ok OK · $failed FAIL · ${rate}% · ${_formatDuration(sw.elapsedMilliseconds)}');

  return results;
}

String _progressBar(int ok, int total) {
  if (total == 0) return '';
  const full = '█';
  const empty = '░';
  final filled = (ok * 4 ~/ total);
  return '[${full * filled}${empty * (4 - filled)}]';
}

String _formatDuration(int ms) {
  if (ms < 1000) return '${ms}ms';
  final s = ms ~/ 1000;
  final rem = ms % 1000;
  if (s < 60) return '${s}.${(rem ~/ 100)}s';
  return '${s ~/ 60}m${(s % 60).toString().padLeft(2, "0")}s';
}

// ─── Core step runner ─────────────────────────────────────────────────────────

Future<ExtDiagResult> _diagnoseSourceWithLog(
  Source src,
  ItemType itemType,
  void Function(String)? onLog,
) async {
  final totalSw = Stopwatch()..start();
  final steps = <DiagStep, DiagStepResult>{};
  final prefix = src.name ?? '?';

  // ── Step 1 : Popular ──────────────────────────────────────────────────────
  List<String> probeUrls = [];
  {
    final sw = Stopwatch()..start();
    try {
      final pages = await getIsolateService
          .get<MPages>(page: 1, source: src, serviceType: 'getPopular')
          .timeout(const Duration(seconds: 45));
      sw.stop();
      final count = pages.list?.length ?? 0;
      probeUrls = (pages.list ?? [])
          .take(3)
          .map((e) => e.link ?? '')
          .where((u) => u.isNotEmpty)
          .toList();
      steps[DiagStep.popular] = DiagStepResult(
        ok: count > 0,
        count: count,
        ms: sw.elapsedMilliseconds,
        error: count == 0 ? 'Aucun résultat retourné' : null,
      );
      onLog?.call(
        '${_nowTime()}  │   [$prefix] POP ${count > 0 ? "✓" : "✗"}'
        ' ${count > 0 ? "$count items" : "vide"} · ${_formatDuration(sw.elapsedMilliseconds)}',
      );
    } catch (e) {
      sw.stop();
      final err = _trimError(e.toString());
      steps[DiagStep.popular] =
          DiagStepResult(ok: false, error: err, ms: sw.elapsedMilliseconds);
      onLog?.call(
          '${_nowTime()}  │   [$prefix] POP ✗ $err · ${_formatDuration(sw.elapsedMilliseconds)}');
    }
  }

  // ── Step 2 : Latest ───────────────────────────────────────────────────────
  {
    final sw = Stopwatch()..start();
    try {
      final pages = await getIsolateService
          .get<MPages>(page: 1, source: src, serviceType: 'getLatestUpdates')
          .timeout(const Duration(seconds: 45));
      sw.stop();
      final count = pages.list?.length ?? 0;
      steps[DiagStep.latest] = DiagStepResult(
        ok: count > 0,
        count: count,
        ms: sw.elapsedMilliseconds,
        error: count == 0 ? 'Aucun résultat retourné' : null,
      );
      onLog?.call(
        '${_nowTime()}  │   [$prefix] LAT ${count > 0 ? "✓" : "✗"}'
        ' ${count > 0 ? "$count items" : "vide"} · ${_formatDuration(sw.elapsedMilliseconds)}',
      );
    } catch (e) {
      sw.stop();
      final err = _trimError(e.toString());
      steps[DiagStep.latest] =
          DiagStepResult(ok: false, error: err, ms: sw.elapsedMilliseconds);
      onLog?.call(
          '${_nowTime()}  │   [$prefix] LAT ✗ $err · ${_formatDuration(sw.elapsedMilliseconds)}');
    }
  }

  // ── Step 3 : Detail ───────────────────────────────────────────────────────
  String? firstEpisodeUrl;
  if (probeUrls.isNotEmpty) {
    final sw = Stopwatch()..start();
    MManga? bestDetail;
    String? lastError;
    int probeIndex = 0;
    for (final probeUrl in probeUrls) {
      probeIndex++;
      try {
        final d = await getIsolateService
            .get<MManga>(url: probeUrl, source: src, serviceType: 'getDetail')
            .timeout(const Duration(seconds: 45));
        final chapCount = d.chapters?.length ?? 0;
        if (bestDetail == null ||
            chapCount > (bestDetail.chapters?.length ?? 0)) {
          bestDetail = d;
        }
        if (chapCount > 1) break;
      } catch (e) {
        lastError = _trimError(e.toString());
        onLog?.call(
          '${_nowTime()}  │   [$prefix] DET probe $probeIndex/${probeUrls.length} ✗ $lastError',
        );
      }
    }
    sw.stop();

    if (bestDetail != null) {
      final chapCount = bestDetail.chapters?.length ?? 0;
      firstEpisodeUrl =
          chapCount > 0 ? bestDetail.chapters!.first.url : null;
      final ok =
          (bestDetail.name != null && bestDetail.name!.isNotEmpty) || chapCount > 0;
      steps[DiagStep.detail] = DiagStepResult(
        ok: ok,
        count: chapCount,
        ms: sw.elapsedMilliseconds,
        error: ok ? null : 'Détail vide (nom absent, 0 chapitres)',
      );
      onLog?.call(
        '${_nowTime()}  │   [$prefix] DET ${ok ? "✓" : "✗"}'
        ' ${ok ? "$chapCount épisodes/chapitres" : "vide"} · ${_formatDuration(sw.elapsedMilliseconds)}',
      );
    } else {
      steps[DiagStep.detail] = DiagStepResult(
        ok: false,
        error: lastError ?? 'Tous les sondages ont échoué',
        ms: sw.elapsedMilliseconds,
      );
      onLog?.call(
        '${_nowTime()}  │   [$prefix] DET ✗ ${lastError ?? "tous les sondages ont échoué"}'
        ' · ${_formatDuration(sw.elapsedMilliseconds)}',
      );
    }
  } else {
    steps[DiagStep.detail] = const DiagStepResult(
      ok: false,
      error: 'Ignoré — Popular a échoué',
      ms: 0,
    );
    onLog?.call('${_nowTime()}  │   [$prefix] DET ⤼ skipped (Popular failed)');
  }

  // ── Step 4 : Media (getVideoList / getPageList) ───────────────────────────
  final previewUrls = <DiagMediaUrl>[];

  if (firstEpisodeUrl != null) {
    final sw = Stopwatch()..start();
    final svcType =
        itemType == ItemType.anime ? 'getVideoList' : 'getPageList';
    final mediaLabel = itemType == ItemType.anime ? 'VID' : 'PAGE';
    try {
      final list = await getIsolateService
          .get<List<dynamic>>(
            url: firstEpisodeUrl,
            source: src,
            serviceType: svcType,
          )
          .timeout(const Duration(seconds: 60));
      sw.stop();
      final count = list.length;
      steps[DiagStep.media] = DiagStepResult(
        ok: count > 0,
        count: count,
        ms: sw.elapsedMilliseconds,
        error: count == 0 ? 'Aucun média retourné' : null,
      );
      onLog?.call(
        '${_nowTime()}  │   [$prefix] $mediaLabel ${count > 0 ? "✓" : "✗"}'
        ' ${count > 0 ? "$count sources" : "vide"} · ${_formatDuration(sw.elapsedMilliseconds)}',
      );

      // Capture preview URLs (up to 5)
      for (final item in list.take(5)) {
        try {
          final rawUrl = (item as dynamic).url?.toString() ?? '';
          if (rawUrl.isEmpty) continue;
          final h = (item as dynamic).headers;
          final q = (() {
            try { return (item as dynamic).quality?.toString() ?? ''; } catch (_) { return ''; }
          })();
          Map<String, String>? hdrs;
          if (h is Map) hdrs = Map<String, String>.from(h);
          previewUrls.add(DiagMediaUrl(url: rawUrl, headers: hdrs, quality: q));
        } catch (_) {}
      }

      // Verify first URL accessibility (non-web only)
      if (count > 0 && !kIsWeb && previewUrls.isNotEmpty) {
        final firstPreview = previewUrls.first;
        try {
          final uri = Uri.parse(firstPreview.url);
          http.Response httpResp;
          try {
            httpResp = await http
                .head(uri, headers: firstPreview.headers)
                .timeout(const Duration(seconds: 12));
          } catch (_) {
            final req = http.Request('GET', uri);
            req.headers['Range'] = 'bytes=0-1023';
            if (firstPreview.headers != null) req.headers.addAll(firstPreview.headers!);
            final stream = await http.Client()
                .send(req)
                .timeout(const Duration(seconds: 12));
            httpResp = await http.Response.fromStream(stream);
          }
          final statusOk = httpResp.statusCode < 400;
          onLog?.call(
            '${_nowTime()}  │   [$prefix] HTTP ${httpResp.statusCode}'
            ' ${statusOk ? "✓ accessible" : "✗ inaccessible"}',
          );
          if (!statusOk) {
            steps[DiagStep.media] = DiagStepResult(
              ok: false,
              count: count,
              ms: sw.elapsedMilliseconds,
              error: 'HTTP ${httpResp.statusCode} — URL inaccessible',
            );
          }
        } catch (httpErr) {
          onLog?.call(
              '${_nowTime()}  │   [$prefix] HTTP ⚠ vérification impossible: ${_trimError(httpErr.toString())}');
        }
      }
    } catch (e) {
      sw.stop();
      final err = _trimError(e.toString());
      steps[DiagStep.media] =
          DiagStepResult(ok: false, error: err, ms: sw.elapsedMilliseconds);
      onLog?.call(
          '${_nowTime()}  │   [$prefix] $mediaLabel ✗ $err · ${_formatDuration(sw.elapsedMilliseconds)}');
    }
  } else {
    steps[DiagStep.media] = const DiagStepResult(
      ok: false,
      error: 'Ignoré — Détail a échoué',
      ms: 0,
    );
    onLog?.call('${_nowTime()}  │   [$prefix] VID ⤼ skipped (Detail failed)');
  }

  totalSw.stop();
  return ExtDiagResult(
    source: src,
    steps: steps,
    totalMs: totalSw.elapsedMilliseconds,
    previewUrls: previewUrls,
  );
}

String _trimError(String raw) {
  final line = raw.split('\n').first.trim();
  return line.length > 160 ? '${line.substring(0, 157)}…' : line;
}

Future<ExtDiagResult> _diagnoseSource(Source src, ItemType itemType) =>
    _diagnoseSourceWithLog(src, itemType, null);

// ─── Markdown report generation ───────────────────────────────────────────────

String generateMarkdownReport({
  required List<ExtDiagResult> results,
  required ItemType itemType,
  required String scopeLabel,
}) {
  final now = DateTime.now();
  final dateStr =
      '${now.year}-${now.month.toString().padLeft(2, "0")}-${now.day.toString().padLeft(2, "0")} '
      '${now.hour.toString().padLeft(2, "0")}:${now.minute.toString().padLeft(2, "0")}:${now.second.toString().padLeft(2, "0")}';
  final ok = results.where((r) => r.allOk).length;
  final failed = results.length - ok;
  final rate = results.isEmpty ? 0 : (ok * 100 ~/ results.length);
  final totalMs = results.fold<int>(0, (acc, r) => acc + r.totalMs);
  final typeLabel = switch (itemType) {
    ItemType.anime => 'Watch / Anime',
    ItemType.manga => 'Manga',
    ItemType.novel => 'Novel',
    _ => itemType.name,
  };

  final buf = StringBuffer();
  buf.writeln('# Diagnostic Watchtower — $dateStr');
  buf.writeln();
  buf.writeln('| Champ | Valeur |');
  buf.writeln('|---|---|');
  buf.writeln('| **Type** | $typeLabel |');
  buf.writeln('| **Scope** | $scopeLabel |');
  buf.writeln('| **Total** | ${results.length} extensions |');
  buf.writeln('| **Résultat** | ✅ $ok OK · ❌ $failed échec(s) · $rate% de réussite |');
  buf.writeln('| **Durée totale** | ${_formatDuration(totalMs)} |');
  buf.writeln();

  final stepTotals = <DiagStep, int>{};
  final stepOk = <DiagStep, int>{};
  for (final step in DiagStep.values) {
    stepTotals[step] = results.where((r) => r.steps.containsKey(step)).length;
    stepOk[step] = results.where((r) => r.steps[step]?.ok == true).length;
  }
  buf.writeln('## Résumé par étape');
  buf.writeln();
  buf.writeln('| Étape | OK | Échec | Taux |');
  buf.writeln('|---|---|---|---|');
  for (final step in DiagStep.values) {
    final label = switch (step) {
      DiagStep.popular => '📋 Popular',
      DiagStep.latest  => '🕐 Latest',
      DiagStep.detail  => '🔍 Détail',
      DiagStep.media   => itemType == ItemType.anime ? '▶️ Vidéos' : '📄 Pages',
    };
    final total = stepTotals[step] ?? 0;
    final okN = stepOk[step] ?? 0;
    final failN = total - okN;
    final stepRate = total == 0 ? '—' : '${okN * 100 ~/ total}%';
    buf.writeln('| $label | $okN | $failN | $stepRate |');
  }
  buf.writeln();
  buf.writeln('---');
  buf.writeln();

  final sorted = [
    ...results.where((r) => r.anyFailed),
    ...results.where((r) => r.allOk),
  ];

  for (final result in sorted) {
    final src = result.source;
    final okSteps = result.okCount;
    final bar = _progressBar(okSteps, result.steps.length);

    buf.writeln('<details>');
    buf.writeln(
        '<summary>${result.allOk ? "✅" : "❌"} **${src.name ?? "Unknown"}**'
        ' `${(src.lang ?? "?").toUpperCase()}` $bar $okSteps/${result.steps.length}'
        ' · ${_formatDuration(result.totalMs)}</summary>');
    buf.writeln();
    buf.writeln('| Étape | Statut | Résultat | Durée |');
    buf.writeln('|-------|--------|----------|-------|');
    for (final e in result.steps.entries) {
      final stepLabel = switch (e.key) {
        DiagStep.popular => '📋 Popular',
        DiagStep.latest  => '🕐 Latest',
        DiagStep.detail  => '🔍 Détail',
        DiagStep.media   => itemType == ItemType.anime ? '▶️ Vidéos' : '📄 Pages',
      };
      final status = e.value.ok ? '✅ OK' : '❌ FAIL';
      final res = e.value.count != null
          ? '${e.value.count} résultats'
          : (e.value.error ?? '—');
      buf.writeln('| $stepLabel | $status | $res | ${_formatDuration(e.value.ms)} |');
    }

    final errors = result.steps.entries
        .where((e) => !e.value.ok && e.value.error != null)
        .toList();
    if (errors.isNotEmpty) {
      buf.writeln();
      buf.writeln('**Erreurs détaillées :**');
      buf.writeln();
      for (final e in errors) {
        final n = switch (e.key) {
          DiagStep.popular => 'Popular',
          DiagStep.latest  => 'Latest',
          DiagStep.detail  => 'Détail',
          DiagStep.media   => itemType == ItemType.anime ? 'Vidéos' : 'Pages',
        };
        buf.writeln('```');
        buf.writeln('[$n] ${e.value.error}');
        buf.writeln('```');
      }
    }
    buf.writeln();
    buf.writeln('</details>');
    buf.writeln();
  }

  return buf.toString();
}

/// Saves the report to [Watchtower/dev/Diagnostic_nNNN.md].
Future<String?> saveDiagnosticReport({
  required List<ExtDiagResult> results,
  required ItemType itemType,
  required String scopeLabel,
}) async {
  if (kIsWeb) return null;
  try {
    final content = generateMarkdownReport(
      results: results,
      itemType: itemType,
      scopeLabel: scopeLabel,
    );
    final baseDir = await StorageProvider().getDirectory();
    if (baseDir == null) return null;

    final devDir = Directory(p.join(baseDir.path, 'dev'));
    await devDir.create(recursive: true);

    int nextN = 1;
    try {
      final existing = devDir
          .listSync()
          .whereType<File>()
          .map((f) => p.basename(f.path))
          .where((name) => RegExp(r'^Diagnostic_n\d+\.md$').hasMatch(name))
          .map((name) {
            final m = RegExp(r'Diagnostic_n(\d+)\.md').firstMatch(name);
            return m != null ? (int.tryParse(m.group(1)!) ?? 0) : 0;
          })
          .toList();
      if (existing.isNotEmpty) nextN = existing.reduce((a, b) => a > b ? a : b) + 1;
    } catch (_) {}
    final filePath = p.join(
        devDir.path, 'Diagnostic_n${nextN.toString().padLeft(3, "0")}.md');

    await File(filePath).writeAsString(content);
    AppLogger.log(
      'Diagnostic report saved: $filePath',
      logLevel: LogLevel.info,
      tag: kLogTagExt,
    );
    return filePath;
  } catch (e) {
    AppLogger.log(
      'saveDiagnosticReport failed: $e',
      logLevel: LogLevel.warning,
      tag: kLogTagExt,
    );
    return null;
  }
}
