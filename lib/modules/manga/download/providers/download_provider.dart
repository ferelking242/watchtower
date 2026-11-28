import 'dart:async';
import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:watchtower/eval/lib.dart';
import 'package:watchtower/eval/model/m_bridge.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/page.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/chapter.dart';
import 'package:watchtower/models/download.dart';
import 'package:watchtower/models/settings.dart';
import 'package:watchtower/models/video.dart';
import 'package:watchtower/modules/watch/detail/download/quality_selection.dart';

/// Re-exported so the screens that already import this provider (batch sheet,
/// catalogue menu) keep resolving [QualityFallback] without a second import.
export 'package:watchtower/modules/watch/detail/download/quality_selection.dart'
    show QualityFallback;
import 'package:watchtower/modules/manga/download/providers/convert_to_cbz.dart';
import 'package:watchtower/services/anti_bot/anti_bot_detection.dart' show isCloudflareError;
import 'package:watchtower/services/anti_bot/challenge_inbox.dart';
import 'package:watchtower/services/download_manager/download_settings_service.dart';
import 'package:watchtower/services/download_series_metadata.dart';
import 'package:watchtower/modules/more/download_queue/download_queue_grouping.dart';
import 'package:watchtower/modules/more/download_queue/download_slot_allocation.dart';
import 'package:watchtower/modules/more/settings/downloads/providers/downloads_state_provider.dart';
import 'package:watchtower/modules/more/providers/incognito_mode_state_provider.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/providers/storage_provider.dart';
import 'package:watchtower/router/router.dart';
import 'package:watchtower/services/download_manager/active_download_registry.dart';
import 'package:watchtower/services/download_manager/archive_progress_store.dart';
import 'package:watchtower/services/download_manager/download_connectivity.dart';
import 'package:watchtower/services/connectivity_service.dart';
import 'package:watchtower/services/download_manager/download_isolate_pool.dart';
import 'package:watchtower/services/download_manager/download_queue_scheduler_signal.dart';
import 'package:watchtower/services/download_manager/download_failure_store.dart';
import 'package:watchtower/services/download_manager/host_cooldown_registry.dart';
import 'package:watchtower/services/download_manager/external_downloader_launcher.dart';
import 'package:watchtower/services/download_manager/m_downloader.dart';
import 'package:watchtower/services/manga_download_manifest.dart';
import 'package:watchtower/services/download_manager/download_size.dart';
import 'package:watchtower/services/get_video_list.dart';
import 'package:watchtower/services/get_chapter_pages.dart';
import 'package:watchtower/services/page_url_cache.dart';
import 'package:watchtower/services/downloaded_video_preference.dart';
import 'package:watchtower/services/watch_comments_cache.dart';
import 'package:watchtower/services/settings_store.dart';
import 'package:watchtower/services/http/m_client.dart';
import 'package:watchtower/services/http/persisted_request_metadata.dart';
import 'package:watchtower/services/download_manager/m3u8/m3u8_downloader.dart';
import 'package:watchtower/services/download_manager/m3u8/models/download.dart';
import 'package:watchtower/services/download_manager/engine_selector.dart';
import 'package:watchtower/services/video_duration_probe_stub.dart'
    if (dart.library.ffi) 'package:watchtower/services/video_duration_probe_io.dart';
import 'package:watchtower/services/download_manager/engines/aria2_engine.dart';
import 'package:watchtower/services/download_manager/engines/download_engine.dart';
import 'package:watchtower/services/download_manager/engines/ffmpeg_hls_engine.dart';
import 'package:watchtower/services/download_manager/engines/zeus_engine.dart';
import 'package:watchtower/services/download_manager/engines/zeus_runtime.dart';
import 'package:watchtower/services/download_manager/media_file_name.dart';
import 'package:watchtower/services/download_manager/speed_meter.dart';
import 'package:watchtower/utils/chapter_link.dart';
import 'package:watchtower/utils/chapter_recognition.dart';
import 'package:watchtower/utils/extensions/chapter.dart';
import 'package:watchtower/utils/extensions/string_extensions.dart';
import 'package:watchtower/utils/headers.dart';
import 'package:watchtower/utils/log/logger.dart';
import 'package:watchtower/utils/reg_exp_matcher.dart';
import 'package:watchtower/utils/utils.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:watchtower/services/download_manager/background_keep_alive.dart';
import 'package:watchtower/services/update_notification_service.dart';
part 'download_provider.g.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Bridge the old developer.log calls in this file into AppLogger so scheduler
/// and worker traces are also visible in the floating log panel.
void log(String message, {Object? error, StackTrace? stackTrace}) {
  AppLogger.log(
    message,
    logLevel: error != null || stackTrace != null ? LogLevel.warning : LogLevel.info,
    tag: LogTag.download,
    error: error,
    stackTrace: stackTrace,
  );
}

const _mangaDownloadManifestName = '.watchtower-download-manifest.json';

Future<MangaDownloadManifest?> _readMangaDownloadManifest(File file) async {
  for (final candidate in [file, File('${file.path}.tmp')]) {
    try {
      if (await candidate.exists()) {
        final manifest = MangaDownloadManifest.decode(await candidate.readAsString());
        if (manifest != null) return manifest;
      }
    } catch (_) {
      // A damaged sidecar must not prevent a chapter from being resumed.
    }
  }
  return null;
}

Future<void> _writeMangaDownloadManifest(File file, MangaDownloadManifest manifest) async {
  final temporary = File('${file.path}.tmp');
  try {
    await file.parent.create(recursive: true);
    await temporary.writeAsString(manifest.encode(), flush: true);
    // `rename` replaces the destination atomically. Deleting it first opened a
    // window in which a second worker (or the OS) removed the file under us and
    // the delete itself threw PathNotFoundException, which aborted a chapter
    // that had already downloaded all its pages.
    await temporary.rename(file.path);
  } catch (error) {
    // The sidecar only speeds up a resume; losing it must never fail the
    // download. Drop a half-written temp file so the next attempt starts clean.
    try {
      if (await temporary.exists()) await temporary.delete();
    } catch (_) {
      // Nothing left to clean up.
    }
    AppLogger.log(
      '[DL] manifest write skipped: $error',
      logLevel: LogLevel.debug,
      tag: LogTag.download,
    );
  }
}

/// Whether re-asking the extension for the page list can plausibly fix this
/// failure, i.e. the URLs we hold are stale rather than the host being busy.
///
/// 404/410 belong here as much as 401/403: a manga CDN that renamed or removed
/// a page answers 404, and every retry then re-requests the same dead URL from
/// the cached list. That is the "downloads one page, fails, relaunch, fails
/// again" loop — the cache has to be dropped before a retry can differ.
bool _isRefreshablePageUrlError(Object error) =>
    RegExp(r'\b(?:401|403|404|410)\b').hasMatch(error.toString());

/// Whether a failure means "slow down" rather than "this URL is stale".
///
/// Deliberately not part of [_isRefreshablePageUrlError]: refreshing the page
/// list cannot fix a 429, and the extra extension call would add load to the
/// host that is already refusing us. A rate limit is handled by cooling the
/// host down instead (see [HostCooldownRegistry]).
bool _isRateLimitError(Object error) {
  final text = error.toString();
  return RegExp(r'\b(?:429|503)\b').hasMatch(text) ||
      text.contains('too many requests') ||
      text.contains('rate limit');
}

/// Clears the cooldown for the source (and page hosts) after a success.
///
/// Keyed like [_recordHostCooldownFromError] so a success actually lifts the
/// hold the dispatch loop is checking.
void _clearHostCooldown(String source, {List<PageUrl>? pageUrls}) {
  final key = HostCooldownRegistry.keyForSource(source);
  final wasHeld = HostCooldownRegistry.instance.isCoolingDown(key);
  HostCooldownRegistry.instance.registerSuccess(key);
  if (wasHeld) {
    AppLogger.log(
      '[cooldown] source=$key answered normally again; hold lifted and the '
      'queue resumes immediately',
      logLevel: LogLevel.info,
      tag: LogTag.download,
    );
  }
  for (final page in pageUrls ?? const <PageUrl>[]) {
    final host = Uri.tryParse(page.url)?.host;
    if (host != null && host.isNotEmpty) {
      HostCooldownRegistry.instance.registerSuccess(host);
    }
  }
}

/// Puts the source behind this download into cooldown after a rate-limit
/// failure, so the queue stops feeding it until the window expires.
///
/// [source] is the extension name, which is what the dispatch loop gates on.
/// Page hosts are recorded too, for diagnostics and for hosts shared by
/// several extensions.
void _recordHostCooldownFromError(
  Object error, {
  required String source,
  List<PageUrl>? pageUrls,
}) {
  if (!_isRateLimitError(error)) return;
  // The server's own hint beats our guess when it gave one.
  final hint = error is DownloadPoolFailure
      ? error.retryAfter
      : error is DownloadPoolException
      ? error.retryAfter
      : null;
  final key = HostCooldownRegistry.keyForSource(source);
  final cooldown = HostCooldownRegistry.instance.registerFailure(
    key,
    retryAfter: hint,
  );
  AppLogger.log(
    '[cooldown] source=$key answered with a rate limit (429/503); every '
    'chapter of this extension is held for ${cooldown.inSeconds}s, then the '
    'queue resumes on its own',
    logLevel: LogLevel.warning,
    tag: LogTag.download,
  );
  for (final page in pageUrls ?? const <PageUrl>[]) {
    final host = Uri.tryParse(page.url)?.host;
    if (host != null && host.isNotEmpty && host != key) {
      HostCooldownRegistry.instance.registerFailure(host, retryAfter: hint);
    }
  }
}

String _safeManifestFailure(Object error) {
  final status = RegExp(
    r'\b(?:401|403|404|408|429|5\d\d)\b',
  ).firstMatch(error.toString())?.group(0);
  return status == null ? error.runtimeType.toString() : 'HTTP $status';
}

/// Convert a raw exception into a human-readable French message.
String friendlyErrorMessage(Object e) {
  // A partial chapter has a usable result, so say what is missing instead of
  // claiming the whole download failed.
  if (e is DownloadPoolFailure && e.isPartial) {
    return '${e.failedCount} page(s) sur ${e.totalCount} n’ont pas pu être '
        'téléchargées.\nRelancez le chapitre pour compléter les pages manquantes.';
  }
  if (e is DownloadPoolException && e.isPartial) {
    return '${e.failedCount} page(s) sur ${e.totalCount} n’ont pas pu être '
        'téléchargées.\nRelancez le chapitre pour compléter les pages manquantes.';
  }
  final msg = e.toString().toLowerCase();
  if (e is SocketException) {
    return 'Impossible de se connecter au serveur.\nVérifiez votre connexion Internet.';
  }
  if (msg.contains('handshake') || msg.contains('certificate')) {
    return 'Erreur de sécurité lors de la connexion au serveur.\nLe certificat SSL est peut-être invalide.';
  }
  if (msg.contains('timeout') || msg.contains('timed out')) {
    return 'La connexion a expiré. Le serveur met trop de temps à répondre.\nRéessayez dans quelques instants.';
  }
  if (msg.contains('connection refused')) {
    return 'Connexion refusée par le serveur. Il est peut-être hors ligne.';
  }
  if (msg.contains('no address') || msg.contains('resolve')) {
    return 'Nom de domaine introuvable.\nVérifiez votre connexion ou réessayez plus tard.';
  }
  if (msg.contains('403') || msg.contains('forbidden')) {
    return 'Accès interdit (403). Ce contenu est peut-être protégé.';
  }
  if (msg.contains('404') || msg.contains('not found')) {
    return 'Contenu introuvable (404). Le lien est peut-être invalide.';
  }
  if (msg.contains('429') || msg.contains('too many requests')) {
    return 'Trop de requêtes envoyées (429).\nPatientez quelques minutes avant de réessayer.';
  }
  if (msg.contains('500') || msg.contains('internal server')) {
    return 'Erreur serveur interne (500). Réessayez plus tard.';
  }
  if (msg.contains('cloudflare') || msg.contains('ddos')) {
    return 'Bloqué par le pare-feu du site (Cloudflare).\nEssayez un VPN ou revenez plus tard.';
  }
  return 'Une erreur inattendue est survenue.\n${e.toString().split('\n').first}';
}

/// Dernière erreur de téléchargement signalée à l'utilisateur.
///
/// Sans ce signalement, un échec (source injoignable, 404, stockage, etc.)
/// restait totalement silencieux : l'entrée repassait en "non démarré" et
/// l'utilisateur avait l'impression que le bouton de téléchargement ne
/// faisait rien. On limite les répétitions (file de plusieurs chapitres) pour
/// ne pas noyer l'écran sous les toasts identiques.
String? _lastDownloadFailureMessage;
DateTime? _lastDownloadFailureAt;
bool _processDownloadsSchedulerRunning = false;
bool? _processDownloadsWifiOverride;

void _notifyDownloadFailure(String message) {
  final now = DateTime.now();
  if (_lastDownloadFailureMessage == message &&
      _lastDownloadFailureAt != null &&
      now.difference(_lastDownloadFailureAt!) < const Duration(seconds: 6)) {
    return;
  }
  _lastDownloadFailureMessage = message;
  _lastDownloadFailureAt = now;
  try {
    botToast(message);
  } catch (_) {
    // botToast ne doit jamais faire échouer la boucle de téléchargement.
  }
}

void _setDownloadStatus(int? id, String status) {
  if (id == null) return;
  try {
    final download = isar.downloads.getSync(id);
    if (download == null || download.isDownload == true || download.status == status) {
      return;
    }
    isar.writeTxnSync(() {
      isar.downloads.putSync(download..status = status);
    });
  } catch (_) {
    // Une entrée corrompue / migration non jouée peut lever un RangeError
    // lors de la désérialisation. On ignore silencieusement : l'important est
    // de ne pas faire planter la boucle de téléchargement.
  }
}

/// Parks a row as rate-limited: kept in the queue (so the scheduler can resume
/// it automatically once the source's cooldown expires) but marked with a
/// dedicated status so the UI can show why nothing is moving.
void _markRateLimited(int? id) {
  if (id == null) return;
  try {
    final download = isar.downloads.getSync(id);
    if (download == null || download.isDownload == true) return;
    isar.writeTxnSync(() {
      isar.downloads.putSync(
        download
          ..isDownload = false
          ..isStartDownload = true
          ..status = 'rate_limited',
      );
    });
  } catch (_) {
    // Same policy as [_setDownloadStatus]: a corrupt row must not break the queue.
  }
}

/// Cooldown still in force for the source that owns [chapter], or null.
///
/// Every gate (scheduler, worker, retry action) has to ask this question with
/// the same key, otherwise a forced start slips past a cooldown the queue is
/// still honouring. The key is the canonical source name, matching the value
/// recorded when the rate-limit failure happened.
Duration? _sourceCooldownFor(Chapter chapter) =>
    _sourceCooldownForName(resolveChapterManga(chapter)?.source);

/// Cooldown still in force for [source], or null.
Duration? _sourceCooldownForName(String? source) {
  if (source == null) return null;
  final remaining = HostCooldownRegistry.instance.remaining(
    HostCooldownRegistry.keyForSource(source),
  );
  if (remaining == null || remaining.isNegative) return null;
  return remaining;
}

/// Tear-off of `read` shared by [WidgetRef] and [ProviderContainer], so the
/// download helpers can run with or without a widget tree.
typedef ProviderRead = T Function<T>(ProviderListenable<T> provider);

Future<void> deleteMediaDownload(WidgetRef ref, int chapterId) =>
    _deleteMediaDownload(ref.read, chapterId);

/// Headless variant of [deleteMediaDownload] for the CLI, where there is no
/// widget tree and therefore no [WidgetRef].
Future<void> deleteMediaDownloadFromContainer(ProviderContainer ref, int chapterId) =>
    _deleteMediaDownload(ref.read, chapterId);

Future<void> _deleteMediaDownload(ProviderRead ref, int chapterId) async {
  final notifier = ref(downloadQueueStateProvider.notifier);
  final download = isar.downloads.getSync(chapterId);
  if (download == null) return;

  isar.writeTxnSync(() {
    final stored = isar.downloads.getSync(chapterId);
    if (stored != null && stored.isDownload != true) {
      isar.downloads.putSync(
        stored
          ..isStartDownload = false
          ..status = 'cancelled',
      );
    }
  });
  await ActiveDownloadRegistry.cancel(chapterId);
  DownloadIsolatePool.instance.cancelTask('$chapterId');
  DownloadIsolatePool.instance.cancelTask('m3u8_$chapterId');
  if (!download.chapter.isLoaded) {
    try {
      download.chapter.loadSync();
    } catch (error) { AppLogger.log('Ignored error (download_provider.dart)', logLevel: LogLevel.debug, tag: LogTag.download, error: error); }
  }
  final chapter = download.chapter.value;
  if (chapter != null) {
    await chapter.deleteDownloadedFiles();
  } else {
    final savedPath = download.filePath;
    if (savedPath != null) {
      for (final candidate in [savedPath, '$savedPath.part', '$savedPath.part.meta']) {
        try {
          final file = File(candidate);
          if (file.existsSync()) file.deleteSync();
        } catch (error) { AppLogger.log('Ignored error (download_provider.dart)', logLevel: LogLevel.debug, tag: LogTag.download, error: error); }
      }
    }
    isar.writeTxnSync(() => isar.downloads.deleteSync(chapterId));
  }

  notifier.setPaused(chapterId, false, updateEngine: false);
  notifier.clearLiveProgress(chapterId);
  await WatchtowerNotificationService.instance.cancelMediaDownloadNotification(chapterId);
}

Future<void> handleMediaDownloadNotificationAction(
  WidgetRef ref,
  int chapterId,
  MediaDownloadNotificationAction action,
) => _handleMediaDownloadNotificationAction(ref.read, chapterId, action);

/// Headless variant of [handleMediaDownloadNotificationAction] for the CLI.
Future<void> handleMediaDownloadNotificationActionFromContainer(
  ProviderContainer ref,
  int chapterId,
  MediaDownloadNotificationAction action,
) => _handleMediaDownloadNotificationAction(ref.read, chapterId, action);

/// Retries every failed chapter of one series card.
///
/// Each chapter goes through the same retry path as the per-chapter button, so
/// the queue, the persisted offsets and the rate-limit parking behave
/// identically — only the trigger differs.
Future<void> handleMediaSeriesRetryFromContainer(
  ProviderContainer ref,
  String seriesKey,
  List<int> chapterIds,
) async {
  for (final chapterId in chapterIds) {
    try {
      await _handleMediaDownloadNotificationAction(
        ref.read,
        chapterId,
        MediaDownloadNotificationAction.retry,
      );
    } catch (error, stackTrace) {
      AppLogger.log(
        '[ch:$chapterId] series retry failed',
        logLevel: LogLevel.error,
        tag: LogTag.download,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}

Future<void> _handleMediaDownloadNotificationAction(
  ProviderRead ref,
  int chapterId,
  MediaDownloadNotificationAction action,
) async {
  final notifier = ref(downloadQueueStateProvider.notifier);
  final notifications = WatchtowerNotificationService.instance;
  final download = isar.downloads.getSync(chapterId);
  if (download == null) {
    await notifications.cancelMediaDownloadNotification(chapterId);
    return;
  }
  final isPaused =
      ref(downloadQueueStateProvider).pausedIds.contains(chapterId) || download.status == 'paused';

  switch (action) {
    case MediaDownloadNotificationAction.pause:
      // Nothing to pause on a chapter that already completed: drop the stale
      // notice instead of leaving a Pause button on a finished download.
      if (download.isDownload == true) {
        await notifications.cancelMediaDownloadNotification(chapterId);
        return;
      }
      if (isPaused) return;
      notifier.setPaused(chapterId, true, updateEngine: false);
      isar.writeTxnSync(() {
        final stored = isar.downloads.getSync(chapterId);
        if (stored != null) {
          isar.downloads.putSync(stored..status = 'paused');
        }
      });
      await ActiveDownloadRegistry.pause(chapterId);
      await notifications.setMediaDownloadPaused(chapterId, isPaused: true);
      break;
    case MediaDownloadNotificationAction.resume:
      // A completed chapter must never be resumed: retrying it would wipe the
      // persisted byte/page counters and re-download from scratch.
      if (download.isDownload == true) {
        await notifications.cancelMediaDownloadNotification(chapterId);
        return;
      }
      if (download.status == 'cancelled') return;
      // Only a paused row used to be resumable, so resuming a failed or
      // rate-limited one silently did nothing — the "resume never restarts"
      // report. Both are stopped states and must be re-queued here.
      if (!isPaused &&
          download.status != 'failed' &&
          download.status != 'rate_limited') {
        return;
      }
      // Resume keeps the existing succeeded/total/downloadedBytes offsets so
      // the transfer continues where it stopped instead of restarting at 0.
      notifier.setPaused(chapterId, false, updateEngine: false);
      isar.writeTxnSync(() {
        final stored = isar.downloads.getSync(chapterId);
        if (stored != null && stored.isDownload != true) {
          isar.downloads.putSync(
            stored
              ..isDownload = false
              ..isStartDownload = true
              ..status = 'queued',
          );
        }
      });
      await ActiveDownloadRegistry.resume(chapterId);
      await notifications.setMediaDownloadPaused(chapterId, isPaused: false);
      ref(processDownloadsProvider());
      break;
    case MediaDownloadNotificationAction.cancel:
      if (download.isDownload == true) return;
      notifier.setPaused(chapterId, false, updateEngine: false);
      isar.writeTxnSync(() {
        final stored = isar.downloads.getSync(chapterId);
        if (stored != null) {
          isar.downloads.putSync(
            stored
              ..isDownload = false
              ..isStartDownload = false
              ..status = 'cancelled',
          );
        }
      });
      await ActiveDownloadRegistry.cancel(chapterId);
      DownloadIsolatePool.instance.cancelTask('$chapterId');
      DownloadIsolatePool.instance.cancelTask('m3u8_$chapterId');
      await notifications.cancelMediaDownloadNotification(chapterId);
      break;
    case MediaDownloadNotificationAction.retry:
      var chapter = download.chapter.value;
      if (chapter == null && !download.chapter.isLoaded) {
        try {
          download.chapter.loadSync();
          chapter = download.chapter.value;
        } catch (error) { AppLogger.log('Ignored error (download_provider.dart)', logLevel: LogLevel.debug, tag: LogTag.download, error: error); }
      }
      chapter ??= isar.chapters.getSync(chapterId);
      if (chapter == null) {
        await notifications.cancelMediaDownloadNotification(chapterId);
        return;
      }
      ensureChapterLinksLoaded(chapter);
      // Retry means "start over", so it clears the counters below. While the
      // source is cooling down that would throw away pages and bytes the
      // paused transfer had already saved, and the worker would still refuse to
      // start — the user loses progress and gains nothing. Park the row instead
      // and let the scheduler resume it when the window expires.
      final retryCooldown = _sourceCooldownFor(chapter);
      if (retryCooldown != null) {
        AppLogger.log(
          '[ch:$chapterId] retry refused: source is rate limited '
          '(${retryCooldown.inSeconds}s left); keeping saved progress',
          logLevel: LogLevel.warning,
          tag: LogTag.download,
        );
        notifier.setPaused(chapterId, false, updateEngine: false);
        _markRateLimited(chapterId);
        await notifications.cancelMediaDownloadNotification(chapterId);
        return;
      }
      notifier.incrementRetry(chapterId);
      notifier.clearLiveProgress(chapterId);
      notifier.setPaused(chapterId, false, updateEngine: false);
      await ActiveDownloadRegistry.cancel(chapterId);
      DownloadIsolatePool.instance.cancelTask('$chapterId');
      DownloadIsolatePool.instance.cancelTask('m3u8_$chapterId');
      isar.writeTxnSync(() {
        final stored = isar.downloads.getSync(chapterId);
        if (stored != null) {
          isar.downloads.putSync(
            stored
              ..succeeded = 0
              ..failed = 0
              ..total = 1
              ..isDownload = false
              ..isStartDownload = true
              ..downloadedBytes = null
              ..totalBytes = null
              ..filePath = null
              ..status = 'fetching_metadata',
          );
        }
      });
      await notifications.cancelMediaDownloadNotification(chapterId);
      ref(processDownloadsProvider());
      break;
  }
}

/// Normalize a raw quality string to a standard label like "1080p", "720p", etc.
String _normalizeQuality(String raw) {
  final s = raw.trim().toLowerCase();
  if (s.isEmpty) return 'Qualité inconnue';

  // Already normalized
  final stdRe = RegExp(r'^(\d{3,4})[pP]');
  final m = stdRe.firstMatch(raw);
  if (m != null) return '${m.group(1)}p';

  // Common keyword mapping
  if (s.contains('4k') || s.contains('2160')) return '2160p (4K)';
  if (s.contains('1080') || s.contains('fhd') || s.contains('full hd')) return '1080p';
  if (s.contains('720') || s.contains('hd')) return '720p';
  if (s.contains('480') || s.contains('sd')) return '480p';
  if (s.contains('360')) return '360p';
  if (s.contains('240')) return '240p';
  if (s.contains('144')) return '144p';
  if (s.contains('best') || s.contains('high')) return 'Haute qualité';
  if (s.contains('low')) return 'Basse qualité';

  return raw.trim();
}

/// Returns true if a URL is a "direct" file link (mp4, webm, avi, mkv, etc.)
/// Returns false for streaming playlists (m3u8, mpd).
bool _isDirectLink(String url) {
  final lower = url.toLowerCase().split('?').first;
  const streamExts = ['.m3u8', '.mpd', '.ts'];
  for (final ext in streamExts) {
    if (lower.endsWith(ext) || lower.contains(ext)) return false;
  }
  const directExts = ['.mp4', '.webm', '.avi', '.mkv', '.flv', '.mov', '.wmv'];
  for (final ext in directExts) {
    if (lower.endsWith(ext)) return true;
  }
  // Fallback: if no known streaming ext, treat as direct
  return true;
}

/// User-chosen quality, keyed by chapter.id. Set by the quality-picker
/// dialog (showAnimeQualityPickerAndQueue). When `downloadChapter` runs
/// for an anime episode, it consults this map to honour the user's pick
/// instead of blindly downloading `videosUrls.first`.
final Map<int, String> chapterPreferredOriginalUrl = {};


/// Persist one download row per selected resolution while keeping every
/// resolution attached to the same series and episode identity.
Chapter prepareVideoQualityDownloadChapter(
  Chapter source, {
  required String quality,
  String? language,
}) {
  if (source.id == null) {
    throw StateError('Impossible de télécharger un épisode sans identifiant.');
  }
  ensureChapterLinksLoaded(source);
  final sourceManga = resolveChapterManga(source);
  final requestedKey = qualityDigits(quality);
  final requestedLang = videoLanguageOf(quality);

  // Query by the indexed `mangaId` instead of scanning every chapter row in
  // the database: this runs on the UI isolate for each episode a user queues.
  final candidates = isar.chapters
      .where()
      .mangaIdEqualTo(source.mangaId)
      .findAllSync();
  for (final candidate in candidates) {
    if (candidate.name != source.name ||
        candidate.url != source.url ||
        candidate.scanlator != source.scanlator ||
        candidate.id == null) {
      continue;
    }
    final existing = isar.downloads.getSync(candidate.id!);
    final existingQuality = existing?.quality;
    // Same resolution is not the same rendition: `720p VF` and `720p VOSTFR`
    // must land on two rows (and two files), otherwise the second download
    // reused the first chapter's row and overwrote its video.
    if (existingQuality != null &&
        qualityDigits(existingQuality) == requestedKey &&
        videoLanguageOf(existingQuality) == requestedLang) {
      chapterPreferredQuality[candidate.id!] = quality;
      if (language != null && language.isNotEmpty) {
        chapterPreferredLang[candidate.id!] = language;
      }
      return candidate;
    }
  }

  final variant = Chapter(
    id: Isar.autoIncrement,
    mangaId: source.mangaId,
    name: source.name,
    url: source.url,
    dateUpload: source.dateUpload,
    scanlator: source.scanlator,
    thumbnailUrl: source.thumbnailUrl,
    description: source.description,
    duration: source.duration,
    updatedAt: source.updatedAt,
  )..manga.value = sourceManga;
  isar.writeTxnSync(() {
    isar.chapters.putSync(variant);
  });
  final variantId = variant.id!;
  chapterPreferredQuality[variantId] = quality;
  if (language != null && language.isNotEmpty) {
    chapterPreferredLang[variantId] = language;
  }
  return variant;
}

/// Queue a selected resolution through Watchtower's normal download pipeline.
/// The queue row stores the exact quality label; the chapter clone has the
/// same manga/episode identity so all variants remain grouped together.
Future<bool> queueVideoQualityDownload({
  required ProviderContainer container,
  required Chapter chapter,
  required String quality,
  String? originalUrl,
  String? language,
}) async {
  final variant = prepareVideoQualityDownloadChapter(chapter, quality: quality, language: language);
  final id = variant.id!;
  final existing = isar.downloads.getSync(id);
  if (existing?.isDownload == true) {
    final path = existing?.filePath;
    if (path != null && path.isNotEmpty && File(path).existsSync()) {
      return false;
    }
    isar.writeTxnSync(() {
      final stored = isar.downloads.getSync(id);
      if (stored != null) {
        isar.downloads.putSync(
          stored
            ..isDownload = false
            ..isStartDownload = false
            ..status = 'failed'
            ..filePath = null,
        );
      }
    });
  }
  if (ActiveDownloadRegistry.isActive(id)) return false;

  chapterPreferredQuality[id] = quality;
  if (originalUrl != null && originalUrl.isNotEmpty) {
    chapterPreferredOriginalUrl[id] = originalUrl;
  }
  if (language != null && language.isNotEmpty) {
    chapterPreferredLang[id] = language;
  }
  await container.read(addDownloadToQueueProvider(chapter: variant).future);
  _rememberSeriesMetadata(variant);
  container.read(downloadQueueStateProvider.notifier).setPaused(id, false);
  container.read(processDownloadsProvider());
  return true;
}

String _actualDurationLabel(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
}

/// User-chosen quality label (normalized via [_normalizeQuality]), keyed by
/// chapter.id. Used by the batch download sheet: unlike
/// [chapterPreferredOriginalUrl] (a single episode's exact URL, valid only
/// for the episode it was picked from), the sheet lets the user pick one
/// quality for MANY episodes at once, and each episode has its own distinct
/// set of video URLs — so a URL from episode 1 would never match episode 5's
/// list. Matching by normalized quality label instead works across episodes.
final Map<int, String> chapterPreferredQuality = {};

/// How a missing [chapterPreferredQuality] resolution must be replaced, keyed
/// by chapter.id. Set by the batch sheet header ("prendre la supérieure" /
/// "prendre l'inférieure"); absent means the strict behaviour (fail the
/// download rather than silently grab another resolution).
final Map<int, QualityFallback> chapterPreferredQualityFallback = {};


/// User-chosen language label (e.g. 'VF', 'VOSTFR', 'EN'), keyed by
/// chapter.id. Applied by [downloadChapter] BEFORE quality matching so the
/// language pick from the batch download sheet actually filters the video
/// list of every selected episode.
final Map<int, String> chapterPreferredLang = {};

/// Show a dialog letting the user pick which quality to download for an
/// anime episode, then enqueue and start the download with that pick.
///
/// Returns `true` if a download was queued, `false` if the user
/// cancelled or nothing playable was found.
Future<bool> showAnimeQualityPickerAndQueue({
  required BuildContext context,
  required WidgetRef ref,
  required Chapter chapter,
}) async {
  // Loading indicator while fetching URLs.
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  List<Video> videos = [];
  String? errorMsg;
  try {
    final result = await ref.read(getVideoListProvider(episode: chapter).future);
    videos = result.$1;
  } catch (e) {
    errorMsg = friendlyErrorMessage(e);
  }

  if (context.mounted) Navigator.of(context, rootNavigator: true).pop();

  if (errorMsg != null) {
    if (context.mounted) botToast(errorMsg);
    return false;
  }
  if (videos.isEmpty) {
    if (context.mounted) {
      botToast('Aucun lien de téléchargement trouvé pour cet épisode.');
    }
    return false;
  }

  // De-duplicate by originalUrl.
  final seen = <String>{};
  final uniqueVideos = <Video>[];
  for (final v in videos) {
    if (seen.add(v.originalUrl)) uniqueVideos.add(v);
  }

  // Split into direct (mp4/webm) and extracted (m3u8/mpd) links.
  final directVideos = uniqueVideos.where((v) => _isDirectLink(v.originalUrl)).toList();
  final extractedVideos = uniqueVideos.where((v) => !_isDirectLink(v.originalUrl)).toList();

  if (!context.mounted) return false;

  Video? selected;
  bool sendToExternal = false;

  await showDialog(
    context: context,
    builder: (ctx) {
      final cs = Theme.of(ctx).colorScheme;
      final initialTab = directVideos.isNotEmpty ? 0 : 1;
      return DefaultTabController(
        initialIndex: initialTab,
        length: 2,
        child: Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: _QualityPickerDialog(
            directVideos: directVideos,
            extractedVideos: extractedVideos,
            preferredExternalDownloader:
                DownloadSettingsService.instance.preferredExternalDownloader ?? '',
            onSelect: (v, external) {
              selected = v;
              sendToExternal = external;
              Navigator.of(ctx).pop();
            },
            onCancel: () => Navigator.of(ctx).pop(),
          ),
        ),
      );
    },
  );

  if (selected == null) return false;

  if (sendToExternal) {
    final appId = DownloadSettingsService.instance.preferredExternalDownloader ?? '';
    final launched = await ExternalDownloaderLauncher.launch(
      url: selected!.originalUrl,
      appId: appId.isEmpty ? 'adm' : appId,
      headers: selected!.headers,
    );
    if (!launched && context.mounted) {
      botToast('Impossible d\'ouvrir le gestionnaire externe. Vérifiez qu\'il est installé.');
    }
    return launched;
  }

  if (!context.mounted) return false;
  return queueVideoQualityDownload(
    container: ProviderScope.containerOf(context, listen: false),
    chapter: chapter,
    quality: selected!.quality,
    originalUrl: selected!.originalUrl,
  );
}

// ── Quality picker dialog widget ──────────────────────────────────────────────

class _QualityPickerDialog extends StatelessWidget {
  final List<Video> directVideos;
  final List<Video> extractedVideos;
  final String preferredExternalDownloader;
  final void Function(Video v, bool external) onSelect;
  final VoidCallback onCancel;

  const _QualityPickerDialog({
    required this.directVideos,
    required this.extractedVideos,
    required this.preferredExternalDownloader,
    required this.onSelect,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
        maxWidth: 420,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              children: [
                Icon(Icons.download_rounded, color: cs.primary, size: 22),
                const SizedBox(width: 10),
                Text(
                  'Choisir la qualité',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: cs.onSurface),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Tab bar
          TabBar(
            tabs: [
              Tab(
                icon: const Icon(Icons.movie_outlined, size: 16),
                text: 'Liens directs (${directVideos.length})',
              ),
              Tab(
                icon: const Icon(Icons.stream_rounded, size: 16),
                text: 'Flux extraits (${extractedVideos.length})',
              ),
            ],
          ),
          // Tab views
          Flexible(
            child: TabBarView(
              children: [
                _VideoList(
                  videos: directVideos,
                  isDirect: true,
                  preferredExternalDownloader: preferredExternalDownloader,
                  onSelect: onSelect,
                ),
                _VideoList(
                  videos: extractedVideos,
                  isDirect: false,
                  preferredExternalDownloader: preferredExternalDownloader,
                  onSelect: onSelect,
                ),
              ],
            ),
          ),
          // Cancel footer
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [TextButton(onPressed: onCancel, child: const Text('Annuler'))],
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoList extends StatelessWidget {
  final List<Video> videos;
  final bool isDirect;
  final String preferredExternalDownloader;
  final void Function(Video v, bool external) onSelect;

  const _VideoList({
    required this.videos,
    required this.isDirect,
    required this.preferredExternalDownloader,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (videos.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isDirect ? Icons.movie_creation_outlined : Icons.stream_rounded,
              size: 44,
              color: cs.onSurfaceVariant.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 12),
            Text(
              isDirect
                  ? 'Aucun lien direct disponible\npour cet épisode'
                  : 'Aucun flux extrait disponible\npour cet épisode',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      shrinkWrap: true,
      itemCount: videos.length,
      separatorBuilder: (_, _) => Divider(height: 1, color: cs.outline.withValues(alpha: 0.15)),
      itemBuilder: (_, i) {
        final v = videos[i];
        final label = _normalizeQuality(v.quality);
        final urlClean = v.originalUrl.split('?').first;
        final ext = urlClean.split('.').last.toUpperCase();
        final isM3u8 =
            urlClean.toLowerCase().endsWith('.m3u8') ||
            v.originalUrl.toLowerCase().contains('.m3u8');

        return _VideoListTile(
          v: v,
          label: label,
          ext: ext,
          isM3u8: isM3u8,
          isDirect: isDirect,
          cs: cs,
          onSelect: onSelect,
        );
      },
    );
  }
}

class _VideoListTile extends StatefulWidget {
  final Video v;
  final String label;
  final String ext;
  final bool isM3u8;
  final bool isDirect;
  final ColorScheme cs;
  final void Function(Video v, bool external) onSelect;

  const _VideoListTile({
    required this.v,
    required this.label,
    required this.ext,
    required this.isM3u8,
    required this.isDirect,
    required this.cs,
    required this.onSelect,
  });

  @override
  State<_VideoListTile> createState() => _VideoListTileState();
}

class _VideoListTileState extends State<_VideoListTile> {
  bool _urlExpanded = false;

  void _copyUrl() {
    Clipboard.setData(ClipboardData(text: widget.v.originalUrl));
    botToast('Lien copié !');
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final extLabel = widget.isM3u8
        ? 'M3U8'
        : widget.ext.length <= 6
        ? widget.ext
        : 'STREAM';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Quality badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.label,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: cs.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Format chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: widget.isM3u8
                      ? Colors.purple.withValues(alpha: 0.15)
                      : cs.tertiaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  extLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: widget.isM3u8 ? Colors.purple.shade300 : cs.onTertiaryContainer,
                  ),
                ),
              ),
              const Spacer(),
              // Copy URL icon
              Tooltip(
                message: 'Copier le lien',
                child: InkWell(
                  onTap: _copyUrl,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(Icons.copy_rounded, size: 16, color: cs.onSurfaceVariant),
                  ),
                ),
              ),
              // Expand/collapse URL
              Tooltip(
                message: _urlExpanded ? 'Réduire' : 'Voir le lien',
                child: InkWell(
                  onTap: () => setState(() => _urlExpanded = !_urlExpanded),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      _urlExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                      size: 16,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              // Download in-app
              Tooltip(
                message: context.l10n.download_in_app,
                child: InkWell(
                  onTap: () => widget.onSelect(widget.v, false),
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(Icons.download_rounded, color: cs.primary, size: 22),
                  ),
                ),
              ),
              // Open in external downloader
              if (!kIsWeb && Platform.isAndroid)
                Tooltip(
                  message: context.l10n.download_open_external,
                  child: InkWell(
                    onTap: () => widget.onSelect(widget.v, true),
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(Icons.open_in_new_rounded, color: cs.secondary, size: 20),
                    ),
                  ),
                ),
            ],
          ),
          // URL preview (collapsible, copyable on long-press)
          AnimatedCrossFade(
            firstChild: const SizedBox(height: 0),
            secondChild: GestureDetector(
              onLongPress: _copyUrl,
              child: Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: SelectableText(
                  widget.v.originalUrl,
                  style: TextStyle(
                    fontSize: 10,
                    color: cs.onSurfaceVariant,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
            crossFadeState: _urlExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}


/// Remembers the original extension and cover next to the downloaded files.
///
/// The local import path cannot recover them from a folder once the app is
/// reinstalled, so the sidecar is what keeps the Watch covers and the real
/// provider name after a scan.
void _rememberSeriesMetadata(Chapter chapter) {
  final manga = chapter.manga.value;
  if (manga == null) return;
  var changed = false;
  if ((manga.imageUrl ?? '').isEmpty &&
      (chapter.thumbnailUrl ?? '').isNotEmpty) {
    manga.imageUrl = chapter.thumbnailUrl;
    changed = true;
  }
  if (changed) {
    try {
      isar.writeTxnSync(() => isar.mangas.putSync(manga));
    } catch (_) {}
  }
  unawaited(writeSeriesMetadata(manga));
}

/// Persist the download row and its IsarLink in the same transaction.
void _putDownloadForChapter(Download download, Chapter chapter) {
  download.chapter.value = chapter;
  isar.downloads.putSync(download);
}

const _pendingDownloadStatuses = {
  'queued',
  'waiting_wifi',
  'waiting_network',
  'fetching_metadata',
  'initializing',
  // Held by a source cooldown rather than by the user. Stays pending so the
  // scheduler resumes it automatically once the rate limit expires.
  'rate_limited',
};

const _terminalDownloadStatuses = {'paused', 'failed', 'cancelled', 'completed'};

/// Statuses that only a live worker can hold.
///
/// A row persisted with one of these while no worker owns it was interrupted
/// mid-transfer — the process was killed, or the isolate died without reaching
/// its `finally`. Such a row is not in [_pendingDownloadStatuses], so without
/// an explicit repair the scheduler never looks at it again and the queue shows
/// an animated row nothing is working on.
const _inFlightDownloadStatuses = {
  'fetching_metadata',
  'initializing',
  'downloading',
};

/// Number of interrupted-transfer repairs before a row is given up on.
const _maxOrphanRepairs = 2;

/// Requeues [download] when it was left mid-transfer by a dead process.
///
/// Returns true when the row was changed. Counters are kept so the restart
/// resumes from the saved offsets instead of re-downloading everything.
///
/// The counter is deliberately *not* persisted in `Download.failed`: the queue
/// renders any row with `failed > 0` as a red failure, so an interrupted — but
/// healthy — transfer would look broken between the repair and its restart.
bool repairOrphanedInFlightRow(
  Download download, {
  required bool isActive,
  int previousRepairs = 0,
}) {
  if (download.isDownload == true) return false;
  final status = download.status;
  if (status == null || !_inFlightDownloadStatuses.contains(status)) {
    return false;
  }
  // A registered worker may still be writing this row; only a row nobody owns
  // is an orphan.
  if (isActive) return false;
  if (previousRepairs >= _maxOrphanRepairs) {
    download
      ..status = 'failed'
      ..isStartDownload = false
      ..isDownload = false;
    return true;
  }
  download
    ..status = 'queued'
    ..isStartDownload = true
    ..isDownload = false;
  return true;
}

bool _isPendingDownload(Download download) {
  if (download.isDownload == true || _terminalDownloadStatuses.contains(download.status)) {
    return false;
  }
  return download.isStartDownload == true || _pendingDownloadStatuses.contains(download.status);
}

@riverpod
Future<void> addDownloadToQueue(Ref ref, {required Chapter chapter}) async {
  final id = chapter.id;
  AppLogger.log(
    '[ch:${id ?? "?"}] queue request received',
    logLevel: LogLevel.info,
    tag: LogTag.download,
  );
  try {
    // Do not persist a chapter without its Manga relation: Isar can otherwise
    // clear an unloaded link during put and the scheduler will skip the orphan.
    ensureChapterLinksLoaded(chapter);
    if (id == null) {
      throw StateError('Impossible de mettre en file un chapitre sans identifiant.');
    }

    Download? existing;
    var corruptRecord = false;
    try {
      existing = isar.downloads.getSync(id);
    } on RangeError {
      // The record cannot be deserialized; replace it transactionally below.
      corruptRecord = true;
    }

    if ((existing?.isDownload ?? false) || ActiveDownloadRegistry.isActive(id)) {
      AppLogger.log(
        '[ch:$id] queue request ignored: already completed or active',
        logLevel: LogLevel.debug,
        tag: LogTag.download,
      );
      return;
    }

    // New items and incomplete legacy/failed/cancelled/paused items share one
    // persistence path. A failed transaction must escape this provider so the
    // caller can report it; starting the scheduler without a stored row is a
    // false success.
    final download =
        existing ??
        Download(
          id: id,
          succeeded: 0,
          failed: 0,
          total: 1,
          isDownload: false,
          isStartDownload: true,
        );
    download
      ..isDownload = false
      ..isStartDownload = true
      ..succeeded = 0
      ..failed = 0
      ..total = 1
      ..downloadedBytes = null
      ..totalBytes = null
      ..filePath = null
      ..title = chapter.name
      ..posterUrl = chapter.thumbnailUrl ?? chapter.manga.value?.imageUrl
      ..quality = chapterPreferredQuality[id] ?? download.quality
      ..status = 'queued';

    final storedChapter = isar.chapters.getSync(id);
    final linkedChapter = storedChapter ?? chapter;
    isar.writeTxnSync(() {
      // A Download link only stores a relation to an Isar object. Some
      // extension-provided chapters reach this path before their Chapter row
      // has been persisted, which otherwise leaves the scheduler with an
      // unresolvable Download.chapter link.
      if (storedChapter == null) {
        isar.chapters.putSync(chapter);
      }
      if (corruptRecord) isar.downloads.deleteSync(id);
      _putDownloadForChapter(download, linkedChapter);
    });
    AppLogger.log(
      '[ch:$id] queued type=${chapter.manga.value?.itemType.name ?? "unknown"} '
      'source=${chapter.manga.value?.source ?? "?"} '
      'replacedCorruptRecord=$corruptRecord',
      logLevel: LogLevel.info,
      tag: LogTag.download,
    );
    // The chapter is queued again, so any reason from a previous attempt is
    // stale and must not keep showing on the row.
    if (id != null) DownloadFailureStore.instance.clear(id);
    _rememberSeriesMetadata(linkedChapter);
  } catch (error, stackTrace) {
    AppLogger.log(
      '[ch:${id ?? "?"}] queue persistence failed',
      logLevel: LogLevel.warning,
      tag: LogTag.download,
      error: error,
      stackTrace: stackTrace,
    );
    rethrow;
  }
}

@riverpod
Future<void> downloadChapter(
  Ref ref, {
  required Chapter chapter,
  bool? useWifi,
  VoidCallback? callback,
}) async {
  final keepAlive = ref.keepAlive();
  final chapterId = chapter.id;
  final mangaForRegistry = chapter.manga.value;
  final ownsActiveSlot =
      chapterId == null ||
      ActiveDownloadRegistry.tryRegisterInternal(
        chapterId,
        '$chapterId',
        itemType: mangaForRegistry?.itemType ?? ItemType.manga,
        source: mangaForRegistry?.source ?? '_unknown',
      );
  if (!ownsActiveSlot) {
    log('[downloadChapter] duplicate worker ignored chapterId=$chapterId');
    AppLogger.log(
      '[ch:$chapterId] duplicate worker ignored; another worker owns this download',
      logLevel: LogLevel.warning,
      tag: LogTag.download,
    );
    callback?.call();
    keepAlive.close();
    return;
  }
  AppLogger.log(
    '[ch:$chapterId] download worker started '
    'type=${mangaForRegistry?.itemType.name ?? "unknown"} '
    'source=${mangaForRegistry?.source ?? "?"}',
    logLevel: LogLevel.info,
    tag: LogTag.download,
  );

  // A fresh run clears any preemption flag left by a previous lowering of the
  // limits, so a later genuine failure is not mistaken for a preemption.
  if (chapterId != null) ActiveDownloadRegistry.clearPreempted(chapterId);

  try {
    // No Internet at all: pause the whole download instead of letting it run
    // into a timeout and end as a hard failure. It stays "queued" so the
    // scheduler resumes it the moment the connection is back.
    if (ConnectivityService.instance.isOffline) {
      _setDownloadStatus(chapterId, 'waiting_network');
      log('[ch:$chapterId] offline — pausing until the connection returns');
      callback?.call();
      keepAlive.close();
      return;
    }

    bool onlyOnWifi = useWifi ?? ref.read(onlyOnWifiStateProvider);
    if (onlyOnWifi) {
      final connectivity = await Connectivity().checkConnectivity();
      if (!hasWifiOrEthernet(connectivity)) {
        _setDownloadStatus(chapterId, 'waiting_wifi');
        log('[ch:$chapterId] waiting for Wi-Fi before starting');
        final context = navigatorKey.currentContext;
        if (context != null && context.mounted) {
          botToast(context.l10n.downloads_are_limited_to_wifi);
        }
        callback?.call();
        keepAlive.close();
        return;
      }
    }

    final http = MClient.init(reqcopyWith: {'useDartHttpClient': true, 'followRedirects': false});

    // ── Per-type connection settings ────────────────────────────────────────
    final mangaConnections = ref.read(mangaConnectionsStateProvider);
    final animeConnections = ref.read(animeConnectionsStateProvider);

    List<PageUrl> pageUrls = [];
    List<PageUrl> pageUrlsForCache = [];
    PageUrl? novelPage;
    List<PageUrl> pages = [];
    final StorageProvider storageProvider = StorageProvider();
    // Résolution robuste du manga EN PREMIER : `getMangaMainDirectory()` fait
    // `resolveChapterManga()` et levait auparavant un "Null check operator used
    // on a null value" (→ téléchargement marqué en échec avant même de
    // commencer) quand le lien Isar n'était pas chargé.
    final manga = resolveChapterManga(chapter);
    if (manga == null) {
      log('[downloadChapter] cannot resolve manga for chapter ${chapter.id} '
          '(mangaId=${chapter.mangaId})');
      _notifyDownloadFailure('Manga introuvable pour ce chapitre.');
      if (chapter.id != null) {
        unawaited(
          WatchtowerNotificationService.instance.markMediaDownloadFailed(
            chapter.id!,
            seriesTitle: mangaForRegistry?.name ?? chapter.name ?? '',
            chapterTitle: chapter.name ?? 'Téléchargement',
            itemType: mangaForRegistry?.itemType.name ?? ItemType.manga.name,
            coverUrl: mangaForRegistry?.imageUrl,
            source: mangaForRegistry?.source,
            lang: mangaForRegistry?.lang,
            sourceId: mangaForRegistry?.sourceId,
          ),
        );
        isar.writeTxnSync(() {
          final d = isar.downloads.getSync(chapter.id!);
          if (d != null) {
            isar.downloads.putSync(
              d
                ..failed = 1
                ..status = 'failed'
                ..isStartDownload = false,
            );
          }
        });
      }
      callback?.call();
      keepAlive.close();
      return;
    }
    // Canonical source name. The queue scheduler gates dispatching on
    // `manga.source`, so every cooldown record/clear in this worker must use
    // the same value or the gate can never match.
    final sourceName = manga.source ?? '_unknown';

    // Hard rate-limit hold. The scheduler already refuses to dispatch a
    // cooling-down source, but a forced start (retry button, notification
    // action, a queued row that survived a restart) bypasses that loop. Refuse
    // here too: park the row as rate-limited and let the scheduler auto-resume
    // it once the window expires.
    final cooldownLeft = _sourceCooldownForName(sourceName);
    if (cooldownLeft != null) {
      AppLogger.log(
        '[ch:$chapterId] source=$sourceName rate limited '
        '(${cooldownLeft.inSeconds}s left); start refused',
        logLevel: LogLevel.warning,
        tag: LogTag.download,
      );
      _markRateLimited(chapterId);
      ActiveDownloadRegistry.unregister(chapterId ?? -1);
      callback?.call();
      keepAlive.close();
      return;
    }
    // Do NOT call requestPermission() here — permission is granted during
    // onboarding. Calling it at download time shows a system dialog mid-session.
    final mangaMainDirectory = await storageProvider.getMangaMainDirectory(chapter);
    List<Track>? subtitles;
    final itemType = manga.itemType;
    final storedQuality = chapterId == null
        ? null
        : chapterPreferredQuality[chapterId] ?? isar.downloads.getSync(chapterId)?.quality;
    // One source of truth for the on-disk name (see animeMp4BaseName): the
    // downloader, the share sheet and the delete path must derive it the same
    // way, otherwise a ` [360p]`-tagged MP4 is written but never found again.
    // A null/blank title falls back to the chapter id instead of crashing on
    // `chapter.name!` with "Null check operator used on a null value".
    final chapterName = itemType == ItemType.anime
        ? animeMp4BaseName(
            chapterName: chapter.name,
            chapterId: chapter.id,
            quality: storedQuality,
          )
        : safeChapterBaseName(chapterName: chapter.name, chapterId: chapter.id);
    final chapterDirectory = (await storageProvider.getMangaChapterDirectory(
      chapter,
      mangaMainDirectory: mangaMainDirectory,
    ))!;
    final mangaManifestFile = itemType == ItemType.manga
        ? File(p.join(chapterDirectory.path, _mangaDownloadManifestName))
        : null;
    await storageProvider.createDirectorySafely(chapterDirectory.path);
    if (!await chapterDirectory.exists()) {
      throw FileSystemException(
        'Impossible de créer le dossier de téléchargement',
        chapterDirectory.path,
      );
    }
    AppLogger.log(
      '[ch:$chapterId] storage directories ready '
      'type=${manga.itemType.name}',
      logLevel: LogLevel.debug,
      tag: LogTag.download,
    );
    Map<String, String> videoHeader = {};
    Map<String, String> htmlHeader = {
      "Priority": "u=0, i",
      "User-Agent":
          "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/117.0.0.0 Safari/537.36",
    };
    bool hasM3U8File = false;
    bool nonM3U8File = false;
    M3u8Downloader? m3u8Downloader;

    // Records every URL this chapter is about to fetch, so a Cloudflare
    // refusal on one of them can route the notification ("Battre le
    // challenge") back to *this* download row (see ChallengeInbox).
    void watchChallengeUrl(String? url) {
      final id = chapter.id;
      if (id == null || url == null || url.trim().isEmpty) return;
      ChallengeInbox.instance.watch(
        chapterId: id,
        url: url,
        sourceId: manga.sourceId,
        sourceName: manga.source,
      );
    }

    // The chapter page the extension reads (e.g. the MissAV episode page): the
    // request Cloudflare refuses before any media URL is even known. A chapter
    // `url` may be an opaque token rather than a path (MKissa stores JSON), in
    // which case there is no page to open and the source base URL is used.
    final chapterSource = manga.sourceId == null
        ? null
        : getSource(manga.lang ?? '', manga.source ?? '', manga.sourceId);
    final chapterPath = chapter.url == null
        ? null
        : chapter.url!.getUrlWithoutDomain;
    final chapterPathIsUrl = chapterPath != null &&
        (chapterPath.startsWith('/') ||
            (Uri.tryParse(chapterPath)?.hasAuthority ?? false));
    final chapterPageUrl = chapterSource == null
        ? null
        : chapterPathIsUrl
        ? '${chapterSource.baseUrl}$chapterPath'
        : chapterSource.baseUrl;
    watchChallengeUrl(chapterPageUrl);

    Future<void> processConvert() async {
      await DownloadSettingsService.instance.load();
      final settings = DownloadSettingsService.instance;
      final archiveFormat = settings.mangaArchiveFormat;
      if (archiveFormat == MangaArchiveFormat.folder) return;
      for (final extension in {archiveFormat.extension, '.cbz', '.zip'}) {
        if (await File(p.join(mangaMainDirectory!.path, '${chapter.name}$extension')).exists()) {
          return;
        }
      }
      final compressionLevel = settings.mangaArchiveCompression;
      final chapterIdForProgress = chapter.id;
      try {
        final chapterNumber = ChapterRecognition().parseChapterNumber(
          manga.name ?? '',
          chapter.name ?? '',
        );
        final comicInfo = ComicInfoData(
          title: chapter.name,
          series: manga.name,
          number: chapterNumber.toString(),
          writer: manga.author,
          penciller: manga.artist,
          summary: manga.description,
          genre: manga.genre?.join(', '),
          translator: chapter.scanlator,
          publishingStatusStr: manga.status.name,
        );
        if (chapterIdForProgress != null) {
          ArchiveProgressStore.instance.set(
            chapterIdForProgress,
            done: 0,
            total: pageUrls.isEmpty ? 1 : pageUrls.length,
          );
        }
        await convertToMangaArchive(
          chapterDir: chapterDirectory.path,
          mangaDir: mangaMainDirectory!.path,
          chapterName: chapter.name!,
          pageList: List.generate(
            pageUrls.length,
            (index) => p.join(chapterDirectory.path, '${padIndex(index)}.jpg'),
          ),
          formatExtension: archiveFormat.extension,
          comicInfo: comicInfo,
          compressionLevel: compressionLevel,
          onProgress: chapterIdForProgress == null
              ? null
              : (done, total, _) {
                  ArchiveProgressStore.instance.set(chapterIdForProgress, done: done, total: total);
                },
        );
      } catch (error) {
        botToast(
          'Erreur lors de la création de l’archive manga : '
          '${friendlyErrorMessage(error)}',
        );
        rethrow;
      } finally {
        if (chapterIdForProgress != null) {
          ArchiveProgressStore.instance.clear(chapterIdForProgress);
        }
      }
    }

    // Tracks an existing non-manga resume offset. Manga resume progress is
    // rebuilt from reusable page files after the manifest scan, so its stored
    // counters must not be added a second time. -1 = not yet captured.
    var _resumeSucceededKbOffset = -1;

    // ── Speed Master: live per-download speed (MB/s) ──────────────────────
    // A sliding window over cumulative byte samples, so a single fast burst or
    // a resume offset jump cannot inflate the value shown in the queue.
    final speedMeter = SpeedMeter();
    var _speedEmaMbs = 0.0;
    var mediaCompletionNotified = false;
    var transferStatusMarked = false;
    var lastMangaBytesUpdateAt = DateTime.fromMillisecondsSinceEpoch(0);
    var lastMangaBytesCompletedUnits = -1;
    var lastLoggedProgressBucket = -1;

    Future<void> setProgress(DownloadProgress progress) async {
      final currentDownload = chapterId == null ? null : isar.downloads.getSync(chapterId);
      if (chapterId != null) ActiveDownloadRegistry.heartbeat(chapterId);
      if (currentDownload?.status == 'paused' || currentDownload?.status == 'cancelled') {
        return;
      }
      // Second pass announced: the transfer is over and the fragments are being
      // assembled + muxed. Surface it through the same golden "second pass" bar
      // the manga archive packer uses, and stop touching the transfer counters
      // (the merge event carries none).
      if (progress.isMerging) {
        if (chapter.id != null) {
          ArchiveProgressStore.instance.markIndeterminate(chapter.id!);
        }
        return;
      }
      final previousLiveProgress = chapterId == null
          ? null
          : ref.read(downloadQueueStateProvider).liveProgress[chapterId!];
      final isMangaByteProgress =
          progress.itemType == ItemType.manga && progress.downloadedBytes != null;
      var skipFrequentMangaByteEffects = false;
      if (isMangaByteProgress) {
        final now = DateTime.now();
        final pageCountAdvanced = progress.completed != lastMangaBytesCompletedUnits;
        skipFrequentMangaByteEffects =
            !progress.isCompleted &&
            !pageCountAdvanced &&
            now.difference(lastMangaBytesUpdateAt) < const Duration(milliseconds: 180);
        if (!skipFrequentMangaByteEffects) {
          lastMangaBytesUpdateAt = now;
          lastMangaBytesCompletedUnits = progress.completed;
        }
      } else if (progress.itemType == ItemType.manga) {
        lastMangaBytesCompletedUnits = progress.completed;
      }
      if (progress.total > 0) {
        final percent = (progress.completed / progress.total * 100).clamp(0, 100).toInt();
        final bucket = (percent ~/ 10) * 10;
        if (bucket >= 10 && bucket > lastLoggedProgressBucket) {
          lastLoggedProgressBucket = bucket;
          final downloadedText = progress.downloadedBytes?.toString() ?? 'inconnu';
          final totalBytesText = progress.totalBytes?.toString() ?? 'inconnu';
          final speedText = _speedEmaMbs > 0.05
              ? '${_speedEmaMbs.toStringAsFixed(1)} MB/s'
              : 'mesure en cours';
          AppLogger.log(
            '[ch:${chapter.id}] transfer progress=$bucket% '
            'units=${progress.completed}/${progress.total} '
            'bytes=$downloadedText/$totalBytesText speed=$speedText',
            logLevel: LogLevel.debug,
            tag: LogTag.download,
          );
        }
      }
      if (progress.total > 0 && AppLogger.isExtremeMode) {
        final pct =
            (progress.total > 0
                    ? (progress.completed / progress.total.clamp(1, double.infinity) * 100)
                    : 0)
                .toInt();
        AppLogger.log(
          '[ch:${chapter.id}] page ${progress.completed}/${progress.total} ($pct%) '
          '• type=${progress.itemType.name}',
          logLevel: LogLevel.debug,
          tag: LogTag.page,
        );
      }
      if (progress.isCompleted && itemType == ItemType.manga) {
        await processConvert();
      }
      if (chapterId != null) {
        final latestDownload = isar.downloads.getSync(chapterId);
        if (latestDownload?.status == 'paused' || latestDownload?.status == 'cancelled') {
          return;
        }
      }

      // ── Compute the values to store in Isar ─────────────────────────────
      // For anime: when we have real byte data, store in KB so the UI can
      // display "14 MB / 58 MB". The _formatSize helper in the queue screen
      // expects KB units (it auto-scales to MB/GB).
      // For manga: store the real page count so the UI shows "7 / 322 images".
      // We never store raw percentages — the UI derives % from succeeded/total
      // only as a last-resort fallback.
      //
      // Crash guard: une entrée Isar corrompue / une migration SQL non jouée
      // peut lever un RangeError nommé `length` lors de getSync. On attrape
      // le tout pour que la boucle ne plante pas et on repart sur des valeurs
      // propres dérivées du callback de progression (qui est toujours fiable).
      Download? download;
      int storedSucceeded = 0;
      int storedTotal = 0;
      if (chapter.id != null) {
        try {
          download = isar.downloads.getSync(chapter.id!);
          storedSucceeded = download?.succeeded ?? 0;
          storedTotal = download?.total ?? 0;
        } catch (_) {
          download = null;
        }
      }
      if (progress.itemType == ItemType.manga) {
        // Old/corrupt rows can contain byte counts or stale page counters.
        // Never treat an impossible value as a valid resume offset, and never
        // let a bogus denominator be reused as the completion page total (that
        // is what republished the ~1M "1/1048576 pages" back into Isar).
        final trustedTotal = trustedMangaPageCount(storedTotal);
        if (trustedTotal == null ||
            storedSucceeded < 0 ||
            (trustedTotal > 0 && storedSucceeded > trustedTotal) ||
            (trustedTotal <= 0 && storedSucceeded > 0)) {
          storedSucceeded = 0;
        }
        storedTotal = trustedTotal ?? 0;
      }

      final reportedDownloadedBytes = progress.itemType == ItemType.anime
          ? trustedDownloadByteCount(progress.downloadedBytes, allowZero: true)
          : null;
      final reportedTotalBytes = progress.itemType == ItemType.anime
          ? trustedDownloadByteCount(progress.totalBytes)
          : null;
      final persistedTotalBytes = progress.itemType == ItemType.anime
          ? trustedDownloadByteCount(download?.totalBytes)
          : null;
      final liveDownloadedBytes = progress.itemType == ItemType.anime
          ? reportedDownloadedBytes
          : trustedDownloadByteCount(progress.downloadedBytes, allowZero: true);
      final liveTotalBytes = progress.itemType == ItemType.anime
          ? reportedTotalBytes ?? persistedTotalBytes
          : trustedDownloadByteCount(progress.totalBytes);
      final isPerFileByteProgress = isMangaByteProgress;
      if (isPerFileByteProgress && !transferStatusMarked && chapter.id != null) {
        _setDownloadStatus(chapter.id, 'downloading');
        transferStatusMarked = true;
      }

      int isarSucceeded;
      int isarTotal;

      if (progress.itemType == ItemType.anime) {
        final dBytes = reportedDownloadedBytes;
        final tBytes = reportedTotalBytes;

        // The terminal callback used by the queue is a generic 1/1 event.
        // Never let that event replace a real video byte total already stored
        // in Isar (for example 14 MB / 140 MB).
        if (progress.isCompleted &&
            dBytes == null &&
            tBytes == null &&
            storedTotal > 500 &&
            storedTotal <= maxTrustedDownloadBytes ~/ 1024) {
          isarSucceeded = storedSucceeded;
          isarTotal = storedTotal;
        } else if (dBytes != null && tBytes != null && tBytes > 0) {
          // dBytes is cumulative, including bytes already present in .part.
          isarSucceeded = (dBytes / 1024).ceil();
          isarTotal = (tBytes / 1024).ceil();
        } else if (dBytes != null && dBytes > 0) {
          // Without a trustworthy byte total, never derive a denominator
          // from the bytes received so far.
          isarSucceeded = progress.isIndeterminate && !progress.isCompleted
              ? 0
              : (dBytes / 1024).ceil();
          isarTotal =
              progress.isCompleted &&
                  storedTotal > 500 &&
                  storedTotal <= maxTrustedDownloadBytes ~/ 1024
              ? storedTotal
              : 1;
        } else {
          // Fallback to segment count (rare — occurs before any bytes land).
          isarSucceeded = progress.completed;
          isarTotal = progress.total > 0 ? progress.total : 1;
        }
      } else {
        // The queue also emits a generic terminal 1/1 callback after all manga
        // pages have been saved. Preserve the real page total from the last
        // live update or Isar instead of replacing it with that sentinel.
        final isGenericMangaCompletion =
            progress.itemType == ItemType.manga &&
            progress.isCompleted &&
            progress.completed == 1 &&
            progress.total == 1 &&
            progress.downloadedBytes == null &&
            progress.totalBytes == null;
        final liveTotal = previousLiveProgress?.totalUnits ?? 0;
        final completionPageTotal = liveTotal > 1
            ? liveTotal
            : storedTotal > 1
            ? storedTotal
            : 0;
        if (isGenericMangaCompletion && completionPageTotal > 1) {
          isarSucceeded = completionPageTotal;
          isarTotal = completionPageTotal;
        } else {
          // Manga / novel: store real page counts.
          isarSucceeded = progress.completed;
          isarTotal = progress.total > 0 ? progress.total : 1;
        }
      }

      // Anti-overflow : ne jamais laisser succeeded dépasser total ni être
      // négatif (source classique du RangeError length quand on calcule
      // downloadedBytes/totalBytes avec un succeeded incohérent).
      if (isarSucceeded < 0) isarSucceeded = 0;
      if (isarTotal > 0 && isarSucceeded > isarTotal) {
        isarSucceeded = isarTotal;
      }
      if (isarTotal <= 0) isarTotal = 1;

      // ── Speed Master: update the live speed shown in the download queue ──
      {
        final notifier = ref.read(downloadQueueStateProvider.notifier);
        if (progress.isCompleted) {
          if (_speedEmaMbs > 0) {
            _speedEmaMbs = 0;
            speedMeter.reset();
            notifier.setSpeed(chapter.id!, 0);
          }
        } else if (progress.itemType == ItemType.anime && !progress.isCompleted) {
          final nowMs = DateTime.now().millisecondsSinceEpoch;
          // Cumulative bytes: the isolate reports the on-disk total, so a
          // resume starts at the offset instead of zero. SpeedMeter ignores a
          // backward jump rather than turning it into a negative rate.
          final bytesNow = progress.downloadedBytes ??
              (isarSucceeded > 0 ? isarSucceeded * 1024 : 0);
          _speedEmaMbs = speedMeter.sample(bytesNow, nowMs);
          notifier.setSpeed(chapter.id!, _speedEmaMbs);
        }
      }

      // ── First-tick: capture resume offset from Isar ──────────────────────
      // setProgress(0, 0, …) is called once before any real progress arrives.
      // Manga progress is based on pages verified on disk, not stale counters.
      if (_resumeSucceededKbOffset < 0) {
        final stored = storedSucceeded;
        if (progress.itemType == ItemType.manga) {
          _resumeSucceededKbOffset = 0;
        } else {
          final threshold = progress.itemType == ItemType.anime ? 500 : 1;
          _resumeSucceededKbOffset =
              stored > threshold &&
                  (progress.itemType != ItemType.anime || stored <= maxTrustedDownloadBytes ~/ 1024)
              ? stored
              : 0;
        }
      }

      // ── Resume-safe corrections for non-manga downloads ─────────────────
      // Manga callbacks are already translated to full page-list counts using
      // the current manifest scan, so neither its denominator nor numerator
      // should be frozen to stale Isar values.
      // Corrections:
      //   1. Once a meaningful total is established, freeze it completely
      //      — never allow it to grow OR shrink from a new estimate.
      //      Only the final completion signal (progress.isCompleted) may
      //      update isarTotal with the real on-disk size / page count.
      //   2. Add the already-downloaded offset to every succeeded value.
      //
      // Thresholds:
      //   • anime  → total is in KB, use >500 KB as "meaningful".
      //   • manga  → total is page count, use >1 as "meaningful" (>sentinel).
      if (download != null) {
        final storedTotal = download.total ?? 0;
        final freezeThreshold = progress.itemType == ItemType.anime ? 500 : 1;
        final hasTrustworthyAnimeTotal =
            progress.itemType != ItemType.anime ||
            reportedTotalBytes != null ||
            persistedTotalBytes != null;
        if (progress.itemType != ItemType.manga &&
            storedTotal > freezeThreshold &&
            (progress.itemType != ItemType.anime ||
                storedTotal <= maxTrustedDownloadBytes ~/ 1024) &&
            !progress.isCompleted &&
            hasTrustworthyAnimeTotal) {
          // Freeze: use stored total regardless of new estimate direction.
          isarTotal = storedTotal;
        }
        // Video byte progress is already cumulative because it is read from
        // the persistent .part file. Only add the old Isar offset for engines
        // that report units/percentages instead of cumulative bytes.
        final hasCumulativeVideoBytes =
            progress.itemType == ItemType.anime && reportedDownloadedBytes != null;
        if (_resumeSucceededKbOffset > 0 && !hasCumulativeVideoBytes) {
          isarSucceeded += _resumeSucceededKbOffset;
          if (isarSucceeded > isarTotal) isarSucceeded = isarTotal;
        }
      }

      // When progress.completed==0 AND there is no resume offset, treat as
      // "not started yet" and write 0.  But when there IS a resume offset
      // (pages/KB already on disk from a previous session), write isarSucceeded
      // (= offset alone, so the bar stays at the pre-pause position instead of
      // jumping backwards to 0 on the very first tick after resume).
      final writtenSucceeded = (progress.completed == 0 && _resumeSucceededKbOffset <= 0)
          ? 0
          : isarSucceeded;
      final exactDownloadedBytes = progress.itemType == ItemType.anime
          ? reportedDownloadedBytes ??
                (progress.isCompleted
                    ? trustedDownloadByteCount(download?.downloadedBytes, allowZero: true)
                    : null)
          : null;
      final exactTotalBytes = progress.itemType == ItemType.anime
          ? reportedTotalBytes ?? persistedTotalBytes
          : null;
      final transferStarted =
          (progress.itemType == ItemType.manga && progress.total > 0) ||
          (exactDownloadedBytes != null && exactDownloadedBytes > 0);
      final String progressStatus;
      if (progress.isCompleted) {
        progressStatus = 'completed';
      } else if (transferStarted) {
        progressStatus = 'downloading';
      } else {
        progressStatus = 'initializing';
      }
      final shouldPersistProgress =
          !isPerFileByteProgress ||
          download == null ||
          download.succeeded != writtenSucceeded ||
          download.total != isarTotal ||
          download.isDownload != progress.isCompleted ||
          download.status != progressStatus;

      if (chapter.id != null) {
        final progressNotifier = ref.read(downloadQueueStateProvider.notifier);
        if (progress.isCompleted) {
          progressNotifier.clearLiveProgress(chapter.id!);
        } else if (!skipFrequentMangaByteEffects &&
            !(progress.downloadedBytes == null &&
                progress.totalBytes == null &&
                progress.total == 0)) {
          progressNotifier.setLiveProgress(
            chapter.id!,
            DownloadLiveProgress(
              downloadedBytes: liveDownloadedBytes,
              totalBytes: liveTotalBytes,
              completedUnits: progress.itemType == ItemType.manga
                  ? writtenSucceeded
                  : progress.completed,
              totalUnits: progress.itemType == ItemType.manga ? isarTotal : progress.total,
              isIndeterminate: progress.isIndeterminate,
            ),
          );
        }
      }

      if (chapter.id == null) {
        // Pas d'ID → on ne peut rien écrire en base. On met juste à jour le
        // state Riverpod live (déjà fait plus haut) et on quitte.
      } else if (download == null) {
        if (!isPerFileByteProgress || progress.total > 0 || progress.isCompleted) {
          try {
            final newDl = Download(
              id: chapter.id,
              succeeded: writtenSucceeded,
              failed: 0,
              total: isarTotal,
              isDownload: progress.isCompleted,
              isStartDownload: true,
              downloadedBytes: exactDownloadedBytes,
              totalBytes: exactTotalBytes,
              title: chapter.name,
              quality: chapterPreferredQuality[chapter.id] ?? download?.quality,
              posterUrl: chapter.thumbnailUrl ?? chapter.manga.value?.imageUrl,
              status: progressStatus,
            );
            isar.writeTxnSync(() {
              _putDownloadForChapter(newDl, chapter);
            });
          } catch (_) {
            // Écriture avortée (entrée corrompue / verrouillage). On ne
            // fait pas planter le téléchargement : le_ui continuera d'afficher
            // la progression live de Riverpod.
          }
        }
      } else {
        final downloadNonNull = download;
        if (shouldPersistProgress && (progress.total != 0 || progress.downloadedBytes != null)) {
          try {
            isar.writeTxnSync(() {
              isar.downloads.putSync(
                downloadNonNull
                  ..succeeded = writtenSucceeded
                  ..total = isarTotal
                  ..failed = 0
                  ..isDownload = progress.isCompleted
                  ..downloadedBytes = exactDownloadedBytes
                  ..totalBytes = exactTotalBytes
                  ..title = chapter.name
                  ..quality = chapterPreferredQuality[chapter.id] ?? downloadNonNull.quality
                  ..posterUrl = chapter.thumbnailUrl ?? chapter.manga.value?.imageUrl
                  ..status = progressStatus,
              );
            });
          } catch (error) { AppLogger.log('Ignored error (download_provider.dart)', logLevel: LogLevel.debug, tag: LogTag.download, error: error); }
        }
      }

      // ── Auto-add to library when a chapter finishes downloading ──────────
      // If the parent manga/anime is not yet in the library (favorite=false),
      // add it automatically so the user can find their downloads in Library.
      if (progress.isCompleted) {
        final parentManga = chapter.manga.value;
        if (parentManga != null && parentManga.id != null && parentManga.favorite != true) {
          try {
            final mangaRecord = isar.mangas.getSync(parentManga.id!);
            if (mangaRecord != null && mangaRecord.favorite != true) {
              isar.writeTxnSync(() {
                mangaRecord.favorite = true;
                isar.mangas.putSync(mangaRecord);
              });
            }
          } catch (_) {
            // Entrée manga corrompue : on ne fait pas planter la fin du
            // téléchargement pour ça.
          }
        }
      }

      if (!progress.isCompleted && chapter.id != null && !skipFrequentMangaByteEffects) {
        // The poster and the extension that serves it must come from the same
        // record, or the card asks a hotlink-protected CDN without its headers.
        final noticeManga = resolveChapterManga(chapter) ?? chapter.manga.value;
        unawaited(
          WatchtowerNotificationService.instance.showMediaDownloadProgress(
            chapterId: chapter.id!,
            seriesTitle: noticeManga?.name ?? chapter.name ?? '',
            chapterTitle: chapter.name ?? 'Téléchargement',
            itemType: progress.itemType.name,
            completed: progress.itemType == ItemType.manga ? writtenSucceeded : progress.completed,
            total: progress.itemType == ItemType.manga ? isarTotal : progress.total,
            downloadedBytes: liveDownloadedBytes,
            totalBytes: liveTotalBytes,
            speedMbs: _speedEmaMbs,
            coverUrl: noticeManga?.imageUrl,
            source: noticeManga?.source,
            lang: noticeManga?.lang,
            sourceId: noticeManga?.sourceId,
          ),
        );
      }

      // Series name is used as the notification heading; the chapter title is
      // carried in the body. `activeCount` here is only for the anime
      // foreground-service subtitle, never a substitute for the series name.
      final chapterTitle = chapter.name?.trim().isNotEmpty == true
          ? chapter.name!.trim()
          : 'Téléchargement';
      final chapterManga = resolveChapterManga(chapter) ?? chapter.manga.value;
      final seriesTitle = chapterManga?.name?.trim().isNotEmpty == true
          ? chapterManga!.name!.trim()
          : chapterTitle;
      final notificationTitle = seriesTitle;
      if (!skipFrequentMangaByteEffects && progress.itemType == ItemType.anime) {
        final downloadedBytes =
            reportedDownloadedBytes ?? trustedDownloadBytesFromKilobytes(isarSucceeded) ?? 0;
        final notificationTotalBytes =
            reportedTotalBytes ??
            trustedDownloadBytesFromKilobytes(isarTotal > 500 ? isarTotal : null, allowZero: false);
        final hasKnownSize = notificationTotalBytes != null && notificationTotalBytes > 0;
        final progressFraction = progress.progressFraction;
        final pct = progressFraction == null
            ? -1
            : (progressFraction * 100).round().clamp(0, 100).toInt();
        final remaining = hasKnownSize
            ? (notificationTotalBytes! - downloadedBytes).clamp(0, double.infinity).toInt()
            : 0;
        final activeCount = ActiveDownloadRegistry.activeCountForType(ItemType.anime);
        final chapterTitle = chapter.name?.trim();
        final baseSubtitle = chapterTitle?.isNotEmpty == true
            ? chapterTitle!
            : 'Vidéo en cours de téléchargement';
        final segmentProgress = !hasKnownSize && progress.totalBytes == null && progress.total > 1
            ? '${progress.completed}/${progress.total} segments'
            : null;
        final notifSub = segmentProgress == null
            ? baseSubtitle
            : '$baseSubtitle · $segmentProgress';
        final etaSeconds = _speedEmaMbs >= 0.05 && hasKnownSize
            ? ((remaining / (_speedEmaMbs * 1024 * 1024)).clamp(0, double.infinity).ceil())
            : null;
        unawaited(
          BackgroundKeepAlive.update(
            count: activeCount,
            title: notificationTitle,
            progress: pct,
            subtitle: notifSub,
            downloadedBytes: downloadedBytes,
            totalBytes: notificationTotalBytes,
            speedMbs: _speedEmaMbs,
            etaSeconds: etaSeconds,
            quality: chapterPreferredQuality[chapter.id] ?? '',
            coverPath: WatchtowerNotificationService.instance.primeCoverPath(
              chapterManga?.imageUrl,
              source: chapterManga?.source,
              lang: chapterManga?.lang,
              sourceId: chapterManga?.sourceId,
            ),
            force: progress.isCompleted,
          ),
        );
      } else if (!skipFrequentMangaByteEffects) {
        final completedUnits = progress.itemType == ItemType.manga
            ? writtenSucceeded
            : progress.completed;
        final totalUnits = progress.itemType == ItemType.manga ? isarTotal : progress.total;
        final pct = totalUnits > 0
            ? ((completedUnits / totalUnits) * 100).round().clamp(0, 100).toInt()
            : -1;
        final activeCount = ActiveDownloadRegistry.activeCountForType(progress.itemType);
        final pageProgress = progress.itemType == ItemType.manga && totalUnits > 1
            ? '$completedUnits/$totalUnits pages'
            : null;
        final baseSubtitle = activeCount == 1 ? chapterTitle : '$seriesTitle · $chapterTitle';
        unawaited(
          BackgroundKeepAlive.update(
            count: activeCount,
            title: notificationTitle,
            progress: pct,
            subtitle: pageProgress == null ? baseSubtitle : '$baseSubtitle · $pageProgress',
            coverPath: WatchtowerNotificationService.instance.primeCoverPath(
              chapterManga?.imageUrl,
              source: chapterManga?.source,
              lang: chapterManga?.lang,
              sourceId: chapterManga?.sourceId,
            ),
            force: progress.isCompleted,
          ),
        );
      }

      if (progress.isCompleted && !mediaCompletionNotified && chapter.id != null) {
        mediaCompletionNotified = true;
        String? candidatePath;
        final directory = mangaMainDirectory;
        if (directory != null) {
          if (progress.itemType == ItemType.anime) {
            candidatePath = m3u8Downloader?.fileName ?? p.join(directory.path, '$chapterName.mp4');
          } else if (progress.itemType == ItemType.manga) {
            final archiveFormat = DownloadSettingsService.instance.mangaArchiveFormat;
            final extension = archiveFormat.isArchive ? archiveFormat.extension : '.cbz';
            candidatePath = p.join(directory.path, '${chapter.name}$extension');
          } else if (progress.itemType == ItemType.novel) {
            candidatePath = p.join(directory.path, '$chapterName.html');
          }
        }
        final completedPath = candidatePath != null && await File(candidatePath).exists()
            ? candidatePath
            : null;
        if (completedPath != null) {
          try {
            final actualFileBytes = await File(completedPath).length();
            final actualDuration = progress.itemType == ItemType.anime
                ? await probeActualVideoDuration(completedPath)
                : null;
            final completedRecord = isar.downloads.getSync(chapter.id!);
            if (completedRecord != null) {
              isar.writeTxnSync(() {
                isar.downloads.putSync(
                  completedRecord
                    ..filePath = completedPath
                    ..status = 'completed'
                    ..isDownload = true
                    ..downloadedBytes = actualFileBytes
                    ..totalBytes = actualFileBytes,
                );
              });
            }
            if (progress.itemType == ItemType.anime) {
              try {
                final completedChapter = isar.chapters.getSync(chapter.id!) ?? chapter;
                ensureChapterLinksLoaded(completedChapter);
                completedChapter
                  ..downloadSize = '$actualFileBytes B'
                  ..duration = actualDuration == null ? null : _actualDurationLabel(actualDuration);
                isar.writeTxnSync(() {
                  isar.chapters.putSync(completedChapter);
                });
              } catch (_) {
                // Real file bytes remain available on the Download row even
                // if a legacy chapter link cannot be reattached.
              }
            }
          } catch (_) {
            // Notification d'achèvement : on ne fait pas planter la fin du
            // téléchargement pour une entrée mal désérialisée.
          }
          if (progress.itemType == ItemType.anime) {
            // Cache the episode's comments next to the file: the comment tab
            // fetches through the extension runtime, which needs the network,
            // so a downloaded episode would otherwise show an empty tab
            // offline.
            unawaited(
              cacheEpisodeComments(
                // Must match the title the player and the comment tab use as
                // their cache key, so no trimming here.
                title: resolveChapterManga(chapter)?.name ?? chapter.name ?? '',
                chapter: chapter,
                sourceManga: resolveChapterManga(chapter),
              ),
            );
          }
        }
        unawaited(
          WatchtowerNotificationService.instance.showMediaDownloadComplete(
            title: chapter.name ?? 'Téléchargement terminé',
            seriesTitle: seriesTitle,
            itemType: progress.itemType.name,
            filePath: completedPath,
            chapterId: chapter.id!,
            completed: progress.itemType == ItemType.manga ? isarSucceeded : progress.completed,
            total: progress.itemType == ItemType.manga ? isarTotal : progress.total,
            downloadedBytes: exactDownloadedBytes,
            totalBytes: exactTotalBytes,
            speedMbs: _speedEmaMbs,
            coverUrl: chapterManga?.imageUrl,
            source: chapterManga?.source,
            lang: chapterManga?.lang,
            sourceId: chapterManga?.sourceId,
          ),
        );
      }
    }

    setProgress(DownloadProgress(0, 0, itemType));

    void savePageUrls() {
      if (ref.read(incognitoModeStateProvider)) return;
      final pageUrlsToCache = pageUrlsForCache.isNotEmpty ? pageUrlsForCache : pageUrls;
      if (pageUrlsToCache.isEmpty) return;
      try {
        final settings = readSettingsSafely(isar: isar);
        final existingEntry = (settings.chapterPageUrlsList ?? [])
            .where((element) => element.chapterId == chapter.id)
            .firstOrNull;
        if (cachedPagesUnchanged(existingEntry, pageUrls)) {
          // Même contenu que ce que getChapterPages vient d'écrire — on ne
          // réécrit pas le record (écriture interrompue = record corrompu).
          AppLogger.log(
            '[ch:${chapter.id}] page cache already up to date — skip Isar write',
            logLevel: LogLevel.debug,
            tag: LogTag.download,
          );
          return;
        }
        final protectedChapterIds = isar.downloads
            .where()
            .findAllSync()
            .where((download) => download.id != null && download.isDownload != true)
            .map((download) => download.id!)
            .toSet();
        final chapterPageUrls = mergeChapterPageurls(
          settings.chapterPageUrlsList,
          chapterId: chapter.id,
          chapterUrl: chapter.url,
          pageUrls: pageUrlsToCache,
          protectedChapterIds: protectedChapterIds,
        );
        isar.writeTxnSync(
          () => isar.settings.putSync(
            settings
              ..chapterPageUrlsList = chapterPageUrls
              ..updatedAt = DateTime.now().millisecondsSinceEpoch,
          ),
        );
      } catch (e, st) {
        AppLogger.log(
          '[ch:${chapter.id}] savePageUrls FAILED: $e',
          logLevel: LogLevel.error,
          tag: LogTag.download,
          error: e,
          stackTrace: st,
        );
        rethrow;
      }
    }

    bool isQueueActionPending() {
      final id = chapter.id;
      if (id == null) return false;
      if (ActiveDownloadRegistry.wasInterrupted(id) ||
          ref.read(downloadQueueStateProvider).pausedIds.contains(id)) {
        return true;
      }
      try {
        final status = isar.downloads.getSync(id)?.status;
        return status == 'paused' || status == 'cancelled';
      } catch (_) {
        return false;
      }
    }

    // True when a lowered simultaneous-download limit stopped this worker. The
    // engine failure paths must then requeue instead of marking the download
    // failed. Reads once and clears the flag so it cannot leak into a later run.
    bool consumePreemption() {
      final id = chapter.id;
      if (id == null) return false;
      final preempted = ActiveDownloadRegistry.wasPreempted(id);
      if (preempted) ActiveDownloadRegistry.clearPreempted(id);
      return preempted;
    }

    String? fetchError;

    if (itemType == ItemType.manga) {
      try {
        AppLogger.log(
          '[ch:${chapter.id}] fetching manga page metadata '
          'source=${manga.source ?? "?"}',
          logLevel: LogLevel.info,
          tag: LogTag.download,
        );
        final value = await ref
            .read(getChapterPagesProvider(chapter: chapter).future)
            .timeout(const Duration(seconds: 90));
        if (value.pageUrls.isNotEmpty) {
          pageUrls = value.pageUrls;
          pageUrlsForCache = value.pageUrls;
          for (final page in pageUrls) {
            watchChallengeUrl(page.url);
          }
          AppLogger.log(
            '[ch:' +
                (chapter.id?.toString() ?? '?') +
                '] ${pageUrls.length} pages fetched'
                    ' • origin[0]=' +
                (pageUrls.isNotEmpty ? safeUrlOriginForLog(pageUrls.first.url) : 'none'),
            logLevel: LogLevel.info,
            tag: LogTag.download,
          );
        } else {
          fetchError = 'getChapterPages returned empty list';
        }
      } on TimeoutException {
        fetchError = 'Fetch timed out after 90s — source returned no data';
        log('[downloadChapter] timeout after 90s for chapterId=${chapter.id}');
      } catch (e, st) {
        fetchError = friendlyErrorMessage(e);
        log('[downloadChapter][manga] getChapterPages error: $e', error: e, stackTrace: st);
      }
    } else if (itemType == ItemType.anime) {
      try {
        AppLogger.log(
          '[ch:${chapter.id}] fetching episode video metadata '
          'source=${manga.source ?? "?"}',
          logLevel: LogLevel.info,
          tag: LogTag.download,
        );
        final value = await ref
            .read(getVideoListProvider(episode: chapter).future)
            .timeout(const Duration(seconds: 90));
        // Detect HLS streams smarter: not every HLS URL ends in .m3u8
        // (e.g. xnxx CDN URLs are tokenized). We also flag a URL as HLS
        // when its host or path hints at HLS, when its quality label
        // mentions HLS, or when the explicit .m3u8 extension is present.
        bool looksLikeHls(dynamic v) {
          final u = (v.originalUrl ?? '').toString().toLowerCase();
          if (u.endsWith('.m3u8') || u.endsWith('.m3u')) return true;
          if (u.contains('.m3u8') ||
              u.contains('/hls/') ||
              u.contains('hls-cdn') ||
              u.contains('hls.'))
            return true;
          // An explicit progressive extension wins over a generic "Auto"
          // label: extensions commonly label a plain mp4 "Auto", and routing
          // it to the segment downloader produced a few-KB invalid file.
          if ((v.originalUrl ?? '').toString().isMediaVideo()) return false;
          final q = (v.quality ?? '').toString().toLowerCase();
          if (q.contains('hls') || q.contains('auto')) return true;
          return false;
        }

        // A URL that is neither an HLS manifest nor a recognised media file
        // (a tokenised CDN link, say) is far more likely a stream than a
        // progressive file, so it keeps the HLS pipeline rather than being
        // discarded as "no playable URL".
        bool isPlayableDirect(dynamic v) =>
            !looksLikeHls(v) && (v.originalUrl ?? '').toString().isMediaVideo();

        final nonM3u8Urls = value.$1.where(isPlayableDirect).toList();
        final m3u8Urls = value.$1.where((v) => !isPlayableDirect(v)).toList();
        nonM3U8File = nonM3u8Urls.isNotEmpty;
        hasM3U8File = nonM3U8File ? false : m3u8Urls.isNotEmpty;
        var videosUrls = nonM3U8File ? nonM3u8Urls : m3u8Urls;
        // Honour the user's quality pick from the picker dialog (if any):
        // move the chosen Video to the front of the list so that
        // `videosUrls.first` below picks it.
        final preferredOriginal = chapter.id != null
            ? chapterPreferredOriginalUrl[chapter.id!]
            : null;
        if (preferredOriginal != null && videosUrls.isNotEmpty) {
          final idx = videosUrls.indexWhere((v) => v.originalUrl == preferredOriginal);
          if (idx > 0) {
            final picked = videosUrls.removeAt(idx);
            videosUrls = [picked, ...videosUrls];
          }
          // One-shot: clear so a future re-download asks again.
          chapterPreferredOriginalUrl.remove(chapter.id!);
        }
        // Batch download sheet: language chosen by label (see
        // [chapterPreferredLang]). Filter FIRST so a multi-lang source never
        // silently downloads the wrong audio track.
        final preferredLang = chapter.id != null ? chapterPreferredLang[chapter.id!] : null;
        if (preferredLang != null && videosUrls.length > 1) {
          final langMatches = videosUrls
              .where(
                (v) =>
                    v.quality.toUpperCase().contains(preferredLang.toUpperCase()) ||
                    (v.audios ?? const []).any(
                      (track) =>
                          (track.label ?? '').toUpperCase().contains(preferredLang.toUpperCase()),
                    ),
              )
              .toList();
          if (langMatches.isNotEmpty) videosUrls = langMatches;
          // One-shot: clear so a future re-download asks again.
          chapterPreferredLang.remove(chapter.id!);
        }
        // Batch download sheet: quality chosen by label (see chapterPreferredQuality
        // doc) since it applies across many episodes that each have their own URLs.
        // STRICT match by default: when the requested resolution exists in this
        // episode's list we download ONLY it — previously a missing match
        // silently fell back to the first entry (often 1080p/auto), so a user
        // asking for 360p could end up with a 1 GB file. The batch header can
        // opt into "prendre la supérieure/inférieure" instead.
        //
        // The match runs against EVERY format the episode publishes, not only
        // the pool the pipeline would have preferred: XVideos answers 360p and
        // 720p as HLS renditions next to one direct "MP4 SD", and picking 360p
        // used to fail with "résolution indisponible" because the direct pool
        // holds no 360p at all. The chosen entry then decides the pipeline.
        final preferredQuality = chapter.id != null
            ? chapterPreferredQuality[chapter.id!] ?? isar.downloads.getSync(chapter.id!)?.quality
            : null;
        final preferredQualityDigits = preferredQuality == null
            ? null
            : qualityDigits(preferredQuality);
        if (preferredQuality != null && value.$1.isNotEmpty) {
          final allVideos = value.$1;
          final fallback = chapter.id == null
              ? QualityFallback.exact
              : chapterPreferredQualityFallback[chapter.id!] ?? QualityFallback.exact;
          final chosen = selectPreferredVideo(
            videos: allVideos,
            preferredQuality: preferredQuality,
            fallback: fallback,
            preferredPool: videosUrls,
          );
          if (chosen == null) {
            throw StateError(
              'La résolution ${preferredQuality} n’est pas disponible pour '
              'cet épisode (formats : ${allVideos.map((v) => v.quality).join(", ")}).',
            );
          }
          videosUrls = [chosen];
          // The pick decides how the stream is fetched: an HLS rendition goes
          // through the segment downloader even when a direct file exists.
          final chosenIsDirect = isPlayableDirect(chosen);
          nonM3U8File = chosenIsDirect;
          hasM3U8File = !chosenIsDirect;
          // One-shot: clear so a future re-download asks again.
          chapterPreferredQuality.remove(chapter.id!);
          chapterPreferredQualityFallback.remove(chapter.id!);
        }
        if (videosUrls.isNotEmpty) {
          // A rendition picked from the expanded master carries no subtitle
          // list of its own (the master names them), so fall back to the first
          // entry that does instead of downloading without subtitles.
          subtitles = videosUrls.first.subtitles;
          if (subtitles == null || subtitles.isEmpty) {
            for (final video in value.$1) {
              final candidate = video.subtitles;
              if (candidate != null && candidate.isNotEmpty) {
                subtitles = candidate;
                break;
              }
            }
          }
          final videoUri = Uri.tryParse(videosUrls.first.originalUrl);
          final referer = videoUri != null ? '${videoUri.scheme}://${videoUri.host}' : null;
          if (hasM3U8File) {
            watchChallengeUrl(videosUrls.first.url);
            pageUrlsForCache = [PageUrl(videosUrls.first.url, headers: videosUrls.first.headers)];
            m3u8Downloader = M3u8Downloader(
              m3u8Url: videosUrls.first.url,
              downloadDir: chapterDirectory.path,
              headers: videosUrls.first.headers ?? {},
              subtitles: subtitles,
              fileName: p.join(mangaMainDirectory!.path, "$chapterName.mp4"),
              chapter: chapter,
              refererUrl: referer,
              sourceId: manga.sourceId,
              concurrentDownloads: animeConnections,
            );
          } else {
            watchChallengeUrl(videosUrls.first.url);
            pageUrls = [PageUrl(videosUrls.first.url)];
            pageUrlsForCache = [PageUrl(videosUrls.first.url, headers: videosUrls.first.headers)];
          }
          videoHeader.addAll(videosUrls.first.headers ?? {});
        } else {
          fetchError = 'getVideoList returned no playable URLs';
        }
      } on TimeoutException {
        fetchError = 'Fetch timed out after 90s — source returned no data';
        log('[downloadChapter] timeout after 90s for chapterId=${chapter.id}');
      } catch (e, st) {
        fetchError = friendlyErrorMessage(e);
        log('[downloadChapter][anime] getVideoList error: $e', error: e, stackTrace: st);
      }
    } else if (itemType == ItemType.novel && chapter.url != null) {
      final novelManga = chapter.manga.value;
      if (novelManga == null) {
        log('[downloadChapter][novel] missing manga link for chapterId=${chapter.id}');
        throw StateError('Manga introuvable pour ce chapitre.');
      }
      final source = getSource(novelManga.lang!, novelManga.source!, novelManga.sourceId)!;
      final chapterUrl = "${source.baseUrl}${chapter.url!.getUrlWithoutDomain}";
      final cookie = MClient.getCookiesPref(chapterUrl);
      final headers = htmlHeader;
      if (cookie.isNotEmpty) {
        try {
          final settings = readSettingsSafely(isar: isar);
          final userAgent = settings.userAgent;
          if (userAgent != null) {
            headers.addAll(cookie);
            headers[HttpHeaders.userAgentHeader] = userAgent;
          }
        } catch (_) {
          // Settings corrompues : on continue sans user-agent.
        }
      }
      final res = await http.get(Uri.parse(chapterUrl), headers: headers);
      if (res.headers.containsKey("Location")) {
        novelPage = PageUrl(res.headers["Location"]!);
      } else {
        novelPage = PageUrl(chapterUrl);
      }
      pageUrlsForCache = [novelPage!];
    }

    // If the fetch failed (exception, empty result, or timeout), mark failed and abort.
    if (fetchError != null) {
      if (itemType == ItemType.manga) {
        ref.invalidate(getChapterPagesProvider(chapter: chapter));
      } else if (itemType == ItemType.anime) {
        ref.invalidate(getVideoListProvider(episode: chapter));
      }
      AppLogger.log(
        '[ch:' + (chapter.id?.toString() ?? '?') + '] FETCH ERROR: $fetchError',
        logLevel: LogLevel.error,
        tag: LogTag.download,
      );
      log('[downloadChapter] aborting — fetch error: $fetchError');
      // A rate-limited extension refuses the *metadata* call (getChapterPages /
      // getVideoList), before any page URL exists. Without recording the
      // cooldown here, the queue fed the throttled source the next chapter on
      // the very next tick — which is why chapter ~20 onwards all failed while
      // the first ones succeeded. pageUrls is empty at this point, so the key
      // is the source name, which is exactly what the scheduler checks.
      _recordHostCooldownFromError(
        fetchError!,
        source: sourceName,
        pageUrls: pageUrls,
      );
      // Rendre l'échec visible : sinon l'icône revenait à son état initial et
      // l'utilisateur croyait que le bouton n'avait rien fait.
      _notifyDownloadFailure(fetchError!);
      // Route the "Battre le challenge" notification back to this download so
      // the queue opens on this row with the inline bypass panel — but only
      // when the failure is actually a Cloudflare refusal. Recording every
      // failure force-opened the panel (and its "Battre le challenge" retry)
      // on downloads that failed for an unrelated reason (expired URL, empty
      // getVideoList, unsupported extension), where the panel correctly showed
      // no challenge and the retry just failed again.
      final challengeUrl =
          chapterPageUrl ??
          (pageUrls.isNotEmpty ? pageUrls.first.url : null) ??
          (pageUrlsForCache.isNotEmpty ? pageUrlsForCache.first.url : null);
      if (chapter.id != null &&
          challengeUrl != null &&
          isCloudflareError(fetchError)) {
        ChallengeInbox.instance.record(
          chapterId: chapter.id!,
          url: challengeUrl,
          sourceId: manga.sourceId,
          sourceName: manga.source,
        );
      }
      // A rate-limited row is waiting, not broken: don't fire the "download
      // failed" notification for it, or a long batch would spam one per chapter.
      final rateLimited = _isRateLimitError(fetchError);
      if (chapter.id != null && !rateLimited) {
        unawaited(
          WatchtowerNotificationService.instance.markMediaDownloadFailed(
            chapter.id!,
            seriesTitle: manga.name ?? chapter.name ?? '',
            chapterTitle: chapter.name ?? 'Téléchargement',
            itemType: itemType.name,
            coverUrl: manga.imageUrl,
            source: manga.source,
            lang: manga.lang,
            sourceId: manga.sourceId,
          ),
        );
      }
      // Parking a rate-limited source as 'failed' made it terminal, so the
      // queue dropped it and only a manual retry could bring it back. Keep it
      // pending as 'rate_limited' instead: the scheduler skips it while the
      // cooldown lasts and picks it up by itself afterwards.
      // Use writeTxnSync + getSync/putSync — never mix sync ops inside
      // async writeTxn; that nests an implicit read-txn inside the write-txn
      // and causes "Cannot perform this operation from within an active
      // transaction" on some Isar versions, which then propagates to the
      // outer catch and results in a double-crash log.
      isar.writeTxnSync(() {
        try {
          final dl = isar.downloads.getSync(chapter.id!);
          if (dl != null) {
            isar.downloads.putSync(
              dl
                ..failed = (dl.failed ?? 0) + (rateLimited ? 0 : 1)
                ..isDownload = false
                ..status = rateLimited ? 'rate_limited' : 'failed'
                // Stop processDownloads from re-queuing this chapter on every
                // 900ms tick.  The user can retry manually from the queue UI.
                ..isStartDownload = !rateLimited,
            );
          }
        } catch (_) {
          // Entrée corrompue : on ne fait pas planter le téléchargement,
          // on laisse le bloc extérieur gérer l'échec.
        }
      });
      // CRITICAL: release processDownloads slot so the next queued
      // download can start — without this, one extension failure blocks
      // the entire download queue forever ("en attente" bug).
      callback?.call();
      keepAlive.close();
      return;
    }

    // Store recovered URLs and headers before directory preparation or
    // transfer work so a forced stop does not discard the resume metadata.
    savePageUrls();

    // ── Pause check after async URL fetch ────────────────────────────────────
    // If the user paused while we were fetching URLs (getChapterPages /
    // getVideoList can take several seconds), honour it before preparing pages.
    // The pool also checks the pause state after initialization, covering a
    // pause that arrives between this check and task submission.
    if (isQueueActionPending()) {
      // Unregister so processDownloads sees this chapter as idle and can
      // re-pick it the moment the user taps resume.
      ActiveDownloadRegistry.unregister(chapter.id!);
      callback?.call();
      keepAlive.close();
      return;
    }

    // Metadata has resolved successfully. Show preparation/transfer setup
    // from this point rather than leaving a queued item labelled as metadata.
    if (chapterId != null && (pageUrls.isNotEmpty || novelPage != null || m3u8Downloader != null)) {
      _setDownloadStatus(chapterId, 'initializing');
    }

    AppLogger.log(
      '[ch:${chapter.id}] metadata resolved type=${itemType.name} '
      'sources=${pageUrls.length} hasHls=$hasM3U8File directVideo=$nonM3U8File',
      logLevel: LogLevel.info,
      tag: LogTag.download,
    );

    if (pageUrls.isNotEmpty) {
      await DownloadSettingsService.instance.load();
      final archiveFormat = DownloadSettingsService.instance.mangaArchiveFormat;
      var archiveFileExist = false;
      if (archiveFormat != MangaArchiveFormat.folder) {
        for (final extension in {archiveFormat.extension, '.cbz', '.zip'}) {
          if (await File(p.join(mangaMainDirectory!.path, '${chapter.name}$extension')).exists()) {
            archiveFileExist = true;
            break;
          }
        }
      }
      bool mp4FileExist = await File(p.join(mangaMainDirectory!.path, "$chapterName.mp4")).exists();
      bool htmlFileExist = await File(
        p.join(mangaMainDirectory!.path, "$chapterName.html"),
      ).exists();
      AppLogger.log(
        '[ch:${chapter.id}] archiveExists=$archiveFileExist '
        'mp4Exists=$mp4FileExist '
        'htmlExists=$htmlFileExist dir=${mangaMainDirectory!.path}',
        logLevel: LogLevel.debug,
        tag: LogTag.download,
      );
      final manifestPages = <PageUrl>[];
      final manifestFilePaths = <String>[];
      final manifestCompleted = <bool>[];
      var mangaCompletedPagesOnDisk = 0;
      final pendingMangaPaths = <String>{};
      MangaDownloadManifest? activeManifest = mangaManifestFile == null
          ? null
          : await _readMangaDownloadManifest(mangaManifestFile);

      Future<void> buildPendingPages() async {
        pages.clear();
        manifestPages.clear();
        manifestFilePaths.clear();
        manifestCompleted.clear();
        pendingMangaPaths.clear();
        for (var index = 0; index < pageUrls.length; index++) {
          final page = pageUrls[index];
          final cookies = MClient.getCookiesPref(page.url, sourceId: manga.sourceId);
          final baseHeaders = itemType == ItemType.manga
              ? ref.read(
                  headersProvider(
                    source: manga.source!,
                    lang: manga.lang!,
                    sourceId: manga.sourceId,
                  ),
                )
              : itemType == ItemType.anime
              ? videoHeader
              : htmlHeader;
          final pageHeaders = Map<String, String>.from(baseHeaders);

          String? headerValue(Map<String, String> values, String name) {
            for (final entry in values.entries) {
              if (entry.key.toLowerCase() == name.toLowerCase()) {
                return entry.value;
              }
            }
            return null;
          }

          final baseCookie = headerValue(pageHeaders, HttpHeaders.cookieHeader);
          final storedCookie = cookies[HttpHeaders.cookieHeader];
          pageHeaders.removeWhere((key, _) => key.toLowerCase() == HttpHeaders.cookieHeader);
          final mergedCookie = MClient.mergeCookieHeaders(baseCookie, storedCookie);
          if (mergedCookie != null) {
            pageHeaders[HttpHeaders.cookieHeader] = mergedCookie;
          }

          final extensionUserAgent = MClient.extensionUserAgentForRequests(
            sourceId: manga.sourceId,
          );
          if (extensionUserAgent?.isNotEmpty == true &&
              !pageHeaders.keys.any((key) => key.toLowerCase() == HttpHeaders.userAgentHeader)) {
            pageHeaders[HttpHeaders.userAgentHeader] = extensionUserAgent!;
          }

          String? pageCookie;
          for (final entry in page.headers?.entries ?? const <MapEntry<String, String>>[]) {
            if (entry.key.toLowerCase() == HttpHeaders.cookieHeader) {
              pageCookie = entry.value;
            } else {
              pageHeaders[entry.key] = entry.value;
            }
          }
          final finalCookie = MClient.mergeCookieHeaders(
            headerValue(pageHeaders, HttpHeaders.cookieHeader),
            pageCookie,
          );
          pageHeaders.removeWhere((key, _) => key.toLowerCase() == HttpHeaders.cookieHeader);
          if (finalCookie != null) {
            pageHeaders[HttpHeaders.cookieHeader] = finalCookie;
          }

          if (itemType == ItemType.manga) {
            final filePath = p.join(chapterDirectory.path, '${padIndex(index)}.jpg');
            final complete = await isReusableDownloadedImage(File(filePath));
            manifestPages.add(PageUrl(page.url.trim(), headers: pageHeaders));
            manifestFilePaths.add(filePath);
            manifestCompleted.add(complete);
            if (!complete) {
              pendingMangaPaths.add(filePath);
              pages.add(PageUrl(page.url.trim(), headers: pageHeaders, fileName: filePath));
            }
          } else if (itemType == ItemType.anime) {
            final file = File(p.join(mangaMainDirectory!.path, '$chapterName.mp4'));
            if (!file.existsSync()) {
              pages.add(
                PageUrl(
                  page.url.trim(),
                  headers: pageHeaders,
                  fileName: p.join(mangaMainDirectory!.path, '$chapterName.mp4'),
                ),
              );
            }
          }
        }
        mangaCompletedPagesOnDisk = manifestCompleted.where((isComplete) => isComplete).length;
      }

      Future<void> reconcileAndPersistMangaManifest({
        bool markDownloading = false,
        bool markFailed = false,
        Object? failure,
      }) async {
        if (mangaManifestFile == null || manifestPages.isEmpty) return;
        activeManifest = reconcileMangaDownloadManifest(
          chapterUrl: chapter.url,
          pages: manifestPages,
          filePaths: manifestFilePaths,
          completed: manifestCompleted,
          chapterId: chapter.id,
          mangaId: chapter.mangaId,
          extensionId: manga.sourceId?.toString(),
          sourceId: manga.sourceId,
          chapterMetadata: {
            'chapterName': chapter.name,
            'chapterDate': chapter.dateUpload,
            'scanlator': chapter.scanlator,
            'seriesName': manga.name,
            'sourceName': manga.source,
            'language': manga.lang,
          },
          previous: activeManifest,
        );
        final current = activeManifest!;
        final updatedPages = <MangaDownloadPage>[];
        final now = DateTime.now().millisecondsSinceEpoch;
        for (final page in current.pages) {
          final complete = await isReusableDownloadedImage(File(page.filePath));
          final pending = pendingMangaPaths.contains(page.filePath);
          final failed = markFailed && pending && !complete;
          final starting = markDownloading && pending && !complete;
          final state = complete
              ? MangaPageState.completed
              : failed
              ? MangaPageState.failed
              : starting
              ? MangaPageState.downloading
              : MangaPageState.pending;
          updatedPages.add(
            page.copyWith(
              state: state,
              attempts: page.attempts + (starting ? 1 : 0),
              lastError: failed && failure != null ? _safeManifestFailure(failure) : null,
              clearLastError: complete || starting,
              updatedAt: now,
            ),
          );
        }
        activeManifest = MangaDownloadManifest(
          chapterId: current.chapterId,
          mangaId: current.mangaId,
          extensionId: current.extensionId,
          sourceId: current.sourceId,
          chapterMetadata: current.chapterMetadata,
          chapterUrl: current.chapterUrl,
          pages: updatedPages,
          createdAt: current.createdAt,
          updatedAt: now,
        );
        await _writeMangaDownloadManifest(mangaManifestFile, activeManifest!);
      }

      if (!archiveFileExist && itemType == ItemType.manga ||
          !mp4FileExist && itemType == ItemType.anime ||
          !htmlFileExist && itemType == ItemType.novel) {
        final mainDirectoryRaw = await storageProvider.getDirectory();
        if (mainDirectoryRaw == null) {
          AppLogger.log(
            '[ch:${chapter.id}] ERROR: getDirectory() returned null — check storage permission',
            logLevel: LogLevel.error,
            tag: LogTag.download,
          );
          throw StateError('getDirectory() returned null for chapterId=${chapter.id}');
        }
        final mainDirectory = mainDirectoryRaw;
        AppLogger.log(
          '[ch:${chapter.id}] storage dir: ${mainDirectory.path}',
          logLevel: LogLevel.debug,
          tag: LogTag.download,
        );
        storageProvider.createDirectorySafely(mainDirectory.path);
        if (!kIsWeb && Platform.isAndroid) {
          final marker = File(p.join(mainDirectory.path, '.nomedia'));
          if (!await marker.exists()) await marker.create();
        }
        await buildPendingPages();
        await reconcileAndPersistMangaManifest();
      }

      AppLogger.log(
        '[ch:${chapter.id}] pages to dl: ${pages.length}/${pageUrls.length} '
        '(${pageUrls.length - pages.length} already on disk)',
        logLevel: LogLevel.info,
        tag: LogTag.download,
      );
      final pausedDuringPreparation = isQueueActionPending();
      if (pausedDuringPreparation) {
        AppLogger.log(
          '[ch:${chapter.id}] pause/cancel honored after page scan',
          logLevel: LogLevel.info,
          tag: LogTag.download,
        );
      } else if (itemType == ItemType.manga && pageUrls.isNotEmpty) {
        // Restore the full denominator and verified on-disk page count before
        // downloading only the missing subset.
        await setProgress(DownloadProgress(mangaCompletedPagesOnDisk, pageUrls.length, itemType));
      }
      if (!pausedDuringPreparation && pages.isEmpty && pageUrls.isNotEmpty) {
        AppLogger.log(
          '[ch:${chapter.id}] all pages already on disk → marking complete',
          logLevel: LogLevel.info,
          tag: LogTag.download,
        );
        if (itemType == ItemType.manga) {
          await reconcileAndPersistMangaManifest();
        }
        await setProgress(DownloadProgress(1, 1, itemType, isCompleted: true));
      } else if (!pausedDuringPreparation) {
        if (chapter.id != null) {
          ref.read(downloadQueueStateProvider.notifier).setEngine(chapter.id!, 'ATLAS');
        }
        AppLogger.log(
          '[ch:' +
              (chapter.id?.toString() ?? '?') +
              '] START ${pages.length} imgs → ' +
              itemType.name,
          logLevel: LogLevel.info,
          tag: LogTag.download,
        );
        log('[downloadChapter][manga] starting ${pages.length} pages chapterId=${chapter.id}');
        try {
          if (itemType == ItemType.manga) {
            _setDownloadStatus(chapterId, 'downloading');
            await reconcileAndPersistMangaManifest(markDownloading: true);
          }
          Future<void> runPageTransfer() =>
              MDownloader(
                chapter: chapter,
                pageUrls: pages,
                subtitles: subtitles,
                subDownloadDir: chapterDirectory.path,
                concurrentDownloads: mangaConnections,
                shouldCancel: isQueueActionPending,
                chapterPageCount: pageUrls.length,
              ).download((progress) {
                final visibleProgress =
                    itemType == ItemType.manga && !progress.isCompleted && progress.total > 0
                    ? DownloadProgress(
                        (mangaCompletedPagesOnDisk + progress.completed)
                            .clamp(0, pageUrls.length)
                            .toInt(),
                        pageUrls.length,
                        progress.itemType,
                        pageUrl: progress.pageUrl,
                        isIndeterminate: progress.isIndeterminate,
                        downloadedBytes: progress.downloadedBytes,
                        totalBytes: progress.totalBytes,
                      )
                    : progress;
                setProgress(visibleProgress);
              });
          try {
            await runPageTransfer();
          } catch (transferError) {
            if (itemType != ItemType.manga || !_isRefreshablePageUrlError(transferError)) {
              rethrow;
            }

            // Signed image URLs can expire while a chapter is queued. Drop
            // the cached list so getPageList can supply fresh URLs/headers,
            // then retry only pages that are still missing.
            final latestSettings = readSettingsSafely(isar: isar);
            latestSettings.chapterPageUrlsList = (latestSettings.chapterPageUrlsList ?? [])
                .where((entry) => entry.chapterId != chapter.id)
                .toList();
            isar.writeTxnSync(() => isar.settings.putSync(latestSettings));
            ref.invalidate(getChapterPagesProvider(chapter: chapter));
            final refreshed = await ref
                .read(getChapterPagesProvider(chapter: chapter).future)
                .timeout(const Duration(seconds: 90));
            if (refreshed.pageUrls.isEmpty) rethrow;

            pageUrls = refreshed.pageUrls;
            pageUrlsForCache = refreshed.pageUrls;
            savePageUrls();
            await buildPendingPages();
            await reconcileAndPersistMangaManifest(markDownloading: true);
            if (pages.isNotEmpty && !isQueueActionPending()) {
              await runPageTransfer();
            }
          }
          if (itemType == ItemType.manga) {
            await reconcileAndPersistMangaManifest();
          }
          final interruptedByQueueAction =
              chapter.id != null && ActiveDownloadRegistry.wasInterrupted(chapter.id!);
          // CRITICAL: MDownloader's onComplete fires onProgress(isCompleted=true)
          // inside a void callback that is NOT awaited.  setProgress is async
          // (it calls processConvert / CBZ conversion before the Isar write),
          // so isDownload=true may NOT be in Isar by the time download() returns.
          // The next processDownloads tick (900 ms) then finds the chapter still
          // with isDownload=false → re-queues it → second dispatch causes a
          // "nested transaction" crash on the extension timeout.
          // Fix: explicitly await a final setProgress here, guaranteed to finish
          // before callback?.call() unblocks processDownloads.  The double-call
          // is idempotent (processConvert skips if the archive already exists).
          if (!interruptedByQueueAction) {
            await setProgress(DownloadProgress(1, 1, itemType, isCompleted: true));
            // A full chapter landed, so the source is serving us again: clear
            // any cooldown so the rest of the batch is not held back needlessly.
            _clearHostCooldown(sourceName, pageUrls: pageUrls);
            if (chapter.id != null) {
              DownloadFailureStore.instance.clear(chapter.id!);
            }
            AppLogger.log(
              '[ch:' + (chapter.id?.toString() ?? '?') + '] COMPLETE ✓',
              logLevel: LogLevel.info,
              tag: LogTag.download,
            );
            log('[downloadChapter][manga] completed chapterId=${chapter.id}');
          }
        } catch (e) {
          if (itemType == ItemType.manga) {
            // A preempted chapter must not be recorded as failed: it is queued
            // again and will resume as soon as a slot frees up.
            final preempted =
                chapter.id != null && ActiveDownloadRegistry.wasPreempted(chapter.id!);
            await reconcileAndPersistMangaManifest(
              markFailed: !preempted,
              failure: preempted ? null : e,
            );
          }
          _recordHostCooldownFromError(e, source: sourceName, pageUrls: pageUrls);
          log(
            '[downloadChapter][manga] FAILED chapterId=${chapter.id} '
            'errorType=${e.runtimeType}',
          );
          rethrow;
        } finally {
          if (chapter.id != null) {
            ActiveDownloadRegistry.unregister(chapter.id!);
          }
        }
      }
    } else if (itemType == ItemType.novel) {
      final file = File(p.join(chapterDirectory.path, "$chapterName.html"));
      log(
        '[downloadChapter][novel] target exists=${file.existsSync()} '
        'hasSource=${novelPage != null}',
      );
      if (!file.existsSync() && novelPage != null) {
        final source = getSource(manga.lang!, manga.source!, manga.sourceId)!;
        log('[downloadChapter][novel] calling getHtmlContent');
        try {
          final html = await withExtensionService(
            source,
            (service) => service.getHtmlContent(
              chapter.manga.value?.name ?? manga.name ?? '',
              chapter.url!,
            ),
          );
          log('[downloadChapter][novel] getHtmlContent returned ${html.length} chars');
          if (html.isNotEmpty) {
            await file.writeAsString(html);
            log('[downloadChapter][novel] HTML saved');
            await setProgress(DownloadProgress(1, 1, itemType, isCompleted: true));
          } else {
            log(
              '[downloadChapter][novel] ERROR: getHtmlContent returned empty '
              'string for chapterId=${chapter.id}',
            );
            // Mark as failed so the user can retry
            try {
              final dl = isar.downloads.getSync(chapter.id!);
              if (dl != null) {
                isar.writeTxnSync(() {
                  isar.downloads.putSync(
                    dl
                      ..failed = 1
                      ..status = 'failed'
                      ..isStartDownload = false,
                  );
                });
              }
            } catch (error) { AppLogger.log('Ignored error (download_provider.dart)', logLevel: LogLevel.debug, tag: LogTag.download, error: error); }
          }
        } catch (e, st) {
          log('[downloadChapter][novel] EXCEPTION in getHtmlContent: $e\n$st');
          try {
            final dl = isar.downloads.getSync(chapter.id!);
            if (dl != null) {
              isar.writeTxnSync(() {
                isar.downloads.putSync(
                  dl
                    ..failed = 1
                    ..status = 'failed'
                    ..isStartDownload = false,
                );
              });
            }
          } catch (error) { AppLogger.log('Ignored error (download_provider.dart)', logLevel: LogLevel.debug, tag: LogTag.download, error: error); }
        }
      } else if (file.existsSync()) {
        log('[downloadChapter][novel] file already exists, marking complete');
        await setProgress(DownloadProgress(1, 1, itemType, isCompleted: true));
      } else {
        log(
          '[downloadChapter][novel] no source available for '
          'chapterId=${chapter.id}',
        );
        try {
          final dl = isar.downloads.getSync(chapter.id!);
          if (dl != null) {
            isar.writeTxnSync(() {
              isar.downloads.putSync(
                dl
                  ..failed = 1
                  ..status = 'failed'
                  ..isStartDownload = false,
              );
            });
          }
        } catch (error) { AppLogger.log('Ignored error (download_provider.dart)', logLevel: LogLevel.debug, tag: LogTag.download, error: error); }
      }
    } else if (hasM3U8File && m3u8Downloader != null) {
      // ── Engine selection ────────────────────────────────────────────────
      await DownloadSettingsService.instance.load();
      final downloadMode = DownloadSettingsService.instance.animeDownloadMode;
      final videoUrl = m3u8Downloader!.m3u8Url;

      final engine = EngineSelector.select(url: videoUrl, itemType: itemType, mode: downloadMode);

      log(
        '[downloadChapter][anime] engine=${engine.badgeLabel} '
        'origin=${safeUrlOriginForLog(videoUrl)}',
      );
      if (chapter.id != null) {
        ref.read(downloadQueueStateProvider.notifier).setEngine(chapter.id!, engine.badgeLabel);
      }

      if (engine == SelectedEngine.aria2 || engine == SelectedEngine.zeus) {
        // ── Aria2 / ZeusDL path ─────────────────────────────────────────
        final isZeus = engine == SelectedEngine.zeus;
        log('[downloadChapter][anime/${isZeus ? 'Zeus' : 'Aria2'}] starting chapterId=${chapter.id}');
        final DownloadEngine activeEngine = isZeus
            ? ZeusEngine(
                url: videoUrl,
                outputPath: m3u8Downloader!.fileName,
                headers: m3u8Downloader!.headers ?? {},
                itemType: itemType,
                chapterId: '${chapter.id}',
                params: ZeusParams(
                  url: videoUrl,
                  quality: null,
                  audioOnly: itemType == ItemType.music,
                ),
              )
            : Aria2Engine(
                url: videoUrl,
                outputPath: m3u8Downloader!.fileName,
                headers: m3u8Downloader!.headers ?? {},
                itemType: itemType,
                chapterId: '${chapter.id}',
              );
        if (chapter.id != null) {
          ActiveDownloadRegistry.registerEngine(
            chapter.id!,
            activeEngine,
            itemType: itemType,
            source: manga.source ?? '_unknown',
          );
        }
        bool engineFailed = false;
        bool enginePreempted = false;
        try {
          await activeEngine.start((progress) => setProgress(progress));
          log('[downloadChapter][anime/${isZeus ? 'Zeus' : 'Aria2'}] completed chapterId=${chapter.id}');
        } catch (e) {
          enginePreempted = consumePreemption();
          engineFailed = !enginePreempted;
          log('[downloadChapter][anime/${isZeus ? 'Zeus' : 'Aria2'}] '
              '${enginePreempted ? 'preempted' : 'FAILED'} chapterId=${chapter.id} error=$e');
        } finally {
          if (chapter.id != null) {
            ActiveDownloadRegistry.unregister(chapter.id!);
          }
        }
        // Aria2 finishes a cancelled process without throwing, so re-check the
        // flag here as well as in the catch.
        enginePreempted = enginePreempted || consumePreemption();
        if (enginePreempted) {
          // A lowered limit stopped this download on purpose: it is already back
          // in the queue, so skip the HLS fallback and let the next tick resume.
          callback?.call();
          keepAlive.close();
          return;
        }
        // Aria2 and ZeusDL cannot do HLS — fall back to internal HLS for
        // .m3u8 streams (and for any extractor failure).
        if (engineFailed) {
          log(
            '[downloadChapter][anime/${isZeus ? 'Zeus' : 'Aria2'}→HLS] falling back to internal HLS chapterId=${chapter.id}',
          );
          if (chapter.id != null) {
            ref.read(downloadQueueStateProvider.notifier).setEngine(chapter.id!, 'HLS');
          }
          final taskId = 'm3u8_${chapter.id}';
          if (chapter.id != null) {
            ActiveDownloadRegistry.registerInternal(
              chapter.id!,
              taskId,
              itemType: itemType,
              source: manga.source ?? '_unknown',
            );
          }
          try {
            await m3u8Downloader!.download((progress) => setProgress(progress));
          } finally {
            if (chapter.id != null) {
              ActiveDownloadRegistry.unregister(chapter.id!);
              // Drop the golden second-pass bar whether the merge succeeded or
              // failed; a failure must not leave it running forever.
              ArchiveProgressStore.instance.clear(chapter.id!);
            }
          }
        }
      } else {
        // ── Internal HLS path ───────────────────────────────────────────
        log('[downloadChapter][anime/HLS] starting chapterId=${chapter.id}');
        final taskId = 'm3u8_${chapter.id}';
        if (chapter.id != null) {
          ActiveDownloadRegistry.registerInternal(
            chapter.id!,
            taskId,
            itemType: itemType,
            source: manga.source ?? '_unknown',
          );
        }

        Object? caughtError;
        try {
          await m3u8Downloader!.download((progress) => setProgress(progress));
          if (consumePreemption()) {
            // A cancelled HLS task completes without throwing; detect it here so
            // the episode is not logged as completed and re-queued on next tick.
            log('[downloadChapter][anime/HLS] preempted chapterId=${chapter.id}');
            callback?.call();
            keepAlive.close();
            return;
          }
          log('[downloadChapter][anime/HLS] completed chapterId=${chapter.id}');
        } catch (e) {
          if (consumePreemption()) {
            log('[downloadChapter][anime/HLS] preempted chapterId=${chapter.id}');
            callback?.call();
            keepAlive.close();
            return;
          }
          caughtError = e;
          log(
            '[downloadChapter][anime/HLS] FAILED chapterId=${chapter.id} '
            'error=$e',
          );
        } finally {
          if (chapter.id != null) {
            ActiveDownloadRegistry.unregister(chapter.id!);
            // The HLS path may have announced the golden second pass; clear it
            // before the FFmpeg fallback re-drives progress.
            ArchiveProgressStore.instance.clear(chapter.id!);
          }
        }

        // ── FFmpeg transport fallback ───────────────────────────────────
        // Some CDNs (Surrit behind MissAV) refuse both the isolate downloader
        // and the in-page browser replay while the same stream plays in the
        // bundled player. Both go through FFmpeg's HTTP stack, so hand the
        // whole playlist to FFmpeg before declaring failure.
        if (caughtError != null && chapter.id != null) {
          log(
            '[downloadChapter][anime/HLS→FFmpeg] retrying chapterId=${chapter.id}',
          );
          final ffmpegEngine = FfmpegHlsEngine(
            url: videoUrl,
            outputPath: m3u8Downloader.fileName,
            headers: m3u8Downloader.headers ?? {},
            itemType: itemType,
            chapterId: '${chapter.id}',
          );
          ref
              .read(downloadQueueStateProvider.notifier)
              .setEngine(chapter.id!, 'FFMPEG');
          ActiveDownloadRegistry.registerEngine(
            chapter.id!,
            ffmpegEngine,
            itemType: itemType,
            source: manga.source ?? '_unknown',
          );
          try {
            await ffmpegEngine.start((progress) => setProgress(progress));
            caughtError = null;
            log(
              '[downloadChapter][anime/FFmpeg] completed chapterId=${chapter.id}',
            );
          } catch (e) {
            if (consumePreemption()) {
              log('[downloadChapter][anime/FFmpeg] preempted chapterId=${chapter.id}');
              callback?.call();
              keepAlive.close();
              return;
            }
            caughtError = e;
            log(
              '[downloadChapter][anime/FFmpeg] FAILED chapterId=${chapter.id} '
              'error=$e',
            );
          } finally {
            ActiveDownloadRegistry.unregister(chapter.id!);
          }
        }

        if (caughtError != null) {
          // Mark the Isar record as failed so the UI can offer retry.
          log('[downloadChapter][anime/HLS→fail] chapterId=${chapter.id}');
          try {
            final dl = isar.downloads.getSync(chapter.id!);
            if (dl != null) {
              isar.writeTxnSync(() {
                // isStartDownload=false stops processDownloads from
                // re-queueing this broken episode every 900ms tick.
                isar.downloads.putSync(
                  dl
                    ..failed = 1
                    ..status = 'failed'
                    ..isStartDownload = false,
                );
              });
            }
          } catch (error) { AppLogger.log('Ignored error (download_provider.dart)', logLevel: LogLevel.debug, tag: LogTag.download, error: error); }
          throw caughtError;
        }
      }
    }

    callback?.call();
    keepAlive.close();
  } catch (e, st) {
    // A lowered limit stopped this worker on purpose. The row was already put
    // back in the queue by [_preemptDownload]; marking it failed here would
    // drop it from the queue and lose the download the user still wants.
    if (chapter.id != null && ActiveDownloadRegistry.wasPreempted(chapter.id!)) {
      log('[downloadChapter] preempted chapterId=${chapter.id}: keeping it queued');
      callback?.call();
      keepAlive.close();
      return;
    }
    // Always fire the callback even on error so processDownloads can unblock
    // its slot counter and exit cleanly instead of looping forever.
    log('[downloadChapter] UNCAUGHT ERROR chapterId=${chapter.id}: $e\n$st');
    final friendly = friendlyErrorMessage(e);
    _notifyDownloadFailure(friendly);
    // Persist the reason per chapter: the toast above is shown once and is
    // dropped outright when no Overlay is live, which is the normal case for a
    // background batch. Without this the queue showed a red row with no reason.
    if (chapter.id != null) {
      DownloadFailureStore.instance.set(
        chapter.id!,
        DownloadFailure(
          message: friendly,
          at: DateTime.now(),
          partial: e is DownloadPoolFailure && e.isPartial,
          failedPages: e is DownloadPoolFailure ? e.failedCount : 0,
          totalPages: e is DownloadPoolFailure ? e.totalCount : 0,
        ),
      );
    }
    AppLogger.log('[ch:${chapter.id}] CRASH: $e', logLevel: LogLevel.error, tag: LogTag.download);
    // Mark as failed so processDownloads does NOT re-queue endlessly.
    // Without this, any uncaught exception leaves the chapter as
    // isDownload=false + isStartDownload=true in Isar → infinite retry loop.
    if (chapter.id != null) {
      // A rate limit is a temporary "come back later", not a broken chapter:
      // park it as rate_limited so the scheduler resumes it once the cooldown
      // expires, instead of dropping it until the user retries by hand.
      final rateLimited = _isRateLimitError(e);
      if (!rateLimited) {
        unawaited(
          WatchtowerNotificationService.instance.markMediaDownloadFailed(
            chapter.id!,
            seriesTitle: mangaForRegistry?.name ?? chapter.name ?? '',
            chapterTitle: chapter.name ?? 'Téléchargement',
            itemType: mangaForRegistry?.itemType.name ?? ItemType.manga.name,
            coverUrl: mangaForRegistry?.imageUrl,
            source: mangaForRegistry?.source,
            lang: mangaForRegistry?.lang,
            sourceId: mangaForRegistry?.sourceId,
          ),
        );
      }
      try {
        final dl = isar.downloads.getSync(chapter.id!);
        if (dl != null) {
          isar.writeTxnSync(() {
            isar.downloads.putSync(
              dl
                ..failed = rateLimited ? (dl.failed ?? 0) : 1
                ..isDownload = false
                ..status = rateLimited ? 'rate_limited' : 'failed'
                // Stop infinite retry — leave isStartDownload=false so
                // processDownloads skips this chapter until user retries.
                // A rate-limited row is the exception: it must stay startable
                // so the scheduler picks it up when the cooldown lifts.
                ..isStartDownload = rateLimited,
            );
          });
        }
      } catch (error) { AppLogger.log('Ignored error (download_provider.dart)', logLevel: LogLevel.debug, tag: LogTag.download, error: error); }
    }
    callback?.call();
    keepAlive.close();
  } finally {
    // Always clean up the registry entry so the chapter is no longer seen
    // as "active" after this function exits (success, failure, or timeout).
    if (chapterId != null && ownsActiveSlot) {
      ActiveDownloadRegistry.unregister(chapterId);
    }
  }
}

/// Stops a running download because a lowered simultaneous-download limit put
/// it over budget, and leaves it ready to be re-dispatched.
///
/// The row is put back in the queue (`queued`, still startable) *before* the
/// worker is cancelled. The worker treats the interruption as a pause
/// ([ActiveDownloadRegistry.wasInterrupted]) and exits without marking the
/// download failed or complete, so the next tick resumes it from its partial
/// `.part` / on-disk pages instead of restarting from zero.
Future<void> _preemptDownload(int downloadId) async {
  try {
    isar.writeTxnSync(() {
      final stored = isar.downloads.getSync(downloadId);
      if (stored == null || stored.isDownload == true) return;
      isar.downloads.putSync(
        stored
          ..isDownload = false
          ..isStartDownload = true
          ..status = 'queued',
      );
    });
  } catch (_) {
    // A corrupt row must not abort the preemption of the others.
  }
  AppLogger.log(
    '[ch:$downloadId] preempted by a lowered simultaneous-download limit; '
    'returned to the queue',
    logLevel: LogLevel.info,
    tag: LogTag.download,
  );
  ActiveDownloadRegistry.markPreempted(downloadId);
  await ActiveDownloadRegistry.preempt(downloadId);
}

@riverpod
Future<void> processDownloads(Ref ref, {bool? useWifi}) async {
  if (useWifi != null) _processDownloadsWifiOverride = useWifi;
  if (_processDownloadsSchedulerRunning) {
    log('[processDownloads] coalesced duplicate scheduler request');
    return;
  }
  _processDownloadsSchedulerRunning = true;
  // Keep this provider alive so it can run for the full duration of the queue.
  final keepAlive = ref.keepAlive();
  final loggedConcurrencyBlocks = <int>{};
  final loggedCooldowns = <int>{};
  // Per-chapter count of "process died mid-transfer" repairs, so a chapter that
  // kills the app on every attempt ends up failed instead of looping.
  final orphanRepairs = <int, int>{};
  // Chapters whose legacy isStartDownload flag was already repaired in this
  // scheduler session. Keeps a long-waiting queue from re-writing (and
  // re-logging) the same rows on every tick.
  final restoredPendingIds = <int>{};
  var isFirstTick = true;
  String? lastQueueWaitState;
  // Resume the queue as soon as the connection comes back: reset the rows the
  // offline gate parked so the next tick dispatches them, instead of leaving
  // them stuck and re-hitting a dead network every 900 ms.
  final connectivitySub = ConnectivityService.instance.onChanged.listen((online) {
    if (!online) return;
    log('[processDownloads] connection restored — resuming parked downloads');
    try {
      final parked = isar.downloads
          .where()
          .findAllSync()
          .where((d) => d.status == 'waiting_network')
          .toList();
      if (parked.isEmpty) return;
      isar.writeTxnSync(() {
        for (final d in parked) {
          final stored = isar.downloads.getSync(d.id!);
          if (stored == null || stored.status != 'waiting_network') continue;
          stored
            ..status = 'queued'
            ..isDownload = false
            ..isStartDownload = true;
          isar.downloads.putSync(stored);
        }
      });
    } catch (e) {
      log('[processDownloads] could not resume parked downloads: $e');
    }
  });
  log('[processDownloads] scheduler started');

  /// Stops the workers that exceed the limits *as soon as* the user lowers
  /// "simultaneous", instead of waiting for the next tick.
  ///
  /// The scheduler only re-evaluates every 900 ms and, more importantly, used
  /// to leave the extra downloads running until they finished, so going from 7
  /// to 3 kept seven downloads alive. This pass reads the freshly saved limits
  /// (the settings map is already updated in memory when the save wakes us) and
  /// preempts the newest over-budget workers on the spot. Raising a limit needs
  /// nothing here: the wakeup makes the next tick dispatch the extra items.
  void applyLoweredLimitsNow() {
    try {
      final service = DownloadSettingsService.instance;
      final typeMax = <ItemType, int>{
        ItemType.manga: service.mangaSimultaneous,
        ItemType.anime: service.watchSimultaneous,
        ItemType.novel: service.novelSimultaneous,
        ItemType.music: service.musicSimultaneous,
        ItemType.game: service.gameSimultaneous,
      };
      final typePerSrcMax = <ItemType, int>{
        ItemType.manga: service.mangaSimultaneousPerSource,
        ItemType.anime: service.watchSimultaneousPerSource,
        ItemType.novel: service.novelSimultaneousPerSource,
        ItemType.music: service.musicSimultaneousPerSource,
        ItemType.game: service.gameSimultaneousPerSource,
      };
      final slotsByType = <ItemType, List<ActiveSlot>>{};
      for (final id in ActiveDownloadRegistry.allActiveIds) {
        final type = ActiveDownloadRegistry.activeTypeOf(id);
        if (type == null) continue;
        (slotsByType[type] ??= <ActiveSlot>[]).add(
          ActiveSlot(
            downloadId: id,
            source: ActiveDownloadRegistry.activeSourceOf(id) ?? '_unknown',
            preempted: ActiveDownloadRegistry.wasPreempted(id),
          ),
        );
      }
      for (final entry in slotsByType.entries) {
        final toPreempt = selectPreemptions(
          slots: entry.value,
          total: typeMax[entry.key] ?? 2,
          perSourceCap: typePerSrcMax[entry.key] ?? 2,
        );
        for (final id in toPreempt) {
          unawaited(_preemptDownload(id));
        }
      }
    } catch (e) {
      // A settings or registry hiccup must not break the queue: the next tick
      // performs the same pass with the same values.
      log('[processDownloads] immediate limit pass failed: $e');
    }
  }

  registerDownloadLimitApplier(applyLoweredLimitsNow);
  // Acquire wakelock + start Android foreground service so the OS does not
  // kill the process while downloads are running in the background.
  unawaited(BackgroundKeepAlive.start());
  try {
    // Un tick qui plante (lecture Isar corrompue → `RangeError (length)`,
    // settings illisibles, …) ne doit JAMAIS tuer la file d'attente : avant,
    // l'exception remontait jusqu'à runZonedGuarded, la boucle mourait et le
    // bouton télécharger ne faisait plus rien. On avale, on tente de réparer
    // les enregistrements illisibles (projection d'IDs = pas de désérialisation),
    // et le tick suivant reprend.
    Future<bool> safeTick(Future<bool> Function() body) async {
      try {
        return await body();
      } catch (e, st) {
        log('[processDownloads] tick error (ignored, next tick retries): $e\n$st');
        try {
          final ids = (await isar.downloads.where().idProperty().findAll()).whereType<int>();
          for (final id in ids) {
            try {
              isar.downloads.getSync(id);
            } on RangeError {
              // Enregistrement Download illisible → on le supprime pour que
              // findAllSync / watch fonctionnent à nouveau (re-téléchargeable).
              isar.writeTxnSync(() => isar.downloads.deleteSync(id));
              log('[processDownloads] purged corrupt download record id=$id');
            }
          }
        } catch (_) {
          // La réparation elle-même peut échouer : on retentera au tick suivant.
        }
        return true;
      }
    }

    await Future.doWhile(() async {
      // Poll interval — short enough to feel snappy, long enough not to thrash.
      // A queue-settings change (total / per-source) completes the registered
      // completer so the new limits are evaluated on the spot instead of on the
      // next poll.
      final wakeup = Completer<void>();
      registerDownloadQueueWakeup(wakeup);
      await Future.any([
        Future<void>.delayed(const Duration(milliseconds: 900)),
        wakeup.future,
      ]);
      clearDownloadQueueWakeup(wakeup);
      return safeTick(() async {
        // Offline: do not launch workers (they would only fail) and back off to
        // a slower poll. The connectivity listener re-queues parked rows and
        // the queue resumes the moment the connection is back.
        if (ConnectivityService.instance.isOffline) {
          for (final download in isar.downloads.where().findAllSync()) {
            if (download.id != null &&
                _pendingDownloadStatuses.contains(download.status) &&
                download.status != 'waiting_network') {
              _setDownloadStatus(download.id, 'waiting_network');
            }
          }
          await Future.delayed(const Duration(seconds: 2));
          return true;
        }
        // ── Re-query Isar fresh every tick ────────────────────────────────────
        // This is the key fix: we never take a snapshot of the queue.  Paused
        // chapters that are later resumed, newly added downloads, and completed
        // downloads are all naturally handled because we look at the live DB
        // state on every iteration instead of a stale list built at startup.
        // isar_community rejects filters on these nullable bool properties at
        // runtime ("Property does not support this filter"). Read the
        // collection and apply the same predicate in Dart.
        final ongoingRaw = isar.downloads.where().findAllSync().where(_isPendingDownload).toList();

        // Release registry entries whose worker died without unregistering.
        // A paused/cancelled worker is kept registered until its own `finally`
        // runs; if that never happens the chapter is skipped forever and the
        // queue silently stalls on one row.
        final reaped = ActiveDownloadRegistry.reapGhosts();
        for (final id in reaped) {
          AppLogger.log(
            '[ch:$id] worker stopped reporting; released its queue slot',
            logLevel: LogLevel.warning,
            tag: LogTag.download,
          );
        }

        // Rows left mid-transfer by a process that died are not pending, so
        // without this pass they would never run again: the queue shows an
        // animated row that nothing is working on. Requeue them (offsets kept)
        // so the batch resumes on its own when the app comes back.
        //
        // Scanning every row on every tick would be wasteful, so the full pass
        // runs once when the scheduler starts and afterwards only when the
        // reaper actually released a slot — the only way a new orphan can
        // appear while this loop is alive.
        if (isFirstTick || reaped.isNotEmpty) {
          final orphans = <int>[];
          try {
            isar.writeTxnSync(() {
              for (final row in isar.downloads.where().findAllSync()) {
                final id = row.id;
                if (id == null) continue;
                final repaired = repairOrphanedInFlightRow(
                  row,
                  isActive: ActiveDownloadRegistry.isActive(id),
                  previousRepairs: orphanRepairs[id] ?? 0,
                );
                if (!repaired) continue;
                orphanRepairs[id] = (orphanRepairs[id] ?? 0) + 1;
                isar.downloads.putSync(row);
                orphans.add(id);
              }
            });
          } catch (_) {
            // A corrupt row must not abort the whole scheduler tick.
          }
          for (final id in orphans) {
            AppLogger.log(
              '[ch:$id] transfer was interrupted by a process stop; '
              'requeued to resume from its saved offsets',
              logLevel: LogLevel.warning,
              tag: LogTag.download,
            );
          }
        }
        isFirstTick = false;

        final stalePendingRows = <Download>[];
        for (final dl in ongoingRaw) {
          // Older pause/resume paths could leave a durable "queued" status with
          // isStartDownload=false. Repair the flags before dispatch so the queue
          // remains recoverable if the app is closed again.
          //
          // The repair runs once per row per scheduler session: a row that
          // waits a long time for a slot used to be re-flagged, re-written and
          // re-logged on every 900 ms tick, which produced >100k warning lines
          // per day and one Isar write transaction per queued row per tick.
          if (dl.id != null && !restoredPendingIds.contains(dl.id!)) {
            if (dl.isStartDownload != true &&
                _pendingDownloadStatuses.contains(dl.status) &&
                !ActiveDownloadRegistry.isActive(dl.id!)) {
              var restored = false;
              var shouldDispatch = false;
              isar.writeTxnSync(() {
                final stored = isar.downloads.getSync(dl.id!);
                if (stored != null &&
                    stored.isDownload != true &&
                    _pendingDownloadStatuses.contains(stored.status)) {
                  shouldDispatch = true;
                  if (stored.isStartDownload != true) {
                    restored = true;
                    stored
                      ..isDownload = false
                      ..isStartDownload = true;
                    isar.downloads.putSync(stored);
                  }
                }
              });
              if (!shouldDispatch) {
                stalePendingRows.add(dl);
                continue;
              }
              dl
                ..isDownload = false
                ..isStartDownload = true;
              if (restored) {
                restoredPendingIds.add(dl.id!);
                AppLogger.log(
                  '[ch:${dl.id}] restored pending state from status=${dl.status}',
                  logLevel: LogLevel.warning,
                  tag: LogTag.download,
                );
              }
            }
          }

          try {
            if (!dl.chapter.isLoaded) dl.chapter.loadSync();
          } catch (_) {
            // If the IsarLink is unreadable, try its stable chapter ID below.
          }
          var ch = dl.chapter.value;
          if (ch == null && dl.id != null) {
            try {
              ch = isar.chapters.getSync(dl.id!);
            } catch (_) {
              // Fall through to a visible failed state below.
            }
            if (ch != null) {
              final recoveredChapter = ch;
              dl.chapter.value = recoveredChapter;
              isar.writeTxnSync(() {
                final stored = isar.downloads.getSync(dl.id!);
                if (stored != null) {
                  stored.chapter.value = recoveredChapter;
                  isar.downloads.putSync(stored);
                }
              });
              AppLogger.log(
                '[ch:${dl.id}] repaired missing Download.chapter link',
                logLevel: LogLevel.warning,
                tag: LogTag.download,
              );
            }
          }
          if (ch == null) {
            final missingId = dl.id;
            AppLogger.log(
              '[ch:${missingId ?? "?"}] queued row has no chapter record; '
              'marking it failed',
              logLevel: LogLevel.warning,
              tag: LogTag.download,
            );
            if (missingId != null) {
              isar.writeTxnSync(() {
                final stored = isar.downloads.getSync(missingId);
                if (stored != null && stored.isDownload != true) {
                  stored
                    ..failed = (stored.failed ?? 0) + 1
                    ..isStartDownload = false
                    ..status = 'failed';
                  isar.downloads.putSync(stored);
                }
              });
            }
            continue;
          }
          // Relation chapitre → manga : on la charge, et si le lien est vide
          // (effacé par un ancien `put` sur un lien non chargé) on la
          // reconstruit depuis mangaId pour ne jamais perdre l'entrée.
          if (!ch.manga.isLoaded && ch.mangaId != null) {
            try {
              ch.manga.loadSync();
            } catch (error) { AppLogger.log('Ignored error (download_provider.dart)', logLevel: LogLevel.debug, tag: LogTag.download, error: error); }
          }
          if (ch.manga.value == null && ch.mangaId != null) {
            try {
              final manga = isar.mangas.getSync(ch.mangaId!);
              if (manga != null) ch.manga.value = manga;
            } catch (_) {
              // Manga corrompu : on laisse le champ null, le chapitre sera
              // ignoré plus tard dans la boucle (ch == null ? continue).
            }
          }
        }

        ongoingRaw.removeWhere(stalePendingRows.contains);
        final pausedIds = ref.read(downloadQueueStateProvider).pausedIds;

        // Items that are waiting to start:
        //   - not paused in the UI
        //   - not currently registered in the ActiveDownloadRegistry (i.e. not
        //     already running inside an isolate or external engine)
        final toStart = ongoingRaw.where((d) {
          final chId = d.chapter.value?.id;
          if (chId == null) return false; // orphaned record — skip
          return !pausedIds.contains(chId) && !ActiveDownloadRegistry.isActive(chId);
        }).toList();
        if (ongoingRaw.isNotEmpty && toStart.isEmpty) {
          final pausedCount = ongoingRaw
              .where((d) => pausedIds.contains(d.chapter.value?.id))
              .length;
          final activeCount = ongoingRaw
              .where((d) => ActiveDownloadRegistry.isActive(d.chapter.value?.id ?? -1))
              .length;
          final waitState = 'pending=${ongoingRaw.length} paused=$pausedCount active=$activeCount';
          if (waitState != lastQueueWaitState) {
            log('[processDownloads] no eligible item: $waitState');
            lastQueueWaitState = waitState;
          }
        } else {
          lastQueueWaitState = null;
        }

        // ── Speed Master: high-priority downloads start first ────────────────
        // `List.sort` is not stable beyond 32 elements, so a plain sort by
        // priority shuffled equal-priority rows and started a 30-chapter queue
        // at chapter 21 instead of chapter 1. Decorate with the original index
        // and use it as the tie-breaker to keep the FIFO (chapter) order.
        // Re-read every tick so toggling priority in the queue UI applies
        // immediately without restarting the scheduler.
        //
        // The list comes from `findAllSync()`, whose order is storage order, so
        // the index alone cannot guarantee chapter order: compare the chapter
        // labels naturally instead (Chapitre 2 before Chapitre 10, and chapter 1
        // first), which is what makes a bulk manga download start at the
        // beginning rather than at chapter 23.
        final prioMap = ref.read(downloadQueueStateProvider).priorities;
        final ordered = orderByPriorityDescending(
          toStart,
          priorityOf: (d) => prioMap[d.chapter.value?.id ?? -1] ?? 0,
          compare: (a, b) => compareChapterLabels(
            a.chapter.value?.name,
            b.chapter.value?.name,
          ),
        );
        toStart
          ..clear()
          ..addAll(ordered);

        final effectiveUseWifi =
            _processDownloadsWifiOverride ??
            (useWifi ?? (ref.read(onlyOnWifiStateProvider) == true));
        final onlyOnWifi = effectiveUseWifi;
        if (onlyOnWifi && toStart.isNotEmpty) {
          bool isOnWifi = false;
          try {
            isOnWifi = hasWifiOrEthernet(await Connectivity().checkConnectivity());
          } catch (e) {
            log('[processDownloads] connectivity check failed: $e');
          }
          if (!isOnWifi) {
            for (final download in toStart) {
              _setDownloadStatus(download.id, 'waiting_wifi');
            }
            log('[processDownloads] ${toStart.length} item(s) waiting for Wi-Fi');
            // Keep the persisted queue alive, but do not launch and immediately
            // re-launch a worker on every short scheduler tick.
            await Future.delayed(const Duration(seconds: 5));
            return true;
          }
          for (final download in toStart) {
            if (download.status == 'waiting_wifi') {
              _setDownloadStatus(download.id, 'queued');
            }
          }
        }

        // Exit when nothing is waiting AND nothing is running.
        if (toStart.isEmpty && !ActiveDownloadRegistry.hasActive) {
          log('[processDownloads] queue drained — stopping');
          return false;
        }

        // ── Re-read limits every tick so settings changes apply immediately ───
        // IMPORTANT: always load() first — the provider build() methods call
        // load() without await (synchronous context), so they return the cached
        // default values on the first build.  Reading directly from the service
        // after awaiting load() guarantees the user's persisted settings are used.
        await DownloadSettingsService.instance.load();
        final typeMax = <ItemType, int>{
          ItemType.manga: DownloadSettingsService.instance.mangaSimultaneous,
          ItemType.anime: DownloadSettingsService.instance.watchSimultaneous,
          ItemType.novel: DownloadSettingsService.instance.novelSimultaneous,
          ItemType.music: DownloadSettingsService.instance.musicSimultaneous,
          ItemType.game: DownloadSettingsService.instance.gameSimultaneous,
        };
        final typePerSrcMax = <ItemType, int>{
          ItemType.manga: DownloadSettingsService.instance.mangaSimultaneousPerSource,
          ItemType.anime: DownloadSettingsService.instance.watchSimultaneousPerSource,
          ItemType.novel: DownloadSettingsService.instance.novelSimultaneousPerSource,
          ItemType.music: DownloadSettingsService.instance.musicSimultaneousPerSource,
          ItemType.game: DownloadSettingsService.instance.gameSimultaneousPerSource,
        };

        // ── Start downloads that fit within the limits ─────────────────────────
        // The per-type "Total" is a budget shared by the sources that still have
        // pending work: the source with the fewest items gets the largest share
        // (see [allocateSourceSlots]). "Src" is an additional per-source cap.
        //
        // Per-source workload (queued + already running) per type, so a share
        // covers both the slots a source uses and the ones it still needs.
        // A worker that was already preempted is only draining: it no longer
        // occupies a slot, so counting it would shrink the budget of the source
        // it belongs to and preempt even more work.
        final pendingByType = <ItemType, Map<String, int>>{};
        for (final d in toStart) {
          final manga = d.chapter.value?.manga.value;
          final type = manga?.itemType ?? ItemType.manga;
          final src = manga?.source ?? '_unknown';
          final bySource = pendingByType[type] ??= <String, int>{};
          bySource[src] = (bySource[src] ?? 0) + 1;
        }
        for (final id in ActiveDownloadRegistry.allActiveIds) {
          final type = ActiveDownloadRegistry.activeTypeOf(id);
          if (type == null) continue;
          if (ActiveDownloadRegistry.wasPreempted(id)) continue;
          final src = ActiveDownloadRegistry.activeSourceOf(id) ?? '_unknown';
          final bySource = pendingByType[type] ??= <String, int>{};
          bySource[src] = (bySource[src] ?? 0) + 1;
        }

        // Budget per source for each type, computed once per tick.
        final budgetByType = <ItemType, Map<String, int>>{};
        Map<String, int> budgetFor(ItemType type) => budgetByType[type] ??=
            allocateSourceSlots(
              total: typeMax[type] ?? 2,
              pendingBySource: pendingByType[type] ?? const {},
              perSourceCap: typePerSrcMax[type] ?? 2,
            );

        // Items that can be launched right now, per type and source. A row that
        // is parked (Wi-Fi, no network, retry backoff) cannot use a slot this
        // tick, so its source must not keep a reserved share idle while another
        // source with ready work waits for the same total budget.
        final startableByType = <ItemType, Map<String, int>>{};
        for (final d in toStart) {
          if (d.status == 'waiting_wifi' || d.status == 'waiting_network') {
            continue;
          }
          final manga = d.chapter.value?.manga.value;
          final type = manga?.itemType ?? ItemType.manga;
          final src = manga?.source ?? '_unknown';
          final bySource = startableByType[type] ??= <String, int>{};
          bySource[src] = (bySource[src] ?? 0) + 1;
        }

        // Preempt the running downloads that no longer fit the budget, so a
        // *lowered* total or per-source limit applies at once instead of only
        // when a slot happens to free up. The oldest workers (started first) are
        // kept; the newest over-budget ones are stopped and put back in the
        // queue, then the budget is dispatched against the resulting counts.
        final activeSlotsByType = <ItemType, List<ActiveSlot>>{};
        for (final id in ActiveDownloadRegistry.allActiveIds) {
          final type = ActiveDownloadRegistry.activeTypeOf(id);
          if (type == null) continue;
          (activeSlotsByType[type] ??= <ActiveSlot>[]).add(
            ActiveSlot(
              downloadId: id,
              source: ActiveDownloadRegistry.activeSourceOf(id) ?? '_unknown',
              preempted: ActiveDownloadRegistry.wasPreempted(id),
            ),
          );
        }
        for (final entry in activeSlotsByType.entries) {
          final toPreempt = selectPreemptions(
            slots: entry.value,
            total: typeMax[entry.key] ?? 2,
            perSourceCap: typePerSrcMax[entry.key] ?? 2,
          );
          for (final id in toPreempt) {
            unawaited(_preemptDownload(id));
          }
        }

        for (final d in toStart) {
          final chapter = d.chapter.value;
          if (chapter == null) continue;

          final type = chapter.manga.value?.itemType ?? ItemType.manga;
          final chSrc = chapter.manga.value?.source ?? '_unknown';

          // Check live counts from the registry (not local counters — those go
          // stale after pause/resume because isolates exit without a callback).
          final curType = ActiveDownloadRegistry.activeCountForType(type);
          final curSrc = ActiveDownloadRegistry.activeCountForSource(type, chSrc);
          // Fallback of 2 instead of 1: an unknown ItemType should not
          // single-thread the queue; 2 is a sane conservative default.
          final tLimit = typeMax[type] ?? 2;
          final sLimit = typePerSrcMax[type] ?? 2;

          // Share of the type budget this source may use, given every source's
          // workload — never more than its "Src" cap. The share only decides
          // who gets a free slot first: when no other source can use it, the
          // slot is handed to this source instead of staying idle.
          final share = budgetFor(type)[chSrc] ?? 0;
          final activeBySource = <String, int>{
            for (final src in pendingByType[type]?.keys ?? const <String>[])
              src: ActiveDownloadRegistry.activeCountForSource(type, src),
          };
          final shareBlocks =
              curSrc >= share &&
              hasCompetingSource(
                source: chSrc,
                startableBySource: startableByType[type] ?? const {},
                activeBySource: activeBySource,
                shareBySource: budgetFor(type),
                perSourceCap: sLimit,
              );

          if (curType >= tLimit || curSrc >= sLimit || shareBlocks) {
            final chapterId = chapter.id;
            if (chapterId != null && loggedConcurrencyBlocks.add(chapterId)) {
              AppLogger.log(
                '[ch:$chapterId] waiting for concurrency slot '
                'type=${type.name} active=$curType/$tLimit '
                'source=$curSrc/$sLimit share=$share',
                logLevel: LogLevel.debug,
                tag: LogTag.download,
              );
            }
            continue;
          }

          // A source that just rate-limited us must not receive the next
          // chapter: without this the queue re-feeds a throttled source on
          // every tick, so every remaining chapter in a long batch fails the
          // same way until the source's window expires on its own.
          final cooldownKey = HostCooldownRegistry.keyForSource(chSrc);
          if (HostCooldownRegistry.instance.isCoolingDown(cooldownKey)) {
            final left =
                HostCooldownRegistry.instance.remaining(cooldownKey)?.inSeconds ??
                0;
            final chapterId = chapter.id;
            if (chapterId != null && loggedCooldowns.add(chapterId)) {
              AppLogger.log(
                '[ch:$chapterId] source=$chSrc cooling down (${left}s left); '
                'holding this chapter',
                logLevel: LogLevel.info,
                tag: LogTag.download,
              );
              // Surface the hold on the row itself, so a queued batch shows
              // "rate limited" instead of looking stuck for no reason.
              _markRateLimited(chapterId);
            }
            continue;
          }
          if (chapter.id != null) {
            loggedCooldowns.remove(chapter.id!);
          }
          if (chapter.id != null) {
            loggedConcurrencyBlocks.remove(chapter.id!);
          }

          if (d.status == 'waiting_wifi' ||
              d.status == 'waiting_network' ||
              d.status == 'rate_limited' ||
              d.status == 'queued') {
            _setDownloadStatus(d.id, 'fetching_metadata');
          }
          AppLogger.log(
            'Queue dispatch [ch:${chapter.id}] type=${type.name} '
            'source=$chSrc active=$curType/$tLimit sourceActive=$curSrc/$sLimit '
            'share=$share',
            logLevel: LogLevel.info,
            tag: LogTag.download,
          );

          // Small stagger to avoid thundering herd on the remote server.
          await Future.delayed(const Duration(milliseconds: 150));

          // Start the download. Its worker claims the registry slot before its
          // first await, so another scheduler cannot launch the same chapter.
          ref.read(downloadChapterProvider(chapter: chapter, useWifi: effectiveUseWifi));

          // This source just consumed one of its ready items: stop counting it
          // as waiting for a slot, so the rest of the budget goes to the others
          // in this same tick.
          final remaining = startableByType[type]?[chSrc];
          if (remaining != null) {
            if (remaining <= 1) {
              startableByType[type]!.remove(chSrc);
            } else {
              startableByType[type]![chSrc] = remaining - 1;
            }
          }
        }

        return true; // keep polling
      });
    });
  } finally {
    // Always release the wakelock and stop the foreground service, whether
    // the queue drained normally, threw, or was cancelled.
    clearDownloadLimitApplier(applyLoweredLimitsNow);
    keepAlive.close();
    unawaited(connectivitySub.cancel());
    unawaited(BackgroundKeepAlive.stop());
    _processDownloadsSchedulerRunning = false;
    _processDownloadsWifiOverride = null;
  }
}
