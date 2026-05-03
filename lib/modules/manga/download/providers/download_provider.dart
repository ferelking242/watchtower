import 'dart:convert';
import 'dart:developer';
import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'dart:ui';
import 'package:connectivity_plus/connectivity_plus.dart';
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
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/providers/storage_provider.dart';
import 'package:watchtower/router/router.dart';
import 'package:watchtower/services/download_manager/active_download_registry.dart';
import 'package:watchtower/services/download_manager/external_downloader_launcher.dart';
import 'package:watchtower/services/download_manager/m_downloader.dart';
import 'package:watchtower/services/get_video_list.dart';
import 'package:watchtower/services/get_chapter_pages.dart';
import 'package:watchtower/services/http/m_client.dart';
import 'package:watchtower/services/download_manager/m3u8/m3u8_downloader.dart';
import 'package:watchtower/services/download_manager/m3u8/models/download.dart';
import 'package:watchtower/services/download_manager/download_settings_service.dart';
import 'package:watchtower/services/download_manager/engine_selector.dart';
import 'package:watchtower/services/download_manager/engines/aria2_engine.dart';
import 'package:watchtower/services/download_manager/engines/zeus_dl_engine.dart';
import 'package:watchtower/services/download_manager/stuck_watchdog.dart';
import 'package:watchtower/utils/chapter_recognition.dart';
import 'package:watchtower/utils/extensions/chapter.dart';
import 'package:watchtower/utils/extensions/string_extensions.dart';
import 'package:watchtower/utils/headers.dart';
import 'package:watchtower/utils/log/logger.dart';
import 'package:watchtower/utils/reg_exp_matcher.dart';
import 'package:watchtower/utils/utils.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'download_provider.g.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

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
    final result =
        await ref.read(getVideoListProvider(episode: chapter).future);
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: _QualityPickerDialog(
            directVideos: directVideos,
            extractedVideos: extractedVideos,
            preferredExternalDownloader: DownloadSettingsService
                .instance.preferredExternalDownloader ?? '',
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
                TextButton(
                  onPressed: onCancel,
                  child: const Text('Annuler'),
                ),
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
        final isM3u8 = urlClean.toLowerCase().endsWith('.m3u8') ||
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
                      ? Colors.purple.withOpacity(0.15)
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
                    child: Icon(Icons.download_rounded, color: cs.primary, size: 22),
                  ),
                ),
              ),
              // Open in external downloader
              if (Platform.isAndroid)
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

@riverpod
Future<void> addDownloadToQueue(Ref ref, {required Chapter chapter}) async {
  final download = isar.downloads.getSync(chapter.id!);
  if (download == null) {
    final download = Download(
      id: chapter.id,
      succeeded: 0,
      failed: 0,
      total: 100,
      isDownload: false,
      isStartDownload: true,
    );
    isar.writeTxnSync(() {
      isar.downloads.putSync(download..chapter.value = chapter);
    });
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
  // Held outside the try so we can guarantee the periodic Timer is
  // cancelled on success, on error AND on early-return — otherwise a
  // failed segment download would leave the watchdog logging
  // "STUCK | no progress for Ns" forever long after the chapter has
  // already been marked failed.
  DownloadStuckWatchdog? watchdogRef;

  try {
    bool onlyOnWifi = useWifi ?? ref.read(onlyOnWifiStateProvider);
    final connectivity = await Connectivity().checkConnectivity();
    final isOnWifi =
        connectivity.contains(ConnectivityResult.wifi) ||
        connectivity.contains(ConnectivityResult.ethernet);
    if (onlyOnWifi && !isOnWifi) {
      botToast(navigatorKey.currentContext!.l10n.downloads_are_limited_to_wifi);
      return;
    }

    final http = MClient.init(
      reqcopyWith: {'useDartHttpClient': true, 'followRedirects': false},
    );

    // ── Per-type connection settings ────────────────────────────────────────
    final mangaConnections = ref.read(mangaConnectionsStateProvider);
    final animeConnections = ref.read(animeConnectionsStateProvider);

    List<PageUrl> pageUrls = [];
    PageUrl? novelPage;
    List<PageUrl> pages = [];
    final StorageProvider storageProvider = StorageProvider();
    await storageProvider.requestPermission();
    final mangaMainDirectory = await storageProvider.getMangaMainDirectory(
      chapter,
    );
    List<Track>? subtitles;
    bool isOk = false;
    final manga = chapter.manga.value!;
    final chapterName = chapter.name!.replaceForbiddenCharacters(' ');
    final itemType = chapter.manga.value!.itemType;
    final chapterDirectory = (await storageProvider.getMangaChapterDirectory(
      chapter,
      mangaMainDirectory: mangaMainDirectory,
    ))!;
    await storageProvider.createDirectorySafely(chapterDirectory.path);
    Map<String, String> videoHeader = {};
    Map<String, String> htmlHeader = {
      "Priority": "u=0, i",
      "User-Agent":
          "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/117.0.0.0 Safari/537.36",
    };
    bool hasM3U8File = false;
    bool nonM3U8File = false;
    M3u8Downloader? m3u8Downloader;

    Future<void> processConvert() async {
      if (!ref.read(saveAsCBZArchiveStateProvider)) return;
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
            pages.map((e) => e.fileName!).toList(),
            comicInfo: comicInfo,
          ).future,
        );
      } catch (error) {
        botToast('Erreur lors de la création du CBZ : ${friendlyErrorMessage(error)}');
      }
    }

    final stuckWatchdog = DownloadStuckWatchdog(
      label: 'chapter=${chapter.id} (${itemType.name})',
    );
    watchdogRef = stuckWatchdog;
    stuckWatchdog.start();

    Future<void> setProgress(DownloadProgress progress) async {
      if (progress.total > 0) {
        final pct = (progress.completed / progress.total * 100).toInt();
        stuckWatchdog.markDownloading();
        stuckWatchdog.notifyProgress(pct);

        // Extreme-mode: emit a per-page/per-segment trace so every unit of
        // work is visible in the log without flooding normal sessions.
        if (AppLogger.isExtremeMode) {
          AppLogger.log(
            '[ch:${chapter.id}] page ${progress.completed}/${progress.total} ($pct%) '
            '• type=${progress.itemType.name}',
            logLevel: LogLevel.debug,
            tag: LogTag.page,
          );
        }
      }
      if (progress.isCompleted) stuckWatchdog.stop();
      if (progress.isCompleted && itemType == ItemType.manga) {
        await processConvert();
      }
      final download = isar.downloads.getSync(chapter.id!);
      if (download == null) {
        final download = Download(
          id: chapter.id,
          succeeded: progress.completed == 0
              ? 0
              : (progress.completed / progress.total * 100).toInt(),
          failed: 0,
          total: 100,
          isDownload: progress.isCompleted,
          isStartDownload: true,
        );
        isar.writeTxnSync(() {
          isar.downloads.putSync(download..chapter.value = chapter);
        });
      } else {
        final download = isar.downloads.getSync(chapter.id!);
        if (download != null && progress.total != 0) {
          isar.writeTxnSync(() {
            isar.downloads.putSync(
              download
                ..succeeded = progress.completed == 0
                    ? 0
                    : (progress.completed / progress.total * 100).toInt()
                ..total = 100
                ..failed = 0
                ..isDownload = progress.isCompleted,
            );
          });
        }
      }
    }

    setProgress(DownloadProgress(0, 0, itemType));

    void savePageUrls() {
      final settings = isar.settings.getSync(227)!;
      List<ChapterPageurls>? chapterPageUrls = [];
      for (var chapterPageUrl in settings.chapterPageUrlsList ?? []) {
        if (chapterPageUrl.chapterId != chapter.id) {
          chapterPageUrls.add(chapterPageUrl);
        }
      }
      final chapterPageHeaders = pageUrls
          .map((e) => e.headers == null ? null : jsonEncode(e.headers))
          .toList();
      chapterPageUrls.add(
        ChapterPageurls()
          ..chapterId = chapter.id
          ..urls = pageUrls.map((e) => e.url).toList()
          ..chapterUrl = chapter.url
          ..headers = chapterPageHeaders.first != null
              ? chapterPageHeaders.map((e) => e.toString()).toList()
              : null,
      );
      isar.writeTxnSync(
        () => isar.settings.putSync(
          settings
            ..chapterPageUrlsList = chapterPageUrls
            ..updatedAt = DateTime.now().millisecondsSinceEpoch,
        ),
      );
    }

    String? fetchError;

    if (itemType == ItemType.manga) {
      ref
          .read(getChapterPagesProvider(chapter: chapter).future)
          .then((value) {
            if (value.pageUrls.isNotEmpty) {
              pageUrls = value.pageUrls;
              isOk = true;
            } else {
              fetchError = 'getChapterPages returned empty list';
              isOk = true;
            }
          })
          .catchError((e, st) {
            fetchError = friendlyErrorMessage(e);
            isOk = true;
            log('[downloadChapter][manga] getChapterPages error: $e', error: e, stackTrace: st);
          });
    } else if (itemType == ItemType.anime) {
      ref.read(getVideoListProvider(episode: chapter).future).then((
        value,
      ) async {
        // Detect HLS streams smarter: not every HLS URL ends in .m3u8
        // (e.g. xnxx CDN URLs are tokenized). We also flag a URL as HLS
        // when its host or path hints at HLS, when its quality label
        // mentions HLS, or when the explicit .m3u8 extension is present.
        bool _looksLikeHls(dynamic v) {
          final u = (v.originalUrl ?? '').toString().toLowerCase();
          if (u.endsWith('.m3u8') || u.endsWith('.m3u')) return true;
          if (u.contains('.m3u8') || u.contains('/hls/') ||
              u.contains('hls-cdn') || u.contains('hls.')) return true;
          final q = (v.quality ?? '').toString().toLowerCase();
          if (q.contains('hls') || q.contains('auto')) return true;
          return false;
        }
        final m3u8Urls = value.$1.where(_looksLikeHls).toList();
        final nonM3u8Urls = value.$1
            .where((element) => !_looksLikeHls(element) && element.originalUrl.isMediaVideo())
            .toList();
        nonM3U8File = nonM3u8Urls.isNotEmpty;
        hasM3U8File = nonM3U8File ? false : m3u8Urls.isNotEmpty;
        var videosUrls = nonM3U8File ? nonM3u8Urls : m3u8Urls;
        // Honour the user's quality pick from the picker dialog (if any):
        // move the chosen Video to the front of the list so that
        // `videosUrls.first` below picks it.
        final preferredOriginal =
            chapter.id != null ? chapterPreferredOriginalUrl[chapter.id!] : null;
        if (preferredOriginal != null && videosUrls.isNotEmpty) {
          final idx = videosUrls
              .indexWhere((v) => v.originalUrl == preferredOriginal);
          if (idx > 0) {
            final picked = videosUrls.removeAt(idx);
            videosUrls = [picked, ...videosUrls];
          }
          // One-shot: clear so a future re-download asks again.
          chapterPreferredOriginalUrl.remove(chapter.id!);
        }
        if (videosUrls.isNotEmpty) {
          subtitles = videosUrls.first.subtitles;

          final videoUri = Uri.tryParse(videosUrls.first.originalUrl);
          final referer = videoUri != null
              ? '${videoUri.scheme}://${videoUri.host}'
              : null;

          if (hasM3U8File) {
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
          }
          videoHeader.addAll(videosUrls.first.headers ?? {});
          isOk = true;
        } else {
          fetchError = 'getVideoList returned no playable URLs';
          isOk = true;
        }
      }).catchError((e, st) {
        fetchError = friendlyErrorMessage(e);
        isOk = true;
        log('[downloadChapter][anime] getVideoList error: $e', error: e, stackTrace: st);
      });
    } else if (itemType == ItemType.novel && chapter.url != null) {
      final manga = chapter.manga.value!;
      final source = getSource(manga.lang!, manga.source!, manga.sourceId)!;
      final chapterUrl = "${source.baseUrl}${chapter.url!.getUrlWithoutDomain}";
      final cookie = MClient.getCookiesPref(chapterUrl);
      final headers = htmlHeader;
      if (cookie.isNotEmpty) {
        final userAgent = isar.settings.getSync(227)!.userAgent!;
        headers.addAll(cookie);
        headers[HttpHeaders.userAgentHeader] = userAgent;
      }
      final res = await http.get(Uri.parse(chapterUrl), headers: headers);
      if (res.headers.containsKey("Location")) {
        novelPage = PageUrl(res.headers["Location"]!);
      } else {
        novelPage = PageUrl(chapterUrl);
      }
      isOk = true;
    }

    // Wait for async fetch (manga/anime) with a hard 90-second timeout so
    // downloads never hang at 0% indefinitely.
    const maxWaitTicks = 90;
    var waitTicks = 0;
    await Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (isOk == true) return false;
      waitTicks++;
      if (waitTicks >= maxWaitTicks) {
        fetchError = 'Fetch timed out after ${maxWaitTicks}s — source returned no data';
        log('[downloadChapter] timeout after ${maxWaitTicks}s for chapterId=${chapter.id}');
        isOk = true;
        return false;
      }
      return true;
    });

    // If the fetch failed (exception, empty result, or timeout), mark failed and abort.
    if (fetchError != null) {
      log('[downloadChapter] aborting — fetch error: $fetchError');
      await isar.writeTxn(() async {
        final dl = isar.downloads.getSync(chapter.id!);
        if (dl != null) {
          isar.downloads.putSync(
            dl
              ..failed = (dl.failed ?? 0) + 1
              ..isDownload = false,
          );
        }
      });
      return;
    }

    log('[downloadChapter] itemType=$itemType chapterId=${chapter.id} chapterName=$chapterName');
    log('[downloadChapter] pageUrls=${pageUrls.length} novelPage=$novelPage hasM3U8=$hasM3U8File nonM3U8=$nonM3U8File');

    if (pageUrls.isNotEmpty) {
      bool cbzFileExist =
          await File(
            p.join(mangaMainDirectory!.path, "${chapter.name}.cbz"),
          ).exists() &&
          ref.read(saveAsCBZArchiveStateProvider);
      bool mp4FileExist = await File(
        p.join(mangaMainDirectory.path, "$chapterName.mp4"),
      ).exists();
      bool htmlFileExist = await File(
        p.join(mangaMainDirectory.path, "$chapterName.html"),
      ).exists();
      if (!cbzFileExist && itemType == ItemType.manga ||
          !mp4FileExist && itemType == ItemType.anime ||
          !htmlFileExist && itemType == ItemType.novel) {
        final mainDirectory = (await storageProvider.getDirectory())!;
        storageProvider.createDirectorySafely(mainDirectory.path);
        for (var index = 0; index < pageUrls.length; index++) {
          if (Platform.isAndroid) {
            if (!(await File(
              p.join(mainDirectory.path, ".nomedia"),
            ).exists())) {
              await File(p.join(mainDirectory.path, ".nomedia")).create();
            }
          }
          final page = pageUrls[index];
          final cookie = MClient.getCookiesPref(page.url);
          final headers = itemType == ItemType.manga
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
          if (cookie.isNotEmpty) {
            final userAgent = isar.settings.getSync(227)!.userAgent!;
            headers.addAll(cookie);
            headers[HttpHeaders.userAgentHeader] = userAgent;
          }
          Map<String, String> pageHeaders = headers;
          pageHeaders.addAll(page.headers ?? {});

          if (itemType == ItemType.manga) {
            final file = File(
              p.join(chapterDirectory.path, "${padIndex(index)}.jpg"),
            );
            if (!file.existsSync()) {
              pages.add(
                PageUrl(
                  page.url.trim(),
                  headers: pageHeaders,
                  fileName: p.join(
                    chapterDirectory.path,
                    "${padIndex(index)}.jpg",
                  ),
                ),
              );
            }
          } else if (itemType == ItemType.anime) {
            final file = File(
              p.join(mangaMainDirectory.path, "$chapterName.mp4"),
            );
            if (!file.existsSync()) {
              pages.add(
                PageUrl(
                  page.url.trim(),
                  headers: pageHeaders,
                  fileName: p.join(mangaMainDirectory.path, "$chapterName.mp4"),
                ),
              );
            }
          }
        }
      }

      if (pages.isEmpty && pageUrls.isNotEmpty) {
        await processConvert();
        savePageUrls();
        await setProgress(DownloadProgress(1, 1, itemType, isCompleted: true));
      } else {
        savePageUrls();

        // Register internal task for pause/cancel support
        final taskId = '${chapter.id}';
        if (chapter.id != null) {
          ActiveDownloadRegistry.registerInternal(chapter.id!, taskId);
          ref
              .read(downloadQueueStateProvider.notifier)
              .setEngine(chapter.id!, 'IMG');
        }
        log('[downloadChapter][manga] starting ${pages.length} pages chapterId=${chapter.id}');
        try {
          await MDownloader(
            chapter: chapter,
            pageUrls: pages,
            subtitles: subtitles,
            subDownloadDir: chapterDirectory.path,
            concurrentDownloads: mangaConnections,
          ).download((progress) {
            setProgress(progress);
          });
          log('[downloadChapter][manga] completed chapterId=${chapter.id}');
        } catch (e) {
          log('[downloadChapter][manga] FAILED chapterId=${chapter.id} error=$e');
          rethrow;
        } finally {
          if (chapter.id != null) {
            ActiveDownloadRegistry.unregister(chapter.id!);
          }
        }
      }
    } else if (itemType == ItemType.novel) {
      final file = File(p.join(chapterDirectory.path, "$chapterName.html"));
      log('[downloadChapter][novel] target=${file.path} exists=${file.existsSync()} novelPage=$novelPage');
      if (!file.existsSync() && novelPage != null) {
        final source = getSource(manga.lang!, manga.source!, manga.sourceId)!;
        log('[downloadChapter][novel] calling getHtmlContent url=${chapter.url}');
        try {
          final html = await withExtensionService(
            source,
            ref.read(androidProxyServerStateProvider),
            (service) => service.getHtmlContent(
              chapter.manga.value!.name!,
              chapter.url!,
            ),
          );
          log('[downloadChapter][novel] getHtmlContent returned ${html.length} chars');
          if (html.isNotEmpty) {
            await file.writeAsString(html);
            log('[downloadChapter][novel] HTML saved to ${file.path}');
            await setProgress(
              DownloadProgress(1, 1, itemType, isCompleted: true),
            );
          } else {
            log('[downloadChapter][novel] ERROR: getHtmlContent returned empty string for ${chapter.url}');
            // Mark as failed so the user can retry
            final dl = isar.downloads.getSync(chapter.id!);
            if (dl != null) {
              isar.writeTxnSync(() {
                isar.downloads.putSync(dl..failed = 1);
              });
            }
          }
        } catch (e, st) {
          log('[downloadChapter][novel] EXCEPTION in getHtmlContent: $e\n$st');
          final dl = isar.downloads.getSync(chapter.id!);
          if (dl != null) {
            isar.writeTxnSync(() {
              isar.downloads.putSync(dl..failed = 1);
            });
          }
        }
      } else if (file.existsSync()) {
        log('[downloadChapter][novel] file already exists, marking complete');
        await setProgress(DownloadProgress(1, 1, itemType, isCompleted: true));
      } else {
        log('[downloadChapter][novel] novelPage is null — nothing to download for ${chapter.url}');
        final dl = isar.downloads.getSync(chapter.id!);
        if (dl != null) {
          isar.writeTxnSync(() {
            isar.downloads.putSync(dl..failed = 1);
          });
        }
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
          ActiveDownloadRegistry.registerEngine(chapter.id!, aria2Engine);
        }
        bool aria2Failed = false;
        try {
          await aria2Engine.start((progress) => setProgress(progress));
          log('[downloadChapter][anime/Aria2] completed chapterId=${chapter.id}');
        } catch (e) {
          aria2Failed = true;
          log('[downloadChapter][anime/Aria2] FAILED chapterId=${chapter.id} error=$e');
        } finally {
          if (chapter.id != null) {
            ActiveDownloadRegistry.unregister(chapter.id!);
          }
        }
        // Aria2 cannot do HLS — fall back to internal HLS for .m3u8 streams
        if (aria2Failed) {
          log('[downloadChapter][anime/Aria2→HLS] falling back to internal HLS chapterId=${chapter.id}');
          if (chapter.id != null) {
            ref
                .read(downloadQueueStateProvider.notifier)
                .setEngine(chapter.id!, 'HLS');
          }
          final taskId = 'm3u8_${chapter.id}';
          if (chapter.id != null) {
            ActiveDownloadRegistry.registerInternal(chapter.id!, taskId);
          }
          try {
            await m3u8Downloader!.download(
              (progress) => setProgress(progress),
            );
          } finally {
            if (chapter.id != null) {
              ActiveDownloadRegistry.unregister(chapter.id!);
            }
          }
        }
      } else if (engine == SelectedEngine.zeusDl) {
        // ── ZeusDL path ─────────────────────────────────────────────────
        log('[downloadChapter][anime/ZeusDL] starting chapterId=${chapter.id}');
        final zeusEngine = ZeusDlEngine(
          url: videoUrl,
          outputPath: m3u8Downloader!.fileName,
          headers: m3u8Downloader!.headers ?? {},
          itemType: itemType,
          chapterId: '${chapter.id}',
        );

        if (chapter.id != null) {
          ActiveDownloadRegistry.registerEngine(chapter.id!, zeusEngine);
        }

        bool zeusFailed = false;
        try {
          await zeusEngine.start((progress) => setProgress(progress));
          log('[downloadChapter][anime/ZeusDL] completed chapterId=${chapter.id}');
        } catch (e) {
          zeusFailed = true;
          log('[downloadChapter][anime/ZeusDL] FAILED chapterId=${chapter.id} error=$e');
        } finally {
          if (chapter.id != null) {
            ActiveDownloadRegistry.unregister(chapter.id!);
          }
        }

        // Fallback to internal HLS if ZeusDL failed and mode allows it
        if (zeusFailed && downloadMode != DownloadMode.zeusDl) {
          log('[downloadChapter][anime/ZeusDL→HLS] falling back to internal HLS chapterId=${chapter.id}');
          if (chapter.id != null) {
            ref
                .read(downloadQueueStateProvider.notifier)
                .setEngine(chapter.id!, 'HLS');
          }
          final taskId = 'm3u8_${chapter.id}';
          if (chapter.id != null) {
            ActiveDownloadRegistry.registerInternal(chapter.id!, taskId);
          }
          try {
            await m3u8Downloader!.download(
              (progress) => setProgress(progress),
            );
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
          ActiveDownloadRegistry.registerInternal(chapter.id!, taskId);
        }

        Object? caughtError;
        try {
          await m3u8Downloader!.download((progress) => setProgress(progress));
          log('[downloadChapter][anime/HLS] completed chapterId=${chapter.id}');
        } catch (e) {
          caughtError = e;
          log(
            '[downloadChapter][anime/HLS] FAILED chapterId=${chapter.id} '
            'error=$e — will try ZeusDL fallback if mode allows',
          );
        } finally {
          if (chapter.id != null) {
            ActiveDownloadRegistry.unregister(chapter.id!);
          }
        }

        // Fallback to ZeusDL on internal failure. The previous version
        // had `if (caughtError != null && false)` which made this branch
        // dead code — that's why HLS failures were never recovered. We
        // re-enable the fallback unconditionally for `auto` mode (any
        // mode other than the user explicitly choosing HLS-only).
        if (caughtError != null) {
          if (downloadMode == DownloadMode.internalDownloader) {
            // User pinned the internal HLS engine — surface the error
            // so the chapter is marked failed and the user can retry.
            log(
              '[downloadChapter][anime/HLS→fail] mode=internalDownloader, '
              'no fallback. chapterId=${chapter.id}',
            );
            // Mark the Isar record as failed so the UI can offer retry.
            final dl = isar.downloads.getSync(chapter.id!);
            if (dl != null) {
              isar.writeTxnSync(() {
                isar.downloads.putSync(dl..failed = 1);
              });
            }
            throw caughtError;
          }
          log(
            '[downloadChapter][anime/HLS→ZeusDL] internal HLS failed, '
            'falling back to ZeusDL chapterId=${chapter.id}',
          );
          if (chapter.id != null) {
            ref
                .read(downloadQueueStateProvider.notifier)
                .setEngine(chapter.id!, 'ZDL');
          }
          final zeusEngine = ZeusDlEngine(
            url: videoUrl,
            outputPath: m3u8Downloader!.fileName,
            headers: m3u8Downloader!.headers ?? {},
            itemType: itemType,
            chapterId: '${chapter.id}',
          );
          if (chapter.id != null) {
            ActiveDownloadRegistry.registerEngine(chapter.id!, zeusEngine);
          }
          try {
            await zeusEngine.start((progress) => setProgress(progress));
            log(
              '[downloadChapter][anime/HLS→ZeusDL] fallback succeeded '
              'chapterId=${chapter.id}',
            );
          } catch (e) {
            log(
              '[downloadChapter][anime/HLS→ZeusDL] fallback ALSO failed '
              'chapterId=${chapter.id} error=$e',
            );
            final dl = isar.downloads.getSync(chapter.id!);
            if (dl != null) {
              isar.writeTxnSync(() {
                isar.downloads.putSync(dl..failed = 1);
              });
            }
            rethrow;
          } finally {
            if (chapter.id != null) {
              ActiveDownloadRegistry.unregister(chapter.id!);
            }
          }
        }
      }
    }

    if (callback != null) {
      callback();
    }
    keepAlive.close();
  } catch (_) {
    keepAlive.close();
  } finally {
    // Cancel the periodic Timer no matter how we exit, so a failed
    // download stops spamming "STUCK" warnings in the log viewer.
    watchdogRef?.stop();
  }
}

@riverpod
Future<void> processDownloads(Ref ref, {bool? useWifi}) async {
  final keepAlive = ref.keepAlive();
  try {
    final ongoingDownloads = await isar.downloads
        .filter()
        .idIsNotNull()
        .isDownloadEqualTo(false)
        .isStartDownloadEqualTo(true)
        .findAll();

    // Skip chapters that are currently paused
    final pausedIds = ref.read(downloadQueueStateProvider).pausedIds;
    // Also skip downloads already actively running to avoid double-start / flicker
    final activeDownloads = ongoingDownloads
        .where(
          (d) =>
              d.chapter.value?.id == null ||
              (!pausedIds.contains(d.chapter.value!.id) &&
                  !ActiveDownloadRegistry.isActive(d.chapter.value!.id!)),
        )
        .toList();

    log('[processDownloads] total=${ongoingDownloads.length} paused=${pausedIds.length} toStart=${activeDownloads.length}');

    final maxConcurrentDownloads = ref.read(concurrentDownloadsStateProvider);

    // ── Cross-source round-robin scheduling ─────────────────────────────────
    // The previous implementation walked `activeDownloads` linearly which
    // meant: queue 3 xnxx + 4 pornhub + 2 redtube → all 3 xnxx start, then
    // pornhub, then redtube. We instead group by source name and pull one
    // download from each non-empty source per pick — so different sites
    // download in parallel from their first chapter, instead of one site
    // hogging the global cap.
    final perSourceQueues = <String, List<Download>>{};
    for (final d in activeDownloads) {
      final src = d.chapter.value?.manga.value?.source ?? '_unknown';
      (perSourceQueues[src] ??= <Download>[]).add(d);
    }
    final sourceOrder = perSourceQueues.keys.toList();
    int rrIdx = 0;
    Download? nextPick() {
      if (sourceOrder.isEmpty) return null;
      for (var attempts = 0; attempts < sourceOrder.length; attempts++) {
        final src = sourceOrder[rrIdx % sourceOrder.length];
        rrIdx++;
        final queue = perSourceQueues[src];
        if (queue != null && queue.isNotEmpty) {
          return queue.removeAt(0);
        }
      }
      return null;
    }

    int downloaded = 0;
    int current = 0;
    bool exhausted = false;

    await Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (activeDownloads.length == downloaded) {
        return false;
      }
      if (current < maxConcurrentDownloads && !exhausted) {
        current++;
        final downloadItem = nextPick();
        if (downloadItem == null) {
          // Nothing left to enqueue; just wait for the in-flight ones.
          exhausted = true;
          current--;
          return true;
        }
        final chapter = downloadItem.chapter.value!;
        // Cancel any stale pool task without deleting the Isar record.
        // Using ActiveDownloadRegistry.cancel() avoids the flicker caused by
        // chapter.cancelDownloads() which deletes the record from Isar.
        if (chapter.id != null) {
          await ActiveDownloadRegistry.cancel(chapter.id!);
        }
        log('[processDownloads] starting chapterId=${chapter.id} "${chapter.name}"');
        await Future.delayed(const Duration(milliseconds: 300));
        ref.read(
          downloadChapterProvider(
            chapter: chapter,
            useWifi: useWifi,
            callback: () {
              downloaded++;
              current--;
              log('[processDownloads] done chapterId=${chapter.id} downloaded=$downloaded/${activeDownloads.length}');
            },
          ),
        );
      }
      return true;
    });
    keepAlive.close();
  } catch (_) {
    keepAlive.close();
  }
}
