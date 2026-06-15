import 'dart:typed_data';
import 'package:flutter/material.dart';
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

import 'watch_player_stub.dart' if (dart.library.ffi) 'watch_player_io.dart';

// SVG icon provided for the movie meta row
const _kFilmSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16" fill="none">
  <path fill-rule="evenodd" clip-rule="evenodd" d="M14.0605 13.4546H11.8205C13.5385 12.2473 14.6666 10.2546 14.6666 8.00001C14.6666 4.32405 11.6759 1.33334 7.99992 1.33334C4.32396 1.33334 1.33325 4.32405 1.33325 8.00001C1.33325 11.676 4.32396 14.6667 7.99992 14.6667C8.01608 14.6667 8.03063 14.6643 8.04679 14.6643C8.05083 14.6643 8.05406 14.6667 8.0581 14.6667H14.0605C14.3951 14.6667 14.666 14.3952 14.666 14.0606C14.6666 13.7261 14.3951 13.4546 14.0605 13.4546ZM7.99992 3.95959C7.33083 3.95959 6.7878 4.50262 6.7878 5.17172C6.7878 5.84081 7.33083 6.38384 7.99992 6.38384C8.66901 6.38384 9.21204 5.84081 9.21204 5.17172C9.21204 4.50262 8.66901 3.95959 7.99992 3.95959ZM7.99992 9.45776C7.33083 9.45776 6.7878 10.0008 6.7878 10.6699C6.7878 11.339 7.33083 11.882 7.99992 11.882C8.66901 11.882 9.21204 11.339 9.21204 10.6699C9.21204 10.0008 8.66901 9.45776 7.99992 9.45776ZM10.7491 6.7087C10.08 6.7087 9.53699 7.25173 9.53699 7.92082C9.53699 8.58991 10.08 9.13294 10.7491 9.13294C11.4182 9.13294 11.9612 8.58991 11.9612 7.92082C11.9612 7.25173 11.4182 6.7087 10.7491 6.7087ZM5.2509 6.7087C4.58181 6.7087 4.03878 7.25173 4.03878 7.92082C4.03878 8.58991 4.58181 9.13294 5.2509 9.13294C5.91999 9.13294 6.46302 8.58991 6.46302 7.92082C6.46302 7.25173 5.91999 6.7087 5.2509 6.7087Z" fill="currentColor"/>
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
    _tabController = TabController(length: 3, vsync: this);
    _player = WatchInlinePlayer();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _player.dispose();
    super.dispose();
  }

  // ─── VIDEO TRIGGER ──────────────────────────────────────────────────────────

  void _maybeStartVideo(List<Chapter> chapters) {
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

    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: _bg,
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
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Spacer(),
                    _AideButton(
                        onTap: () =>
                            _showOptionsSheet(context, chapters)),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
            ],
          ),
        ),
        // ── Contenu scrollable ────────────────────────────────────────────────
        Expanded(
          child: NestedScrollView(
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
                      Tab(text: 'Détails'),
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
                _buildDetailsTab(chapters),
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

    // Language/country code
    final lang = widget.manga.lang?.trim().toUpperCase() ?? '';
    if (lang.isNotEmpty) parts.add(lang);

    // First genre that isn't "film"/"movie"/"serie"
    final typeGenre = (widget.manga.genre ?? [])
        .where((g) {
          final l = g.toLowerCase().trim();
          return l != 'film' && l != 'movie' && l != 'série' && l != 'serie';
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
          _kFilmSvg,
          width: 14,
          height: 14,
          colorFilter: ColorFilter.mode(_grey, BlendMode.srcIn),
        ),
        vbar(),
        const Icon(Icons.star_rounded, color: Color(0xFFFFD700), size: 13),
        const SizedBox(width: 4),
        Text(
          (widget.manga.author?.trim().isNotEmpty == true &&
                  RegExp(r'^\d{4}$').hasMatch(widget.manga.author!.trim()))
              ? widget.manga.author!.trim()
              : 'N/A',
          style: TextStyle(color: _grey, fontSize: 12),
        ),
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
        final maxH    = screen - 230 - statusH; // never cover player

        return Container(
          height: maxH,
          decoration: BoxDecoration(
            color: _surface,
          ),
          child: Column(
            children: [
              // ── Header ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
                child: Row(
                  children: [
                    Text(
                      'Plus de détails',
                      style: TextStyle(
                        color: _textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.close, color: _grey, size: 20),
                      onPressed: () => Navigator.pop(sheetCtx),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
              const Divider(height: 12),
              // ── Scrollable content ──
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  children: [
                    // Poster + title + meta
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: cachedNetworkImage(
                            imageUrl: toImgUrl(
                                manga.customCoverFromTracker ??
                                    manga.imageUrl ?? ''),
                            width: 80,
                            height: 115,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                manga.name ?? '',
                                style: TextStyle(
                                  color: _textPrimary,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 6),
                              // meta pills: lang, status, source
                              Wrap(
                                spacing: 5,
                                runSpacing: 5,
                                children: [
                                  _infoPill(Icons.language,
                                      (manga.lang ?? '').toUpperCase()),
                                  _infoPill(
                                      Icons.circle, _statusLabel(manga.status)),
                                  if ((manga.source ?? '').isNotEmpty)
                                    _infoPill(
                                        Icons.storage_outlined, manga.source!),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    // Description
                    if ((manga.description ?? '').isNotEmpty) ...[
                      _sheetSectionLabel('Info'),
                      const SizedBox(height: 8),
                      StatefulBuilder(
                        builder: (c, setSt) => GestureDetector(
                          onTap: () => setSt(
                              () => _isDescriptionExpanded =
                                  !_isDescriptionExpanded),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                manga.description ?? '',
                                maxLines: _isDescriptionExpanded ? null : 4,
                                overflow: _isDescriptionExpanded
                                    ? TextOverflow.visible
                                    : TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: _grey,
                                    fontSize: 13,
                                    height: 1.55),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _isDescriptionExpanded
                                    ? 'Voir moins'
                                    : 'Voir plus',
                                style:
                                    TextStyle(color: _accent, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    // Genres
                    if ((manga.genre?.isNotEmpty ?? false)) ...[
                      _sheetSectionLabel('Genres'),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final g in (manga.genre ?? []))
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 13, vertical: 6),
                              decoration: BoxDecoration(
                                color: _accent.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: _accent.withValues(alpha: 0.30),
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
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
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

  List<String> _detectLanguages(List<Chapter> chapters) {
    final langRx = RegExp(
        r'\b(VF|VOSTFR|VO|French|English|Français|Dub|Sub|MULTI|VOSTA)\b',
        caseSensitive: false);
    final seen = <String>{};
    for (final ch in chapters) {
      for (final m
          in langRx.allMatches('${ch.scanlator ?? ''} ${ch.name ?? ''}')) {
        seen.add(m.group(0)!.toUpperCase());
      }
    }
    return seen.toList();
  }

  List<Chapter> _filterChapters(List<Chapter> all) {
    List<Chapter> result = all;
    final season = _selectedSeason;
    if (season != null) {
      final num = RegExp(r'\d+').firstMatch(season)?.group(0) ?? '';
      final rx = RegExp(
          r'(?:Saison|Season|Partie|Part)\s*' +
              num +
              r'|S' +
              num.padLeft(2, '0'),
          caseSensitive: false);
      final filtered =
          result.where((ch) => rx.hasMatch(ch.name ?? '')).toList();
      if (filtered.isNotEmpty) result = filtered;
    }
    final lang = _selectedLanguage;
    if (lang != null) {
      final filtered = result
          .where((ch) =>
              (ch.scanlator ?? '').toUpperCase().contains(lang) ||
              (ch.name ?? '').toUpperCase().contains(lang))
          .toList();
      if (filtered.isNotEmpty) result = filtered;
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
              if (!isMovie) ...[
                _buildDropdownPill(
                  label: seasons.isNotEmpty
                      ? (_selectedSeason ?? seasons.first)
                      : 'Saison 1',
                  items: seasons.isNotEmpty ? seasons : ['Saison 1'],
                  onSelect: (v) => setState(() => _selectedSeason = v),
                ),
                const SizedBox(width: 8),
              ],
              _buildDropdownPill(
                label: languages.isNotEmpty
                    ? (_selectedLanguage ?? languages.first)
                    : 'Langue',
                items: languages.isNotEmpty ? languages : ['Langue'],
                onSelect: (v) => setState(() => _selectedLanguage = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ── Content ───────────────────────────────────────────────────────────
        if (chapters.isEmpty)
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
  }) {
    return GestureDetector(
      onTap: () => _showDropdownSheet(items, onSelect),
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
              label,
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

  void _showDropdownSheet(List<String> items, void Function(String) onSelect) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: _surface,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36, height: 4,
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _faint,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ...items.map((item) {
                final isSel = item == _selectedLanguage || item == _selectedSeason;
                return InkWell(
                  onTap: () {
                    Navigator.pop(ctx);
                    onSelect(item);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 15),
                    child: Row(
                      children: [
                        Text(
                          item,
                          style: TextStyle(
                            color: isSel ? _accent : _textPrimary,
                            fontSize: 15,
                            fontWeight: isSel
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                        const Spacer(),
                        if (isSel)
                          Icon(Icons.check_rounded, color: _accent, size: 18),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  // _buildSelectorRow replaced by _buildDropdownPill + _showDropdownSheet above

  // ─── MOVIE BOX — small rectangle, title only ─────────────────────────────────

  Widget _buildMovieBox(Chapter chapter) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => chapter.pushToReaderView(context, ignoreIsRead: true),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: _accent.withValues(alpha: 0.28), width: 0.8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.play_arrow_rounded, color: _accent, size: 20),
              const SizedBox(width: 6),
              Text(
                'Regarder',
                style: TextStyle(
                  color: _accent,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── EPISODE SORT ────────────────────────────────────────────────────────────
  // Sort episodes by number (descending: latest first). Uses first digit sequence
  // found in the chapter name; falls back to chapter index.

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

  static const int    _kMaxVisibleEps = 5;
  static const double _kEpThumbW      = 108.0;

  Widget _buildEpisodeList(List<Chapter> chapters, List<Chapter> allChapters) {
    if (chapters.isEmpty) return const SizedBox.shrink();
    final display   = chapters.take(_kMaxVisibleEps).toList();
    final remaining = chapters.length - display.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < display.length; i++) ...[
          _buildEpCard(display[i], fallbackIndex: i + 1),
          if (i < display.length - 1) const SizedBox(height: 8),
        ],
        if (remaining > 0) ...[
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => _showAllEpisodesSheet(context, allChapters),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.grid_view_rounded, size: 16, color: _accent),
                  const SizedBox(width: 8),
                  Text(
                    '$remaining épisodes de plus',
                    style: TextStyle(
                        color: _accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEpCard(Chapter chapter, {required int fallbackIndex}) {
    final isPlaying = _player.loadedChapterId == chapter.id;
    final watched   = (chapter.isRead ?? false) && !isPlaying;
    final epNum     = _epNum(chapter.name, fallbackIndex);

    // Thumbnail: episode-specific if available, else anime cover
    final thumb = (chapter.thumbnailUrl?.isNotEmpty ?? false)
        ? chapter.thumbnailUrl!
        : toImgUrl(
            widget.manga.customCoverFromTracker ?? widget.manga.imageUrl ?? '');

    // Episode label: "Ép. N" + optional name after the raw number
    String epLabel = 'Ép. $epNum';
    final rawName  = chapter.name ?? '';
    final stripped = rawName
        .replaceAll(RegExp(r'(?:Ep\.?|Episode|Épisode)\s*\d+', caseSensitive: false), '')
        .replaceAll(RegExp(r'^\s*[-–—·:]\s*'), '')
        .trim();
    if (stripped.isNotEmpty) epLabel += ' · $stripped';

    return GestureDetector(
      onTap: () => _loadEpisodeInBanner(chapter),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isPlaying
              ? _accent.withValues(alpha: 0.09)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isPlaying
                ? _accent.withValues(alpha: 0.38)
                : _faint.withValues(alpha: 0.32),
            width: isPlaying ? 1.0 : 0.6,
          ),
        ),
        child: Row(
          children: [
            // ── Thumbnail (16:9) ──────────────────────────────────────────────
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: _kEpThumbW,
                height: _kEpThumbW * 9 / 16,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (thumb.isEmpty)
                      Container(color: _card)
                    else
                      cachedNetworkImage(
                        imageUrl: thumb,
                        width: _kEpThumbW,
                        height: _kEpThumbW * 9 / 16,
                        fit: BoxFit.cover,
                      ),
                    // Scrim gradient
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: const [0.3, 1.0],
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.55),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Playing indicator
                    if (isPlaying)
                      Center(
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.50),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.equalizer_rounded,
                              color: Colors.white, size: 14),
                        ),
                      )
                    else
                      // Subtle play icon on hover / default
                      Positioned(
                        right: 4,
                        bottom: 4,
                        child: Icon(
                          watched
                              ? Icons.check_circle_rounded
                              : Icons.play_circle_outline_rounded,
                          color: Colors.white.withValues(alpha: 0.70),
                          size: 16,
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 12),

            // ── Episode info ──────────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    epLabel,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isPlaying ? _accent : _textPrimary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                  if ((chapter.description?.isNotEmpty ?? false)) ...[
                    const SizedBox(height: 3),
                    Text(
                      chapter.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: _grey, fontSize: 11, height: 1.45),
                    ),
                  ],
                  if ((chapter.duration?.isNotEmpty ?? false)) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded,
                            size: 10, color: _faint),
                        const SizedBox(width: 3),
                        Text(
                          chapter.duration!,
                          style: TextStyle(color: _faint, fontSize: 10.5),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // ── Status icon ───────────────────────────────────────────────────
            const SizedBox(width: 6),
            if (isPlaying)
              Icon(Icons.volume_up_rounded, color: _accent, size: 16)
            else if (watched)
              Icon(Icons.check_rounded, color: _grey, size: 16),
          ],
        ),
      ),
    );
  }

  // ─── ALL EPISODES SHEET (MovieBox style) ─────────────────────────────────────

  void _showAllEpisodesSheet(BuildContext ctx, List<Chapter> allChapters) {
    final seasons = _detectSeasons(allChapters);
    String? sheetSeason = seasons.isNotEmpty ? seasons.first : null;

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
              final rx = RegExp(
                r'(?:Saison|Season|Partie|Part)\s*' +
                    num +
                    r'|S' +
                    num.padLeft(2, '0'),
                caseSensitive: false,
              );
              final filtered =
                  allChapters.where((ch) => rx.hasMatch(ch.name ?? '')).toList();
              display = filtered.isNotEmpty ? filtered : allChapters;
            } else {
              display = allChapters;
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
                                      children: seasons
                                          .map(
                                            (s) => ListTile(
                                              title: Text(s,
                                                  style: TextStyle(
                                                      color: onSurface)),
                                              selected: s == sheetSeason,
                                              selectedColor: accent,
                                              onTap: () =>
                                                  Navigator.pop(sheetCtx, s),
                                            ),
                                          )
                                          .toList(),
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
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 6,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            childAspectRatio: 1.1,
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

    // ── Cast names from artist field ───────────────────────────────────────
    final castNames = (manga.artist ?? '')
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    // ── Year / director ────────────────────────────────────────────────────
    final year = (manga.author ?? '').trim();

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
            !typeKws.any((k) => g.toLowerCase() == k.toLowerCase()))
        .toList();

    final isMovie = _isMovie(chapters);

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
                  borderRadius: BorderRadius.circular(10),
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

          // ── Informations ──────────────────────────────────────────────────
          _sectionLabel('Informations'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (year.isNotEmpty)
                _infoChip(
                    Icons.calendar_today_outlined, year, _card, _grey),
              if (chapters.isNotEmpty)
                _infoChip(
                  Icons.play_circle_outline_rounded,
                  isMovie
                      ? 'Film'
                      : '${chapters.length} épisode${chapters.length > 1 ? 's' : ''}',
                  _accent.withValues(alpha: 0.10),
                  _accent,
                ),
              if (statusLabel.isNotEmpty)
                _infoChip(Icons.circle, statusLabel,
                    statusColor.withValues(alpha: 0.10), statusColor),
              if ((manga.lang?.isNotEmpty ?? false))
                _infoChip(Icons.language_rounded,
                    manga.lang!.toUpperCase(), _card, _grey),
              if (typeTag != null)
                _infoChip(
                    Icons.videocam_outlined, typeTag, _card, _grey),
              if ((manga.source?.isNotEmpty ?? false))
                _infoChip(Icons.storage_outlined, manga.source!, _card,
                    _grey),
            ],
          ),
          const SizedBox(height: 26),

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

          // ── Réalisateur (uniquement si ce n'est pas juste une année) ───────
          if (year.isNotEmpty && RegExp(r'[a-zA-ZÀ-ÿ]').hasMatch(year)) ...[
            _sectionLabel('Réalisateur'),
            const SizedBox(height: 8),
            _detailRow(Icons.person_outline_rounded, year),
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
    // Pour vous : utilise le service anibrain.ai pour les recommandations
    // basées sur le titre courant. L'extension peut aussi fournir getForYou().
    return FutureBuilder<List<RecommendationResult>?>(
      future: getRecommendations(
        widget.manga.name ?? '',
        widget.manga.itemType,
        // Poids par défaut : genres 30%, synopsis 40%, setting 15%, thème 20%
        AlgorithmWeights(),
      ),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        final recs = snap.data;
        if (recs == null || recs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: _card,
                      shape: BoxShape.circle,
                      border: Border.all(color: _faint, width: 1.5),
                    ),
                    child: Icon(Icons.movie_filter_outlined,
                        color: _grey, size: 26),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Aucune recommandation trouvée',
                    style: TextStyle(
                        color: _onSurface.withValues(alpha: 0.7),
                        fontSize: 14,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Ajoute ce titre à ta bibliothèque\npour de meilleures suggestions.',
                    style: TextStyle(color: _grey, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }
        // Grille de recommandations : poster + titre
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
            final rec = recs[i];
            final imgUrl =
                rec.imgURLs.isNotEmpty ? rec.imgURLs.first : null;
            final title = rec.titleRomaji ??
                rec.titleEnglish ??
                rec.titleNative ??
                '';
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
    // Commentaires : l'extension doit exposer getComments(url, page).
    // Vérification via le champ supportsComments dans les métadonnées source.
    final source = getSource(
      widget.manga.lang ?? '',
      widget.manga.source ?? '',
      widget.manga.sourceId,
    );
    final supportsComments =
        (source?.additionalParams?.contains('"supportsComments":true') ??
            false) ||
        (source?.notes?.contains('supportsComments') ?? false);

    if (!supportsComments) {
      // Source ne fournit pas de commentaires → placeholder informatif
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _card,
                shape: BoxShape.circle,
                border: Border.all(color: _faint, width: 1.5),
              ),
              child:
                  Icon(Icons.chat_bubble_outline, color: _grey, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              'Commentaires non disponibles',
              style: TextStyle(
                  color: _onSurface.withValues(alpha: 0.7),
                  fontSize: 14,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            Text(
              'Cette extension ne fournit pas\nde commentaires (supportsComments: false).',
              style: TextStyle(color: _grey, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            if ((source?.name ?? '').isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Source : ${source!.name}',
                  style: TextStyle(color: _grey, fontSize: 11),
                ),
              ),
          ],
        ),
      );
    }

    // Source supporte les commentaires — à implémenter avec getCommentsProvider
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, color: _accent, size: 32),
          const SizedBox(height: 12),
          Text('Chargement des commentaires…',
              style: TextStyle(color: _grey, fontSize: 13)),
        ],
      ),
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

enum _Downloader { internal, aria2, zeus, external }

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
  final Set<Chapter> _selected = {};
  bool _selectAll = false;
  bool _downloaderExpanded = false;

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

  List<Chapter> get _displayChapters {
    if (_selectedSeason == null) return widget.chapters;
    final num = _selectedSeason!.replaceAll('Saison ', '');
    return widget.chapters.where((ch) {
      final m = _seasonRe.firstMatch(ch.name ?? '');
      return m != null && m.group(1) == num;
    }).toList();
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
    final m = RegExp(r'\d+').firstMatch(ch.name ?? '');
    return m != null
        ? 'E${m.group(0)!.padLeft(2, '0')}'
        : 'E${(fallback + 1).toString().padLeft(2, '0')}';
  }

  String _downloaderLabel() {
    switch (_downloader) {
      case _Downloader.internal: return 'Interne';
      case _Downloader.aria2: return 'Aria2';
      case _Downloader.zeus: return 'Zeus';
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
      if (_selectedQuality != null && _videos.isNotEmpty) {
        for (final ch in chapters) {
          if (ch.id == null) continue;
          final match = _videos.cast<Video?>().firstWhere(
            (v) => _normQ(v!.quality) == _selectedQuality,
            orElse: () => null,
          );
          if (match != null) {
            chapterPreferredOriginalUrl[ch.id!] = match.originalUrl;
          }
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
    final langs      = _langs;
    final seasons    = _seasons;
    final qualities  = _qualities;
    final totalSz    = _totalSizeLabel();

    return Container(
      height: maxH,
      decoration: BoxDecoration(color: _bg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header poster + blur ──────────────────────────────────────────────
          _buildHeader(),

          // ── Loading bar ───────────────────────────────────────────────────────
          if (_loading)
            LinearProgressIndicator(
              color: _accent,
              backgroundColor: _faint,
              minHeight: 2,
              borderRadius: BorderRadius.zero,
            ),

          // ── Quality cards ─────────────────────────────────────────────────────
          if (!_loading && qualities.isNotEmpty)
            _buildQualityCards(qualities),

          // ── Language / Season filters (only if multiple) ──────────────────────
          if (!_loading) ...[
            if (langs.length > 1)
              _buildFilterRow(
                icon: Icons.language_rounded,
                label: 'Lang',
                items: langs,
                selected: _selectedLang,
                onSelect: (l) => setState(() {
                  _selectedLang = _selectedLang == l ? null : l;
                  _selectedQuality = null;
                }),
              ),
            if (seasons.length > 1)
              _buildFilterRow(
                icon: Icons.layers_rounded,
                label: 'Saison',
                items: seasons,
                selected: _selectedSeason,
                onSelect: (s) => setState(() {
                  _selectedSeason = _selectedSeason == s ? null : s;
                  _selected.clear();
                  _selectAll = false;
                }),
              ),
          ],

          // ── Downloader collapsible ────────────────────────────────────────────
          _buildDownloaderCollapsible(),

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

          // ── Download button ───────────────────────────────────────────────────
          _buildDownloadButton(totalSz),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 12, 10),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.download_rounded, color: _accent, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Télécharger',
                      style: TextStyle(
                        color: _grey,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      widget.manga.name ?? '',
                      style: TextStyle(
                        color: _text,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: _faint,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.close, color: _grey, size: 16),
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, thickness: 0.8, color: _faint),
      ],
    );
  }

  // ── Quality cards ─────────────────────────────────────────────────────────────
  Widget _buildQualityCards(List<String> qualities) {
    final effective = _selectedQuality ?? qualities.first;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.hd_outlined, size: 13, color: _grey),
            const SizedBox(width: 5),
            Text('Qualité',
                style: TextStyle(
                    color: _grey,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
          ]),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: qualities.map((q) {
                final sel = q == effective;
                return GestureDetector(
                  onTap: () => setState(() => _selectedQuality = q),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    margin: const EdgeInsets.only(right: 8),
                    width: 72,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: sel
                          ? LinearGradient(
                              colors: [
                                _accent,
                                _accent.withValues(alpha: 0.65),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: sel ? null : _card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: sel ? Colors.transparent : _faint,
                        width: 0.8,
                      ),
                      boxShadow: sel
                          ? [
                              BoxShadow(
                                color: _accent.withValues(alpha: 0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      q,
                      style: TextStyle(
                        color: sel
                            ? Colors.white
                            : _text.withValues(alpha: 0.65),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
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
  }

  // ── Filter row (lang / season) ────────────────────────────────────────────────
  Widget _buildFilterRow({
    required IconData icon,
    required String label,
    required List<String> items,
    required String? selected,
    required void Function(String) onSelect,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 2),
      child: Row(
        children: [
          Icon(icon, size: 13, color: _grey),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: _grey,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500)),
          const SizedBox(width: 10),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: items.map((item) {
                  final sel = item == selected;
                  return GestureDetector(
                    onTap: () => onSelect(item),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 11, vertical: 5),
                      decoration: BoxDecoration(
                        color: sel
                            ? _accent.withValues(alpha: 0.12)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: sel ? _accent : _faint,
                          width: sel ? 1.2 : 0.8,
                        ),
                      ),
                      child: Text(
                        item,
                        style: TextStyle(
                          color: sel ? _accent : _grey,
                          fontSize: 11.5,
                          fontWeight:
                              sel ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Downloader collapsible ────────────────────────────────────────────────────
  Widget _buildDownloaderCollapsible() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () => setState(() => _downloaderExpanded = !_downloaderExpanded),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(
              children: [
                Icon(Icons.download_for_offline_outlined,
                    size: 15, color: _grey),
                const SizedBox(width: 8),
                Text('Télécharger avec',
                    style: TextStyle(
                        color: _text.withValues(alpha: 0.75),
                        fontSize: 13,
                        fontWeight: FontWeight.w500)),
                const Spacer(),
                Text(_downloaderLabel(),
                    style: TextStyle(
                        color: _accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                const SizedBox(width: 4),
                AnimatedRotation(
                  turns: _downloaderExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 220),
                  child: Icon(Icons.keyboard_arrow_down_rounded,
                      size: 18, color: _grey),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeInOut,
          child: _downloaderExpanded
              ? _buildDownloaderOptions()
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildDownloaderOptions() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _downloaderTile(
            icon: Icons.settings_input_component_outlined,
            label: 'Downloader interne',
            subtitle: 'Moteur intégré Watchtower',
            value: _Downloader.internal,
          ),
          Divider(height: 1, indent: 52, color: _faint),
          _downloaderTile(
            icon: Icons.multiple_stop_rounded,
            label: 'Aria2',
            subtitle: 'Téléchargeur multi-connexions',
            value: _Downloader.aria2,
          ),
          Divider(height: 1, indent: 52, color: _faint),
          _downloaderTile(
            icon: Icons.bolt_outlined,
            label: 'Zeus',
            subtitle: 'Téléchargeur haute vitesse',
            value: _Downloader.zeus,
          ),
          Divider(height: 1, indent: 52, color: _faint),
          _externalTile(),
        ],
      ),
    );
  }

  Widget _downloaderTile({
    required IconData icon,
    required String label,
    required String subtitle,
    required _Downloader value,
  }) {
    final sel = _downloader == value;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => setState(() => _downloader = value),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: sel
                  ? _accent.withValues(alpha: 0.15)
                  : _faint.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon,
                size: 17, color: sel ? _accent : _grey),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: sel ? _accent : _text,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600)),
                Text(subtitle,
                    style: TextStyle(color: _grey, fontSize: 11)),
              ],
            ),
          ),
          if (sel) Icon(Icons.check_rounded, color: _accent, size: 18),
        ]),
      ),
    );
  }

  Widget _externalTile() {
    final sel = _downloader == _Downloader.external;
    const apps = [
      ('ADM', 'adm'),
      ('1DM', '1dm'),
      ('FDM', 'fdm'),
      ('IDM+', 'idm'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: sel
                  ? _accent.withValues(alpha: 0.15)
                  : _faint.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(Icons.open_in_new_rounded,
                size: 17, color: sel ? _accent : _grey),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Downloader Android',
                    style: TextStyle(
                        color: sel ? _accent : _text,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: apps.map((a) {
                    final appSel =
                        sel && _externalApp == a.$2;
                    return GestureDetector(
                      onTap: () => setState(() {
                        _downloader = _Downloader.external;
                        _externalApp = a.$2;
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: appSel
                              ? _accent.withValues(alpha: 0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: appSel ? _accent : _faint,
                            width: appSel ? 1.2 : 0.8,
                          ),
                        ),
                        child: Text(
                          a.$1,
                          style: TextStyle(
                            color: appSel ? _accent : _grey,
                            fontSize: 12,
                            fontWeight: appSel
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          if (sel) Icon(Icons.check_rounded, color: _accent, size: 18),
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
          borderRadius: BorderRadius.circular(10),
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

  // ── Download button ───────────────────────────────────────────────────────────
  Widget _buildDownloadButton(String totalSz) {
    final empty = _selected.isEmpty;
    final String label;
    if (empty) {
      label = 'Télécharger';
    } else if (totalSz.isNotEmpty) {
      label = 'Télécharger  •  $totalSz';
    } else {
      label = _isFilm
          ? 'Télécharger  •  Film'
          : 'Télécharger  •  ${_selected.length} ep.';
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: _bg,
        border: Border(top: BorderSide(color: _faint)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              gradient: empty
                  ? null
                  : LinearGradient(
                      colors: [
                        _accent,
                        _accent.withValues(alpha: 0.70),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
              color: empty ? _faint : null,
              borderRadius: BorderRadius.circular(14),
              boxShadow: empty
                  ? null
                  : [
                      BoxShadow(
                        color: _accent.withValues(alpha: 0.38),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: empty ? null : _startDownload,
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.download_rounded,
                        size: 18,
                        color: empty
                            ? _text.withValues(alpha: 0.35)
                            : Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        label,
                        style: TextStyle(
                          color: empty
                              ? _text.withValues(alpha: 0.35)
                              : Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
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
