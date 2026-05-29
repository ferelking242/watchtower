import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'package:flutter/foundation.dart';
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

class ExtDiagResult {
  final Source source;
  final Map<DiagStep, DiagStepResult> steps;
  bool get allOk => steps.values.every((s) => s.ok);
  bool get anyFailed => steps.values.any((s) => !s.ok);
  const ExtDiagResult({required this.source, required this.steps});
}

typedef OnExtResult = void Function(ExtDiagResult result);

String _nowTime() {
  final n = DateTime.now();
  return '${n.hour.toString().padLeft(2, "0")}:${n.minute.toString().padLeft(2, "0")}:${n.second.toString().padLeft(2, "0")}';
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
  final futures = sources.map((src) async {
    final result = await _diagnoseSource(src, itemType);
    results.add(result);
    onResult?.call(result);
    AppLogger.log(
      '${result.allOk ? "✅" : "❌"} ${src.name} [${src.lang}]',
      logLevel: result.anyFailed ? LogLevel.warning : LogLevel.info,
      tag: kLogTagExt,
    );
    return result;
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

// ─── Scoped runner (sequential, with live logs) ───────────────────────────────

/// Runs diagnostics for a given list of sources, sequentially.
/// [onLog] receives formatted log lines in real-time.
Future<List<ExtDiagResult>> runDiagnosticsForSources(
  List<Source> sources,
  ItemType itemType, {
  OnExtResult? onResult,
  void Function(String line)? onLog,
}) async {
  onLog?.call('${_nowTime()}  🔬 Démarrage — ${sources.length} extension(s)');

  final results = <ExtDiagResult>[];
  for (final src in sources) {
    onLog?.call('');
    onLog?.call('${_nowTime()}  ⏱ "${src.name}" [${(src.lang ?? "?").toUpperCase()}]…');
    final result = await _diagnoseSourceWithLog(src, itemType, onLog);
    results.add(result);
    onResult?.call(result);
    final okCount = result.steps.values.where((s) => s.ok).length;
    onLog?.call(
      '${_nowTime()}  ${result.allOk ? "✅" : "❌"} "${src.name}" — $okCount/${result.steps.length} étapes OK',
    );
  }

  final ok = results.where((r) => r.allOk).length;
  onLog?.call('');
  onLog?.call('${_nowTime()}  🏁 Terminé — $ok/${results.length} extensions OK');
  return results;
}

// ─── Core step runner ─────────────────────────────────────────────────────────

Future<ExtDiagResult> _diagnoseSourceWithLog(
  Source src,
  ItemType itemType,
  void Function(String)? onLog,
) async {
  final steps = <DiagStep, DiagStepResult>{};

  // ── Step 1 : Popular ──────────────────────────────────────────────────────
  String? firstItemUrl;
  {
    final sw = Stopwatch()..start();
    try {
      final pages = await getIsolateService
          .get<MPages>(page: 1, source: src, serviceType: 'getPopular')
          .timeout(const Duration(seconds: 45));
      sw.stop();
      final count = pages.list?.length ?? 0;
      firstItemUrl = count > 0 ? pages.list!.first.link : null;
      steps[DiagStep.popular] = DiagStepResult(
        ok: count > 0,
        count: count,
        ms: sw.elapsedMilliseconds,
        error: count == 0 ? 'Aucun résultat' : null,
      );
      onLog?.call(
        '${_nowTime()}    📋 Popular: ${count > 0 ? "✅ $count entrées" : "❌ Aucun résultat"} (${sw.elapsedMilliseconds}ms)',
      );
    } catch (e) {
      sw.stop();
      final err = e.toString().split('\n').first;
      steps[DiagStep.popular] =
          DiagStepResult(ok: false, error: err, ms: sw.elapsedMilliseconds);
      onLog?.call('${_nowTime()}    📋 Popular: ❌ $err (${sw.elapsedMilliseconds}ms)');
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
        error: count == 0 ? 'Aucun résultat' : null,
      );
      onLog?.call(
        '${_nowTime()}    🕐 Latest: ${count > 0 ? "✅ $count entrées" : "❌ Aucun résultat"} (${sw.elapsedMilliseconds}ms)',
      );
    } catch (e) {
      sw.stop();
      final err = e.toString().split('\n').first;
      steps[DiagStep.latest] =
          DiagStepResult(ok: false, error: err, ms: sw.elapsedMilliseconds);
      onLog?.call('${_nowTime()}    🕐 Latest: ❌ $err (${sw.elapsedMilliseconds}ms)');
    }
  }

  // ── Step 3 : Detail ───────────────────────────────────────────────────────
  String? firstEpisodeUrl;
  if (firstItemUrl != null) {
    final sw = Stopwatch()..start();
    try {
      final detail = await getIsolateService
          .get<MManga>(url: firstItemUrl, source: src, serviceType: 'getDetail')
          .timeout(const Duration(seconds: 45));
      sw.stop();
      final chapCount = detail.chapters?.length ?? 0;
      firstEpisodeUrl = chapCount > 0 ? detail.chapters!.first.url : null;
      final ok = detail.name != null && detail.name!.isNotEmpty;
      steps[DiagStep.detail] = DiagStepResult(
        ok: ok,
        count: chapCount,
        ms: sw.elapsedMilliseconds,
        error: ok ? null : 'Détail vide',
      );
      onLog?.call(
        '${_nowTime()}    🔍 Détail: ${ok ? "✅ $chapCount chapitres/épisodes" : "❌ Détail vide"} (${sw.elapsedMilliseconds}ms)',
      );
    } catch (e) {
      sw.stop();
      final err = e.toString().split('\n').first;
      steps[DiagStep.detail] =
          DiagStepResult(ok: false, error: err, ms: sw.elapsedMilliseconds);
      onLog?.call('${_nowTime()}    🔍 Détail: ❌ $err (${sw.elapsedMilliseconds}ms)');
    }
  } else {
    steps[DiagStep.detail] = const DiagStepResult(
      ok: false,
      error: "Ignoré (popular échoué)",
      ms: 0,
    );
    onLog?.call("${_nowTime()}    🔍 Détail: ⏭ Ignoré (popular échoué)");
  }

  // ── Step 4 : Media (getVideoList / getPageList) ───────────────────────────
  if (firstEpisodeUrl != null) {
    final sw = Stopwatch()..start();
    final svcType =
        itemType == ItemType.anime ? 'getVideoList' : 'getPageList';
    final mediaEmoji = itemType == ItemType.anime ? '▶️' : '📄';
    final mediaLabel = itemType == ItemType.anime ? 'Vidéos' : 'Pages';
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
        error: count == 0 ? 'Aucun média' : null,
      );
      onLog?.call(
        '${_nowTime()}    $mediaEmoji $mediaLabel: ${count > 0 ? "✅ $count sources" : "❌ Aucun média"} (${sw.elapsedMilliseconds}ms)',
      );
    } catch (e) {
      sw.stop();
      final err = e.toString().split('\n').first;
      steps[DiagStep.media] =
          DiagStepResult(ok: false, error: err, ms: sw.elapsedMilliseconds);
      onLog?.call(
          '${_nowTime()}    $mediaEmoji $mediaLabel: ❌ $err (${sw.elapsedMilliseconds}ms)');
    }
  } else {
    steps[DiagStep.media] = const DiagStepResult(
      ok: false,
      error: "Ignoré (détail échoué)",
      ms: 0,
    );
    onLog?.call(
        "${_nowTime()}    ${itemType == ItemType.anime ? '▶️' : '📄'} Médias: ⏭ Ignoré (détail échoué)");
  }

  return ExtDiagResult(source: src, steps: steps);
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
  final typeLabel = switch (itemType) {
    ItemType.anime => 'Watch / Anime',
    ItemType.manga => 'Manga',
    ItemType.novel => 'Novel',
    _ => itemType.name,
  };

  final buf = StringBuffer();
  buf.writeln('# Diagnostic Watchtower — $dateStr');
  buf.writeln();
  buf.writeln('| | |');
  buf.writeln('|---|---|');
  buf.writeln('| **Type** | $typeLabel |');
  buf.writeln('| **Scope** | $scopeLabel |');
  buf.writeln('| **Total** | ${results.length} extensions |');
  buf.writeln(
      '| **Résultat** | ${ok > 0 ? "✅" : ""} $ok OK  ·  ${failed > 0 ? "❌" : ""} $failed échec(s) |');
  buf.writeln();
  buf.writeln('---');
  buf.writeln();

  // Failed extensions first, then OK
  final sorted = [
    ...results.where((r) => r.anyFailed),
    ...results.where((r) => r.allOk),
  ];

  for (final result in sorted) {
    final src = result.source;
    final okSteps = result.steps.values.where((s) => s.ok).length;

    buf.writeln('<details>');
    buf.writeln(
        '<summary>${result.allOk ? "✅" : "❌"} ${src.name ?? "Unknown"}'
        ' (${(src.lang ?? "?").toUpperCase()}) — $okSteps/${result.steps.length} OK</summary>');
    buf.writeln();
    buf.writeln('| Étape | Statut | Résultat | Durée |');
    buf.writeln('|-------|--------|----------|-------|');
    for (final e in result.steps.entries) {
      final stepLabel = switch (e.key) {
        DiagStep.popular => '📋 Popular',
        DiagStep.latest => '🕐 Latest',
        DiagStep.detail => '🔍 Détail',
        DiagStep.media =>
          itemType == ItemType.anime ? '▶️ Vidéos' : '📄 Pages',
      };
      final status = e.value.ok ? '✅ OK' : '❌ FAIL';
      final res = e.value.count != null
          ? '${e.value.count} entrées'
          : (e.value.error ?? '—');
      buf.writeln('| $stepLabel | $status | $res | ${e.value.ms}ms |');
    }

    final errors = result.steps.entries
        .where((e) => !e.value.ok && e.value.error != null)
        .toList();
    if (errors.isNotEmpty) {
      buf.writeln();
      buf.writeln('**Erreurs :**');
      for (final e in errors) {
        final n = switch (e.key) {
          DiagStep.popular => 'Popular',
          DiagStep.latest => 'Latest',
          DiagStep.detail => 'Détail',
          DiagStep.media => 'Médias',
        };
        buf.writeln('- `[$n]` ${e.value.error}');
      }
    }
    buf.writeln();
    buf.writeln('</details>');
    buf.writeln();
  }

  return buf.toString();
}

/// Saves the report to [Watchtower/dev/diagnostic_TYPE_TIMESTAMP.md].
/// Returns the file path on success, null on failure.
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

    final now = DateTime.now();
    final stamp =
        '${now.year}${now.month.toString().padLeft(2, "0")}${now.day.toString().padLeft(2, "0")}'
        '_${now.hour.toString().padLeft(2, "0")}${now.minute.toString().padLeft(2, "0")}${now.second.toString().padLeft(2, "0")}';
    final filePath =
        p.join(devDir.path, 'diagnostic_${itemType.name}_$stamp.md');

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
