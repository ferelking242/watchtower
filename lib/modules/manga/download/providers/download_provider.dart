import 'dart:async';
import 'dart:io'
    if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'dart:ui';
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
import 'package:watchtower/modules/manga/download/providers/convert_to_cbz.dart';
import 'package:watchtower/modules/more/settings/browse/providers/browse_state_provider.dart';
import 'package:watchtower/modules/more/settings/downloads/providers/downloads_state_provider.dart';
import 'package:watchtower/modules/more/providers/incognito_mode_state_provider.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/providers/storage_provider.dart';
import 'package:watchtower/router/router.dart';
import 'package:watchtower/services/download_manager/active_download_registry.dart';
import 'package:watchtower/services/download_manager/download_connectivity.dart';
import 'package:watchtower/services/download_manager/download_isolate_pool.dart';
import 'package:watchtower/services/download_manager/external_downloader_launcher.dart';
import 'package:watchtower/services/download_manager/m_downloader.dart';
import 'package:watchtower/services/download_manager/download_size.dart';
import 'package:watchtower/services/get_video_list.dart';
import 'package:watchtower/services/get_chapter_pages.dart';
import 'package:watchtower/services/page_url_cache.dart';
import 'package:watchtower/services/settings_store.dart';
import 'package:watchtower/services/http/m_client.dart';
import 'package:watchtower/services/download_manager/m3u8/m3u8_downloader.dart';
import 'package:watchtower/services/download_manager/m3u8/models/download.dart';
import 'package:watchtower/services/download_manager/download_settings_service.dart';
import 'package:watchtower/services/manga_download_manifest.dart';
import 'package:watchtower/services/download_manager/engine_selector.dart';
import 'package:watchtower/services/download_manager/engines/aria2_engine.dart';
import 'package:watchtower/utils/chapter_recognition.dart';
import 'package:watchtower/utils/extensions/chapter.dart';
import 'package:watchtower/utils/extensions/string_extensions.dart';
import 'package:watchtower/utils/headers.dart';
import 'package:watchtower/utils/log/logger.dart';
import 'package:watchtower/utils/reg_exp_matcher.dart';
import 'package:watchtower/utils/utils.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:watchtower/utils/constant.dart';
import 'package:watchtower/services/download_manager/background_keep_alive.dart';
import 'package:watchtower/services/update_notification_service.dart';
part 'download_provider.g.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Bridge the old developer.log calls in this file into AppLogger so scheduler
/// and worker traces are also visible in the floating log panel.
void log(String message, {Object? error, StackTrace? stackTrace}) {
  AppLogger.log(
    message,
    logLevel: error != null || stackTrace != null
        ? LogLevel.warning
        : LogLevel.info,
    tag: LogTag.download,
    error: error,
    stackTrace: stackTrace,
  );
}

/// Convert a raw exception into a human-readable French message.
String friendlyErrorMessage(Object e) {
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
    if (download == null ||
        download.isDownload == true ||
        download.status == status) {
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

Future<void> deleteMediaDownload(WidgetRef ref, int chapterId) async {
  final notifier = ref.read(downloadQueueStateProvider.notifier);
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
    } catch (_) {}
  }
  final chapter = download.chapter.value;
  if (chapter != null) {
    await chapter.deleteDownloadedFiles();
  } else {
    final savedPath = download.filePath;
    if (savedPath != null) {
      for (final candidate in [
        savedPath,
        '$savedPath.part',
        '$savedPath.part.meta',
      ]) {
        try {
          final file = File(candidate);
          if (file.existsSync()) file.deleteSync();
        } catch (_) {}
      }
    }
    isar.writeTxnSync(() => isar.downloads.deleteSync(chapterId));
  }

  notifier.setPaused(chapterId, false, updateEngine: false);
  notifier.clearLiveProgress(chapterId);
  await WatchtowerNotificationService.instance.cancelMediaDownloadNotification(
    chapterId,
  );
}

Future<void> handleMediaDownloadNotificationAction(
  WidgetRef ref,
  int chapterId,
  MediaDownloadNotificationAction action,
) async {
  final notifier = ref.read(downloadQueueStateProvider.notifier);
  final notifications = WatchtowerNotificationService.instance;
  final download = isar.downloads.getSync(chapterId);
  if (download == null) {
    await notifications.cancelMediaDownloadNotification(chapterId);
    return;
  }
  final isPaused =
      ref.read(downloadQueueStateProvider).pausedIds.contains(chapterId) ||
      download.status == 'paused';

  switch (action) {
    case MediaDownloadNotificationAction.pause:
      if (isPaused || download.isDownload == true) return;
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
      if (!isPaused || download.status == 'cancelled') return;
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
      ref.read(processDownloadsProvider());
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
        } catch (_) {}
      }
      chapter ??= isar.chapters.getSync(chapterId);
      if (chapter == null) {
        await notifications.cancelMediaDownloadNotification(chapterId);
        return;
      }
      ensureChapterLinksLoaded(chapter);
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
      ref.read(processDownloadsProvider());
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
  if (s.contains('1080') || s.contains('fhd') || s.contains('full hd'))
    return '1080p';
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

/// Reduces a quality string to just its resolution digits (e.g. "1080p",
/// "1080P", "1080", "FHD 1080p60" → "1080"). Used to match a quality chosen
/// in one UI (which may format labels differently, e.g. uppercase "P") against
/// quality strings from a completely different source/episode's video list,
/// without depending on either side's exact label formatting.
String _qualityDigits(String raw) {
  final m = RegExp(r'(\d{3,4})').firstMatch(raw);
  if (m != null) return m.group(1)!;
  return raw.trim().toLowerCase();
}

/// Resolve (and persist) the manga owning [chapter] as safely as possible.
///
/// Root cause of "le téléchargement ne démarre pas" : un chapitre chargé
/// directement depuis Isar peut avoir son `IsarLink<Manga>` NON chargé
/// (`chapter.manga.value == null`). L'ancien code lançait alors
/// `StateError('chapter.manga not loaded')`, le téléchargement échouait
/// immédiatement, l'entrée passait en `failed` et disparaissait du
/// gestionnaire.
///
/// On répare ici : on charge le lien si besoin, et on retombe sur
/// `mangaId` (champ dénormalisé, jamais effacé) en dernier recours.
Manga resolveChapterManga(Chapter chapter) {
  Manga? manga = chapter.manga.value;
  if (manga == null) {
    if (!chapter.manga.isLoaded) {
      try {
        chapter.manga.loadSync();
      } catch (_) {
        // Lien absent en base : on tentera le mangaId juste après.
      }
      manga = chapter.manga.value;
    }
    if (manga == null && chapter.mangaId != null) {
      try {
        manga = isar.mangas.getSync(chapter.mangaId!);
        if (manga != null) {
          // Re-attache le lien pour les écritures suivantes (et pour l'UI).
          chapter.manga.value = manga;
        }
      } catch (_) {
        // Manga corrompu / migration non jouée : on laisse null, le caller
        // (``downloadChapter``) attrape le StateError et markera failed.
      }
    }
  }
  if (manga == null) {
    throw StateError(
      'Manga introuvable pour chapterId=${chapter.id} '
      '(mangaId=${chapter.mangaId}) — téléchargement impossible.',
    );
  }
  return manga;
}

/// Garantit que le manga associé au chapitre est lisible avant la mise en file.
///
/// Les liens Isar peuvent être absents ou corrompus dans d'anciennes bases.
/// On essaie le lien puis le mangaId de secours, en transformant les erreurs
/// de désérialisation en message exploitable au lieu de les laisser remonter
/// sous forme de RangeError générique.
void ensureChapterLinksLoaded(Chapter chapter) {
  Object? linkError;
  Manga? manga;
  try {
    manga = chapter.manga.value;
    if (manga == null && !chapter.manga.isLoaded) {
      chapter.manga.loadSync();
      manga = chapter.manga.value;
    }
  } catch (error) {
    linkError = error;
  }
  if (manga == null && chapter.mangaId != null) {
    try {
      manga = isar.mangas.getSync(chapter.mangaId!);
      if (manga != null) {
        chapter.manga.value = manga;
      }
    } catch (error) {
      linkError = error;
      manga = null;
    }
  }
  if (manga == null) {
    final detail = linkError == null ? '' : ': $linkError';
    throw StateError(
      'Impossible de lire le manga lié au chapitre '
      '(chapterId=${chapter.id}, mangaId=${chapter.mangaId})$detail',
    );
  }
}

/// User-chosen quality label (normalized via [_normalizeQuality]), keyed by
/// chapter.id. Used by the batch download sheet: unlike
/// [chapterPreferredOriginalUrl] (a single episode's exact URL, valid only
/// for the episode it was picked from), the sheet lets the user pick one
/// quality for MANY episodes at once, and each episode has its own distinct
/// set of video URLs — so a URL from episode 1 would never match episode 5's
/// list. Matching by normalized quality label instead works across episodes.
final Map<int, String> chapterPreferredQuality = {};

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
    final result = await ref.read(
      getVideoListProvider(episode: chapter).future,
    );
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
  final directVideos = uniqueVideos
      .where((v) => _isDirectLink(v.originalUrl))
      .toList();
  final extractedVideos = uniqueVideos
      .where((v) => !_isDirectLink(v.originalUrl))
      .toList();

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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: _QualityPickerDialog(
            directVideos: directVideos,
            extractedVideos: extractedVideos,
            preferredExternalDownloader:
                DownloadSettingsService.instance.preferredExternalDownloader ??
                '',
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
    final appId =
        DownloadSettingsService.instance.preferredExternalDownloader ?? '';
    final launched = await ExternalDownloaderLauncher.launch(
      url: selected!.originalUrl,
      appId: appId.isEmpty ? 'adm' : appId,
      headers: selected!.headers,
    );
    if (!launched && context.mounted) {
      botToast(
        'Impossible d\'ouvrir le gestionnaire externe. Vérifiez qu\'il est installé.',
      );
    }
    return launched;
  }

  if (chapter.id != null) {
    chapterPreferredOriginalUrl[chapter.id!] = selected!.originalUrl;
  }
  await ref.read(addDownloadToQueueProvider(chapter: chapter).future);
  if (chapter.id != null) {
    ref.read(downloadQueueStateProvider.notifier).setPaused(chapter.id!, false);
  }
  ref.read(processDownloadsProvider());
  return true;
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
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: cs.onSurface,
                  ),
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
              children: [
                TextButton(onPressed: onCancel, child: const Text('Annuler')),
              ],
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
      separatorBuilder: (_, __) =>
          Divider(height: 1, color: cs.outline.withValues(alpha: 0.15)),
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
                    color: widget.isM3u8
                        ? Colors.purple.shade300
                        : cs.onTertiaryContainer,
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
                    child: Icon(
                      Icons.copy_rounded,
                      size: 16,
                      color: cs.onSurfaceVariant,
                    ),
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
                      _urlExpanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 16,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              // Download in-app
              Tooltip(
                message: 'Télécharger dans l\'application',
                child: InkWell(
                  onTap: () => widget.onSelect(widget.v, false),
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      Icons.download_rounded,
                      color: cs.primary,
                      size: 22,
                    ),
                  ),
                ),
              ),
              // Open in external downloader
              if (!kIsWeb && Platform.isAndroid)
                Tooltip(
                  message: 'Ouvrir dans un gestionnaire externe',
                  child: InkWell(
                    onTap: () => widget.onSelect(widget.v, true),
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        Icons.open_in_new_rounded,
                        color: cs.secondary,
                        size: 20,
                      ),
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
            crossFadeState: _urlExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}

/// Persist the download row and its IsarLink in the same transaction.
void _putDownloadForChapter(Download download, Chapter chapter) {
  download.chapter.value = chapter;
  isar.downloads.putSync(download);
}

const _pendingDownloadStatuses = {
  'queued',
  'waiting_wifi',
  'fetching_metadata',
  'initializing',
};

const _terminalDownloadStatuses = {
  'paused',
  'failed',
  'cancelled',
  'completed',
};

bool _isPendingDownload(Download download) {
  if (download.isDownload == true ||
      _terminalDownloadStatuses.contains(download.status)) {
    return false;
  }
  return download.isStartDownload == true ||
      _pendingDownloadStatuses.contains(download.status);
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
      throw StateError(
        'Impossible de mettre en file un chapitre sans identifiant.',
      );
    }

    Download? existing;
    var corruptRecord = false;
    try {
      existing = isar.downloads.getSync(id);
    } on RangeError {
      // The record cannot be deserialized; replace it transactionally below.
      corruptRecord = true;
    }

    if ((existing?.isDownload ?? false) ||
        ActiveDownloadRegistry.isActive(id)) {
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
      ..quality = chapterPreferredQuality[id]
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

  try {
    bool onlyOnWifi = useWifi ?? ref.read(onlyOnWifiStateProvider);
    if (onlyOnWifi) {
      final connectivity = await Connectivity().checkConnectivity();
      if (!hasWifiOrEthernet(connectivity)) {
        _setDownloadStatus(chapterId, 'waiting_wifi');
        log('[ch:$chapterId] waiting for Wi-Fi before starting');
        final context = navigatorKey.currentContext;
        if (context != null) {
          botToast(context.l10n.downloads_are_limited_to_wifi);
        }
        callback?.call();
        keepAlive.close();
        return;
      }
    }

    final http = MClient.init(
      reqcopyWith: {'useDartHttpClient': true, 'followRedirects': false},
    );

    // ── Per-type connection settings ────────────────────────────────────────
    final mangaConnections = ref.read(mangaConnectionsStateProvider);
    final animeConnections = ref.read(animeConnectionsStateProvider);

    List<PageUrl> pageUrls = [];
    List<PageUrl> pageUrlsForCache = [];
    PageUrl? novelPage;
    List<PageUrl> pages = [];
    final mangaPageTasks = <PageUrl>[];
    final mangaPagePaths = <String>[];
    final mangaPageCompleted = <bool>[];
    MangaDownloadManifest? activeMangaManifest;
    final StorageProvider storageProvider = StorageProvider();
    // Résolution robuste du manga EN PREMIER : `getMangaMainDirectory()` fait
    // `chapter.manga.value!` et levait donc un "Null check operator used on a
    // null value" (→ téléchargement marqué en échec avant même de commencer)
    // quand le lien Isar n'était pas chargé. resolveChapterManga() charge le
    // lien et retombe sur mangaId si nécessaire.
    Manga manga;
    try {
      manga = resolveChapterManga(chapter);
    } on StateError catch (e) {
      log('[downloadChapter] cannot resolve manga: $e');
      _notifyDownloadFailure('Manga introuvable pour ce chapitre.');
      if (chapter.id != null) {
        unawaited(
          WatchtowerNotificationService.instance.markMediaDownloadFailed(
            chapter.id!,
            seriesTitle: mangaForRegistry?.name ?? chapter.name ?? '',
            chapterTitle: chapter.name ?? 'Téléchargement',
            itemType: mangaForRegistry?.itemType.name ?? ItemType.manga.name,
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
    // Do NOT call requestPermission() here — permission is granted during
    // onboarding. Calling it at download time shows a system dialog mid-session.
    final mangaMainDirectory = await storageProvider.getMangaMainDirectory(
      chapter,
    );
    List<Track>? subtitles;
    final chapterName = chapter.name!.replaceForbiddenCharacters(' ');
    final itemType = manga.itemType;
    final chapterDirectory = (await storageProvider.getMangaChapterDirectory(
      chapter,
      mangaMainDirectory: mangaMainDirectory,
    ))!;
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
    await DownloadSettingsService.instance.load();
    ref.invalidate(mangaArchiveFormatStateProvider);
    final saveMangaAsCbz =
        itemType == ItemType.manga &&
        ref.read(mangaArchiveFormatStateProvider) == MangaArchiveFormat.cbz;

    Future<void> processConvert() async {
      if (!saveMangaAsCbz) return;
      final cbzFile = File(
        p.join(mangaMainDirectory!.path, '${chapter.name}.cbz'),
      );
      if (cbzFile.existsSync() && cbzFile.lengthSync() > 0) return;
      if (mangaPageTasks.isEmpty ||
          mangaPageTasks.any((page) => page.fileName == null)) {
        throw StateError('La liste complète des pages manga est indisponible.');
      }
      try {
        final chapterNumber = ChapterRecognition().parseChapterNumber(
          chapter.manga.value!.name!,
          chapter.name!,
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
        await ref.read(
          convertToCBZProvider(
            chapterDirectory.path,
            mangaMainDirectory!.path,
            chapter.name!,
            mangaPageTasks.map((page) => page.fileName!).toList(),
            comicInfo: comicInfo,
          ).future,
        );
      } catch (error) {
        botToast(
          'Erreur lors de la création du CBZ : ${friendlyErrorMessage(error)}',
        );
        rethrow;
      }
    }

    void persistMangaManifest(MangaDownloadManifest manifest) {
      final id = chapter.id;
      if (id == null) {
        throw StateError(
          'Impossible de sauvegarder le manifeste sans identifiant de chapitre.',
        );
      }
      Download? record;
      try {
        record = isar.downloads.getSync(id);
      } catch (_) {
        record = null;
      }
      final download =
          record ??
          Download(
            id: id,
            succeeded: 0,
            failed: 0,
            total: manifest.pages.length,
            isDownload: false,
            isStartDownload: true,
            title: chapter.name,
            status: 'initializing',
          );
      download.pageManifestJson = manifest.encode();
      isar.writeTxnSync(() => _putDownloadForChapter(download, chapter));
    }

    void updateMangaPageState(String? filePath, MangaPageState newState) {
      final manifest = activeMangaManifest;
      if (manifest == null || filePath == null) return;
      final index = manifest.pages.indexWhere(
        (page) => page.filePath == filePath,
      );
      if (index < 0 || manifest.pages[index].state == newState) return;
      final updatedPages = [...manifest.pages];
      updatedPages[index] = updatedPages[index].copyWith(state: newState);
      activeMangaManifest = MangaDownloadManifest(
        chapterUrl: manifest.chapterUrl,
        pages: updatedPages,
      );
      persistMangaManifest(activeMangaManifest!);
    }

    void markMangaFailure(Object error) {
      final manifest = activeMangaManifest;
      if (manifest == null) return;
      final errorText = error.toString();
      int? failedIndex;
      for (var index = 0; index < manifest.pages.length; index++) {
        final page = manifest.pages[index];
        if (page.state == MangaPageState.completed) continue;
        if (errorText.contains(page.filePath) ||
            errorText.contains(p.basename(page.filePath))) {
          failedIndex = index;
          break;
        }
      }
      if (failedIndex == null) {
        final incomplete = [
          for (var index = 0; index < manifest.pages.length; index++)
            if (manifest.pages[index].state != MangaPageState.completed) index,
        ];
        if (incomplete.length == 1) failedIndex = incomplete.single;
      }
      final updatedPages = [
        for (var index = 0; index < manifest.pages.length; index++)
          manifest.pages[index].copyWith(
            state: index == failedIndex
                ? MangaPageState.failed
                : manifest.pages[index].state == MangaPageState.downloading
                ? MangaPageState.pending
                : manifest.pages[index].state,
          ),
      ];
      activeMangaManifest = MangaDownloadManifest(
        chapterUrl: manifest.chapterUrl,
        pages: updatedPages,
      );
      persistMangaManifest(activeMangaManifest!);
    }

    // Tracks the KB already stored in Isar from a previous (paused) download
    // session.  Captured once on the very first setProgress() call, then added
    // as an offset to every subsequent tick so the progress bar never goes
    // backwards after a pause → resume.  -1 = not yet captured.
    var _resumeSucceededKbOffset = -1;

    // ── Speed Master: live per-download speed (EMA, MB/s) ──────────────────
    // Sampled from consecutive byte progress ticks; smoothed so the value in
    // the queue UI stays readable instead of jumping on every segment done.
    var _speedLastKb = -1;
    var _speedLastMs = 0;
    var _speedEmaMbs = 0.0;
    var mediaCompletionNotified = false;
    var transferStatusMarked = false;
    var lastMangaBytesUpdateAt = DateTime.fromMillisecondsSinceEpoch(0);
    var lastLoggedProgressBucket = -1;

    Future<void> setProgress(DownloadProgress progress) async {
      final currentDownload = chapterId == null
          ? null
          : isar.downloads.getSync(chapterId);
      if (currentDownload?.status == 'paused' ||
          currentDownload?.status == 'cancelled') {
        return;
      }
      if (progress.itemType == ItemType.manga &&
          progress.downloadedBytes != null) {
        final now = DateTime.now();
        if (now.difference(lastMangaBytesUpdateAt) <
            const Duration(milliseconds: 180)) {
          return;
        }
        lastMangaBytesUpdateAt = now;
      }
      if (progress.total > 0) {
        final percent = (progress.completed / progress.total * 100)
            .clamp(0, 100)
            .toInt();
        final bucket = (percent ~/ 10) * 10;
        if (bucket >= 10 && bucket > lastLoggedProgressBucket) {
          lastLoggedProgressBucket = bucket;
          AppLogger.log(
            '[ch:${chapter.id}] transfer progress=$bucket% '
            'units=${progress.completed}/${progress.total}',
            logLevel: LogLevel.debug,
            tag: LogTag.download,
          );
        }
      }
      if (progress.total > 0 && AppLogger.isExtremeMode) {
        final pct =
            (progress.total > 0
                    ? (progress.completed /
                          progress.total.clamp(1, double.infinity) *
                          100)
                    : 0)
                .toInt();
        AppLogger.log(
          '[ch:${chapter.id}] page ${progress.completed}/${progress.total} ($pct%) '
          '• type=${progress.itemType.name}',
          logLevel: LogLevel.debug,
          tag: LogTag.page,
        );
      }
      if (chapterId != null) {
        final latestDownload = isar.downloads.getSync(chapterId);
        if (latestDownload?.status == 'paused' ||
            latestDownload?.status == 'cancelled') {
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
      if (progress.itemType == ItemType.manga &&
          (storedSucceeded < 0 ||
              storedTotal < 0 ||
              (storedTotal > 0 && storedSucceeded > storedTotal) ||
              (storedTotal <= 0 && storedSucceeded > 0))) {
        // Old/corrupt rows can contain byte counts or stale page counters.
        // Never treat an impossible value as a valid resume offset.
        storedSucceeded = 0;
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
      final isPerFileByteProgress =
          progress.itemType != ItemType.anime &&
          progress.downloadedBytes != null;
      if (isPerFileByteProgress &&
          !transferStatusMarked &&
          chapter.id != null) {
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
        // Manga / novel: store real page counts.
        isarSucceeded = progress.completed;
        isarTotal = progress.total > 0 ? progress.total : 1;
      }

      // Anti-overflow : ne jamais laisser succeeded dépasser total ni être
      // négatif (source classique du RangeError length quand on calcule
      // downloadedBytes/totalBytes avec un succeeded incohérent).
      if (isarSucceeded < 0) isarSucceeded = 0;
      if (isarTotal > 0 && isarSucceeded > isarTotal) {
        isarSucceeded = isarTotal;
      }
      if (isarTotal <= 0) isarTotal = 1;

      if (chapter.id != null) {
        final progressNotifier = ref.read(downloadQueueStateProvider.notifier);
        if (progress.isCompleted) {
          progressNotifier.clearLiveProgress(chapter.id!);
        } else if (!(progress.downloadedBytes == null &&
            progress.totalBytes == null &&
            progress.total == 0)) {
          progressNotifier.setLiveProgress(
            chapter.id!,
            DownloadLiveProgress(
              downloadedBytes: liveDownloadedBytes,
              totalBytes: liveTotalBytes,
              completedUnits: progress.completed,
              totalUnits: progress.total,
              isIndeterminate: progress.isIndeterminate,
            ),
          );
        }
      }

      // ── Speed Master: update the live speed shown in the download queue ──
      {
        final notifier = ref.read(downloadQueueStateProvider.notifier);
        if (progress.isCompleted) {
          if (_speedEmaMbs > 0 || _speedLastKb >= 0) {
            _speedEmaMbs = 0;
            _speedLastKb = -1;
            notifier.setSpeed(chapter.id!, 0);
          }
        } else if (progress.itemType == ItemType.anime &&
            !progress.isCompleted) {
          final nowMs = DateTime.now().millisecondsSinceEpoch;
          final kbNow = progress.downloadedBytes != null
              ? (progress.downloadedBytes! / 1024).ceil()
              : isarSucceeded; // includes resume offset → cumulative
          if (_speedLastKb < 0) {
            _speedLastKb = kbNow;
            _speedLastMs = nowMs;
          } else {
            final dtSec = (nowMs - _speedLastMs) / 1000.0;
            // ≥0.5 s between samples keeps the EMA stable without flooding.
            if (dtSec >= 0.5) {
              final instMbs = ((kbNow - _speedLastKb) / 1024.0) / dtSec;
              if (instMbs >= 0) {
                _speedEmaMbs = _speedEmaMbs <= 0
                    ? instMbs
                    : (_speedEmaMbs * 0.7 + instMbs * 0.3);
                notifier.setSpeed(chapter.id!, _speedEmaMbs);
              }
              // Negative delta = a resume reset happened mid-session: re-seed.
              _speedLastKb = kbNow;
              _speedLastMs = nowMs;
            }
          }
        }
      }

      // Manga progress now includes every valid page already on disk, so it
      // must not add a second offset from the older queue record.
      if (progress.itemType == ItemType.manga && progress.total > 0) {
        _resumeSucceededKbOffset = 0;
      } else if (_resumeSucceededKbOffset < 0) {
        final stored = storedSucceeded;
        final threshold = progress.itemType == ItemType.anime ? 500 : 1;
        _resumeSucceededKbOffset =
            stored > threshold &&
                (progress.itemType != ItemType.anime ||
                    stored <= maxTrustedDownloadBytes ~/ 1024)
            ? stored
            : 0;
      }

      // ── Resume-safe corrections for byte-counted media ───────────────────
      // Manga reports the complete page list and valid files on disk above,
      // so its total and completed count are authoritative on every resume.
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
            progress.itemType == ItemType.anime &&
            reportedDownloadedBytes != null;
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
      final writtenSucceeded =
          (progress.completed == 0 && _resumeSucceededKbOffset <= 0)
          ? 0
          : isarSucceeded;
      final exactDownloadedBytes = progress.itemType == ItemType.anime
          ? reportedDownloadedBytes ??
                (progress.isCompleted
                    ? trustedDownloadByteCount(
                        download?.downloadedBytes,
                        allowZero: true,
                      )
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

      if (chapter.id == null) {
        // Pas d'ID → on ne peut rien écrire en base. On met juste à jour le
        // state Riverpod live (déjà fait plus haut) et on quitte.
      } else if (download == null) {
        if (isPerFileByteProgress) {
          // Byte ticks for a page are volatile UI progress; do not create or
          // rewrite Isar rows until a full page has passed image validation.
        } else {
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
              quality: chapterPreferredQuality[chapter.id],
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
        if (!isPerFileByteProgress &&
            (progress.total != 0 || progress.downloadedBytes != null)) {
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
                  ..quality = chapterPreferredQuality[chapter.id]
                  ..posterUrl =
                      chapter.thumbnailUrl ?? chapter.manga.value?.imageUrl
                  ..status = progressStatus,
              );
            });
          } catch (_) {}
        }
      }

      // ── Auto-add to library when a chapter finishes downloading ──────────
      // If the parent manga/anime is not yet in the library (favorite=false),
      // add it automatically so the user can find their downloads in Library.
      if (progress.isCompleted) {
        final parentManga = chapter.manga.value;
        if (parentManga != null &&
            parentManga.id != null &&
            parentManga.favorite != true) {
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

      if (!progress.isCompleted && chapter.id != null) {
        unawaited(
          WatchtowerNotificationService.instance.showMediaDownloadProgress(
            chapterId: chapter.id!,
            seriesTitle: chapter.manga.value?.name ?? chapter.name ?? '',
            chapterTitle: chapter.name ?? 'Téléchargement',
            itemType: progress.itemType.name,
            completed: progress.completed,
            total: progress.total,
            downloadedBytes: liveDownloadedBytes,
            totalBytes: liveTotalBytes,
          ),
        );
      }

      // The native foreground service remains the single persistent summary;
      // individual named notifications above provide the expandable details.
      final chapterTitle = chapter.name?.trim().isNotEmpty == true
          ? chapter.name!.trim()
          : 'Téléchargement';
      final seriesTitle = chapter.manga.value?.name?.trim().isNotEmpty == true
          ? chapter.manga.value!.name!.trim()
          : chapterTitle;
      final registeredCount = ActiveDownloadRegistry.activeCountForType(
        progress.itemType,
      );
      final activeCount = registeredCount > 0 ? registeredCount : 1;
      final notificationTitle = activeCount == 1
          ? seriesTitle
          : '$activeCount téléchargements en cours';
      if (progress.itemType == ItemType.anime) {
        final downloadedBytes =
            reportedDownloadedBytes ??
            trustedDownloadBytesFromKilobytes(isarSucceeded) ??
            0;
        final notificationTotalBytes =
            reportedTotalBytes ??
            trustedDownloadBytesFromKilobytes(
              isarTotal > 500 ? isarTotal : null,
              allowZero: false,
            );
        final hasKnownSize =
            notificationTotalBytes != null && notificationTotalBytes > 0;
        final pct = hasKnownSize
            ? (((downloadedBytes * 100) ~/ notificationTotalBytes!)).clamp(
                0,
                100,
              )
            : -1;
        final remaining = hasKnownSize
            ? (notificationTotalBytes! - downloadedBytes)
                  .clamp(0, double.infinity)
                  .toInt()
            : 0;
        final activeCount = ActiveDownloadRegistry.activeCountForType(
          ItemType.anime,
        );
        final chapterTitle = chapter.name?.trim();
        final notifSub = chapterTitle?.isNotEmpty == true
            ? chapterTitle!
            : 'Vidéo en cours de téléchargement';
        final etaSeconds = _speedEmaMbs >= 0.05 && hasKnownSize
            ? ((remaining / (_speedEmaMbs * 1024 * 1024))
                  .clamp(0, double.infinity)
                  .ceil())
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
            force: progress.isCompleted,
          ),
        );
      } else {
        final pct = progress.total > 0
            ? ((progress.completed / progress.total) * 100)
                  .round()
                  .clamp(0, 100)
                  .toInt()
            : -1;
        unawaited(
          BackgroundKeepAlive.update(
            count: activeCount,
            title: notificationTitle,
            progress: pct,
            subtitle: activeCount == 1
                ? chapterTitle
                : '$seriesTitle · $chapterTitle',
            force: progress.isCompleted,
          ),
        );
      }

      if (progress.isCompleted &&
          !mediaCompletionNotified &&
          chapter.id != null) {
        mediaCompletionNotified = true;
        String? candidatePath;
        final directory = mangaMainDirectory;
        if (directory != null) {
          if (progress.itemType == ItemType.anime) {
            candidatePath =
                m3u8Downloader?.fileName ??
                p.join(directory.path, '$chapterName.mp4');
          } else if (progress.itemType == ItemType.manga) {
            candidatePath = saveMangaAsCbz
                ? p.join(directory.path, '${chapter.name}.cbz')
                : chapterDirectory.path;
          } else if (progress.itemType == ItemType.novel) {
            candidatePath = p.join(directory.path, '$chapterName.html');
          }
        }
        final completedPathExists = candidatePath != null &&
            (progress.itemType == ItemType.manga && !saveMangaAsCbz
                ? await Directory(candidatePath).exists()
                : await File(candidatePath).exists());
        final completedPath = completedPathExists ? candidatePath : null;
        if (completedPath != null) {
          try {
            final completedRecord = isar.downloads.getSync(chapter.id!);
            if (completedRecord != null) {
              isar.writeTxnSync(() {
                isar.downloads.putSync(
                  completedRecord
                    ..filePath = completedPath
                    ..status = 'completed'
                    ..isDownload = true,
                );
              });
            }
          } catch (_) {
            // Notification d'achèvement : on ne fait pas planter la fin du
            // téléchargement pour une entrée mal désérialisée.
          }
        }
        unawaited(
          WatchtowerNotificationService.instance.showMediaDownloadComplete(
            title: chapter.name ?? 'Téléchargement terminé',
            seriesTitle: seriesTitle,
            itemType: progress.itemType.name,
            filePath: completedPath,
            chapterId: chapter.id!,
          ),
        );
      }
    }

    setProgress(DownloadProgress(0, 0, itemType));

    void savePageUrls() {
      if (ref.read(incognitoModeStateProvider)) return;
      final pageUrlsToCache = pageUrlsForCache.isNotEmpty
          ? pageUrlsForCache
          : pageUrls;
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
            .where(
              (download) =>
                  download.id != null && download.isDownload != true,
            )
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
          AppLogger.log(
            '[ch:' +
                (chapter.id?.toString() ?? '?') +
                '] ${pageUrls.length} pages fetched'
                    ' • url[0]=' +
                (pageUrls.isNotEmpty
                    ? pageUrls.first.url.substring(
                        0,
                        pageUrls.first.url.length.clamp(0, 80),
                      )
                    : 'none'),
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
        log(
          '[downloadChapter][manga] getChapterPages error: $e',
          error: e,
          stackTrace: st,
        );
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
          final q = (v.quality ?? '').toString().toLowerCase();
          if (q.contains('hls') || q.contains('auto')) return true;
          return false;
        }

        final m3u8Urls = value.$1.where(looksLikeHls).toList();
        final nonM3u8Urls = value.$1
            .where(
              (element) =>
                  !looksLikeHls(element) && element.originalUrl.isMediaVideo(),
            )
            .toList();
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
          final idx = videosUrls.indexWhere(
            (v) => v.originalUrl == preferredOriginal,
          );
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
        final preferredLang = chapter.id != null
            ? chapterPreferredLang[chapter.id!]
            : null;
        if (preferredLang != null && videosUrls.length > 1) {
          final langMatches = videosUrls
              .where(
                (v) => v.quality.toUpperCase().contains(
                  preferredLang.toUpperCase(),
                ),
              )
              .toList();
          if (langMatches.isNotEmpty) videosUrls = langMatches;
          // One-shot: clear so a future re-download asks again.
          chapterPreferredLang.remove(chapter.id!);
        }
        // Batch download sheet: quality chosen by label (see chapterPreferredQuality
        // doc) since it applies across many episodes that each have their own URLs.
        // STRICT match: when the requested resolution exists in this episode's
        // list we download ONLY it — previously a missing match silently fell
        // back to the first entry (often 1080p/auto), so a user asking for
        // 360p could end up with a 1 GB file.
        final preferredQuality = chapter.id != null
            ? chapterPreferredQuality[chapter.id!]
            : null;
        if (preferredQuality != null && videosUrls.isNotEmpty) {
          final exactMatches = videosUrls
              .where((v) => _qualityDigits(v.quality) == preferredQuality)
              .toList();
          if (exactMatches.isNotEmpty) {
            videosUrls = exactMatches;
          }
          // No exact match: keep the source order as fallback rather than
          // guessing a different resolution.
          // One-shot: clear so a future re-download asks again.
          chapterPreferredQuality.remove(chapter.id!);
        }
        if (videosUrls.isNotEmpty) {
          subtitles = videosUrls.first.subtitles;
          final videoUri = Uri.tryParse(videosUrls.first.originalUrl);
          final referer = videoUri != null
              ? '${videoUri.scheme}://${videoUri.host}'
              : null;
          if (hasM3U8File) {
            pageUrlsForCache = [
              PageUrl(
                videosUrls.first.url,
                headers: videosUrls.first.headers,
              ),
            ];
            m3u8Downloader = M3u8Downloader(
              m3u8Url: videosUrls.first.url,
              downloadDir: chapterDirectory.path,
              headers: videosUrls.first.headers ?? {},
              subtitles: subtitles,
              fileName: p.join(mangaMainDirectory!.path, "$chapterName.mp4"),
              chapter: chapter,
              refererUrl: referer,
              concurrentDownloads: animeConnections,
            );
          } else {
            pageUrls = [PageUrl(videosUrls.first.url)];
            pageUrlsForCache = [
              PageUrl(
                videosUrls.first.url,
                headers: videosUrls.first.headers,
              ),
            ];
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
        log(
          '[downloadChapter][anime] getVideoList error: $e',
          error: e,
          stackTrace: st,
        );
      }
    } else if (itemType == ItemType.novel && chapter.url != null) {
      final manga = chapter.manga.value!;
      final source = getSource(manga.lang!, manga.source!, manga.sourceId)!;
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
      // Rendre l'échec visible : sinon l'icône revenait à son état initial et
      // l'utilisateur croyait que le bouton n'avait rien fait.
      _notifyDownloadFailure(fetchError!);
      if (chapter.id != null) {
        unawaited(
          WatchtowerNotificationService.instance.markMediaDownloadFailed(
            chapter.id!,
            seriesTitle: manga.name ?? chapter.name ?? '',
            chapterTitle: chapter.name ?? 'Téléchargement',
            itemType: itemType.name,
          ),
        );
      }
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
                ..failed = (dl.failed ?? 0) + 1
                ..isDownload = false
                ..status = 'failed'
                // Stop processDownloads from re-queuing this chapter on every
                // 900ms tick.  The user can retry manually from the queue UI.
                ..isStartDownload = false,
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
    // getVideoList can take several seconds), honour the pause now instead of
    // starting the actual download.  Without this check the early
    // registerInternal at line 662 would absorb the cancelTask() call (no
    // running pool task yet → no-op), and the download would start anyway.
    if (chapter.id != null &&
        (ref
                .read(downloadQueueStateProvider)
                .pausedIds
                .contains(chapter.id!) ||
            isar.downloads.getSync(chapter.id!)?.status == 'cancelled')) {
      // Unregister so processDownloads sees this chapter as idle and can
      // re-pick it the moment the user taps resume.
      ActiveDownloadRegistry.unregister(chapter.id!);
      callback?.call();
      keepAlive.close();
      return;
    }

    // Metadata has resolved successfully. Show preparation/transfer setup
    // from this point rather than leaving a queued item labelled as metadata.
    if (chapterId != null &&
        (pageUrls.isNotEmpty || novelPage != null || m3u8Downloader != null)) {
      _setDownloadStatus(chapterId, 'initializing');
    }

    AppLogger.log(
      '[ch:${chapter.id}] metadata resolved type=${itemType.name} '
      'sources=${pageUrls.length} hasHls=$hasM3U8File directVideo=$nonM3U8File',
      logLevel: LogLevel.info,
      tag: LogTag.download,
    );

    Future<void> buildMangaPagePlan() async {
      mangaPageTasks.clear();
      mangaPagePaths.clear();
      mangaPageCompleted.clear();
      pages.clear();
      final baseHeaders = Map<String, String>.from(
        ref.read(
          headersProvider(
            source: manga.source!,
            lang: manga.lang!,
            sourceId: manga.sourceId,
          ),
        ),
      );
      for (var index = 0; index < pageUrls.length; index++) {
        final page = pageUrls[index];
        final cookie = MClient.getCookiesPref(page.url);
        final pageHeaders = Map<String, String>.from(baseHeaders);
        if (cookie.isNotEmpty) {
          try {
            final userAgent = readSettingsSafely(isar: isar).userAgent;
            pageHeaders.addAll(cookie);
            if (userAgent != null) {
              pageHeaders[HttpHeaders.userAgentHeader] = userAgent;
            }
          } catch (_) {
            pageHeaders.addAll(cookie);
          }
        }
        pageHeaders.addAll(page.headers ?? const {});
        final filePath = p.join(
          chapterDirectory.path,
          '${padIndex(index)}.jpg',
        );
        final task = PageUrl(
          page.url.trim(),
          headers: pageHeaders,
          fileName: filePath,
        );
        final completed = await isReusableDownloadedImage(File(filePath));
        mangaPageTasks.add(task);
        mangaPagePaths.add(filePath);
        mangaPageCompleted.add(completed);
        if (!completed) pages.add(task);
      }

      final previous = chapter.id == null
          ? null
          : MangaDownloadManifest.decode(
              isar.downloads.getSync(chapter.id!)?.pageManifestJson,
            );
      activeMangaManifest = reconcileMangaDownloadManifest(
        chapterUrl: chapter.url,
        pages: mangaPageTasks,
        filePaths: mangaPagePaths,
        completed: mangaPageCompleted,
        previous: previous,
      );
      persistMangaManifest(activeMangaManifest!);
    }

    if (pageUrls.isNotEmpty) {
      final cbzFile = File(
        p.join(mangaMainDirectory!.path, '${chapter.name}.cbz'),
      );
      bool cbzFileExist =
          saveMangaAsCbz &&
          await cbzFile.exists() &&
          (await cbzFile.length()) > 0;
      bool mp4FileExist = await File(
        p.join(mangaMainDirectory.path, "$chapterName.mp4"),
      ).exists();
      bool htmlFileExist = await File(
        p.join(mangaMainDirectory.path, "$chapterName.html"),
      ).exists();
      AppLogger.log(
        '[ch:${chapter.id}] cbzExists=$cbzFileExist mp4Exists=$mp4FileExist '
        'htmlExists=$htmlFileExist dir=${mangaMainDirectory.path}',
        logLevel: LogLevel.debug,
        tag: LogTag.download,
      );
      if ((!cbzFileExist && itemType == ItemType.manga) ||
          (!mp4FileExist && itemType == ItemType.anime) ||
          (!htmlFileExist && itemType == ItemType.novel)) {
        final mainDirectoryRaw = await storageProvider.getDirectory();
        if (mainDirectoryRaw == null) {
          AppLogger.log(
            '[ch:${chapter.id}] ERROR: getDirectory() returned null — check storage permission',
            logLevel: LogLevel.error,
            tag: LogTag.download,
          );
          throw StateError(
            'getDirectory() returned null for chapterId=${chapter.id}',
          );
        }
        final mainDirectory = mainDirectoryRaw;
        AppLogger.log(
          '[ch:${chapter.id}] storage dir: ${mainDirectory.path}',
          logLevel: LogLevel.debug,
          tag: LogTag.download,
        );
        storageProvider.createDirectorySafely(mainDirectory.path);
        if (!kIsWeb && Platform.isAndroid) {
          final noMediaFile = File(p.join(mainDirectory.path, '.nomedia'));
          if (!await noMediaFile.exists()) await noMediaFile.create();
        }
        if (itemType == ItemType.manga) {
          await buildMangaPagePlan();
        } else {
          for (var index = 0; index < pageUrls.length; index++) {
            final page = pageUrls[index];
            final cookie = MClient.getCookiesPref(page.url);
            final headers = itemType == ItemType.anime
                ? videoHeader
                : htmlHeader;
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
            final pageHeaders = Map<String, String>.from(headers)
              ..addAll(page.headers ?? {});
            if (itemType == ItemType.anime) {
              final file = File(
                p.join(mangaMainDirectory.path, '$chapterName.mp4'),
              );
              if (!file.existsSync()) {
                pages.add(
                  PageUrl(
                    page.url.trim(),
                    headers: pageHeaders,
                    fileName: p.join(
                      mangaMainDirectory.path,
                      '$chapterName.mp4',
                    ),
                  ),
                );
              }
            }
          }
        }
      }

      if (activeMangaManifest != null) {
        final alreadyCompleted = activeMangaManifest!.pages
            .where((page) => page.state == MangaPageState.completed)
            .length;
        await setProgress(
          DownloadProgress(
            alreadyCompleted,
            activeMangaManifest!.pages.length,
            ItemType.manga,
          ),
        );
      }

      AppLogger.log(
        '[ch:${chapter.id}] pages to dl: ${pages.length}/${pageUrls.length} '
        '(${pageUrls.length - pages.length} already on disk)',
        logLevel: LogLevel.info,
        tag: LogTag.download,
      );
      if (pages.isEmpty && pageUrls.isNotEmpty) {
        AppLogger.log(
          '[ch:${chapter.id}] all pages already on disk → marking complete',
          logLevel: LogLevel.info,
          tag: LogTag.download,
        );
        await processConvert();
        final total = activeMangaManifest?.pages.length ?? 1;
        await setProgress(
          DownloadProgress(total, total, itemType, isCompleted: true),
        );
      } else {
        // Register internal task for pause/cancel support
        final taskId = '${chapter.id}';
        if (chapter.id != null) {
          ActiveDownloadRegistry.registerInternal(
            chapter.id!,
            taskId,
            itemType: itemType,
            source: manga.source ?? '_unknown',
          );
          ref
              .read(downloadQueueStateProvider.notifier)
              .setEngine(chapter.id!, 'ATLAS');
        }
        AppLogger.log(
          '[ch:' +
              (chapter.id?.toString() ?? '?') +
              '] START ${pages.length} imgs → ' +
              itemType.name,
          logLevel: LogLevel.info,
          tag: LogTag.download,
        );
        // Log up to 3 page URLs so user can verify they are images not HTML
        for (var _li = 0; _li < pages.length && _li < 3; _li++) {
          final _u = pages[_li].url;
          AppLogger.log(
            '[ch:' +
                (chapter.id?.toString() ?? '?') +
                '] url[$_li] ' +
                (_u.length > 90 ? _u.substring(0, 90) + '…' : _u),
            logLevel: LogLevel.debug,
            tag: LogTag.download,
          );
        }
        log(
          '[downloadChapter][manga] starting ${pages.length} pages chapterId=${chapter.id}',
        );
        try {
          if (itemType == ItemType.manga) {
            _setDownloadStatus(chapterId, 'downloading');
          }

          Future<void> downloadCurrentPageList() async {
            final manifest = activeMangaManifest;
            final completedBeforeStart =
                manifest?.pages
                    .where((page) => page.state == MangaPageState.completed)
                    .length ??
                0;
            await MDownloader(
              chapter: chapter,
              pageUrls: pages,
              subtitles: subtitles,
              subDownloadDir: chapterDirectory.path,
              concurrentDownloads: mangaConnections,
              completedBeforeStart: itemType == ItemType.manga
                  ? completedBeforeStart
                  : 0,
              totalPageCount: itemType == ItemType.manga
                  ? manifest?.pages.length
                  : null,
              deferCompletionCallback: itemType == ItemType.manga,
            ).download((progress) {
              if (itemType == ItemType.manga && progress.pageUrl != null) {
                updateMangaPageState(
                  progress.pageUrl!.fileName,
                  progress.downloadedBytes == null
                      ? MangaPageState.completed
                      : MangaPageState.downloading,
                );
              }
              unawaited(setProgress(progress));
            });
          }

          if (itemType == ItemType.manga) {
            var refreshedUrls = false;
            while (true) {
              try {
                await downloadCurrentPageList();
                break;
              } catch (error, stackTrace) {
                markMangaFailure(error);
                final interrupted =
                    chapter.id != null &&
                    ActiveDownloadRegistry.wasInterrupted(chapter.id!);
                if (refreshedUrls || interrupted) {
                  Error.throwWithStackTrace(error, stackTrace);
                }

                refreshedUrls = true;
                try {
                  pageUrls = await fetchFreshChapterPageUrls(
                    chapter: chapter,
                    lang: manga.lang!,
                    sourceName: manga.source!,
                    sourceId: manga.sourceId,
                  ).timeout(const Duration(seconds: 90));
                  pageUrlsForCache = pageUrls;
                  savePageUrls();
                  await buildMangaPagePlan();
                  final refreshedManifest = activeMangaManifest!;
                  final completed = refreshedManifest.pages
                      .where((page) => page.state == MangaPageState.completed)
                      .length;
                  await setProgress(
                    DownloadProgress(
                      completed,
                      refreshedManifest.pages.length,
                      ItemType.manga,
                    ),
                  );
                  if (chapter.id != null &&
                      ActiveDownloadRegistry.wasInterrupted(chapter.id!)) {
                    Error.throwWithStackTrace(error, stackTrace);
                  }
                  if (pages.isEmpty) break;
                } catch (refreshError, refreshStack) {
                  log(
                    '[downloadChapter][manga] URL refresh failed '
                    'chapterId=${chapter.id} error=$refreshError',
                    error: refreshError,
                    stackTrace: refreshStack,
                  );
                  Error.throwWithStackTrace(error, stackTrace);
                }
              }
            }
          } else {
            await downloadCurrentPageList();
          }

          final interruptedByQueueAction =
              chapter.id != null &&
              ActiveDownloadRegistry.wasInterrupted(chapter.id!);
          // MDownloader completion callbacks are void and are not awaited.
          // Manga defers that signal until archive conversion is done, then
          // this awaited update commits the final queue state before returning.
          // The next processDownloads tick (900 ms) then finds the chapter still
          // with isDownload=false → re-queues it → second dispatch causes a
          // "nested transaction" crash on the extension timeout.
          // An awaited final update prevents that race.
          if (!interruptedByQueueAction) {
            await processConvert();
            final total = activeMangaManifest?.pages.length ?? 1;
            await setProgress(
              DownloadProgress(total, total, itemType, isCompleted: true),
            );
            AppLogger.log(
              '[ch:' + (chapter.id?.toString() ?? '?') + '] COMPLETE ✓',
              logLevel: LogLevel.info,
              tag: LogTag.download,
            );
            log('[downloadChapter][manga] completed chapterId=${chapter.id}');
          }
        } catch (e) {
          log(
            '[downloadChapter][manga] FAILED chapterId=${chapter.id} error=$e',
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
              chapter.manga.value!.name!,
              chapter.url!,
            ),
          );
          log(
            '[downloadChapter][novel] getHtmlContent returned ${html.length} chars',
          );
          if (html.isNotEmpty) {
            await file.writeAsString(html);
            log('[downloadChapter][novel] HTML saved');
            await setProgress(
              DownloadProgress(1, 1, itemType, isCompleted: true),
            );
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
            } catch (_) {}
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
          } catch (_) {}
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
        } catch (_) {}
      }
    } else if (hasM3U8File && m3u8Downloader != null) {
      // ── Engine selection ────────────────────────────────────────────────
      await DownloadSettingsService.instance.load();
      final downloadMode = DownloadSettingsService.instance.animeDownloadMode;
      final videoUrl = m3u8Downloader!.m3u8Url;

      final engine = EngineSelector.select(
        url: videoUrl,
        itemType: itemType,
        mode: downloadMode,
      );

      log('[downloadChapter][anime] engine=${engine.badgeLabel} url=$videoUrl');
      if (chapter.id != null) {
        ref
            .read(downloadQueueStateProvider.notifier)
            .setEngine(chapter.id!, engine.badgeLabel);
      }

      if (engine == SelectedEngine.aria2) {
        // ── Aria2 path ──────────────────────────────────────────────────
        log('[downloadChapter][anime/Aria2] starting chapterId=${chapter.id}');
        final aria2Engine = Aria2Engine(
          url: videoUrl,
          outputPath: m3u8Downloader!.fileName,
          headers: m3u8Downloader!.headers ?? {},
          itemType: itemType,
          chapterId: '${chapter.id}',
        );
        if (chapter.id != null) {
          ActiveDownloadRegistry.registerEngine(
            chapter.id!,
            aria2Engine,
            itemType: itemType,
            source: manga.source ?? '_unknown',
          );
        }
        bool aria2Failed = false;
        try {
          await aria2Engine.start((progress) => setProgress(progress));
          log(
            '[downloadChapter][anime/Aria2] completed chapterId=${chapter.id}',
          );
        } catch (e) {
          aria2Failed = true;
          log(
            '[downloadChapter][anime/Aria2] FAILED chapterId=${chapter.id} error=$e',
          );
        } finally {
          if (chapter.id != null) {
            ActiveDownloadRegistry.unregister(chapter.id!);
          }
        }
        // Aria2 cannot do HLS — fall back to internal HLS for .m3u8 streams
        if (aria2Failed) {
          log(
            '[downloadChapter][anime/Aria2→HLS] falling back to internal HLS chapterId=${chapter.id}',
          );
          if (chapter.id != null) {
            ref
                .read(downloadQueueStateProvider.notifier)
                .setEngine(chapter.id!, 'HLS');
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
          log('[downloadChapter][anime/HLS] completed chapterId=${chapter.id}');
        } catch (e) {
          caughtError = e;
          log(
            '[downloadChapter][anime/HLS] FAILED chapterId=${chapter.id} '
            'error=$e',
          );
        } finally {
          if (chapter.id != null) {
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
          } catch (_) {}
          throw caughtError;
        }
      }
    }

    callback?.call();
    keepAlive.close();
  } catch (e, st) {
    // Always fire the callback even on error so processDownloads can unblock
    // its slot counter and exit cleanly instead of looping forever.
    log('[downloadChapter] UNCAUGHT ERROR chapterId=${chapter.id}: $e\n$st');
    _notifyDownloadFailure(friendlyErrorMessage(e));
    AppLogger.log(
      '[ch:${chapter.id}] CRASH: $e',
      logLevel: LogLevel.error,
      tag: LogTag.download,
    );
    // Mark as failed so processDownloads does NOT re-queue endlessly.
    // Without this, any uncaught exception leaves the chapter as
    // isDownload=false + isStartDownload=true in Isar → infinite retry loop.
    if (chapter.id != null) {
      unawaited(
        WatchtowerNotificationService.instance.markMediaDownloadFailed(
          chapter.id!,
          seriesTitle: mangaForRegistry?.name ?? chapter.name ?? '',
          chapterTitle: chapter.name ?? 'Téléchargement',
          itemType: mangaForRegistry?.itemType.name ?? ItemType.manga.name,
        ),
      );
      try {
        final dl = isar.downloads.getSync(chapter.id!);
        if (dl != null) {
          isar.writeTxnSync(() {
            isar.downloads.putSync(
              dl
                ..failed = 1
                ..isDownload = false
                ..status = 'failed'
                // Stop infinite retry — leave isStartDownload=false so
                // processDownloads skips this chapter until user retries.
                ..isStartDownload = false,
            );
          });
        }
      } catch (_) {}
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
  String? lastQueueWaitState;
  log('[processDownloads] scheduler started');
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
        log(
          '[processDownloads] tick error (ignored, next tick retries): $e\n$st',
        );
        try {
          final ids = (await isar.downloads.where().idProperty().findAll())
              .whereType<int>();
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
      await Future.delayed(const Duration(milliseconds: 900));
      return safeTick(() async {
        // ── Re-query Isar fresh every tick ────────────────────────────────────
        // This is the key fix: we never take a snapshot of the queue.  Paused
        // chapters that are later resumed, newly added downloads, and completed
        // downloads are all naturally handled because we look at the live DB
        // state on every iteration instead of a stale list built at startup.
        // isar_community rejects filters on these nullable bool properties at
        // runtime ("Property does not support this filter"). Read the
        // collection and apply the same predicate in Dart.
        final ongoingRaw = isar.downloads
            .where()
            .findAllSync()
            .where(_isPendingDownload)
            .toList();

        final stalePendingRows = <Download>[];
        for (final dl in ongoingRaw) {
          // Older pause/resume paths could leave a durable "queued" status with
          // isStartDownload=false. Repair the flags before dispatch so the queue
          // remains recoverable if the app is closed again.
          if (dl.isStartDownload != true &&
              _pendingDownloadStatuses.contains(dl.status) &&
              dl.id != null &&
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
              AppLogger.log(
                '[ch:${dl.id}] restored pending state from status=${dl.status}',
                logLevel: LogLevel.warning,
                tag: LogTag.download,
              );
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
            } catch (_) {}
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
          return !pausedIds.contains(chId) &&
              !ActiveDownloadRegistry.isActive(chId);
        }).toList();
        if (ongoingRaw.isNotEmpty && toStart.isEmpty) {
          final pausedCount = ongoingRaw
              .where((d) => pausedIds.contains(d.chapter.value?.id))
              .length;
          final activeCount = ongoingRaw
              .where(
                (d) =>
                    ActiveDownloadRegistry.isActive(d.chapter.value?.id ?? -1),
              )
              .length;
          final waitState =
              'pending=${ongoingRaw.length} paused=$pausedCount active=$activeCount';
          if (waitState != lastQueueWaitState) {
            log('[processDownloads] no eligible item: $waitState');
            lastQueueWaitState = waitState;
          }
        } else {
          lastQueueWaitState = null;
        }

        // ── Speed Master: high-priority downloads start first ────────────────
        // Stable sort: within the same priority the original (FIFO-ish) Isar
        // order is preserved. Re-read every tick so toggling priority in the
        // queue UI applies immediately without restarting the scheduler.
        final prioMap = ref.read(downloadQueueStateProvider).priorities;
        toStart.sort(
          (a, b) => (prioMap[b.chapter.value?.id ?? -1] ?? 0).compareTo(
            prioMap[a.chapter.value?.id ?? -1] ?? 0,
          ),
        );

        final effectiveUseWifi =
            _processDownloadsWifiOverride ??
            (useWifi ?? (ref.read(onlyOnWifiStateProvider) == true));
        final onlyOnWifi = effectiveUseWifi;
        if (onlyOnWifi && toStart.isNotEmpty) {
          bool isOnWifi = false;
          try {
            isOnWifi = hasWifiOrEthernet(
              await Connectivity().checkConnectivity(),
            );
          } catch (e) {
            log('[processDownloads] connectivity check failed: $e');
          }
          if (!isOnWifi) {
            for (final download in toStart) {
              _setDownloadStatus(download.id, 'waiting_wifi');
            }
            log(
              '[processDownloads] ${toStart.length} item(s) waiting for Wi-Fi',
            );
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
        };
        final typePerSrcMax = <ItemType, int>{
          ItemType.manga:
              DownloadSettingsService.instance.mangaSimultaneousPerSource,
          ItemType.anime:
              DownloadSettingsService.instance.watchSimultaneousPerSource,
          ItemType.novel:
              DownloadSettingsService.instance.novelSimultaneousPerSource,
        };

        // ── Start downloads that fit within the limits ─────────────────────────
        // Cross-source round-robin: interleave sources fairly.
        final perSourceQueues = <String, List<Download>>{};
        for (final d in toStart) {
          final src = d.chapter.value?.manga.value?.source ?? '_unknown';
          (perSourceQueues[src] ??= <Download>[]).add(d);
        }
        final sourceKeys = perSourceQueues.keys.toList();
        int rrIdx = 0;

        outer:
        for (var attempt = 0; attempt < toStart.length; attempt++) {
          // Round-robin over sources
          final src = sourceKeys[rrIdx % sourceKeys.length];
          rrIdx++;

          final queue = perSourceQueues[src];
          if (queue == null || queue.isEmpty) continue;

          final d = queue.first;
          final chapter = d.chapter.value;
          if (chapter == null) {
            queue.removeAt(0);
            continue;
          }

          final type = chapter.manga.value?.itemType ?? ItemType.manga;
          final chSrc = chapter.manga.value?.source ?? '_unknown';

          // Check live counts from the registry (not local counters — those go
          // stale after pause/resume because isolates exit without a callback).
          final curType = ActiveDownloadRegistry.activeCountForType(type);
          final curSrc = ActiveDownloadRegistry.activeCountForSource(
            type,
            chSrc,
          );
          // Fallback of 2 instead of 1: an unknown ItemType should not
          // single-thread the queue; 2 is a sane conservative default.
          final tLimit = typeMax[type] ?? 2;
          final sLimit = typePerSrcMax[type] ?? 2;

          if (curType >= tLimit || curSrc >= sLimit) {
            final chapterId = chapter.id;
            if (chapterId != null && loggedConcurrencyBlocks.add(chapterId)) {
              AppLogger.log(
                '[ch:$chapterId] waiting for concurrency slot '
                'type=${type.name} active=$curType/$tLimit '
                'source=$curSrc/$sLimit',
                logLevel: LogLevel.debug,
                tag: LogTag.download,
              );
            }
            continue outer;
          }
          if (chapter.id != null) {
            loggedConcurrencyBlocks.remove(chapter.id!);
          }

          queue.removeAt(0);
          if (d.status == 'waiting_wifi' || d.status == 'queued') {
            _setDownloadStatus(d.id, 'fetching_metadata');
          }

          AppLogger.log(
            'Queue dispatch [ch:${chapter.id}] type=${type.name} '
            'source=$chSrc active=$curType/$tLimit sourceActive=$curSrc/$sLimit',
            logLevel: LogLevel.info,
            tag: LogTag.download,
          );

          // Small stagger to avoid thundering herd on the remote server.
          await Future.delayed(const Duration(milliseconds: 150));

          // Start the download. Its worker claims the registry slot before its
          // first await, so another scheduler cannot launch the same chapter.
          ref.read(
            downloadChapterProvider(
              chapter: chapter,
              useWifi: effectiveUseWifi,
            ),
          );
        }

        return true; // keep polling
      });
    });
  } finally {
    // Always release the wakelock and stop the foreground service, whether
    // the queue drained normally, threw, or was cancelled.
    keepAlive.close();
    unawaited(BackgroundKeepAlive.stop());
    _processDownloadsSchedulerRunning = false;
    _processDownloadsWifiOverride = null;
  }
}
