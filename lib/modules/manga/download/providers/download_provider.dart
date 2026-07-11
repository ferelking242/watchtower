import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
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

/// User-chosen quality label (normalized via [_normalizeQuality]), keyed by
/// chapter.id. Used by the batch download sheet: unlike
/// [chapterPreferredOriginalUrl] (a single episode's exact URL, valid only
/// for the episode it was picked from), the sheet lets the user pick one
/// quality for MANY episodes at once, and each episode has its own distinct
/// set of video URLs — so a URL from episode 1 would never match episode 5's
/// list. Matching by normalized quality label instead works across episodes.
final Map<int, String> chapterPreferredQuality = {};

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

@riverpod
Future<void> addDownloadToQueue(Ref ref, {required Chapter chapter}) async {
  final download = isar.downloads.getSync(chapter.id!);
  if (download == null) {
    // Use a sentinel value of 1 so the progress bar shows "waiting" (0/1)
    // without dividing by zero. setProgress will overwrite this with the
    // real page count (manga) or real byte total (anime) as soon as the
    // first progress callback fires.
    final download = Download(
      id: chapter.id,
      succeeded: 0,
      failed: 0,
      total: 1,
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
  try {
    bool onlyOnWifi = useWifi ?? ref.read(onlyOnWifiStateProvider);
    final connectivity = await Connectivity().checkConnectivity();
    final isOnWifi =
        connectivity.contains(ConnectivityResult.wifi) ||
        connectivity.contains(ConnectivityResult.ethernet);
    if (onlyOnWifi && !isOnWifi) {
      botToast(navigatorKey.currentContext!.l10n.downloads_are_limited_to_wifi);
      callback?.call();
      keepAlive.close();
      return;
    }

    // Register immediately so any concurrent processDownloads call sees this
    // chapter as active and does not double-start it while the page-URL fetch
    // is still in progress (was the root cause of the "0/1 page" stuck bug).
    if (chapter.id != null) {
      ActiveDownloadRegistry.registerInternal(chapter.id!, '${chapter.id}');
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
    // Do NOT call requestPermission() here — permission is granted during
    // onboarding. Calling it at download time shows a system dialog mid-session.
    final mangaMainDirectory = await storageProvider.getMangaMainDirectory(
      chapter,
    );
    List<Track>? subtitles;
    final manga = chapter.manga.value ?? (throw StateError('chapter.manga not loaded'));
    final chapterName = chapter.name!.replaceForbiddenCharacters(' ');
    final itemType = manga.itemType;
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

    Future<void> setProgress(DownloadProgress progress) async {
      if (progress.total > 0 && AppLogger.isExtremeMode) {
        final pct = (progress.completed / progress.total * 100).toInt();
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

      // ── Compute the values to store in Isar ─────────────────────────────
      // For anime: when we have real byte data, store in KB so the UI can
      // display "14 MB / 58 MB". The _formatSize helper in the queue screen
      // expects KB units (it auto-scales to MB/GB).
      // For manga: store the real page count so the UI shows "7 / 322 images".
      // We never store raw percentages — the UI derives % from succeeded/total
      // only as a last-resort fallback.
      int isarSucceeded;
      int isarTotal;

      if (progress.itemType == ItemType.anime) {
        final dBytes = progress.downloadedBytes;
        final tBytes = progress.totalBytes;
        if (dBytes != null && tBytes != null && tBytes > 0) {
          // Convert bytes → KB (integer, minimum 1 to avoid 0/0)
          isarSucceeded = (dBytes / 1024).ceil();
          isarTotal = (tBytes / 1024).ceil();
        } else if (dBytes != null && dBytes > 0) {
          // Total unknown (chunked transfer) — store downloaded KB only,
          // set total = downloaded+1 so progress bar stays < 100%.
          isarSucceeded = (dBytes / 1024).ceil();
          isarTotal = isarSucceeded + 1;
        } else {
          // Fallback to segment count (rare — occurs during first segment
          // before any bytes have landed yet).
          isarSucceeded = progress.completed;
          isarTotal = progress.total > 0 ? progress.total : 1;
        }
      } else {
        // Manga / novel: store real page counts.
        isarSucceeded = progress.completed;
        isarTotal = progress.total > 0 ? progress.total : 1;
      }

      final download = isar.downloads.getSync(chapter.id!);
      if (download == null) {
        final newDl = Download(
          id: chapter.id,
          succeeded: progress.completed == 0 ? 0 : isarSucceeded,
          failed: 0,
          total: isarTotal,
          isDownload: progress.isCompleted,
          isStartDownload: true,
        );
        isar.writeTxnSync(() {
          isar.downloads.putSync(newDl..chapter.value = chapter);
        });
      } else {
        if (progress.total != 0) {
          isar.writeTxnSync(() {
            isar.downloads.putSync(
              download
                ..succeeded = progress.completed == 0 ? 0 : isarSucceeded
                ..total = isarTotal
                ..failed = 0
                ..isDownload = progress.isCompleted,
            );
          });
        }
      }
    }

    setProgress(DownloadProgress(0, 0, itemType));

    void savePageUrls() {
      final settings = (isar.settings.getSync(kSettingsId) ?? Settings());
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
      try {
        final value = await ref
            .read(getChapterPagesProvider(chapter: chapter).future)
            .timeout(const Duration(seconds: 90));
        if (value.pageUrls.isNotEmpty) {
          pageUrls = value.pageUrls;
          AppLogger.log(
            '[ch:' + (chapter.id?.toString() ?? '?') + '] ${pageUrls.length} pages fetched'
            ' • url[0]=' + (pageUrls.isNotEmpty ? pageUrls.first.url.substring(0, pageUrls.first.url.length.clamp(0, 80)) : 'none'),
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
          if (u.contains('.m3u8') || u.contains('/hls/') ||
              u.contains('hls-cdn') || u.contains('hls.')) return true;
          final q = (v.quality ?? '').toString().toLowerCase();
          if (q.contains('hls') || q.contains('auto')) return true;
          return false;
        }
        final m3u8Urls = value.$1.where(looksLikeHls).toList();
        final nonM3u8Urls = value.$1
            .where((element) => !looksLikeHls(element) && element.originalUrl.isMediaVideo())
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
          final idx = videosUrls.indexWhere((v) => v.originalUrl == preferredOriginal);
          if (idx > 0) {
            final picked = videosUrls.removeAt(idx);
            videosUrls = [picked, ...videosUrls];
          }
          // One-shot: clear so a future re-download asks again.
          chapterPreferredOriginalUrl.remove(chapter.id!);
        }
        // Batch download sheet: quality chosen by label (see chapterPreferredQuality
        // doc) since it applies across many episodes that each have their own URLs.
        final preferredQuality =
            chapter.id != null ? chapterPreferredQuality[chapter.id!] : null;
        if (preferredQuality != null && videosUrls.isNotEmpty) {
          final idx = videosUrls
              .indexWhere((v) => _qualityDigits(v.quality) == preferredQuality);
          if (idx > 0) {
            final picked = videosUrls.removeAt(idx);
            videosUrls = [picked, ...videosUrls];
          }
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
      final manga = chapter.manga.value!;
      final source = getSource(manga.lang!, manga.source!, manga.sourceId)!;
      final chapterUrl = "${source.baseUrl}${chapter.url!.getUrlWithoutDomain}";
      final cookie = MClient.getCookiesPref(chapterUrl);
      final headers = htmlHeader;
      if (cookie.isNotEmpty) {
        final userAgent = (isar.settings.getSync(kSettingsId) ?? Settings()).userAgent!;
        headers.addAll(cookie);
        headers[HttpHeaders.userAgentHeader] = userAgent;
      }
      final res = await http.get(Uri.parse(chapterUrl), headers: headers);
      if (res.headers.containsKey("Location")) {
        novelPage = PageUrl(res.headers["Location"]!);
      } else {
        novelPage = PageUrl(chapterUrl);
      }
    }

    // If the fetch failed (exception, empty result, or timeout), mark failed and abort.
    if (fetchError != null) {
      AppLogger.log(
        '[ch:' + (chapter.id?.toString() ?? '?') + '] FETCH ERROR: $fetchError',
        logLevel: LogLevel.error,
        tag: LogTag.download,
      );
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
      // CRITICAL: release processDownloads slot so the next queued
      // download can start — without this, one extension failure blocks
      // the entire download queue forever ("en attente" bug).
      callback?.call();
      keepAlive.close();
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
      AppLogger.log(
        '[ch:${chapter.id}] cbzExists=$cbzFileExist mp4Exists=$mp4FileExist '
        'htmlExists=$htmlFileExist dir=${mangaMainDirectory.path}',
        logLevel: LogLevel.debug,
        tag: LogTag.download,
      );
      if (!cbzFileExist && itemType == ItemType.manga ||
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
        for (var index = 0; index < pageUrls.length; index++) {
          if (!kIsWeb && Platform.isAndroid) {
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
            final userAgent = (isar.settings.getSync(kSettingsId) ?? Settings()).userAgent!;
            headers.addAll(cookie);
            headers[HttpHeaders.userAgentHeader] = userAgent;
          }
          // Copy headers so each page gets its own map (avoids mutating
          // the shared `headers` reference across loop iterations).
          final Map<String, String> pageHeaders = Map<String, String>.from(headers);
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
        AppLogger.log(
          '[ch:' + (chapter.id?.toString() ?? '?') + '] START ${pages.length} imgs → ' + itemType.name,
          logLevel: LogLevel.info,
          tag: LogTag.download,
        );
        // Log up to 3 page URLs so user can verify they are images not HTML
        for (var _li = 0; _li < pages.length && _li < 3; _li++) {
          final _u = pages[_li].url;
          AppLogger.log(
            '[ch:' + (chapter.id?.toString() ?? '?') + '] url[$_li] '
            + (_u.length > 90 ? _u.substring(0, 90) + '…' : _u),
            logLevel: LogLevel.debug,
            tag: LogTag.download,
          );
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
          AppLogger.log(
            '[ch:' + (chapter.id?.toString() ?? '?') + '] COMPLETE ✓',
            logLevel: LogLevel.info,
            tag: LogTag.download,
          );
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
          final dl = isar.downloads.getSync(chapter.id!);
          if (dl != null) {
            isar.writeTxnSync(() {
              isar.downloads.putSync(dl..failed = 1);
            });
          }
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
    AppLogger.log(
      '[ch:${chapter.id}] CRASH: $e',
      logLevel: LogLevel.error,
      tag: LogTag.download,
    );
    // Mark as failed so processDownloads does NOT re-queue endlessly.
    // Without this, any uncaught exception leaves the chapter as
    // isDownload=false + isStartDownload=true in Isar → infinite retry loop.
    if (chapter.id != null) {
      try {
        final dl = isar.downloads.getSync(chapter.id!);
        if (dl != null) {
          isar.writeTxnSync(() {
            isar.downloads.putSync(dl..failed = 1..isDownload = false);
          });
        }
      } catch (_) {}
    }
    callback?.call();
    keepAlive.close();
  } finally {
    // Always clean up the registry entry so the chapter is no longer seen
    // as "active" after this function exits (success, failure, or timeout).
    if (chapter.id != null) {
      ActiveDownloadRegistry.unregister(chapter.id!);
    }
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

    // Isar links are lazy — load chapter and manga before accessing .value.
    for (final dl in ongoingDownloads) {
      await dl.chapter.load();
      final ch = dl.chapter.value;
      if (ch != null) await ch.manga.load();
    }

    // Skip chapters that are currently paused or already actively running.
    // Also skip downloads whose chapter link failed to load (orphaned record).
    final pausedIds = ref.read(downloadQueueStateProvider).pausedIds;
    final toStart = ongoingDownloads
        .where(
          (d) {
            final chId = d.chapter.value?.id;
            if (chId == null) return false; // orphaned — skip
            return !pausedIds.contains(chId) &&
                !ActiveDownloadRegistry.isActive(chId);
          },
        )
        .toList();

    log('[processDownloads] total=${ongoingDownloads.length} paused=${pausedIds.length} toStart=${toStart.length}');

    if (toStart.isEmpty) {
      keepAlive.close();
      return;
    }

    // ── Concurrency limits ───────────────────────────────────────────────────
    // Global cap (legacy "simultaneous downloads" setting).
    // NOTE: declared as var so they can be refreshed each tick inside doWhile.
    var globalMax = ref.read(concurrentDownloadsStateProvider);
    // Per-type caps and per-(type,source) caps read from the dedicated providers.
    var typeMax = <ItemType, int>{
      ItemType.manga: ref.read(mangaSimultaneousStateProvider),
      ItemType.anime: ref.read(watchSimultaneousStateProvider),
      ItemType.novel: ref.read(novelSimultaneousStateProvider),
    };
    var typePerSrcMax = <ItemType, int>{
      ItemType.manga: ref.read(mangaSimultaneousPerSourceStateProvider),
      ItemType.anime: ref.read(watchSimultaneousPerSourceStateProvider),
      ItemType.novel: ref.read(novelSimultaneousPerSourceStateProvider),
    };

    // ── Cross-source round-robin queues ──────────────────────────────────────
    // Group by source so the scheduler interleaves sources fairly.
    final perSourceQueues = <String, List<Download>>{};
    for (final d in toStart) {
      final src = d.chapter.value?.manga.value?.source ?? '_unknown';
      (perSourceQueues[src] ??= <Download>[]).add(d);
    }
    final sourceOrder = perSourceQueues.keys.toList();
    int rrIdx = 0;

    // Active-download counters — updated synchronously so each tick is
    // consistent even when multiple downloads finish between ticks.
    int current = 0; // global in-flight count
    final activePerType = <ItemType, int>{}; // in-flight per ItemType
    final activePerSrc = <String, int>{}; // in-flight per '${type}_$source'

    int downloaded = 0; // completed (callback fired) count

    bool allQueuesEmpty() =>
        perSourceQueues.values.every((q) => q.isEmpty);

    /// Round-robin pick that respects per-type and per-source limits.
    /// Returns null when all remaining items are at their limit (not truly
    /// exhausted — a slot will free when an in-flight download finishes).
    Download? nextPick() {
      if (allQueuesEmpty()) return null;
      final n = sourceOrder.length;
      for (var i = 0; i < n; i++) {
        final src = sourceOrder[(rrIdx + i) % n];
        final queue = perSourceQueues[src];
        if (queue == null || queue.isEmpty) continue;
        final d = queue.first;
        final type = d.chapter.value?.manga.value?.itemType ?? ItemType.manga;
        final tLimit = typeMax[type] ?? 1;
        final sLimit = typePerSrcMax[type] ?? 1;
        final curType = activePerType[type] ?? 0;
        final curSrc = activePerSrc['${type.name}_$src'] ?? 0;
        if (curType >= tLimit || curSrc >= sLimit) continue;
        rrIdx = (rrIdx + i + 1) % n;
        return queue.removeAt(0);
      }
      return null; // all remaining items are throttled — wait for a free slot
    }

    await Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));

      // Done: all started downloads have completed.
      if (toStart.length == downloaded) return false;

      // Refresh limits each tick so settings changes take effect immediately.
      // Since globalMax/typeMax/typePerSrcMax are var (not final) and captured
      // by the nextPick() closure by reference, the closure sees updated values.
      globalMax = ref.read(concurrentDownloadsStateProvider);
      typeMax = <ItemType, int>{
        ItemType.manga: ref.read(mangaSimultaneousStateProvider),
        ItemType.anime: ref.read(watchSimultaneousStateProvider),
        ItemType.novel: ref.read(novelSimultaneousStateProvider),
      };
      typePerSrcMax = <ItemType, int>{
        ItemType.manga: ref.read(mangaSimultaneousPerSourceStateProvider),
        ItemType.anime: ref.read(watchSimultaneousPerSourceStateProvider),
        ItemType.novel: ref.read(novelSimultaneousPerSourceStateProvider),
      };

      // Try to start as many downloads as possible within all caps.
      while (current < globalMax) {
        final downloadItem = nextPick();
        if (downloadItem == null) break; // nothing to start right now

        final chapter = downloadItem.chapter.value!;
        final type = downloadItem.chapter.value?.manga.value?.itemType ?? ItemType.manga;
        final src = downloadItem.chapter.value?.manga.value?.source ?? '_unknown';

        // Update counters before starting so re-entrant ticks see the right state.
        current++;
        activePerType[type] = (activePerType[type] ?? 0) + 1;
        activePerSrc['${type.name}_$src'] = (activePerSrc['${type.name}_$src'] ?? 0) + 1;

        AppLogger.log(
          'Queue → [ch:' + (chapter.id?.toString() ?? '?') + '] '
          '"' + ((chapter.name ?? '').length > 35 ? chapter.name!.substring(0, 35) + '…' : (chapter.name ?? '')) + '" '
          'type=' + type.name,
          logLevel: LogLevel.info,
          tag: LogTag.download,
        );
        log('[processDownloads] starting chapterId=${chapter.id} "${chapter.name}" type=${type.name} src=$src');
        await Future.delayed(const Duration(milliseconds: 200));
        ref.read(
          downloadChapterProvider(
            chapter: chapter,
            useWifi: useWifi,
            callback: () {
              downloaded++;
              current = (current - 1).clamp(0, 9999);
              activePerType[type] = ((activePerType[type] ?? 1) - 1).clamp(0, 9999);
              activePerSrc['${type.name}_$src'] = ((activePerSrc['${type.name}_$src'] ?? 1) - 1).clamp(0, 9999);
              log('[processDownloads] done chapterId=${chapter.id} downloaded=$downloaded/${toStart.length}');
            },
          ),
        );
      }

      // If everything is truly exhausted and nothing is in flight, stop.
      if (allQueuesEmpty() && current == 0) return false;

      return true; // keep polling
    });
    keepAlive.close();
  } catch (_) {
    keepAlive.close();
  }
}
