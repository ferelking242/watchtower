import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:isar_community/isar.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:watchtower/eval/model/m_bridge.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/chapter.dart';
import 'package:watchtower/models/download.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/models/video.dart';
import 'package:watchtower/modules/manga/detail/providers/isar_providers.dart';
import 'package:watchtower/modules/manga/download/providers/download_provider.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/services/download_manager/download_settings_service.dart';
import 'package:watchtower/services/download_manager/external_downloader_launcher.dart';
import 'package:watchtower/services/get_video_list.dart';
import 'package:watchtower/utils/cached_network.dart';
import 'package:watchtower/utils/constant.dart';
import 'package:watchtower/utils/extensions/build_context_extensions.dart';
import 'package:watchtower/utils/extensions/chapter.dart';
import 'package:watchtower/utils/extensions/string_extensions.dart';
import 'package:watchtower/utils/headers.dart';
import 'package:watchtower/utils/utils.dart';
import 'package:watchtower/models/settings.dart';
import 'package:watchtower/services/recommendation.dart';
import 'package:watchtower/modules/watch/detail/language_display.dart';
import 'package:watchtower/services/isolate_service.dart';

import 'watch_player_stub.dart' if (dart.library.ffi) 'watch_player_io.dart';

// SVG icon — film (clapperboard)
const _kMovieSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none">
  <rect x="2" y="6" width="20" height="14" rx="2" stroke="currentColor" stroke-width="1.8"/>
  <path d="M2 10h20" stroke="currentColor" stroke-width="1.5"/>
  <path d="M7 6V2" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>
  <path d="M12 6V2" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>
  <path d="M17 6V2" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>
  <path d="M2 7l5-3M9 7l5-3M16 7l5-3" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/>
</svg>''';

// SVG icon — série (écran TV)
const _kSerieSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none">
  <rect x="2" y="3" width="20" height="14" rx="2" stroke="currentColor" stroke-width="1.8"/>
  <path d="M8 21h8M12 17v4" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>
  <circle cx="8" cy="10" r="2.5" stroke="currentColor" stroke-width="1.5"/>
  <path d="M13 8h4M13 12h3" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/>
</svg>''';

class WatchDetailView extends ConsumerStatefulWidget {
  final Manga manga;
  final bool sourceExist;
  final Function(bool) checkForUpdate;
  final bool isLoading;

  const WatchDetailView({
    super.key,
    required this.manga,
    required this.sourceExist,
    required this.checkForUpdate,
    this.isLoading = false,
  });

  @override
  ConsumerState<WatchDetailView> createState() => _WatchDetailViewState();
}

class _WatchDetailViewState extends ConsumerState<WatchDetailView>
    with TickerProviderStateMixin {
  late final TabController _tabController;
  late final WatchInlinePlayer _player;

  String? _selectedSeason;
  String? _selectedLanguage;
  String? _selectedServer;
  bool _isDescriptionExpanded = false;
  final _headerTitleOpacity = ValueNotifier<double>(0.0);
  final _nestedScrollCtrl = ScrollController();

  // ── Theme helpers ────────────────────────────────────────────────────────────
  Color get _accent     => context.primaryColor;
  Color get _bg         => Theme.of(context).scaffoldBackgroundColor;
  Color get _card       => Theme.of(context).colorScheme.surfaceContainerHighest;
  Color get _surface    => Theme.of(context).colorScheme.surface;
  Color get _onSurface  => Theme.of(context).colorScheme.onSurface;
  Color get _grey       => _onSurface.withValues(alpha: 0.50);
  Color get _faint      => _onSurface.withValues(alpha: 0.30);
  Color get _textPrimary => _onSurface;
  bool  get _isLight    => context.isLight;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _player = WatchInlinePlayer();
    _player.onQualityChanged = () { if (mounted) setState(() {}); };
    _nestedScrollCtrl.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_nestedScrollCtrl.hasClients) return;
    final pixels = _nestedScrollCtrl.position.pixels;
    _headerTitleOpacity.value = (pixels / 80.0).clamp(0.0, 1.0);
  }

  // Track last orientation so we only call SystemChrome when it changes
  bool _lastWasLandscape = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    if (isLandscape != _lastWasLandscape) {
      _lastWasLandscape = isLandscape;
      if (isLandscape) {
        // Hide system UI so there are no black bars from the nav bar or
        // status bar eating into the fullscreen video area.
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } else {
        SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.manual,
          overlays: SystemUiOverlay.values,
        );
      }
    }
  }

  @override
  void dispose() {
    // Restore system UI when leaving the page
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    _nestedScrollCtrl.removeListener(_onScroll);
    _nestedScrollCtrl.dispose();
    _headerTitleOpacity.dispose();
    _tabController.dispose();
    _player.dispose();
    super.dispose();
  }

  // ─── VIDEO TRIGGER ──────────────────────────────────────────────────────────

  void _maybeStartVideo(List<Chapter> chapters) {
    // On web the inline stub is replaced by AnimePlayerView — no auto-play.
    if (kIsWeb) return;
    if (chapters.isEmpty) return;
    _player.title = widget.manga.name ?? '';
    // Only auto-load E01 the very first time (loadedChapterId == null).
    // Never override a chapter the user has explicitly chosen.
    if (_player.loadedChapterId != null) return;
    _player.loadedChapterId = chapters.first.id;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _player.load(ref: ref, chapter: chapters.first);
      if (mounted) setState(() {});
    });
  }

  void _loadEpisodeInBanner(Chapter chapter) {
    // On web, open the real full-screen player (AnimePlayerView) instead
    // of the HTML5 inline stub.  AnimePlayerView reads chapter.url directly
    // from Isar — no extension call, no manga link needed.
    if (kIsWeb) {
      context.push('/animePlayerView', extra: chapter.id!);
      return;
    }
    _player.title = widget.manga.name ?? '';
    _player.reset();
    _player.loadedChapterId = chapter.id;
    if (mounted) setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _player.load(ref: ref, chapter: chapter);
      if (mounted) setState(() {});
    });
  }

  // ─── ACTIONS ────────────────────────────────────────────────────────────────

  void _toggleFavorite() {
    final manga = widget.manga;
    isar.writeTxnSync(() {
      manga.favorite = !(manga.favorite ?? false);
      if (manga.favorite!) manga.dateAdded = DateTime.now().millisecondsSinceEpoch;
      isar.mangas.putSync(manga);
    });
    setState(() {});
  }

  void _share(BuildContext ctx) {
    final source = getSource(widget.manga.lang!, widget.manga.source!, widget.manga.sourceId);
    if (source == null) return;
    final url = '${source.baseUrl}${widget.manga.link!.getUrlWithoutDomain}';
    SharePlus.instance.share(ShareParams(text: url));
  }

  void _downloadAll(List<Chapter> chapters) {
    for (final ch in chapters) {
      final entry = isar.downloads.filter().idEqualTo(ch.id).findFirstSync();
      if (entry == null || !(entry.isDownload ?? false)) {
        ref.read(addDownloadToQueueProvider(chapter: ch));
      }
    }
    ref.read(processDownloadsProvider());
    botToast('Tous les épisodes mis en file');
  }

  // ─── BUILD ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final chapters = ref
        .watch(getChaptersStreamProvider(mangaId: widget.manga.id!))
        .when(
          data: (list) => list.reversed.toList(),
          loading: () => widget.manga.chapters.toList().reversed.toList(),
          error: (_, __) => <Chapter>[],
        );

    _maybeStartVideo(chapters);

    // ── Update episode navigation callbacks on every build ────────────────────
    final sorted = _sortedEpisodes(chapters);
    final curIdx  = sorted.indexWhere((c) => c.id == _player.loadedChapterId);
    _player.onPrevEpisode = (curIdx > 0)
        ? () => _loadEpisodeInBanner(sorted[curIdx - 1])
        : null;
    _player.onNextEpisode = (curIdx >= 0 && curIdx < sorted.length - 1)
        ? () => _loadEpisodeInBanner(sorted[curIdx + 1])
        : null;
    _player.chapters     = sorted;
    _player.onEpisodeTap = _loadEpisodeInBanner;

    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: isLandscape ? Colors.black : _bg,
      // In landscape the body must extend behind the bottom navigation bar
      // so the video fills edge-to-edge without a black gap at the bottom.
      extendBody: isLandscape,
      body: isLandscape
          ? _buildLandscape(chapters)
          : _buildPortrait(chapters),
    );
  }

  // ─── PORTRAIT ───────────────────────────────────────────────────────────────

  Widget _buildPortrait(List<Chapter> chapters) {
    final topPad = MediaQuery.of(context).padding.top;
    return Column(
      children: [
        // ── Player — toujours fixé, ne scrolle jamais ─────────────────────────
        SizedBox(
          height: 230 + topPad,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildBanner(chapters),
              Positioned(
                top: topPad,
                left: 0,
                right: 0,
                child: ValueListenableBuilder<bool>(
                  valueListenable: _player.controlsVisible,
                  builder: (_, controlsVis, __) => AnimatedOpacity(
                    opacity: controlsVis ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 250),
                    child: IgnorePointer(
                      ignoring: !controlsVis,
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          Expanded(
                            child: ValueListenableBuilder<double>(
                              valueListenable: _headerTitleOpacity,
                              builder: (_, opacity, __) => Opacity(
                                opacity: opacity,
                                child: Text(
                                  widget.manga.name ?? '',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    shadows: [Shadow(blurRadius: 6, color: Colors.black54)],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                          _AideButton(
                              onTap: () =>
                                  _showOptionsSheet(context, chapters)),
                          const SizedBox(width: 4),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // ── Contenu scrollable ────────────────────────────────────────────────
        Expanded(
          child: NestedScrollView(
            controller: _nestedScrollCtrl,
            headerSliverBuilder: (ctx, innerBoxIsScrolled) => [
              SliverToBoxAdapter(child: _buildMetadataBlock(chapters)),
              SliverPersistentHeader(
                pinned: true,
                delegate: _TabBarDelegate(
                  TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    indicatorColor: _accent,
                    indicatorWeight: 2.5,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: _AnimatedTabIndicator(color: _accent),
                    labelColor: _textPrimary,
                    unselectedLabelColor: _grey,
                    labelStyle: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w600),
                    unselectedLabelStyle: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w400),
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(text: 'Pour vous'),
                      Tab(text: 'Commentaires'),
                    ],
                  ),
                  color: _bg,
                ),
              ),
            ],
            body: TabBarView(
              controller: _tabController,
              children: [
                _buildRecommendationsTab(),
                _buildCommentsTab(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── LANDSCAPE — fullscreen player ──────────────────────────────────────────

  Widget _buildLandscape(List<Chapter> chapters) {
    if (_player.hasVideoUrl) {
      return SizedBox.expand(child: _player.buildFullscreenPlayer());
    }
    return Stack(
      children: [
        SizedBox.expand(child: _buildBannerImageOnly()),
        SafeArea(
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── BANNER ─────────────────────────────────────────────────────────────────

  Widget _buildBanner(List<Chapter> chapters) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildBannerImageOnly(),

        // Player fades in smoothly over cover when URL is ready
        AnimatedOpacity(
          opacity: _player.hasVideoUrl ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 480),
          curve: Curves.easeInOut,
          child: _player.buildBannerOverlay(context: context),
        ),

        // Loading pulse — visible while video URL is being resolved
        if (!_player.hasVideoUrl && !_player.loadFailed &&
            _player.loadedChapterId != null)
          const _LoadingBannerPulse(),

        // Reel-mode button — appears once the loaded video is detected as
        // vertical/short-form content (e.g. MovieBox "TV courte").
        ValueListenableBuilder<bool>(
          valueListenable: _player.isPortraitFormat,
          builder: (_, isReel, __) {
            if (!isReel || !_player.hasVideoUrl) return const SizedBox.shrink();
            final chapter = chapters.firstWhere(
              (c) => c.id == _player.loadedChapterId,
              orElse: () => chapters.first,
            );
            return Positioned(
              right: 10,
              bottom: 10,
              child: GestureDetector(
                onTap: () => _player.launchReelPage(
                  context: context,
                  chapters: chapters,
                  currentChapter: chapter,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24, width: 0.8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.smart_display_rounded, color: Colors.white, size: 14),
                      SizedBox(width: 5),
                      Text('Mode Reel', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            );
          },
        ),

        // Top shadow uniquement pour lisibilité des contrôles — bord bas net
        const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.40],
                colors: [Color(0xAA000000), Colors.transparent],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBannerImageOnly() {
    final manga = widget.manga;
    final headers = (manga.isLocalArchive ?? false)
        ? null
        : ref.watch(headersProvider(
            source: manga.source!,
            lang: manga.lang!,
            sourceId: manga.sourceId,
          ));
    final imgUrl = toImgUrl(manga.customCoverFromTracker ?? manga.imageUrl ?? '');

    if (manga.customCoverImage != null) {
      return Image.memory(
        manga.customCoverImage as Uint8List,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }
    return cachedNetworkImage(
      headers: headers,
      imageUrl: imgUrl,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
    );
  }

  // ─── METADATA BLOCK ─────────────────────────────────────────────────────────

  Widget _buildMetadataBlock(List<Chapter> chapters) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTitleRow(),
          const SizedBox(height: 7),
          _buildMetaRow(chapters),
          const SizedBox(height: 14),
          _buildActionButtons(chapters),
          const SizedBox(height: 20),
          _buildRessourcesSection(chapters),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ─── TITLE ROW ──────────────────────────────────────────────────────────────
  // Title + "Info ›" plain text right next to title (not far right)

  Widget _buildTitleRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Flexible(
          child: Text(
            widget.manga.name ?? '',
            style: TextStyle(
              color: _textPrimary,
              fontSize: 21,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: () => _showInfoSheet(context),
          child: Text(
            'Info ›',
            style: TextStyle(
              color: _accent,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  // ─── META ROW ───────────────────────────────────────────────────────────────
  // [SVG] | [★ score] | lang | genre | ...

  Widget _buildMetaRow(List<Chapter> chapters) {
    final isMovie = _isMovie(chapters);
    final parts = <String>[];

    // Production country from ·-prefixed genres (provided by extensions)
    final productionCountry = (widget.manga.genre ?? [])
        .where((g) => g.startsWith('·'))
        .map((g) => g.substring(1).trim())
        .where((g) => g.isNotEmpty)
        .firstOrNull;
    // Fallback to lang when no country available (never display raw "MULTI")
    final lang = widget.manga.lang?.trim() ?? '';
    if (productionCountry != null && productionCountry.isNotEmpty) {
      parts.add(productionCountry);
    } else if (lang.isNotEmpty && lang.toLowerCase() != 'multi') {
      parts.add(lang.toUpperCase());
    }

    // First genre that isn't "film"/"movie"/"serie" and isn't ·-prefixed
    final typeGenre = (widget.manga.genre ?? [])
        .where((g) {
          final l = g.toLowerCase().trim();
          return l != 'film' && l != 'movie' && l != 'série' && l != 'serie'
              && !g.startsWith('·');
        })
        .take(1)
        .firstOrNull;
    if (typeGenre != null && typeGenre.isNotEmpty) parts.add(typeGenre);

    // Seasons count for series
    if (!isMovie) {
      final seasons = _detectSeasons(chapters);
      if (seasons.isNotEmpty) {
        parts.add('${seasons.length} saison${seasons.length > 1 ? 's' : ''}');
      }
    } else {
      parts.add('Film');
    }

    Widget vbar() => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text('|', style: TextStyle(color: _faint, fontSize: 12)),
        );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SvgPicture.string(
          isMovie ? _kMovieSvg : _kSerieSvg,
          width: 14,
          height: 14,
          colorFilter: ColorFilter.mode(_grey, BlendMode.srcIn),
        ),
        vbar(),
        const Icon(Icons.star_rounded, color: Color(0xFFFFD700), size: 13),
        const SizedBox(width: 4),
        Builder(builder: (_) {
          final rawDesc = widget.manga.description ?? '';
          final imdbM = RegExp(r'IMDb\s+([\d.]+)').firstMatch(rawDesc);
          return Text(imdbM != null ? imdbM.group(1)! : 'N/A',
              style: TextStyle(color: _grey, fontSize: 12));
        }),
        if (parts.isNotEmpty) ...[
          vbar(),
          Expanded(
            child: Text(
              parts.join('  |  '),
              style: TextStyle(color: _grey, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ] else
          const Expanded(child: SizedBox.shrink()),
      ],
    );
  }

  // ─── INFO SHEET ─────────────────────────────────────────────────────────────
  // Fixed bottom sheet — no drag handle, never overlaps player (230 px)

  void _showInfoSheet(BuildContext ctx) {
      final manga = widget.manga;
      showModalBottomSheet(
        context: ctx,
        isScrollControlled: true,
        barrierColor: Colors.transparent,
        backgroundColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        builder: (sheetCtx) {
          final screen  = MediaQuery.of(ctx).size.height;
          final statusH = MediaQuery.of(ctx).padding.top;
          final maxH    = screen - 230 - statusH;

          final desc = (manga.description ?? '').trim();
          final genres = (manga.genre ?? []).where((g) => !g.startsWith('·')).toList();
          final countrySheet = (manga.genre ?? []).where((g) => g.startsWith('·'))
              .map((g) => g.substring(1)).firstOrNull;
          final year   = (manga.author ?? '').trim();
          final _aS = (manga.artist ?? '').split(',').map((s) => s.trim())
              .where((s) => s.isNotEmpty).toList();
          final dirSheet  = _aS.isNotEmpty ? _aS.first : null;
          final castSheet = _aS.length > 1 ? _aS.sublist(1).join(', ') : null;
          final lang   = (manga.lang ?? '').toUpperCase();

          return Container(
            height: maxH,
            decoration: BoxDecoration(color: _surface),
            child: Column(
              children: [
                // ── Close button only (no title, no handle) ──────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
                  child: Row(
                    children: [
                      const Spacer(),
                      GestureDetector(
                        onTap: () => Navigator.pop(sheetCtx),
                        child: Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                              color: _card, shape: BoxShape.circle),
                          child: Icon(Icons.close, size: 16, color: _grey),
                        ),
                      ),
                    ],
                  ),
                ),
                // ── Scrollable IMDB-style content ─────────────────────────────
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    children: [
                      // ── Hero: cover + title + badges ─────────────────────
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Poster
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: cachedNetworkImage(
                              imageUrl: toImgUrl(
                                  manga.customCoverFromTracker ??
                                      manga.imageUrl ?? ''),
                              width: 96,
                              height: 140,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Title
                                Text(
                                  manga.name ?? '',
                                  style: TextStyle(
                                    color: _textPrimary,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                // Status badge
                                if ((manga.status?.toString() ?? '').isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _accent.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                          color: _accent.withValues(alpha: 0.35),
                                          width: 0.7),
                                    ),
                                    child: Text(
                                      _statusLabel(manga.status),
                                      style: TextStyle(
                                          color: _accent,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                const SizedBox(height: 8),
                                // Language + source pills
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    if (lang.isNotEmpty)
                                      _infoPill(Icons.language, lang),
                                    if ((manga.source ?? '').isNotEmpty)
                                      _infoPill(Icons.storage_outlined,
                                          manga.source!),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // ── Synopsis ─────────────────────────────────────────
                      if (desc.isNotEmpty) ...[
                        _sheetSectionLabel('Synopsis'),
                        const SizedBox(height: 8),
                        StatefulBuilder(
                          builder: (c, setSt) => GestureDetector(
                            onTap: () => setSt(() =>
                                _isDescriptionExpanded =
                                    !_isDescriptionExpanded),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  desc,
                                  maxLines:
                                      _isDescriptionExpanded ? null : 5,
                                  overflow: _isDescriptionExpanded
                                      ? TextOverflow.visible
                                      : TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: _grey,
                                      fontSize: 13,
                                      height: 1.6),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _isDescriptionExpanded
                                      ? 'Voir moins'
                                      : 'Voir plus',
                                  style: TextStyle(
                                      color: _accent, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                      ],

                      // ── Genres ───────────────────────────────────────────
                      if (genres.isNotEmpty) ...[
                        _sheetSectionLabel('Genres'),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final g in genres)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _card,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: _faint, width: 0.7),
                                ),
                                child: Text(g,
                                    style: TextStyle(
                                        color: _textPrimary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 22),
                      ],

                      // ── Cast / Crew ───────────────────────────────────────
                      if (dirSheet != null || castSheet != null || countrySheet != null) ...[
                        _sheetSectionLabel('Équipe & Infos'),
                        const SizedBox(height: 12),
                        if (countrySheet != null) ...[
                          _castRow(Icons.public_outlined, 'Pays', countrySheet),
                          const SizedBox(height: 10),
                        ],
                        if (dirSheet != null) ...[
                          _castRow(Icons.movie_creation_outlined, 'Réalisateur', dirSheet),
                          const SizedBox(height: 10),
                        ],
                        if (castSheet != null)
                          _castRow(Icons.people_outlined, 'Distribution', castSheet),
                        const SizedBox(height: 22),
                      ],

                      // ── Info table ───────────────────────────────────────
                      _sheetSectionLabel('Details'),
                      const SizedBox(height: 12),
                      _infoRow('Langue', lang.isNotEmpty ? lang : '—'),
                      _infoRow('Statut', _statusLabel(manga.status)),
                      if ((manga.source ?? '').isNotEmpty)
                        _infoRow('Source', manga.source!),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    Widget _castRow(IconData icon, String role, String name) {
      return Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, size: 18, color: _accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: TextStyle(
                        color: _textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                Text(role,
                    style: TextStyle(color: _grey, fontSize: 11)),
              ],
            ),
          ),
        ],
      );
    }

    Widget _infoRow(String label, String value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Text(label,
                style: TextStyle(
                    color: _grey, fontSize: 13, fontWeight: FontWeight.w500)),
            const Spacer(),
            Text(value,
                style: TextStyle(
                    color: _textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      );
    }

  

  Widget _infoPill(IconData icon, String label) {
    if (label.trim().isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: _grey),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: _grey, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _sheetSectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
          color: _textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w700),
    );
  }

  String _statusLabel(dynamic status) {
    switch (status?.toString()) {
      case '0': return 'En cours';
      case '1': return 'Terminé';
      case '2': return 'Licencié';
      case '3': return 'Annulé';
      case '4': return 'En pause';
      default:  return 'Inconnu';
    }
  }

  // ─── ACTION BUTTONS ─────────────────────────────────────────────────────────

  Widget _buildActionButtons(List<Chapter> chapters) {
    final isFav = widget.manga.favorite ?? false;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _chip(
            icon: isFav ? Icons.bookmark : Icons.bookmark_border_outlined,
            label: isFav ? 'Dans la library' : 'Ajouter à la library',
            onTap: _toggleFavorite,
            active: isFav,
          ),
          const SizedBox(width: 8),
          _chip(
              icon: Icons.drive_file_move_outlined,
              label: 'Migrer',
              onTap: () => context.pushNamed('migrate', extra: widget.manga)),
          const SizedBox(width: 8),
          _chip(
              icon: Icons.share_outlined,
              label: 'Partager',
              onTap: () => _share(context)),
          const SizedBox(width: 8),
          _chip(
              icon: Icons.download_outlined,
              label: 'Télécharger',
              onTap: () => _showDownloadSheet(context, chapters)),
          const SizedBox(width: 8),
          _chip(
              icon: Icons.language_outlined,
              label: 'WebView',
              onTap: _openInBrowser),
        ],
      ),
    );
  }

  Widget _chip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool active = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: active ? _accent.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
              color: active ? _accent : _faint.withValues(alpha: 0.45),
              width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 17,
                color: active ? _accent : _onSurface.withValues(alpha: 0.55)),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color:
                        active ? _accent : _onSurface.withValues(alpha: 0.55),
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }

  // ─── MOVIE / SERIES DETECTION ───────────────────────────────────────────────

  bool _isMovie(List<Chapter> chapters) {
    if (widget.isLoading) return false;
    if (chapters.isEmpty) return false;
    // 1 episode → movie/single; 2+ → series
    return chapters.length == 1;
  }

  List<String> _detectSeasons(List<Chapter> chapters) {
    final seasonRegex = RegExp(
        r'(?:Saison|Season|Partie|Part)\s*(\d+)|S(\d{1,2})(?:E\d+)?',
        caseSensitive: false);
    final seen = <String>{};
    for (final ch in chapters) {
      final m = seasonRegex.firstMatch(ch.name ?? '');
      if (m != null) {
        final num = m.group(1) ?? m.group(2) ?? '1';
        seen.add('Saison $num');
      }
    }
    if (seen.isEmpty) return [];
    return seen.toList()
      ..sort((a, b) {
        final na =
            int.tryParse(a.replaceAll(RegExp(r'\D'), '')) ?? 0;
        final nb =
            int.tryParse(b.replaceAll(RegExp(r'\D'), '')) ?? 0;
        return na.compareTo(nb);
      });
  }

  // Clé interne utilisée pour le filtrage (code ISO en minuscule si connu,
  // sinon mot brut en majuscule pour compat avec les extensions historiques).
  String? _langKey(Chapter ch) {
    final code = extractLangCode(ch.scanlator);
    if (code != null) return code.toLowerCase();
    final langRx = RegExp(
        r'\b(VF|VOSTFR|VO|French|English|Français|Dub|Sub|MULTI|VOSTA|'
        r'Japanese|Chinese|Korean|Spanish|Portuguese|Russian|Arabic|German|'
        r'Italian|Polish|Turkish|Vietnamese|Thai|Indonesian|Hindi|Dutch|'
        r'Swedish|Finnish|Norwegian|Danish|Czech|Slovak|Romanian|Hungarian|'
        r'Bulgarian|Croatian|Serbian|Ukrainian|Hebrew|Persian)\b',
        caseSensitive: false);
    final m = langRx.firstMatch('${ch.scanlator ?? ''} ${ch.name ?? ''}');
    return m?.group(0)?.toUpperCase();
  }

  List<String> _detectLanguages(List<Chapter> chapters) {
    final seen = <String>{};
    for (final ch in chapters) {
      final key = _langKey(ch);
      if (key != null) seen.add(key);
    }
    return seen.toList();
  }

  List<Chapter> _filterChapters(List<Chapter> all) {
    List<Chapter> result = all;
    final season = _selectedSeason;
    if (season != null) {
      final num = RegExp(r'\d+').firstMatch(season)?.group(0) ?? '';
      // S0? matches both "S1" and "S01"; (?!\d) prevents "S1" matching "S10"
      final rx = RegExp(
          r'(?:Saison|Season|Partie|Part)\s*' +
              num +
              r'\b|S0?' + num + r'(?!\d)',
          caseSensitive: false);
      final filtered =
          result.where((ch) => rx.hasMatch(ch.name ?? '')).toList();
      if (filtered.isNotEmpty) result = filtered;
    }
    final lang = _selectedLanguage;
    if (lang != null) {
      final filtered = result.where((ch) => _langKey(ch) == lang).toList();
      if (filtered.isNotEmpty) result = filtered;
    }
    // Some extensions return duplicate entries for the same episode (e.g. one
    // per source/quality variant). Without deduping, the season+language
    // filter above can still leave far more entries than actual episodes,
    // which threw off the "+N more" count on the episode strip (it counted
    // duplicates from every season instead of just the remaining episodes of
    // the selected one). Keep one Chapter per distinct episode number.
    {
      final seen = <int>{};
      final deduped = <Chapter>[];
      for (int i = 0; i < result.length; i++) {
        if (seen.add(_epNum(result[i].name, i + 1))) deduped.add(result[i]);
      }
      result = deduped;
    }
    return result;
  }

  // ─── RESSOURCES SECTION ─────────────────────────────────────────────────────

  Widget _buildRessourcesSection(List<Chapter> chapters) {
    final isMovie  = _isMovie(chapters);
    final seasons  = isMovie ? <String>[] : _detectSeasons(chapters);
    // Auto-select first season when user hasn't picked one yet
    if (!isMovie && seasons.isNotEmpty && _selectedSeason == null) {
      _selectedSeason = seasons.first;
    }
    final languages = _detectLanguages(chapters);
    final filtered  = _filterChapters(chapters);

    final source = getSource(
        widget.manga.lang ?? '',
        widget.manga.source ?? '',
        widget.manga.sourceId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header: [icon] Ressources ······ [ext_icon] [ext_name] [⋮] ─────────
        Row(
          children: [
            Icon(Icons.video_library_outlined,
                size: 16, color: _textPrimary),
            const SizedBox(width: 6),
            Text(
              'Ressources',
              style: TextStyle(
                  color: _textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            if (source != null) ...[
              // Extension icon (extreme right, before options btn)
              if ((source.iconUrl ?? '').isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: cachedNetworkImage(
                    imageUrl: source.iconUrl!,
                    width: 16,
                    height: 16,
                    fit: BoxFit.cover,
                  ),
                ),
              const SizedBox(width: 4),
              Text(
                source.name ?? '',
                style: TextStyle(
                    color: _grey,
                    fontSize: 12,
                    fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 8),
            ],
            GestureDetector(
              onTap: () => _showOptionsSheet(context, chapters),
              child: Icon(Icons.more_vert_rounded, size: 20, color: _grey),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── 2 boxes : Saison (série) · Langue ────────────────────────────
        // Note: no background video-list fetch here — avoids Cloudflare triggers
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // Skeleton pills during initial load
              if (widget.isLoading && chapters.isEmpty) ...[
                _SkeletonBox(radius: 8, w: 90, h: 36),
                const SizedBox(width: 8),
                _SkeletonBox(radius: 8, w: 70, h: 36),
              ] else ...[
              if (!isMovie) ...[
                _buildDropdownPill(
                  label: seasons.isNotEmpty
                      ? (_selectedSeason ?? seasons.first)
                      : 'Saison 1',
                  items: seasons.isNotEmpty ? seasons : ['Saison 1'],
                  onSelect: (v) => setState(() => _selectedSeason = v),
                  sheetTitle: 'Choisissez la saison',
                ),
                if (languages.isNotEmpty) const SizedBox(width: 8),
              ],
              if (languages.isNotEmpty)
                _buildDropdownPill(
                  label: _selectedLanguage ?? languages.first,
                  items: languages,
                  onSelect: (v) => setState(() => _selectedLanguage = v),
                  displayLabel: (key) => localizedLanguageLabel(
                      key, Localizations.localeOf(context).languageCode),
                  sheetTitle: 'Choisissez la langue',
                ),
              if (_player.loadedVideos.length > 1) ...[
                const SizedBox(width: 8),
                _buildDropdownPill(
                  label: _player.selectedQuality ?? _player.loadedVideos.first.quality,
                  items: _player.loadedVideos.map((v) => v.quality).toList(),
                  onSelect: (q) {
                    final video = _player.loadedVideos.firstWhere(
                      (v) => v.quality == q,
                      orElse: () => _player.loadedVideos.first,
                    );
                    _player.switchQuality(video).then((_) {
                      if (mounted) setState(() {});
                    });
                    setState(() {});
                  },
                  sheetTitle: 'Choisissez la résolution',
                  selectedValue: _player.selectedQuality,
                ),
              ],
              ], // close else spread
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ── Content ───────────────────────────────────────────────────────────
        if (widget.isLoading && chapters.isEmpty)
          // Skeleton episode tiles — visible dès le début sans pop
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (int i = 0; i < 8; i++) ...[
                  _SkeletonBox(radius: 6, w: 48, h: 48),
                  if (i < 7) const SizedBox(width: 8),
                ],
              ],
            ),
          )
        else if (chapters.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                Icon(Icons.video_library_outlined, color: _grey, size: 40),
                const SizedBox(height: 8),
                Text('Aucun épisode disponible',
                    style: TextStyle(color: _grey)),
              ],
            ),
          )
        else if (isMovie)
          _buildMovieBox(filtered.isNotEmpty ? filtered.first : chapters.first)
        else
          _buildEpisodeList(
            _sortedEpisodes(filtered),
            _sortedEpisodes(chapters),
          ),
      ],
    );
  }

  // ── Dropdown pill (MovieBox style: "French dub ▼") ───────────────────────────
  Widget _buildDropdownPill({
    required String label,
    required List<String> items,
    required void Function(String) onSelect,
    String Function(String)? displayLabel,
    String? sheetTitle,
    String? selectedValue,
  }) {
    return GestureDetector(
      onTap: () => _showDropdownSheet(label, items, onSelect,
          displayLabel: displayLabel, sheetTitle: sheetTitle,
          selectedValue: selectedValue),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _faint, width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              displayLabel?.call(label) ?? label,
              style: TextStyle(
                  color: _onSurface.withValues(alpha: 0.75), fontSize: 13),
            ),
            const SizedBox(width: 6),
            Icon(Icons.keyboard_arrow_down_rounded, color: _grey, size: 18),
          ],
        ),
      ),
    );
  }

    void _showDropdownSheet(
        String label, List<String> items, void Function(String) onSelect,
        {String Function(String)? displayLabel, String? sheetTitle,
        String? selectedValue}) {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        barrierColor: Colors.transparent,
        backgroundColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        builder: (ctx) {
          final screen  = MediaQuery.of(context).size.height;
          final statusH = MediaQuery.of(context).padding.top;
          final maxH    = screen - 230 - statusH;
          return Container(
            height: maxH,
            decoration: BoxDecoration(color: _surface),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 12, 10),
                  child: Row(
                    children: [
                      Text(sheetTitle ?? displayLabel?.call(label) ?? label,
                          style: TextStyle(
                              color: _textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w600)),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                              color: _card, shape: BoxShape.circle),
                          child: Icon(Icons.close, size: 16, color: _grey),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: _faint),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: items.map((item) {
                      // Use explicit selectedValue when provided (e.g. quality);
                      // fall back to comparing against language/season state.
                      final isSel = selectedValue != null
                          ? item == selectedValue
                          : item == _selectedLanguage || item == _selectedSeason;
                      return GestureDetector(
                        onTap: () {
                          Navigator.pop(ctx);
                          onSelect(item);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            gradient: isSel
                                ? LinearGradient(
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                    colors: [
                                      _accent.withValues(alpha: 0.30),
                                      _accent.withValues(alpha: 0.10),
                                    ],
                                  )
                                : null,
                            color: isSel ? null : _card,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSel
                                  ? _accent.withValues(alpha: 0.55)
                                  : Colors.transparent,
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            displayLabel?.call(item) ?? item,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isSel ? _accent : _textPrimary,
                              fontSize: 14,
                              fontWeight: isSel
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

  // _buildSelectorRow replaced by _buildDropdownPill + _showDropdownSheet above

  // ─── MOVIE BOX — small rectangle, title only ─────────────────────────────────

  Widget _buildMovieBox(Chapter chapter) {
      final title = widget.manga.name ?? '';
      return GestureDetector(
        onTap: () => _loadEpisodeInBanner(chapter),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                _accent.withValues(alpha: 0.20),
                _accent.withValues(alpha: 0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _accent.withValues(alpha: 0.30), width: 0.8),
          ),
          child: Text(
            title.isNotEmpty ? title : 'Regarder',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _accent,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    static const int    _kMaxVisibleEps = 5;
  static const double _kEpThumbW      = 108.0;

  List<Chapter> _sortedEpisodes(List<Chapter> chapters) {
    final indexed = chapters.asMap().entries.toList();
    indexed.sort((a, b) {
      final na = _epNum(a.value.name, a.key);
      final nb = _epNum(b.value.name, b.key);
      return na.compareTo(nb); // ascending — ep 1 first
    });
    return indexed.map((e) => e.value).toList();
  }

  int _epNum(String? name, int fallback) {
    if (name == null || name.isEmpty) return fallback;
    // Try "Ep. N" / "Ep N" / "Episode N" pattern first
    final epMatch = RegExp(r'(?:Ep\.?|Episode)\s*(\d+)', caseSensitive: false)
        .firstMatch(name);
    if (epMatch != null) return int.tryParse(epMatch.group(1)!) ?? fallback;
    // Fall back to the LAST number in the name (avoids matching season number first)
    final all = RegExp(r'\d+').allMatches(name);
    if (all.isEmpty) return fallback;
    return int.tryParse(all.last.group(0)!) ?? fallback;
  }

  // ─── EPISODE LIST (card style with cover + shimmer) ─────────────────────────

  Widget _buildEpisodeList(List<Chapter> chapters, List<Chapter> allChapters) {
      if (chapters.isEmpty) return const SizedBox.shrink();
      const int maxVisible = 14;
      final display   = chapters.take(maxVisible).toList();
      final remaining = chapters.length - display.length;

      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // "Tous" tile
            GestureDetector(
              onTap: () => _showAllEpisodesSheet(context, allChapters),
              child: Container(
                width: 48, height: 48,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _faint, width: 0.6),
                ),
                child: Center(
                  child: Text('Tous',
                      style: TextStyle(
                          color: _textPrimary, fontSize: 12, fontWeight: FontWeight.w500)),
                ),
              ),
            ),
            // Episode tiles
            for (int i = 0; i < display.length; i++) ...[
              _buildEpTile(display[i], fallbackIndex: i + 1),
              if (i < display.length - 1) const SizedBox(width: 8),
            ],
            // "+N more" tile
            if (remaining > 0) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _showAllEpisodesSheet(context, allChapters),
                child: Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: _card,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Text('+$remaining',
                        style: TextStyle(
                            color: _accent, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    Widget _buildEpTile(Chapter chapter, {required int fallbackIndex}) {
      final isPlaying = _player.loadedChapterId == chapter.id;
      // Use fallbackIndex directly (sorted order) for display — avoids always showing "01"
      final epNum = fallbackIndex.toString().padLeft(2, '0');

      return GestureDetector(
        onTap: () => _loadEpisodeInBanner(chapter),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 48, height: 48,
          decoration: BoxDecoration(
            gradient: isPlaying
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _accent.withValues(alpha: 0.45),
                      _accent.withValues(alpha: 0.15),
                    ],
                  )
                : null,
            color: isPlaying ? null : _card,
            borderRadius: BorderRadius.circular(6),
            border: isPlaying
                ? Border.all(color: _accent.withValues(alpha: 0.55), width: 0.8)
                : null,
          ),
          child: Center(
            child: Text(
              epNum,
              style: TextStyle(
                color: isPlaying ? _accent : _textPrimary,
                fontSize: 15,
                fontWeight: isPlaying ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      );
    }

    void _showAllEpisodesSheet(BuildContext ctx, List<Chapter> allChapters) {
    final seasons = _detectSeasons(allChapters);
    // Start on the currently-selected season so the sheet matches the active filter.
    String? sheetSeason = (_selectedSeason != null && seasons.contains(_selectedSeason))
        ? _selectedSeason
        : (seasons.isNotEmpty ? seasons.first : null);

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (_, setSt) {
            // Filter by selected season if any
            List<Chapter> display;
            if (sheetSeason != null) {
              final num = RegExp(r'\d+').firstMatch(sheetSeason!)?.group(0) ?? '';
              // S0? matches both "S1" and "S01"; (?!\d) prevents "S1" matching "S10"
              final rx = RegExp(
                r'(?:Saison|Season|Partie|Part)\s*' +
                    num +
                    r'\b|S0?' + num + r'(?!\d)',
                caseSensitive: false,
              );
              final filtered =
                  allChapters.where((ch) => rx.hasMatch(ch.name ?? '')).toList();
              display = filtered.isNotEmpty ? filtered : allChapters;
            } else {
              display = allChapters;
            }
            // Also filter by the currently-selected language to avoid showing
            // duplicates when the extension returns multiple language variants.
            if (_selectedLanguage != null) {
              final langFiltered =
                  display.where((ch) => _langKey(ch) == _selectedLanguage).toList();
              if (langFiltered.isNotEmpty) display = langFiltered;
            }
            // Deduplicate by episode number within the current view so that
            // remaining variants (no language selected) don't appear multiple times.
            {
              final seen = <int>{};
              final deduped = <Chapter>[];
              for (int i = 0; i < display.length; i++) {
                if (seen.add(_epNum(display[i].name, i + 1))) deduped.add(display[i]);
              }
              display = deduped;
            }

            final bg = Theme.of(ctx).scaffoldBackgroundColor;
            final card = Theme.of(ctx).colorScheme.surfaceContainerHighest;
            final onSurface = Theme.of(ctx).colorScheme.onSurface;
            final accent = ctx.primaryColor;
            final grey = onSurface.withValues(alpha: 0.50);
            final faint = onSurface.withValues(alpha: 0.25);

            final _maxFrac = ((MediaQuery.of(ctx).size.height - 230 - MediaQuery.of(ctx).padding.top) / MediaQuery.of(ctx).size.height).clamp(0.40, 0.92);
            return DraggableScrollableSheet(
              initialChildSize: (_maxFrac * 0.85).clamp(0.40, _maxFrac),
              minChildSize: 0.40,
              maxChildSize: _maxFrac,
              expand: false,
              builder: (_, scrollCtrl) {
                return Container(
                  decoration: BoxDecoration(
                    color: bg,
                  ),
                  child: Column(
                    children: [
                      // Drag handle
                      Padding(
                        padding: const EdgeInsets.only(top: 10, bottom: 6),
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: faint,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      // Header: season pill (if multi-season) + close
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                        child: Row(
                          children: [
                            if (seasons.length > 1) ...[
                              GestureDetector(
                                onTap: () async {
                                  final picked = await showModalBottomSheet<String>(
                                    context: sheetCtx,
                                    backgroundColor: bg,
                                    shape: const RoundedRectangleBorder(
                                      borderRadius: BorderRadius.vertical(
                                          top: Radius.circular(16)),
                                    ),
                                    builder: (_) => ListView(
                                      shrinkWrap: true,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 8),
                                      children: seasons.map((s) {
                                        final isSel = s == sheetSeason;
                                        return GestureDetector(
                                          onTap: () =>
                                              Navigator.pop(sheetCtx, s),
                                          child: AnimatedContainer(
                                            duration: const Duration(
                                                milliseconds: 150),
                                            margin: const EdgeInsets.symmetric(
                                                vertical: 4),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 16, vertical: 14),
                                            decoration: BoxDecoration(
                                              gradient: isSel
                                                  ? LinearGradient(
                                                      begin:
                                                          Alignment.centerLeft,
                                                      end: Alignment.centerRight,
                                                      colors: [
                                                        accent.withValues(
                                                            alpha: 0.30),
                                                        accent.withValues(
                                                            alpha: 0.10),
                                                      ],
                                                    )
                                                  : null,
                                              color: isSel ? null : card,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                color: isSel
                                                    ? accent.withValues(
                                                        alpha: 0.55)
                                                    : Colors.transparent,
                                                width: 0.8,
                                              ),
                                            ),
                                            child: Text(
                                              s,
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: isSel ? accent : onSurface,
                                                fontSize: 14,
                                                fontWeight: isSel
                                                    ? FontWeight.w600
                                                    : FontWeight.w400,
                                              ),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  );
                                  if (picked != null) {
                                    setSt(() => sheetSeason = picked);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: card,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        sheetSeason ?? seasons.first,
                                        style: TextStyle(
                                          color: onSurface,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(Icons.keyboard_arrow_down_rounded,
                                          size: 18, color: grey),
                                    ],
                                  ),
                                ),
                              ),
                            ] else
                              Text(
                                'Épisodes (${display.length})',
                                style: TextStyle(
                                  color: onSurface,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            const Spacer(),
                            GestureDetector(
                              onTap: () => Navigator.pop(sheetCtx),
                              child: Icon(Icons.close_rounded,
                                  size: 22, color: grey),
                            ),
                          ],
                        ),
                      ),
                      // Episode grid
                      Expanded(
                        child: GridView.builder(
                          controller: scrollCtrl,
                          padding:
                              const EdgeInsets.fromLTRB(16, 0, 16, 32),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            // 5 columns on narrow phones (≤ 390 pt, e.g. iPhone 7/SE),
                            // 6 on wider devices — keeps cells readable.
                            crossAxisCount: MediaQuery.of(sheetCtx).size.width <= 390 ? 5 : 6,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            childAspectRatio: 1.05,
                          ),
                          itemCount: display.length,
                          itemBuilder: (_, i) {
                            final ch = display[i];
                            final epNum = _epNum(ch.name, i + 1);
                            final label =
                                epNum.toString().padLeft(2, '0');
                            final isWatched = ch.isRead ?? false;
                            return GestureDetector(
                              onTap: () {
                                Navigator.pop(sheetCtx);
                                _loadEpisodeInBanner(ch);
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isWatched
                                      ? accent.withValues(alpha: 0.85)
                                      : card,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    color: isWatched
                                        ? Colors.white
                                        : onSurface,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // ─── TABS ────────────────────────────────────────────────────────────────────

  Widget _buildDetailsTab(List<Chapter> chapters) {
    final manga = widget.manga;

    // ── Parse gallery images embedded in description ───────────────────────
    final rawDesc = manga.description ?? '';
    const galleryMark = '\n__GALLERY__:';
    final gIdx = rawDesc.indexOf(galleryMark);
    final description =
        gIdx >= 0 ? rawDesc.substring(0, gIdx) : rawDesc;
    final galleryUrls = gIdx >= 0
        ? rawDesc
            .substring(gIdx + galleryMark.length)
            .split('||')
            .where((u) => u.trim().isNotEmpty)
            .toList()
        : <String>[];

    // ── Cast / director from artist (extension: "Director, Actor1, Actor2, …") ──
    final _artistParts = (manga.artist ?? '').split(',')
        .map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    final director  = _artistParts.isNotEmpty ? _artistParts.first : null;
    final castNames = _artistParts.length > 1 ? _artistParts.sublist(1) : <String>[];

    // ── Year from author (extension sets author = releaseYear) ───────────────
    final year = (manga.author ?? '').trim();

    // ── Country from genre list (·-prefixed by extension) ────────────────────
    final country = (manga.genre ?? []).where((g) => g.startsWith('·'))
        .map((g) => g.substring(1)).firstOrNull;

    // ── IMDb rating from description ("IMDb X.X") ────────────────────────────
    final _imdbM = RegExp(r'IMDb\s+([\d.]+)').firstMatch(description);
    final imdbRating = _imdbM?.group(1);

    // ── Status label + colour ──────────────────────────────────────────────
    String statusLabel = '';
    Color statusColor = _grey;
    switch (manga.status) {
      case Status.ongoing:
        statusLabel = 'En cours';
        statusColor = const Color(0xFF22C55E);
        break;
      case Status.completed:
      case Status.publishingFinished:
        statusLabel = 'Terminé';
        statusColor = _accent;
        break;
      case Status.canceled:
        statusLabel = 'Annulé';
        statusColor = const Color(0xFFEF4444);
        break;
      case Status.onHiatus:
        statusLabel = 'En pause';
        statusColor = const Color(0xFFF59E0B);
        break;
      default:
        break;
    }

    // ── Type keyword + clean genre list ───────────────────────────────────
    const typeKws = ['TV', 'Movie', 'Film', 'OVA', 'ONA', 'Special', 'Music'];
    final typeTag = (manga.genre ?? [])
        .where((g) => typeKws.any((k) => g.toLowerCase() == k.toLowerCase()))
        .firstOrNull;
    final genres = (manga.genre ?? [])
        .where((g) =>
            !typeKws.any((k) => g.toLowerCase() == k.toLowerCase()) &&
            !g.startsWith('·'))
        .toList();

    final isMovie = _isMovie(chapters);

    // ── Build structured info rows ─────────────────────────────────────────
    final infoRows = <_DetailInfoRow>[];
    // Année (uniquement si c'est vraiment une année numérique)
    if (year.isNotEmpty && RegExp(r'^\d{4}$').hasMatch(year)) {
      infoRows.add(_DetailInfoRow(label: 'Année', value: year));
    }
    if (country != null && country.isNotEmpty) {
      infoRows.add(_DetailInfoRow(label: 'Pays', value: country));
    }
    if (imdbRating != null) {
      infoRows.add(_DetailInfoRow(label: 'IMDb', value: '★ ' + imdbRating));
    }
    if (director != null && director.isNotEmpty) {
      infoRows.add(_DetailInfoRow(label: 'Réalisateur', value: director));
    }
    // Nb épisodes / type
    if (chapters.isNotEmpty) {
      infoRows.add(_DetailInfoRow(
        label: isMovie ? 'Type' : 'Épisodes',
        value: isMovie ? 'Film' : '${chapters.length}',
        accent: true,
        accentColor: _accent,
      ));
    }
    // Statut
    if (statusLabel.isNotEmpty) {
      infoRows.add(_DetailInfoRow(
        label: 'Statut',
        value: statusLabel,
        accent: true,
        accentColor: statusColor,
      ));
    }
    // Langue
    if (manga.lang?.isNotEmpty ?? false) {
      infoRows.add(_DetailInfoRow(label: 'Langue', value: manga.lang!.toUpperCase()));
    }
    // Format
    if (typeTag != null) {
      infoRows.add(_DetailInfoRow(label: 'Format', value: typeTag));
    }
    // Source
    if (manga.source?.isNotEmpty ?? false) {
      infoRows.add(_DetailInfoRow(label: 'Source', value: manga.source!));
    }


    // ── Check if truly empty ───────────────────────────────────────────────
    final hasAnyContent = description.isNotEmpty ||
        galleryUrls.isNotEmpty ||
        infoRows.isNotEmpty ||
        genres.isNotEmpty ||
        castNames.isNotEmpty;

    if (!hasAnyContent) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: _card,
                  shape: BoxShape.circle,
                  border: Border.all(color: _faint, width: 1.5),
                ),
                child: Icon(Icons.info_outline_rounded, size: 30, color: _grey),
              ),
              const SizedBox(height: 16),
              Text(
                'Aucun détail disponible',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Les informations apparaîtront\nlorsqu'elles seront disponibles.",
                style: TextStyle(color: _grey, fontSize: 13, height: 1.5),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 52),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Synopsis ──────────────────────────────────────────────────────
          if (description.isNotEmpty) ...[
            _sectionLabel('Synopsis'),
            const SizedBox(height: 10),
            StatefulBuilder(
              builder: (ctx, setSt) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedSize(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeInOut,
                    child: ConstrainedBox(
                      constraints: _isDescriptionExpanded
                          ? const BoxConstraints()
                          : const BoxConstraints(maxHeight: 80),
                      child: Text(
                        description,
                        overflow: _isDescriptionExpanded
                            ? TextOverflow.visible
                            : TextOverflow.clip,
                        style: TextStyle(
                            color: _grey, fontSize: 13.5, height: 1.65),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => setSt(() =>
                        _isDescriptionExpanded = !_isDescriptionExpanded),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _isDescriptionExpanded ? 'Voir moins' : 'Voir plus',
                          style: TextStyle(
                            color: _accent,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 3),
                        AnimatedRotation(
                          turns: _isDescriptionExpanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 260),
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 18,
                            color: _accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
          ],

          // ── Aperçus / galerie ─────────────────────────────────────────────
          if (galleryUrls.isNotEmpty) ...[
            _sectionLabel('Aperçus'),
            const SizedBox(height: 10),
            SizedBox(
              height: 148,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: galleryUrls.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: cachedNetworkImage(
                    imageUrl: toImgUrl(galleryUrls[i]),
                    width: 230,
                    height: 148,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 26),
          ],

          // ── Informations — grid 2 colonnes ────────────────────────────────
          if (infoRows.isNotEmpty) ...[
            _sectionLabel('Informations'),
            const SizedBox(height: 12),
            _buildInfoGrid(infoRows),
            const SizedBox(height: 26),
          ],

          // ── Genres ────────────────────────────────────────────────────────
          if (genres.isNotEmpty) ...[
            _sectionLabel('Genres'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final g in genres)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 13, vertical: 6),
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: _accent.withValues(alpha: 0.25),
                          width: 0.8),
                    ),
                    child: Text(
                      g,
                      style: TextStyle(
                          color: _onSurface.withValues(alpha: 0.75),
                          fontSize: 12),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 26),
          ],

          // ── Casting ───────────────────────────────────────────────────────
          if (castNames.isNotEmpty) ...[
            _sectionLabel('Casting'),
            const SizedBox(height: 12),
            SizedBox(
              height: 102,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: castNames.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (ctx, i) {
                  final name = castNames[i];
                  final initials = name
                      .split(' ')
                      .take(2)
                      .map((w) => w.isNotEmpty ? w[0] : '')
                      .join()
                      .toUpperCase();
                  final col = _castColor(i);
                  return SizedBox(
                    width: 70,
                    child: Column(
                      children: [
                        Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            color: col.withValues(alpha: 0.14),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: col.withValues(alpha: 0.38),
                                width: 1.5),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            initials,
                            style: TextStyle(
                              color: col,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          name,
                          style: TextStyle(
                              color: _grey,
                              fontSize: 10.5,
                              height: 1.3),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  // ── Info grid 2 colonnes ───────────────────────────────────────────────────

  Widget _buildInfoGrid(List<_DetailInfoRow> rows) {
    const hGap = 10.0;
    const vGap = 10.0;
    const cellH = 62.0;

    final rowWidgets = <Widget>[];
    for (int i = 0; i < rows.length; i += 2) {
      final left = rows[i];
      final hasRight = i + 1 < rows.length;
      final right = hasRight ? rows[i + 1] : null;

      rowWidgets.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _infoCell(left, cellH)),
            if (hasRight && right != null) ...[
              const SizedBox(width: hGap),
              Expanded(child: _infoCell(right, cellH)),
            ],
          ],
        ),
      );

      if (i + 2 < rows.length) {
        rowWidgets.add(const SizedBox(height: vGap));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rowWidgets,
    );
  }

  Widget _infoCell(_DetailInfoRow row, double h) {
    final Color bg = row.accent
        ? row.accentColor!.withValues(alpha: 0.09)
        : _card;
    final Color borderColor = row.accent
        ? row.accentColor!.withValues(alpha: 0.30)
        : _faint.withValues(alpha: 0.45);
    final Color valueColor = row.accent ? row.accentColor! : _textPrimary;
    return Container(
      height: h,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            row.label,
            style: TextStyle(
              color: _grey,
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            row.value,
            style: TextStyle(
              color: valueColor,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              height: 1.1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Color _castColor(int index) {
    const colors = [
      Color(0xFF6366F1),
      Color(0xFFEC4899),
      Color(0xFF14B8A6),
      Color(0xFFF59E0B),
      Color(0xFF10B981),
      Color(0xFFEF4444),
      Color(0xFF8B5CF6),
      Color(0xFF3B82F6),
      Color(0xFFF97316),
    ];
    return colors[index % colors.length];
  }

  Widget _infoChip(IconData icon, String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: fg.withValues(alpha: 0.20), width: 0.7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon == Icons.circle)
            Container(
              width: 7,
              height: 7,
              decoration:
                  BoxDecoration(shape: BoxShape.circle, color: fg),
            )
          else
            Icon(icon, size: 12, color: fg),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
                color: fg,
                fontSize: 12,
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: TextStyle(
            color: _textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700),
      );

  Widget _detailRow(IconData icon, String text) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: _grey),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style:
                  TextStyle(color: _grey, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      );

  Widget _buildRecommendationsTab() {
    // Pour vous : appel via l'extension getRecommendations (API native MovieBox).
    final _recSrc = getSource(
      widget.manga.lang ?? '',
      widget.manga.source ?? '',
      widget.manga.sourceId,
    );

    Widget _empty() => Center(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    color: _card, shape: BoxShape.circle,
                    border: Border.all(color: _faint, width: 1.5),
                  ),
                  child: Icon(Icons.movie_filter_outlined, color: _grey, size: 26),
                ),
                const SizedBox(height: 14),
                Text('Aucune recommandation',
                    style: TextStyle(color: _onSurface.withValues(alpha: 0.7),
                        fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                Text('Les suggestions apparaîtront ici.',
                    style: TextStyle(color: _grey, fontSize: 12),
                    textAlign: TextAlign.center),
              ],
            ),
          ),
        );

    if (_recSrc == null) return _empty();

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: getIsolateService
          .get<List<dynamic>>(
            url: widget.manga.link ?? '',
            source: _recSrc,
            serviceType: 'getRecommendations',
            proxyServer: '',
          )
          .then((raw) => raw.map((e) => Map<String, dynamic>.from(e as Map)).toList()),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.62,
            ),
            itemCount: 9,
            itemBuilder: (_, __) => _SkeletonBox(radius: 8, aspect: null),
          );
        }
        final recs = snap.data;
        if (recs == null || recs.isEmpty) return _empty();

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.62,
          ),
          itemCount: recs.length,
          itemBuilder: (_, i) {
            final rec    = recs[i];
            final imgUrl = rec['imageUrl'] as String?;
            final title  = (rec['name'] as String?) ?? '';
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: imgUrl != null
                        ? cachedNetworkImage(
                            imageUrl: imgUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          )
                        : Container(
                            color: _card,
                            child: Icon(Icons.movie_outlined,
                                color: _grey, size: 28),
                          ),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  title,
                  style: TextStyle(
                      color: _textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildCommentsTab() {
    final source = getSource(
      widget.manga.lang ?? '',
      widget.manga.source ?? '',
      widget.manga.sourceId,
    );
    return _CommentsSection(
      url: widget.manga.link ?? '',
      title: widget.manga.name ?? '',
      source: source,
      accent: _accent,
      bg: _bg,
      card: _card,
      onSurface: _onSurface,
      grey: _grey,
      faint: _faint,
      textPrimary: _textPrimary,
    );
  }
  // ─── DOWNLOAD SHEET ─────────────────────────────────────────────────────────

  void _showDownloadSheet(BuildContext ctx, List<Chapter> chapters) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      elevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (_) => _DownloadSheet(
        manga: widget.manga,
        chapters: chapters,
        onDownload: (selected) {
          Navigator.pop(ctx);
          for (final ch in selected) {
            final entry =
                isar.downloads.filter().idEqualTo(ch.id).findFirstSync();
            if (entry == null || !(entry.isDownload ?? false)) {
              ref.read(addDownloadToQueueProvider(chapter: ch));
            }
          }
          ref.read(processDownloadsProvider());
          if (selected.isNotEmpty)
            _showAfterDownloadSheet(ctx, selected.length);
        },
      ),
    );
  }

  void _showAfterDownloadSheet(BuildContext ctx, int count) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.download_rounded, color: _accent, size: 20),
                  const SizedBox(width: 8),
                  Text('Téléchargement $count fichier(s)',
                      style: TextStyle(
                          color: _textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Icon(Icons.close, color: _grey, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Regardez pendant le téléchargement, sans données supplémentaires.',
                style:
                    TextStyle(color: _grey, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.of(ctx).pushNamed('/downloadQueue');
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _textPrimary,
                        side: BorderSide(color: _faint),
                        padding:
                            const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Voir le téléchargement'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accent,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Regarder maintenant'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── OPTIONS SHEET ──────────────────────────────────────────────────────────

  void _openInBrowser() {
    final source = getSource(
        widget.manga.lang ?? '',
        widget.manga.source ?? '',
        widget.manga.sourceId);
    if (source == null || (widget.manga.link ?? '').isEmpty) return;
    final raw = '${source.baseUrl}${widget.manga.link!.getUrlWithoutDomain}';
    context.push("/mangawebview",
        extra: {'url': raw, 'title': widget.manga.name ?? ''});
  }

  void _showOptionsSheet(BuildContext ctx, List<Chapter> chapters) {
    final source = getSource(
        widget.manga.lang ?? '',
        widget.manga.source ?? '',
        widget.manga.sourceId);
    showModalBottomSheet(
      context: ctx,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38, height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              decoration: BoxDecoration(
                  color: _faint,
                  borderRadius: BorderRadius.circular(2)),
            ),
            ListTile(
              leading: Icon(Icons.refresh, color: _grey),
              title: Text('Actualiser',
                  style: TextStyle(color: _textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                widget.checkForUpdate(true);
              },
            ),
            ListTile(
              leading: Icon(Icons.open_in_browser_outlined, color: _grey),
              title: Text('Ouvrir dans le navigateur',
                  style: TextStyle(color: _textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                _openInBrowser();
              },
            ),
            if (source != null)
              ListTile(
                leading: Icon(Icons.settings_outlined, color: _grey),
                title: Text("Paramètres de l'extension",
                    style: TextStyle(color: _textPrimary)),
                onTap: () {
                  Navigator.pop(ctx);
                  ctx.pushNamed('extension_detail', extra: source);
                },
              ),
            ListTile(
              leading: Icon(Icons.share, color: _grey),
              title: Text('Partager',
                  style: TextStyle(color: _textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                _share(ctx);
              },
            ),
            ListTile(
              leading: Icon(Icons.download, color: _grey),
              title: Text('Tout télécharger',
                  style: TextStyle(color: _textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                _downloadAll(chapters);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ─── AIDE BUTTON ────────────────────────────────────────────────────────────

class _AideButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AideButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.help_outline_rounded, color: Colors.white, size: 18),
            SizedBox(height: 1),
            Text('Aide',
                style: TextStyle(color: Colors.white, fontSize: 9.5)),
          ],
        ),
      ),
    );
  }
}

// ─── DOWNLOAD SHEET — Refonte complète style MovieBox ─────────────────────────

enum _Downloader { internal, aria2, external }

class _DownloadSheet extends ConsumerStatefulWidget {
  final Manga manga;
  final List<Chapter> chapters;
  final void Function(List<Chapter> selected) onDownload;

  const _DownloadSheet({
    required this.manga,
    required this.chapters,
    required this.onDownload,
  });

  @override
  ConsumerState<_DownloadSheet> createState() => _DownloadSheetState();
}

class _DownloadSheetState extends ConsumerState<_DownloadSheet> {
  // ── Theme ─────────────────────────────────────────────────────────────────────
  Color get _accent  => Theme.of(context).primaryColor;
  Color get _bg      => Theme.of(context).scaffoldBackgroundColor;
  Color get _card    => Theme.of(context).colorScheme.surfaceContainerHighest;
  Color get _text    => Theme.of(context).colorScheme.onSurface;
  Color get _grey    => _text.withValues(alpha: 0.50);
  Color get _faint   => _text.withValues(alpha: 0.13);

  // ── State ─────────────────────────────────────────────────────────────────────
  bool _loading = true;
  List<Video> _videos = [];
  String? _selectedQuality;
  String? _selectedLang;
  String? _selectedSeason;
  _Downloader _downloader = _Downloader.internal;
  String _externalApp = 'adm';
  static const Map<String, String> _externalAppIds = {
    'ADM': 'adm',
    '1DM': '1dm',
    'FDM': 'fdm',
    'IDM+': 'idm',
  };
  final Set<Chapter> _selected = {};
  bool _selectAll = false;

  bool get _isFilm {
    if (widget.chapters.length != 1) return false;
    final name = widget.chapters.first.name ?? '';
    return !RegExp(
            r'(?:Saison|Season|Ep\.?\s*\d|S\d+\s*E\d+|\bE\d+)',
            caseSensitive: false)
        .hasMatch(name);
  }

  static final _langRe =
      RegExp(r'\b(VF|VO|VOSTFR|VOSTA|MULTI|EN|FR|JAP?|ENG?)\b',
          caseSensitive: false);
  static final _seasonRe =
      RegExp(r'(?:[Ss]aison|[Ss]eason|\bS)[ ]*(\d+)');

  // ── Init ──────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    final pref = DownloadSettingsService.instance.preferredExternalDownloader ?? '';
    if (pref.isNotEmpty) _externalApp = pref;
    _loadVideos();
  }

  Future<void> _loadVideos() async {
    if (widget.chapters.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final result =
          await ref.read(getVideoListProvider(episode: widget.chapters.first).future);
      final videos = result.$1;
      final seen = <String>{};
      if (mounted) {
        setState(() {
          _videos = videos.where((v) => seen.add(v.originalUrl)).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Data derivations ──────────────────────────────────────────────────────────

  List<String> get _langs {
    final s = <String>{};
    for (final v in _videos) {
      final m = _langRe.firstMatch(v.quality);
      if (m != null) s.add(m.group(0)!.toUpperCase());
    }
    return s.toList()..sort();
  }

  List<String> get _seasons {
    final s = <String>{};
    for (final ch in widget.chapters) {
      final m = _seasonRe.firstMatch(ch.name ?? '');
      if (m != null) s.add('Saison ${m.group(1)}');
    }
    return s.toList()..sort();
  }

  /// Same ep-number logic as the parent widget's _epNum — used to dedup the
  /// grid so multi-source/multi-quality entries don't repeat the same episode.
  static int _epNumLocal(Chapter ch, int fallback) {
    final name = ch.name ?? '';
    final em = RegExp(r'(?:Ep\.?|Episode)\s*(\d+)', caseSensitive: false).firstMatch(name);
    if (em != null) return int.tryParse(em.group(1)!) ?? fallback;
    final all = RegExp(r'\d+').allMatches(name).toList();
    if (all.isNotEmpty) return int.tryParse(all.last.group(0)!) ?? fallback;
    return fallback;
  }

  List<Chapter> get _displayChapters {
    List<Chapter> base;
    if (_selectedSeason == null) {
      base = widget.chapters;
    } else {
      final num = _selectedSeason!.replaceAll('Saison ', '');
      base = widget.chapters.where((ch) {
        final m = _seasonRe.firstMatch(ch.name ?? '');
        return m != null && m.group(1) == num;
      }).toList();
    }
    // Dedup: keep first Chapter per distinct episode number so multi-source
    // duplicates don't inflate the grid.
    final seen = <int>{};
    final result = <Chapter>[];
    for (var i = 0; i < base.length; i++) {
      if (seen.add(_epNumLocal(base[i], i))) result.add(base[i]);
    }
    return result;
  }

  List<String> get _qualities {
    var src = _videos;
    if (_selectedLang != null) {
      final f = src
          .where((v) => v.quality.toUpperCase().contains(_selectedLang!))
          .toList();
      if (f.isNotEmpty) src = f;
    }
    final seen = <String>{};
    return src.map((v) => _normQ(v.quality)).where(seen.add).toList();
  }

  static String _normQ(String raw) {
    if (raw.trim().isEmpty) return 'Auto';
    final m = RegExp(r'^(\d{3,4})[pP]').firstMatch(raw);
    if (m != null) return '${m.group(1)}P';
    final s = raw.toLowerCase();
    if (s.contains('4k') || s.contains('2160')) return '4K';
    if (s.contains('1080') || s.contains('fhd')) return '1080P';
    if (s.contains('720') || s.contains('hd')) return '720P';
    if (s.contains('480') || s.contains('sd')) return '480P';
    if (s.contains('360')) return '360P';
    if (s.contains('240')) return '240P';
    return raw.trim();
  }

  // ── Total size ────────────────────────────────────────────────────────────────
  String _totalSizeLabel() {
    if (_selected.isEmpty) return '';
    double totalMB = 0;
    bool anyKnown = false;
    for (final ch in _selected) {
      final sz = ch.downloadSize;
      if (sz != null && sz.trim().isNotEmpty) {
        final m = RegExp(r'([\d.]+)\s*(MB|GB|KB)', caseSensitive: false)
            .firstMatch(sz);
        if (m != null) {
          anyKnown = true;
          final num = double.tryParse(m.group(1)!) ?? 0;
          final unit = m.group(2)!.toUpperCase();
          if (unit == 'GB') totalMB += num * 1024;
          else if (unit == 'KB') totalMB += num / 1024;
          else totalMB += num;
        }
      }
    }
    if (!anyKnown) return '';
    if (totalMB >= 1024) {
      return '${(totalMB / 1024).toStringAsFixed(1)} GB';
    }
    return '${totalMB.toStringAsFixed(1)} MB';
  }

  String _epLabel(Chapter ch, int fallback) {
    if (_isFilm) return 'Film';
    final name = ch.name ?? '';
    // "Ep. N" / "Episode N" pattern first — most reliable when present.
    final epMatch =
        RegExp(r'(?:Ep\.?|Episode)\s*(\d+)', caseSensitive: false).firstMatch(name);
    if (epMatch != null) {
      return 'E${epMatch.group(1)!.padLeft(2, '0')}';
    }
    // Otherwise take the LAST number in the name, not the first — names like
    // "Saison 1 Episode 5" or "S01E05" always have the season number first,
    // so matching the first digit sequence produced "E01" for every episode.
    final all = RegExp(r'\d+').allMatches(name).toList();
    if (all.isNotEmpty) {
      return 'E${all.last.group(0)!.padLeft(2, '0')}';
    }
    return 'E${(fallback + 1).toString().padLeft(2, '0')}';
  }

  String _downloaderLabel() {
    switch (_downloader) {
      case _Downloader.internal: return 'Interne';
      case _Downloader.aria2: return 'Aria2';
      case _Downloader.external: return _externalApp.toUpperCase();
    }
  }

  // ── Download action ───────────────────────────────────────────────────────────
  Future<void> _startDownload() async {
    if (_selected.isEmpty) return;
    final chapters = _selected.toList();

    if (_downloader == _Downloader.external) {
      if (mounted) Navigator.pop(context);
      for (final ch in chapters) {
        try {
          final result = await ref.read(getVideoListProvider(episode: ch).future);
          final videos = result.$1;
          if (videos.isEmpty) {
            botToast('Aucun lien pour ${ch.name ?? '?'}');
            continue;
          }
          Video best = videos.first;
          if (_selectedQuality != null) {
            final match = videos.cast<Video?>().firstWhere(
              (v) => _normQ(v!.quality) == _selectedQuality,
              orElse: () => null,
            );
            if (match != null) best = match;
          }
          final launched = await ExternalDownloaderLauncher.launch(
            url: best.url,
            appId: _externalApp,
            headers: best.headers,
          );
          if (!launched && mounted) {
            botToast('Impossible d\'ouvrir $_externalApp — vérifiez qu\'il est installé.');
          }
        } catch (e) {
          if (mounted) botToast(e.toString().split('\n').first);
        }
      }
    } else {
      if (_selectedQuality != null) {
        // Store the chosen quality LABEL, not a URL: `_videos` was only ever
        // loaded for widget.chapters.first, so its URLs are meaningless for
        // every other selected episode (each episode has its own distinct
        // video list). downloadChapter() re-fetches each chapter's own
        // videos and matches this label against them at actual download time.
        final digitsMatch = RegExp(r'(\d{3,4})').firstMatch(_selectedQuality!);
        final qualityKey =
            digitsMatch?.group(1) ?? _selectedQuality!.trim().toLowerCase();
        for (final ch in chapters) {
          if (ch.id == null) continue;
          chapterPreferredQuality[ch.id!] = qualityKey;
        }
      }
      widget.onDownload(chapters);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final displayed  = _displayChapters;
    final screenH    = MediaQuery.of(context).size.height;
    final statusH    = MediaQuery.of(context).padding.top;
    final maxH       = screenH - 230 - statusH;
    final seasons    = _seasons;
    final qualities  = _qualities;
    final totalSz    = _totalSizeLabel();

    return Container(
      height: maxH,
      decoration: BoxDecoration(color: _bg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Close button only (no drag handle per user request) ───────────────
          _buildTopBar(),

          // ── Loading bar ───────────────────────────────────────────────────────
          if (_loading)
            LinearProgressIndicator(
              color: _accent,
              backgroundColor: _faint,
              minHeight: 2,
              borderRadius: BorderRadius.zero,
            ),

          // ── [Saison] [Qualité] [⬇ Télécharger] — 3 left-aligned box pills ────
          if (!_loading)
            _buildActionPillsRow(seasons, qualities, totalSz),

          // ── Divider ───────────────────────────────────────────────────────────
          Divider(height: 1, thickness: 0.8, color: _faint),

          // ── Select all header ─────────────────────────────────────────────────
          _buildSelectAllHeader(displayed),

          // ── Episode grid ──────────────────────────────────────────────────────
          Flexible(
            child: GridView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 2.4,
              ),
              itemCount: displayed.length,
              itemBuilder: (_, i) => _buildEpisodeCard(displayed[i], i),
            ),
          ),
        ],
      ),
    );
  }

  // ── Top bar: close X only — no drag handle ──────────────────────────────────
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 6),
      child: Row(
        children: [
          Text('Télécharger',
              style: TextStyle(
                  color: _text, fontSize: 15, fontWeight: FontWeight.w600)),
          const Spacer(),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(color: _faint, shape: BoxShape.circle),
              child: Icon(Icons.close, color: _grey, size: 15),
            ),
          ),
        ],
      ),
    );
  }

  // ── Box pill (same visual language as the main screen's Saison/Langue/
  // Qualité dropdown pills: transparent, thin border, no shadow) ──────────────
  Widget _buildPill({
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _faint, width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(color: _text.withValues(alpha: 0.75), fontSize: 13)),
            const SizedBox(width: 6),
            Icon(Icons.keyboard_arrow_down_rounded, color: _grey, size: 18),
          ],
        ),
      ),
    );
  }

  void _showPillSheet(
    String title,
    List<String> items,
    String? selectedValue,
    void Function(String) onSelect,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 10),
              child: Row(
                children: [
                  Text(title,
                      style: TextStyle(
                          color: _text, fontSize: 15, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(color: _card, shape: BoxShape.circle),
                      child: Icon(Icons.close, size: 16, color: _grey),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: _faint),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: items.map((item) {
                  final sel = item == selectedValue;
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      onSelect(item);
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: sel ? _accent.withValues(alpha: 0.12) : _card,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: sel ? _accent.withValues(alpha: 0.55) : Colors.transparent,
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        item,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: sel ? _accent : _text,
                          fontSize: 14,
                          fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 3 left-aligned boxes: [Saison] [Qualité] [⬇ Télécharger] ─────────────────
  // "Télécharger avec" removed per user request.
  // The download CTA is the 3rd box — highlighted when episodes are selected.
  Widget _buildActionPillsRow(
      List<String> seasons, List<String> qualities, String totalSz) {
    final empty = _selected.isEmpty;
    final dlLabel = empty
        ? 'Télécharger'
        : totalSz.isNotEmpty
            ? '${_selected.length} ep.  •  $totalSz'
            : _isFilm
                ? 'Film ↓'
                : '${_selected.length} ep. ↓';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Row(
        children: [
          // Season pill — only when multiple seasons
          if (seasons.length > 1) ...[
            _buildPill(
              label: _selectedSeason ?? seasons.first,
              onTap: () => _showPillSheet(
                'Saison',
                seasons,
                _selectedSeason,
                (s) => setState(() {
                  _selectedSeason = _selectedSeason == s ? null : s;
                  _selected.clear();
                  _selectAll = false;
                }),
              ),
            ),
            const SizedBox(width: 8),
          ],
          // Quality pill — only when qualities loaded
          if (qualities.isNotEmpty) ...[
            _buildPill(
              label: _selectedQuality ?? qualities.first,
              onTap: () => _showPillSheet(
                'Résolution',
                qualities,
                _selectedQuality ?? qualities.first,
                (q) => setState(() => _selectedQuality = q),
              ),
            ),
            const SizedBox(width: 8),
          ],
          // Download CTA pill — always last, highlighted when episodes selected
          GestureDetector(
            onTap: empty ? null : _startDownload,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: empty ? Colors.transparent : _accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: empty ? _faint : _accent,
                  width: empty ? 0.8 : 1.2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.download_rounded,
                      size: 15,
                      color: empty ? _grey : _accent),
                  const SizedBox(width: 6),
                  Text(
                    dlLabel,
                    style: TextStyle(
                      color: empty ? _grey : _accent,
                      fontSize: 13,
                      fontWeight: empty ? FontWeight.normal : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Select all header ─────────────────────────────────────────────────────────
  Widget _buildSelectAllHeader(List<Chapter> displayed) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => setState(() {
              _selectAll = !_selectAll;
              if (_selectAll) {
                _selected.addAll(displayed);
              } else {
                _selected.removeAll(displayed);
              }
            }),
            child: Row(
              children: [
                _ModernCheckbox(checked: _selectAll, accent: _accent, faint: _faint),
                const SizedBox(width: 10),
                Text(
                  'Tout sélectionner',
                  style: TextStyle(
                    color: _text.withValues(alpha: 0.75),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Text(
            _isFilm
                ? 'Film'
                : '${displayed.length} épisode${displayed.length > 1 ? 's' : ''}',
            style: TextStyle(color: _grey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ── Episode card (grid) ───────────────────────────────────────────────────────
  Widget _buildEpisodeCard(Chapter chapter, int index) {
    final sel = _selected.contains(chapter);
    final epLabel = _epLabel(chapter, index);
    final rawSize = chapter.downloadSize?.trim();
    final sizeLabel = (rawSize != null && rawSize.isNotEmpty) ? rawSize : null;

    return GestureDetector(
      onTap: () => setState(() {
        sel ? _selected.remove(chapter) : _selected.add(chapter);
        _selectAll = _selected.length == _displayChapters.length;
      }),
      child: Container(
        decoration: BoxDecoration(
          color: sel ? _accent.withValues(alpha: 0.10) : _card,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: sel ? _accent.withValues(alpha: 0.55) : Colors.transparent,
            width: 0.9,
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    epLabel,
                    style: TextStyle(
                      color: sel ? _accent : _text,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (sizeLabel != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      sizeLabel,
                      style: TextStyle(color: _grey, fontSize: 9),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (sel)
              Positioned(
                top: 4,
                right: 4,
                child: Icon(Icons.check_circle_rounded,
                    color: _accent, size: 13),
              ),
          ],
        ),
      ),
    );
  }

}

// ── Modern checkbox ────────────────────────────────────────────────────────────
class _ModernCheckbox extends StatelessWidget {
  final bool checked;
  final Color accent;
  final Color faint;
  const _ModernCheckbox({
    required this.checked,
    required this.accent,
    required this.faint,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: checked ? accent : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: checked ? accent : faint.withValues(alpha: 0.9),
          width: 1.6,
        ),
      ),
      child: checked
          ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
          : null,
    );
  }
}

// ─── COMMENT MODEL ──────────────────────────────────────────────────────────

class _Comment {
  final String id;
  final String author;
  final String timeAgo;
  final String body;
  int likes;
  bool liked;
  bool collapsed;
  final List<_Comment> replies;

  _Comment({
    required this.id,
    required this.author,
    required this.timeAgo,
    required this.body,
    this.likes = 0,
    this.liked = false,
    this.collapsed = false,
    List<_Comment>? replies,
  }) : replies = replies ?? [];
}

// ─── COMMENTS SECTION ────────────────────────────────────────────────────────

class _CommentsSection extends StatefulWidget {
  final String url;
  final String title;
  final Source? source;
  final Color accent;
  final Color bg;
  final Color card;
  final Color onSurface;
  final Color grey;
  final Color faint;
  final Color textPrimary;

  const _CommentsSection({
    required this.url,
    required this.title,
    this.source,
    required this.accent,
    required this.bg,
    required this.card,
    required this.onSurface,
    required this.grey,
    required this.faint,
    required this.textPrimary,
  });

  @override
  State<_CommentsSection> createState() => _CommentsSectionState();
}

class _CommentsSectionState extends State<_CommentsSection> {
  late List<_Comment> _comments;
  bool _loading = true;
  String? _replyingToId;
  final _replyController = TextEditingController();
  final _commentController = TextEditingController();
  String _sortMode = 'Meilleures';

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _replyController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() { _loading = true; });
    final src = widget.source;
    if (src == null) {
      if (!mounted) return;
      setState(() { _comments = []; _loading = false; });
      return;
    }
    try {
      final raw = await getIsolateService.get<List<dynamic>>(
        url: widget.url, source: src,
        serviceType: 'getComments', proxyServer: '',
      );
      if (!mounted) return;
      final mapped = raw.map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        final sv = m['score']; final sc = sv is num ? sv.toDouble() : -1.0;
        final dt = (m['date'] as String?) ?? '';
        return _Comment(
          id: ((m['author'] ?? 'anon') as String) + dt,
          author: (m['author'] as String?) ?? 'Anonyme',
          timeAgo: dt,
          body: ((m['content'] as String?) ?? '').trim() +
              (sc > 0 ? '  ★' + sc.toStringAsFixed(1) : ''),
        );
      }).toList();
      setState(() { _comments = mapped; _loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _comments = []; _loading = false; });
    }
  }

  List<_Comment> _mockComments() => [
    _Comment(
      id: 'c1',
      author: 'AlexDupont',
      timeAgo: 'il y a 3h',
      body: 'Excellent film ! Paul Walker était vraiment incroyable dans ce rôle. La scène de parkour au début m\'a coupé le souffle.',
      likes: 142,
      replies: [
        _Comment(
          id: 'c1r1',
          author: 'MarieF',
          timeAgo: 'il y a 2h',
          body: 'Complètement d\'accord, David Belle aussi ! Le fondateur du parkour en personne, ça change tout.',
          likes: 67,
          replies: [
            _Comment(
              id: 'c1r1r1',
              author: 'AlexDupont',
              timeAgo: 'il y a 1h',
              body: 'Exactement ! Et la chorégraphie est clairement réelle, pas du CGI.',
              likes: 29,
            ),
          ],
        ),
        _Comment(
          id: 'c1r2',
          author: 'FilmFan75',
          timeAgo: 'il y a 2h',
          body: 'Paul Walker R.I.P. 🙏 Un acteur qui nous manque encore.',
          likes: 201,
        ),
      ],
    ),
    _Comment(
      id: 'c2',
      author: 'CineClub_Paris',
      timeAgo: 'il y a 5h',
      body: 'Le remake américain de "Banlieue 13". Si vous aimez, regardez l\'original avec Cyril Raffaelli, il est encore meilleur !',
      likes: 88,
      replies: [
        _Comment(
          id: 'c2r1',
          author: 'OriginalFan',
          timeAgo: 'il y a 4h',
          body: 'Oui ! B13 est un chef-d\'œuvre du cinéma d\'action français. Luc Besson au top.',
          likes: 54,
        ),
      ],
    ),
    _Comment(
      id: 'c3',
      author: 'NightOwl_42',
      timeAgo: 'il y a 8h',
      body: 'L\'action est bonne mais le scénario est assez prévisible. 3.5/5 pour moi.',
      likes: 31,
      replies: [],
    ),
    _Comment(
      id: 'c4',
      author: 'StreamAddict',
      timeAgo: 'il y a 1j',
      body: 'Je viens de finir. La fin est satisfaisante même si on la voit venir dès le début. Bon divertissement du vendredi soir.',
      likes: 19,
      replies: [
        _Comment(
          id: 'c4r1',
          author: 'WeekendVibes',
          timeAgo: 'il y a 20h',
          body: 'Pareil, parfait pour ne pas trop se prendre la tête !',
          likes: 8,
        ),
      ],
    ),
  ];

  void _toggleLike(_Comment comment) {
    setState(() {
      if (comment.liked) {
        comment.likes--;
        comment.liked = false;
      } else {
        comment.likes++;
        comment.liked = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              strokeWidth: 2,
              color: widget.accent,
            ),
            const SizedBox(height: 12),
            Text('Chargement des commentaires…',
                style: TextStyle(color: widget.grey, fontSize: 13)),
          ],
        ),
      );
    }

    final total = _comments.fold<int>(
      0, (sum, c) => sum + 1 + c.replies.fold<int>(0, (s, r) => s + 1 + r.replies.length));

    return Column(
      children: [
        // Header bar
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Row(
            children: [
              Text(
                '$total commentaires',
                style: TextStyle(
                  color: widget.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _sortMode = _sortMode == 'Meilleures' ? 'Récents' : 'Meilleures';
                    if (_sortMode == 'Récents') {
                      _comments.sort((a, b) => b.timeAgo.compareTo(a.timeAgo));
                    } else {
                      _comments.sort((a, b) => b.likes.compareTo(a.likes));
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: widget.card,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: widget.faint, width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.sort_rounded, size: 13, color: widget.grey),
                      const SizedBox(width: 4),
                      Text(
                        _sortMode,
                        style: TextStyle(color: widget.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // Write comment bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: GestureDetector(
            onTap: () => _showWriteCommentSheet(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: widget.card,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: widget.faint, width: 0.8),
              ),
              child: Row(
                children: [
                  _CommentAvatar(
                    author: 'Moi',
                    size: 26,
                    accent: widget.accent,
                    isLight: false,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Ajouter un commentaire…',
                    style: TextStyle(color: widget.grey, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ),
        Divider(height: 1, color: widget.faint),
        // Comment list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: _comments.length,
            itemBuilder: (ctx, i) => _CommentTile(
              comment: _comments[i],
              depth: 0,
              accent: widget.accent,
              bg: widget.bg,
              card: widget.card,
              grey: widget.grey,
              faint: widget.faint,
              textPrimary: widget.textPrimary,
              onLike: _toggleLike,
              onReply: (c) => _showWriteCommentSheet(context, replyTo: c),
              onCollapse: (_) => setState(() {}),
            ),
          ),
        ),
      ],
    );
  }

  void _showWriteCommentSheet(BuildContext ctx, {_Comment? replyTo}) {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          decoration: BoxDecoration(
            color: widget.bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: widget.faint,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (replyTo != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: widget.card,
                      borderRadius: BorderRadius.circular(8),
                      border: Border(left: BorderSide(color: widget.accent, width: 3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          replyTo.author,
                          style: TextStyle(
                            color: widget.accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          replyTo.body,
                          style: TextStyle(color: widget.grey, fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _CommentAvatar(author: 'Moi', size: 32, accent: widget.accent, isLight: false),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: ctrl,
                        autofocus: true,
                        maxLines: 4,
                        minLines: 1,
                        style: TextStyle(color: widget.textPrimary, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: replyTo != null
                              ? 'Répondre à ${replyTo.author}…'
                              : 'Votre commentaire…',
                          hintStyle: TextStyle(color: widget.grey),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        final text = ctrl.text.trim();
                        if (text.isEmpty) return;
                        setState(() {
                          if (replyTo != null) {
                            replyTo.replies.add(_Comment(
                              id: 'new_${DateTime.now().millisecondsSinceEpoch}',
                              author: 'Moi',
                              timeAgo: 'à l\'instant',
                              body: text,
                            ));
                          } else {
                            _comments.insert(0, _Comment(
                              id: 'new_${DateTime.now().millisecondsSinceEpoch}',
                              author: 'Moi',
                              timeAgo: 'à l\'instant',
                              body: text,
                            ));
                          }
                        });
                        Navigator.pop(sheetCtx);
                      },
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: widget.accent,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── COMMENT TILE (recursive) ────────────────────────────────────────────────

class _CommentTile extends StatelessWidget {
  final _Comment comment;
  final int depth;
  final Color accent;
  final Color bg;
  final Color card;
  final Color grey;
  final Color faint;
  final Color textPrimary;
  final void Function(_Comment) onLike;
  final void Function(_Comment) onReply;
  final void Function(_Comment) onCollapse;

  static const _kDepthColors = [
    Color(0xFF6366F1),
    Color(0xFF14B8A6),
    Color(0xFFF59E0B),
    Color(0xFFEC4899),
    Color(0xFF10B981),
  ];

  const _CommentTile({
    required this.comment,
    required this.depth,
    required this.accent,
    required this.bg,
    required this.card,
    required this.grey,
    required this.faint,
    required this.textPrimary,
    required this.onLike,
    required this.onReply,
    required this.onCollapse,
  });

  Color get _threadColor => _kDepthColors[depth % _kDepthColors.length];

  @override
  Widget build(BuildContext context) {
    final indent = depth * 16.0;
    return Padding(
      padding: EdgeInsets.only(left: indent, top: depth == 0 ? 12 : 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thread line + content
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Thread line (only for replies)
                if (depth > 0) ...[
                  GestureDetector(
                    onTap: () {
                      comment.collapsed = !comment.collapsed;
                      onCollapse(comment);
                    },
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: _threadColor.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                ] else ...[
                  const SizedBox(width: 16),
                ],
                // Comment body
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: 16, bottom: depth == 0 ? 0 : 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Author row
                        Row(
                          children: [
                            _CommentAvatar(
                              author: comment.author,
                              size: depth == 0 ? 30 : 24,
                              accent: _threadColor,
                              isLight: false,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Row(
                                children: [
                                  Text(
                                    comment.author,
                                    style: TextStyle(
                                      color: textPrimary,
                                      fontSize: depth == 0 ? 13 : 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    comment.timeAgo,
                                    style: TextStyle(color: grey, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            // Collapse toggle
                            GestureDetector(
                              onTap: () {
                                comment.collapsed = !comment.collapsed;
                                onCollapse(comment);
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(
                                  comment.collapsed
                                      ? Icons.expand_more_rounded
                                      : Icons.expand_less_rounded,
                                  color: grey,
                                  size: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (!comment.collapsed) ...[
                          const SizedBox(height: 6),
                          // Body
                          Text(
                            comment.body,
                            style: TextStyle(
                              color: textPrimary.withValues(alpha: 0.88),
                              fontSize: 13.5,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Action bar
                          Row(
                            children: [
                              // Like
                              GestureDetector(
                                onTap: () => onLike(comment),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      comment.liked
                                          ? Icons.favorite_rounded
                                          : Icons.favorite_border_rounded,
                                      color: comment.liked ? const Color(0xFFEF4444) : grey,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${comment.likes}',
                                      style: TextStyle(
                                        color: comment.liked ? const Color(0xFFEF4444) : grey,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Reply
                              GestureDetector(
                                onTap: () => onReply(comment),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.reply_rounded, color: grey, size: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Répondre',
                                      style: TextStyle(color: grey, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Replies count badge
                              if (comment.replies.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _threadColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: _threadColor.withValues(alpha: 0.30), width: 0.7),
                                  ),
                                  child: Text(
                                    '${comment.replies.length} réponse${comment.replies.length > 1 ? 's' : ''}',
                                    style: TextStyle(
                                      color: _threadColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          // Divider for top-level comments
                          if (depth == 0 && comment.replies.isEmpty) ...[
                            const SizedBox(height: 12),
                            Divider(height: 1, color: faint),
                          ],
                        ] else ...[
                          const SizedBox(height: 4),
                          Text(
                            '${comment.replies.length} réponse${comment.replies.length > 1 ? 's' : ''} cachée${comment.replies.length > 1 ? 's' : ''}',
                            style: TextStyle(color: grey, fontSize: 11),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Nested replies
          if (!comment.collapsed)
            for (final reply in comment.replies)
              _CommentTile(
                comment: reply,
                depth: depth + 1,
                accent: accent,
                bg: bg,
                card: card,
                grey: grey,
                faint: faint,
                textPrimary: textPrimary,
                onLike: onLike,
                onReply: onReply,
                onCollapse: onCollapse,
              ),
          // Separator for top-level with replies
          if (depth == 0 && comment.replies.isNotEmpty && !comment.collapsed)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Divider(height: 1, color: faint),
            ),
        ],
      ),
    );
  }
}

// ─── COMMENT AVATAR ──────────────────────────────────────────────────────────

class _CommentAvatar extends StatelessWidget {
  final String author;
  final double size;
  final Color accent;
  final bool isLight;

  const _CommentAvatar({
    required this.author,
    required this.size,
    required this.accent,
    required this.isLight,
  });

  @override
  Widget build(BuildContext context) {
    final initials = author.isEmpty
        ? '?'
        : author.trim().split(' ').map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').take(2).join();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: accent.withValues(alpha: 0.18),
        border: Border.all(color: accent.withValues(alpha: 0.40), width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          color: accent,
          fontSize: size * 0.38,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ─── ANIMATED TAB INDICATOR ─────────────────────────────────────────────────

class _AnimatedTabIndicator extends Decoration {
  final Color color;
  const _AnimatedTabIndicator({required this.color});

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _AnimatedTabIndicatorPainter(color: color, onChanged: onChanged);
}

class _AnimatedTabIndicatorPainter extends BoxPainter {
  final Color color;
  _AnimatedTabIndicatorPainter({required this.color, VoidCallback? onChanged})
      : super(onChanged);

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration cfg) {
    if (cfg.size == null) return;
    final rect = offset & cfg.size!;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    const h = 3.0;
    const r = 1.5;
    final bar = Rect.fromLTWH(
      rect.left + 4,
      rect.bottom - h,
      rect.width - 8,
      h,
    );
    canvas.drawRRect(
        RRect.fromRectAndRadius(bar, const Radius.circular(r)), paint);
  }
}

// ─── SLIVER TAB BAR DELEGATE ────────────────────────────────────────────────

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final Color color;

  const _TabBarDelegate(this.tabBar, {this.color = Colors.black});

  @override
  double get minExtent => tabBar.preferredSize.height + 1;
  @override
  double get maxExtent => tabBar.preferredSize.height + 1;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) =>
      ColoredBox(
        color: color,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            tabBar,
            Container(height: 1, color: const Color(0xFF2a2a2a)),
          ],
        ),
      );

  @override
  bool shouldRebuild(_TabBarDelegate old) =>
      old.tabBar != tabBar || old.color != color;
}

// ─── Generic shimmer skeleton box ─────────────────────────────────────────────

class _SkeletonBox extends StatefulWidget {
  final double radius;
  final double? w;
  final double? h;
  final double? aspect;   // aspect ratio when w/h are null

  const _SkeletonBox({this.radius = 8, this.w, this.h, this.aspect});

  @override
  State<_SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<_SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.06, end: 0.18).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.white : Colors.black;

    Widget box = AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: widget.w,
        height: widget.h,
        decoration: BoxDecoration(
          color: baseColor.withValues(alpha: _anim.value),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );

    if (widget.aspect != null) {
      box = AspectRatio(aspectRatio: widget.aspect!, child: box);
    }
    return box;
  }
}

// ─── Pulsing loading overlay for the banner ────────────────────────────────────

class _LoadingBannerPulse extends StatefulWidget {
  const _LoadingBannerPulse();

  @override
  State<_LoadingBannerPulse> createState() => _LoadingBannerPulseState();
}

class _LoadingBannerPulseState extends State<_LoadingBannerPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.15, end: 0.42).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        color: Colors.black.withValues(alpha: _anim.value),
        child: const Center(
          child: _ThreeDotsAnimation(),
        ),
      ),
    );
  }
}

// ─── 3 jumping dots animation ─────────────────────────────────────────────────

class _ThreeDotsAnimation extends StatefulWidget {
  const _ThreeDotsAnimation();

  @override
  State<_ThreeDotsAnimation> createState() => _ThreeDotsAnimationState();
}

class _ThreeDotsAnimationState extends State<_ThreeDotsAnimation>
    with TickerProviderStateMixin {
  final List<AnimationController> _ctrls = [];
  final List<Animation<double>> _anims = [];

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < 3; i++) {
      final c = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 500),
      );
      _ctrls.add(c);
      _anims.add(Tween<double>(begin: 0, end: -9).animate(
        CurvedAnimation(parent: c, curve: Curves.easeInOut),
      ));
      Future.delayed(Duration(milliseconds: i * 140), () {
        if (mounted) c.repeat(reverse: true);
      });
    }
  }

  @override
  void dispose() {
    for (final c in _ctrls) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _anims[i],
          builder: (_, __) => Transform.translate(
            offset: Offset(0, _anims[i].value),
            child: Container(
              width: 7,
              height: 7,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      }),
    );
  }

}
// ── Data class for detail info grid rows ─────────────────────────────────────

class _DetailInfoRow {
  final String label;
  final String value;
  final bool accent;
  final Color? accentColor;

  const _DetailInfoRow({
    required this.label,
    required this.value,
    this.accent = false,
    this.accentColor,
  });
}
