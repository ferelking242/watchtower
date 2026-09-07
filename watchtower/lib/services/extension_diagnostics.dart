import 'dart:async';
import 'dart:convert';
import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
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

/// The four stages of a source diagnosis. Every stage keeps its own logs so a
/// failure always explains *why* (e.g. a red video step exposes the raw error
/// instead of a bare ❌).
enum DiagStep { popular, latest, detail, media }

// ─── Media preview URL ────────────────────────────────────────────────────────

class DiagMediaUrl {
  final String url;
  final Map<String, String>? headers;
  final String quality;
  const DiagMediaUrl({required this.url, this.headers, this.quality = ''});

  Map<String, dynamic> toJson() => {
        'url': url,
        'quality': quality,
        'hasHeaders': headers != null && headers!.isNotEmpty,
      };
}

// ─── Step result ──────────────────────────────────────────────────────────────

class DiagStepResult {
  final bool ok;

  /// Raw failure reason. Kept complete (not truncated) so exports and logs
  /// always carry the exact message.
  final String? error;
  final int? count;
  final int ms;

  /// Raw log lines produced while this stage ran — the “why” behind the status.
  final List<String> logs;

  bool get hasLogs => logs.isNotEmpty;

  const DiagStepResult({
    required this.ok,
    this.error,
    this.count,
    required this.ms,
    this.logs = const [],
  });

  DiagStepResult copyWith({
    bool? ok,
    String? error,
    int? count,
    int? ms,
    List<String>? logs,
    bool clearError = false,
  }) {
    return DiagStepResult(
      ok: ok ?? this.ok,
      error: clearError ? null : (error ?? this.error),
      count: count ?? this.count,
      ms: ms ?? this.ms,
      logs: logs ?? this.logs,
    );
  }
}

// ─── Extension result ─────────────────────────────────────────────────────────

class ExtDiagResult {
  final Source source;
  final Map<DiagStep, DiagStepResult> steps;
  final int totalMs;
  final List<DiagMediaUrl> previewUrls;

  /// Chronological trace of every log line emitted for this source, so the
  /// run console and exports always match what happened.
  final List<String> logs;

  /// True when the run was cancelled while this source was being diagnosed
  /// (some stages may be missing because they never ran).
  final bool cancelled;

  bool get allOk => steps.values.every((s) => s.ok);
  bool get anyFailed => steps.values.any((s) => !s.ok);
  int get okCount => steps.values.where((s) => s.ok).length;
  int get failCount => steps.values.where((s) => !s.ok).length;
  int get skippedCount => steps.length - okCount - failCount;

  const ExtDiagResult({
    required this.source,
    required this.steps,
    this.totalMs = 0,
    this.previewUrls = const [],
    this.logs = const [],
    this.cancelled = false,
  });

  /// All errors (including from cancelled/skipped stages) in reading order.
  Iterable<MapEntry<DiagStep, DiagStepResult>> get failedSteps =>
      steps.entries.where((e) => !e.value.ok);

  Iterable<MapEntry<DiagStep, DiagStepResult>> get failedWithReason =>
      steps.entries.where((e) => !e.value.ok && e.value.error != null);
}

typedef OnExtResult = void Function(ExtDiagResult result);

/// Shared mutable controls for a running batch: lets the UI pause/resume and
/// cancel a diagnostic run from outside the engine.
class DiagRunControls {
  bool _paused = false;
  bool _cancelled = false;

  bool get isPaused => _paused;
  bool get isCancelled => _cancelled;

  void pause() => _paused = true;
  void resume() => _paused = false;
  void cancel() {
    _cancelled = true;
    _paused = false; // release any waiter stuck on pause
  }

  void reset() {
    _paused = false;
    _cancelled = false;
  }

  /// Waits while the run is paused (polling — resumes within ~100 ms).
  Future<void> waitIfPaused() async {
    while (_paused && !_cancelled) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  /// True when the batch should stop scheduling/continuing work.
  Future<bool> aborted() async {
    if (_cancelled) return true;
    await waitIfPaused();
    return _cancelled;
  }
}

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

/// Diagnoses a single source (used for retry-after-Cloudflare and one-off
/// re-tests). Returns null when the run was cancelled before this source even
/// started.
Future<ExtDiagResult?> diagnoseSource(
  Source source,
  ItemType itemType, {
  void Function(String line)? onLog,
  DiagRunControls? controls,
}) async {
  if (controls != null) {
    await controls.waitIfPaused();
    if (controls.isCancelled) return null;
  }
  return _diagnoseSourceWithLog(source, itemType, onLog, controls: controls);
}

// ─── Scoped runner with pool + logs + pause/cancel ───────────────────────────

Future<List<ExtDiagResult>> runDiagnosticsForSources(
  List<Source> sources,
  ItemType itemType, {
  OnExtResult? onResult,
  void Function(String line)? onLog,
  int concurrency = 4,
  DiagRunControls? controls,
}) async {
  final sw = Stopwatch()..start();
  onLog?.call('${_nowTime()}  ┌─ START ─── ${sources.length} extension(s) · pool=$concurrency');

  final results = <ExtDiagResult>[];
  final sem = _Semaphore(concurrency.clamp(1, 8));

  var _logChain = Future<void>.value();
  void safeLog(String line) {
    _logChain = _logChain.then((_) {
      onLog?.call(line);
    });
  }

  final futures = sources.map((src) async {
    await sem.acquire();
    try {
      if (controls != null) {
        await controls.waitIfPaused();
        if (controls.isCancelled) {
          safeLog('${_nowTime()}  │   ⤼ "${src.name}" annulé (pas encore démarré)');
          return;
        }
      }
      safeLog('${_nowTime()}  ├─ [RUN] "${src.name}" [${(src.lang ?? "?").toUpperCase()}]…');
      final result = await _diagnoseSourceWithLog(
        src,
        itemType,
        safeLog,
        controls: controls,
      );
      // If the batch was cancelled while this source ran, tag the result so the
      // UI can show “interrompu” instead of a plain failure.
      final effective = controls != null && controls.isCancelled
          ? ExtDiagResult(
              source: result.source,
              steps: result.steps,
              totalMs: result.totalMs,
              previewUrls: result.previewUrls,
              logs: result.logs,
              cancelled: true,
            )
          : result;
      results.add(effective);
      onResult?.call(effective);
      if (!effective.cancelled) {
        final bar = _progressBar(effective.okCount, effective.steps.length);
        safeLog(
          '${_nowTime()}  │   ${effective.allOk ? "✅" : "❌"} "${src.name}"'
          ' $bar ${effective.okCount}/${effective.steps.length} · ${effective.totalMs}ms',
        );
      } else {
        safeLog('${_nowTime()}  │   ⛔ "${src.name}" interrompu par l’annulation');
      }
    } finally {
      sem.release();
    }
  }).toList();

  await Future.wait(futures);
  await _logChain;

  sw.stop();
  final cancelled = controls?.isCancelled ?? false;
  final ok = results.where((r) => r.allOk).length;
  final failed = results.length - ok;
  final rate = results.isEmpty ? 0 : (ok * 100 ~/ results.length);
  if (cancelled) {
    onLog?.call('${_nowTime()}  └─ CANCELLED ── $ok OK · $failed FAIL · ${results.length} analysée(s) · ${_formatDuration(sw.elapsedMilliseconds)}');
  } else {
    onLog?.call('${_nowTime()}  └─ DONE ── $ok OK · $failed FAIL · ${rate}% · ${_formatDuration(sw.elapsedMilliseconds)}');
  }

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

/// Human label for a step (used by reports).
String diagStepLabel(DiagStep step, ItemType itemType) => switch (step) {
      DiagStep.popular => 'Popular',
      DiagStep.latest => 'Latest',
      DiagStep.detail => 'Détail',
      DiagStep.media => itemType == ItemType.anime ? 'Vidéos' : 'Pages',
    };

String diagStepEmoji(DiagStep step, ItemType itemType) => switch (step) {
      DiagStep.popular => '📋',
      DiagStep.latest => '🕐',
      DiagStep.detail => '🔍',
      DiagStep.media => itemType == ItemType.anime ? '▶️' : '📄',
    };

// ─── Per-step runners ─────────────────────────────────────────────────────────

/// Step 1 — getPopular
Future<DiagStepResult> _runPopularStep(
  Source src,
  ItemType itemType,
  void Function(String) log, {
  required List<String> probeUrlsOut,
}) async {
  final sw = Stopwatch()..start();
  try {
    final pages = await getIsolateService
        .get<MPages>(page: 1, source: src, serviceType: 'getPopular')
        .timeout(const Duration(seconds: 45));
    sw.stop();
    final count = pages.list?.length ?? 0;
    probeUrlsOut.addAll(
      (pages.list ?? [])
          .take(3)
          .map((e) => e.link ?? '')
          .where((u) => u.isNotEmpty),
    );
    final result = DiagStepResult(
      ok: count > 0,
      count: count,
      ms: sw.elapsedMilliseconds,
      error: count == 0 ? 'Aucun résultat retourné (liste vide)' : null,
    );
    log('POP ${count > 0 ? "✓" : "✗"} ${count > 0 ? "$count items" : "liste vide"} · ${_formatDuration(sw.elapsedMilliseconds)}');
    return result;
  } catch (e) {
    sw.stop();
    final err = _trimError(e.toString());
    log('POP ✗ $err · ${_formatDuration(sw.elapsedMilliseconds)}');
    return DiagStepResult(ok: false, error: err, ms: sw.elapsedMilliseconds);
  }
}

/// Step 2 — getLatestUpdates
Future<DiagStepResult> _runLatestStep(
  Source src,
  ItemType itemType,
  void Function(String) log,
) async {
  final sw = Stopwatch()..start();
  try {
    final pages = await getIsolateService
        .get<MPages>(page: 1, source: src, serviceType: 'getLatestUpdates')
        .timeout(const Duration(seconds: 45));
    sw.stop();
    final count = pages.list?.length ?? 0;
    final result = DiagStepResult(
      ok: count > 0,
      count: count,
      ms: sw.elapsedMilliseconds,
      error: count == 0 ? 'Aucun résultat retourné (liste vide)' : null,
    );
    log('LAT ${count > 0 ? "✓" : "✗"} ${count > 0 ? "$count items" : "liste vide"} · ${_formatDuration(sw.elapsedMilliseconds)}');
    return result;
  } catch (e) {
    sw.stop();
    final err = _trimError(e.toString());
    log('LAT ✗ $err · ${_formatDuration(sw.elapsedMilliseconds)}');
    return DiagStepResult(ok: false, error: err, ms: sw.elapsedMilliseconds);
  }
}

/// Step 3 — getDetail on up to 3 probes from Popular, keeps the richest one.
/// Returns the step result and the first episode/chapter link (when found).
Future<(DiagStepResult, String?)> _runDetailStep(
  Source src,
  ItemType itemType,
  void Function(String) log, {
  required List<String> probeUrls,
}) async {
  if (probeUrls.isEmpty) {
    log('DET ⤼ ignoré — Popular a échoué (aucune URL de sondage)');
    return (
      const DiagStepResult(
        ok: false,
        error: 'Ignoré — Popular a échoué (aucune URL de sondage)',
        ms: 0,
      ),
      null,
    );
  }

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
      log('DET sondage $probeIndex/${probeUrls.length} ✓ $chapCount épisode(s)/chapitre(s)');
      if (bestDetail == null ||
          chapCount > (bestDetail.chapters?.length ?? 0)) {
        bestDetail = d;
      }
      if (chapCount > 1) break;
    } catch (e) {
      lastError = _trimError(e.toString());
      log('DET sondage $probeIndex/${probeUrls.length} ✗ $lastError');
    }
  }
  sw.stop();

  if (bestDetail != null) {
    final chapCount = bestDetail.chapters?.length ?? 0;
    final ok =
        (bestDetail.name != null && bestDetail.name!.isNotEmpty) || chapCount > 0;
    final link = (bestDetail.chapters?.isNotEmpty ?? false)
        ? bestDetail.chapters!.first.url
        : null;
    if (link == null) {
      log('DET ⚠ OK mais aucun lien d’épisode/chapitre exploitable');
    }
    final result = DiagStepResult(
      ok: ok,
      count: chapCount,
      ms: sw.elapsedMilliseconds,
      error: ok ? null : 'Détail vide (nom absent, 0 chapitres)',
    );
    log('DET ${ok ? "✓" : "✗"} ${ok ? "$chapCount épisode(s)/chapitre(s)" : "vide"} · ${_formatDuration(sw.elapsedMilliseconds)}');
    return (result, ok ? link : null);
  }

  final err = lastError ?? 'Tous les sondages ont échoué';
  log('DET ✗ $err · ${_formatDuration(sw.elapsedMilliseconds)}');
  return (
    DiagStepResult(
      ok: false,
      error: err,
      ms: sw.elapsedMilliseconds,
    ),
    null,
  );
}

/// Step 4 — getVideoList / getPageList + HTTP reachability of the first media.
Future<DiagStepResult> _runMediaStep(
  Source src,
  ItemType itemType,
  void Function(String) log, {
  required String firstEpisodeUrl,
  required List<DiagMediaUrl> previewUrlsOut,
}) async {
  final sw = Stopwatch()..start();
  final svcType = itemType == ItemType.anime ? 'getVideoList' : 'getPageList';
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
    var step = DiagStepResult(
      ok: count > 0,
      count: count,
      ms: sw.elapsedMilliseconds,
      error: count == 0 ? 'Aucun média retourné (liste vide)' : null,
    );
    log('$mediaLabel ${count > 0 ? "✓" : "✗"} ${count > 0 ? "$count source(s)" : "liste vide"} · ${_formatDuration(sw.elapsedMilliseconds)}');

    // Capture preview URLs (up to 5)
    for (final item in list.take(5)) {
      try {
        final rawUrl = (item as dynamic).url?.toString() ?? '';
        if (rawUrl.isEmpty) continue;
        final h = (item as dynamic).headers;
        String q = '';
        try {
          q = (item as dynamic).quality?.toString() ?? '';
        } catch (_) {}
        Map<String, String>? hdrs;
        if (h is Map) hdrs = Map<String, String>.from(h);
        previewUrlsOut.add(DiagMediaUrl(url: rawUrl, headers: hdrs, quality: q));
      } catch (_) {}
    }

    // Verify first URL accessibility (non-web only)
    if (count > 0 && !kIsWeb && previewUrlsOut.isNotEmpty) {
      final firstPreview = previewUrlsOut.first;
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
        log('HTTP ${httpResp.statusCode} ${statusOk ? "✓ accessible" : "✗ inaccessible"} (${uri.host})');
        if (!statusOk) {
          step = step.copyWith(
            ok: false,
            error: 'HTTP ${httpResp.statusCode} — l’URL média est inaccessible (${firstPreview.url})',
          );
        }
      } catch (httpErr) {
        log('HTTP ⚠ vérification impossible: ${_trimError(httpErr.toString())}');
      }
    }
    return step;
  } catch (e) {
    sw.stop();
    final err = _trimError(e.toString());
    log('$mediaLabel ✗ $err · ${_formatDuration(sw.elapsedMilliseconds)}');
    return DiagStepResult(
      ok: false,
      error: err,
      ms: sw.elapsedMilliseconds,
    );
  }
}

// ─── Core source runner ───────────────────────────────────────────────────────

Future<ExtDiagResult> _diagnoseSourceWithLog(
  Source src,
  ItemType itemType,
  void Function(String)? onLog, {
  DiagRunControls? controls,
}) async {
  final totalSw = Stopwatch()..start();
  final prefix = src.name ?? '?';

  // Buckets: every step gets its own log list + a chronological trace.
  final trace = <String>[];
  final stepBufs = <DiagStep, List<String>>{};
  void emit(DiagStep step, String msg) {
    final line = '${_nowTime()}  │   [$prefix] $msg';
    trace.add(line);
    stepBufs.putIfAbsent(step, () => []).add(msg);
    onLog?.call(line);
  }

  Future<bool> aborted() async {
    if (controls == null) return false;
    await controls.waitIfPaused();
    return controls.isCancelled;
  }

  DiagStepResult skippedStep(String reason) =>
      DiagStepResult(ok: false, error: reason, ms: 0);

  final steps = <DiagStep, DiagStepResult>{};
  final previewUrls = <DiagMediaUrl>[];
  final probeUrls = <String>[];
  var cancelled = false;

  // ── Step 1 : Popular ──────────────────────────────────────────────────────
  if (!await aborted()) {
    steps[DiagStep.popular] = await _runPopularStep(
      src,
      itemType,
      (m) => emit(DiagStep.popular, m),
      probeUrlsOut: probeUrls,
    );
  } else {
    cancelled = true;
    emit(DiagStep.popular, 'POP ⤼ interrompu (annulation)');
    steps[DiagStep.popular] = skippedStep('Interrompu — étape non exécutée');
  }

  // ── Step 2 : Latest ───────────────────────────────────────────────────────
  if (!await aborted()) {
    steps[DiagStep.latest] = await _runLatestStep(
      src,
      itemType,
      (m) => emit(DiagStep.latest, m),
    );
  } else {
    cancelled = true;
    emit(DiagStep.latest, 'LAT ⤼ interrompu (annulation)');
    steps[DiagStep.latest] = skippedStep('Interrompu — étape non exécutée');
  }

  // ── Step 3 : Detail ───────────────────────────────────────────────────────
  String? firstEpisodeUrl;
  if (!await aborted()) {
    final (detail, link) = await _runDetailStep(
      src,
      itemType,
      (m) => emit(DiagStep.detail, m),
      probeUrls: probeUrls,
    );
    steps[DiagStep.detail] = detail;
    firstEpisodeUrl = link;
  } else {
    cancelled = true;
    emit(DiagStep.detail, 'DET ⤼ interrompu (annulation)');
    steps[DiagStep.detail] = skippedStep('Interrompu — étape non exécutée');
  }

  // ── Step 4 : Media ────────────────────────────────────────────────────────
  if (firstEpisodeUrl != null && !await aborted()) {
    steps[DiagStep.media] = await _runMediaStep(
      src,
      itemType,
      (m) => emit(DiagStep.media, m),
      firstEpisodeUrl: firstEpisodeUrl,
      previewUrlsOut: previewUrls,
    );
  } else if (firstEpisodeUrl == null && !cancelled) {
    steps[DiagStep.media] = skippedStep('Ignoré — Détail a échoué (pas de lien média)');
    emit(DiagStep.media, 'VID ⤼ ignoré — Détail a échoué');
  } else {
    cancelled = true;
    emit(DiagStep.media, 'VID ⤼ interrompu (annulation)');
    steps[DiagStep.media] = skippedStep('Interrompu — étape non exécutée');
  }

  totalSw.stop();

  // Attach collected logs to each step result.
  final withLogs = <DiagStep, DiagStepResult>{};
  for (final e in steps.entries) {
    final r = e.value;
    withLogs[e.key] = DiagStepResult(
      ok: r.ok,
      error: r.error,
      count: r.count,
      ms: r.ms,
      logs: stepBufs[e.key] ?? const [],
    );
  }

  return ExtDiagResult(
    source: src,
    steps: withLogs,
    totalMs: totalSw.elapsedMilliseconds,
    previewUrls: previewUrls,
    logs: trace,
    cancelled: cancelled,
  );
}

String _trimError(String raw) {
  // Keep the first line for compact display but preserve full text in logs.
  final line = raw.split('\n').first.trim();
  return line.length > 400 ? '${line.substring(0, 397)}…' : line;
}

Future<ExtDiagResult> _diagnoseSource(Source src, ItemType itemType) =>
    _diagnoseSourceWithLog(src, itemType, null);

// ─── Shared report metadata ───────────────────────────────────────────────────

String _nowStamp() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, "0")}-${now.day.toString().padLeft(2, "0")} '
      '${now.hour.toString().padLeft(2, "0")}:${now.minute.toString().padLeft(2, "0")}:${now.second.toString().padLeft(2, "0")}';
}

String _typeLabel(ItemType itemType) => switch (itemType) {
      ItemType.anime => 'Watch / Anime',
      ItemType.manga => 'Manga',
      ItemType.novel => 'Novel',
      _ => itemType.name,
    };

String _reportHeaderTable({
  required ItemType itemType,
  required String scopeLabel,
  required List<ExtDiagResult> results,
  String? note,
}) {
  final ok = results.where((r) => r.allOk).length;
  final failed = results.length - ok;
  final rate = results.isEmpty ? 0 : (ok * 100 ~/ results.length);
  final totalMs = results.fold<int>(0, (acc, r) => acc + r.totalMs);
  final buf = StringBuffer();
  buf.writeln('| Champ | Valeur |');
  buf.writeln('|---|---|');
  buf.writeln('| **Type** | ${_typeLabel(itemType)} |');
  buf.writeln('| **Scope** | $scopeLabel |');
  buf.writeln('| **Total** | ${results.length} extensions |');
  buf.writeln('| **Résultat** | ✅ $ok OK · ❌ $failed échec(s) · $rate% de réussite |');
  buf.writeln('| **Durée totale** | ${_formatDuration(totalMs)} |');
  if (note != null) buf.writeln('| **Note** | $note |');
  return buf.toString();
}

String _stepSummaryMarkdown(List<ExtDiagResult> results, ItemType itemType) {
  final buf = StringBuffer();
  buf.writeln('## Résumé par étape');
  buf.writeln();
  buf.writeln('| Étape | Testé | OK | Échec | Taux |');
  buf.writeln('|---|---|---|---|---|');
  for (final step in DiagStep.values) {
    final total = results.where((r) => r.steps.containsKey(step)).length;
    final okN = results.where((r) => r.steps[step]?.ok == true).length;
    final failN = total - okN;
    final stepRate = total == 0 ? '—' : '${okN * 100 ~/ total}%';
    buf.writeln('| ${diagStepEmoji(step, itemType)} ${diagStepLabel(step, itemType)} | $total | $okN | $failN | $stepRate |');
  }
  return buf.toString();
}

// ─── Markdown report ─────────────────────────────────────────────────────────

String generateMarkdownReport({
  required List<ExtDiagResult> results,
  required ItemType itemType,
  required String scopeLabel,
  String? note,
}) {
  final buf = StringBuffer();
  buf.writeln('# Diagnostic Watchtower — ${_nowStamp()}');
  buf.writeln();
  buf.writeln(_reportHeaderTable(
    results: results,
    itemType: itemType,
    scopeLabel: scopeLabel,
    note: note,
  ));
  buf.writeln();
  buf.writeln(_stepSummaryMarkdown(results, itemType));
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
    final badge = result.cancelled
        ? '⛔'
        : result.allOk
            ? '✅'
            : '❌';

    buf.writeln('<details>');
    buf.writeln(
        '<summary>$badge **${src.name ?? "Unknown"}**'
        ' `${(src.lang ?? "?").toUpperCase()}` $bar $okSteps/${result.steps.length}'
        ' · ${_formatDuration(result.totalMs)}</summary>');
    buf.writeln();
    buf.writeln('| Étape | Statut | Résultat | Durée | Logs |');
    buf.writeln('|-------|--------|----------|-------|------|');
    for (final e in result.steps.entries) {
      final stepLabel = '${diagStepEmoji(e.key, itemType)} ${diagStepLabel(e.key, itemType)}';
      final status = e.value.ok ? '✅ OK' : '❌ FAIL';
      final res = e.value.count != null
          ? '${e.value.count} résultats'
          : (e.value.error ?? '—');
      final hasLogs = e.value.hasLogs ? '${e.value.logs.length}' : '—';
      buf.writeln('| $stepLabel | $status | $res | ${_formatDuration(e.value.ms)} | $hasLogs |');
    }

    // Per-step logs: the real reason behind every red/green stage.
    final withLogs = result.steps.entries.where((e) => e.value.hasLogs).toList();
    if (withLogs.isNotEmpty) {
      for (final e in withLogs) {
        final n = diagStepLabel(e.key, itemType);
        buf.writeln();
        buf.writeln('**Logs — $n :**');
        buf.writeln();
        buf.writeln('```');
        for (final l in e.value.logs) {
          buf.writeln(l);
        }
        buf.writeln('```');
      }
    }

    final errors = result.failedWithReason.toList();
    if (errors.isNotEmpty) {
      buf.writeln();
      buf.writeln('**Erreurs détaillées :**');
      buf.writeln();
      for (final e in errors) {
        final n = diagStepLabel(e.key, itemType);
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

// ─── JSON report ─────────────────────────────────────────────────────────────

String generateJsonReport({
  required List<ExtDiagResult> results,
  required ItemType itemType,
  required String scopeLabel,
  String? note,
}) {
  final ok = results.where((r) => r.allOk).length;
  final failed = results.length - ok;
  final totalMs = results.fold<int>(0, (acc, r) => acc + r.totalMs);

  final steps = <String, Map<String, dynamic>>{};
  for (final step in DiagStep.values) {
    final tested = results.where((r) => r.steps.containsKey(step)).length;
    final okN = results.where((r) => r.steps[step]?.ok == true).length;
    steps[step.name] = {
      'label': diagStepLabel(step, itemType),
      'tested': tested,
      'ok': okN,
      'failed': tested - okN,
    };
  }

  final extensions = results.map((r) {
    final src = r.source;
    return <String, dynamic>{
      'id': src.id,
      'name': src.name ?? 'Unknown',
      'lang': src.lang ?? '',
      'sourceCodeLanguage': src.sourceCodeLanguage?.name,
      'nsfw': src.isNsfw == true,
      'hasCloudflare': src.hasCloudflare == true,
      'baseUrl': src.baseUrl ?? '',
      'status': r.cancelled
          ? 'cancelled'
          : r.allOk
              ? 'ok'
              : 'failed',
      'totalMs': r.totalMs,
      'okSteps': r.okCount,
      'failSteps': r.failCount,
      'steps': {
        for (final e in r.steps.entries)
          e.key.name: <String, dynamic>{
            'label': diagStepLabel(e.key, itemType),
            'ok': e.value.ok,
            'error': e.value.error,
            'count': e.value.count,
            'ms': e.value.ms,
            'logs': e.value.logs,
          },
      },
      'previewUrls': r.previewUrls.map((u) => u.toJson()).toList(),
      'logs': r.logs,
    };
  }).toList();

  final report = <String, dynamic>{
    'app': 'Watchtower',
    'generatedAt': DateTime.now().toIso8601String(),
    'type': _typeLabel(itemType),
    'itemType': itemType.name,
    'scope': scopeLabel,
    'note': note,
    'summary': {
      'total': results.length,
      'ok': ok,
      'failed': failed,
      'successRate': results.isEmpty ? 0 : (ok * 100 / results.length).round(),
      'totalMs': totalMs,
    },
    'steps': steps,
    'extensions': extensions,
  };

  const encoder = JsonEncoder.withIndent('  ');
  return encoder.convert(report);
}

// ─── Plain-text report ───────────────────────────────────────────────────────

String generateTextReport({
  required List<ExtDiagResult> results,
  required ItemType itemType,
  required String scopeLabel,
  String? note,
}) {
  final ok = results.where((r) => r.allOk).length;
  final failed = results.length - ok;
  final rate = results.isEmpty ? 0 : (ok * 100 ~/ results.length);
  final totalMs = results.fold<int>(0, (acc, r) => acc + r.totalMs);

  final buf = StringBuffer();
  buf.writeln('=' * 60);
  buf.writeln('DIAGNOSTIC WATCHTOWER — ${_nowStamp()}');
  buf.writeln('=' * 60);
  buf.writeln('Type       : ${_typeLabel(itemType)}');
  buf.writeln('Scope      : $scopeLabel');
  buf.writeln('Total      : ${results.length} extensions');
  buf.writeln('Résultat   : $ok OK · $failed échec(s) · $rate%');
  buf.writeln('Durée      : ${_formatDuration(totalMs)}');
  if (note != null) buf.writeln('Note       : $note');
  buf.writeln();

  for (final step in DiagStep.values) {
    final total = results.where((r) => r.steps.containsKey(step)).length;
    final okN = results.where((r) => r.steps[step]?.ok == true).length;
    buf.writeln('[${diagStepLabel(step, itemType).toUpperCase()}] '
        '$okN OK / $total testées');
  }
  buf.writeln();
  buf.writeln('-' * 60);

  final sorted = [
    ...results.where((r) => r.anyFailed),
    ...results.where((r) => r.allOk),
  ];
  for (final result in sorted) {
    final src = result.source;
    final badge = result.cancelled
        ? '⛔'
        : result.allOk
            ? '✅'
            : '❌';
    buf.writeln();
    buf.writeln('$badge ${src.name ?? 'Unknown'} '
        '[${(src.lang ?? '?').toUpperCase()}] '
        '${result.okCount}/${result.steps.length} · ${_formatDuration(result.totalMs)}');
    for (final e in result.steps.entries) {
      final v = e.value;
      final res = v.count != null
          ? '${v.count} résultats'
          : (v.error ?? (v.ok ? 'OK' : '—'));
      buf.writeln('   ${v.ok ? "✓" : "✗"} ${diagStepLabel(e.key, itemType)} '
          '· ${_formatDuration(v.ms)} — $res');
      if (v.hasLogs) {
        for (final l in v.logs) {
          buf.writeln('       · $l');
        }
      }
    }
    buf.writeln();
  }
  return buf.toString();
}

// ─── CSV report ──────────────────────────────────────────────────────────────

String _csvEscape(String v) {
  if (v.contains(',') || v.contains('"') || v.contains('\n') || v.contains('\r')) {
    return '"${v.replaceAll('"', '""')}"';
  }
  return v;
}

String generateCsvReport({
  required List<ExtDiagResult> results,
  required ItemType itemType,
  required String scopeLabel,
  String? note,
}) {
  final buf = StringBuffer();
  final cols = <String>[
    'extension', 'lang', 'type', 'nsfw', 'has_cloudflare',
    'status', 'total_ms', 'ok_steps', 'fail_steps',
    for (final s in DiagStep.values) ...[
      '${s.name}_ok',
      '${s.name}_count',
      '${s.name}_ms',
      '${s.name}_error',
      '${s.name}_logs',
    ],
  ];
  buf.writeln(cols.map(_csvEscape).join(','));

  final sorted = [
    ...results.where((r) => r.anyFailed),
    ...results.where((r) => r.allOk),
  ];
  for (final r in sorted) {
    final src = r.source;
    final row = <String>[
      src.name ?? 'Unknown',
      src.lang ?? '',
      src.sourceCodeLanguage?.name ?? '',
      (src.isNsfw == true).toString(),
      (src.hasCloudflare == true).toString(),
      r.cancelled ? 'cancelled' : (r.allOk ? 'ok' : 'failed'),
      '${r.totalMs}',
      '${r.okCount}',
      '${r.failCount}',
      for (final s in DiagStep.values)
        if (r.steps.containsKey(s)) ...[
          r.steps[s]!.ok ? 'ok' : 'fail',
          '${r.steps[s]!.count ?? ''}',
          '${r.steps[s]!.ms}',
          r.steps[s]!.error ?? '',
          r.steps[s]!.logs.join('\n'),
        ] else ...[
          '', '', '0', 'non testé', '',
        ],
    ];
    buf.writeln(row.map(_csvEscape).join(','));
  }
  return buf.toString();
}

// ─── Multi-format saving ──────────────────────────────────────────────────────

/// Saves every format (md / json / txt / csv) into `dev/Diagnostic_nNNN.*`
/// and returns the list of saved paths (markdown first).
Future<List<String>> saveDiagnosticReports({
  required List<ExtDiagResult> results,
  required ItemType itemType,
  required String scopeLabel,
  String? note,
}) async {
  if (kIsWeb) return const [];
  try {
    final md = generateMarkdownReport(
      results: results,
      itemType: itemType,
      scopeLabel: scopeLabel,
      note: note,
    );
    final json = generateJsonReport(
      results: results,
      itemType: itemType,
      scopeLabel: scopeLabel,
      note: note,
    );
    final txt = generateTextReport(
      results: results,
      itemType: itemType,
      scopeLabel: scopeLabel,
      note: note,
    );
    final csv = generateCsvReport(
      results: results,
      itemType: itemType,
      scopeLabel: scopeLabel,
      note: note,
    );

    final baseDir = await StorageProvider().getDirectory();
    if (baseDir == null) return const [];

    final devDir = Directory(p.join(baseDir.path, 'dev'));
    await devDir.create(recursive: true);

    int nextN = 1;
    try {
      final existing = devDir
          .listSync()
          .whereType<File>()
          .map((f) => p.basename(f.path))
          .where((name) => RegExp(r'^Diagnostic_n\d+\.(md|json|txt|csv)$').hasMatch(name))
          .map((name) {
            final m = RegExp(r'Diagnostic_n(\d+)\.').firstMatch(name);
            return m != null ? (int.tryParse(m.group(1)!) ?? 0) : 0;
          })
          .toList();
      if (existing.isNotEmpty) nextN = existing.reduce((a, b) => a > b ? a : b) + 1;
    } catch (_) {}

    final base = 'Diagnostic_n${nextN.toString().padLeft(3, "0")}';
    final saved = <String>[];
    for (final (ext, content) in [
      ('md', md),
      ('json', json),
      ('txt', txt),
      ('csv', csv),
    ]) {
      final filePath = p.join(devDir.path, '$base.$ext');
      await File(filePath).writeAsString(content);
      saved.add(filePath);
    }
    AppLogger.log(
      'Diagnostic reports saved: ${saved.join(', ')}',
      logLevel: LogLevel.info,
      tag: kLogTagExt,
    );
    return saved;
  } catch (e) {
    AppLogger.log(
      'saveDiagnosticReports failed: $e',
      logLevel: LogLevel.warning,
      tag: kLogTagExt,
    );
    return const [];
  }
}

/// Legacy single-format helper — returns the markdown path.
Future<String?> saveDiagnosticReport({
  required List<ExtDiagResult> results,
  required ItemType itemType,
  required String scopeLabel,
}) async {
  final paths = await saveDiagnosticReports(
    results: results,
    itemType: itemType,
    scopeLabel: scopeLabel,
  );
  return paths.isEmpty ? null : paths.first;
}
