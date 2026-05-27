import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:isar_community/isar.dart';
import 'package:share_plus/share_plus.dart';
import 'package:watchtower/eval/model/m_bridge.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/chapter.dart';
import 'package:watchtower/models/download.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/modules/manga/detail/providers/isar_providers.dart';
import 'package:watchtower/modules/manga/download/providers/download_provider.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/utils/cached_network.dart';
import 'package:watchtower/utils/constant.dart';
import 'package:watchtower/utils/extensions/build_context_extensions.dart';
import 'package:watchtower/utils/extensions/chapter.dart';
import 'package:watchtower/utils/extensions/string_extensions.dart';
import 'package:watchtower/utils/headers.dart';
import 'package:watchtower/utils/utils.dart';

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
    _tabController = TabController(length: 2, vsync: this);
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
    final chapterId = chapters.first.id;
    if (_player.loadedChapterId == chapterId) return;
    _player.loadedChapterId = chapterId;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _player.load(ref: ref, chapter: chapters.first);
      if (_player.hasVideoUrl && mounted) setState(() {});
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
    return NestedScrollView(
      headerSliverBuilder: (ctx, innerBoxIsScrolled) => [
        SliverAppBar(
          expandedHeight: 230,
          pinned: true,
          backgroundColor: _bg,
          automaticallyImplyLeading: false,
          // ── Back button ──────────────────────────────────────────────────────
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          // ── Actions (loading + Aide) ─────────────────────────────────────────
          actions: [
            if (widget.isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 14),
                child: SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                ),
              ),
            _AideButton(onTap: () => _showOptionsSheet(context, chapters)),
            const SizedBox(width: 4),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: _buildBanner(chapters),
          ),
        ),
        SliverToBoxAdapter(child: _buildMetadataBlock(chapters)),
        SliverPersistentHeader(
          pinned: true,
          delegate: _TabBarDelegate(
            TabBar(
              controller: _tabController,
              indicatorColor: _accent,
              indicatorWeight: 2.5,
              labelColor: _textPrimary,
              unselectedLabelColor: _grey,
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
    );
  }

  // ─── LANDSCAPE — fullscreen player ──────────────────────────────────────────

  Widget _buildLandscape(List<Chapter> chapters) {
    return Stack(
      children: [
        if (_player.hasVideoUrl)
          SizedBox.expand(child: _player.buildFullscreenPlayer())
        else
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

        _player.buildBannerOverlay(context: context, chapters: chapters),

        if (!_player.hasVideoUrl && chapters.isNotEmpty)
          const Center(
            child: SizedBox(
              width: 34, height: 34,
              child: CircularProgressIndicator(
                  strokeWidth: 2.5, color: Colors.white),
            ),
          ),

        // Gradient blend
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0.0, 0.3, 0.65, 1.0],
              colors: [
                _bg.withValues(alpha: 0.72),
                _bg.withValues(alpha: 0.0),
                _bg.withValues(alpha: 0.27),
                _bg,
              ],
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
  // SVG icon | ★ rating | year | country | type

  Widget _buildMetaRow(List<Chapter> chapters) {
    final isMovie = _isMovie(chapters);
    final parts = <String>[];

    final author = widget.manga.author?.trim() ?? '';
    if (author.isNotEmpty) parts.add(author);

    // First genre that isn't "film"/"movie"/"serie"
    final typeGenre = (widget.manga.genre ?? [])
        .where((g) {
          final l = g.toLowerCase().trim();
          return l != 'film' && l != 'movie' && l != 'série' && l != 'serie';
        })
        .take(1)
        .firstOrNull;
    if (typeGenre != null && typeGenre.isNotEmpty) parts.add(typeGenre);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // SVG icon — coloured with secondary text colour
        SvgPicture.string(
          _kFilmSvg,
          width: 14,
          height: 14,
          colorFilter: ColorFilter.mode(_grey, BlendMode.srcIn),
        ),
        if (parts.isNotEmpty) ...[
          const SizedBox(width: 7),
          // ★ star
          const Icon(Icons.star_rounded, color: Color(0xFFFFD700), size: 13),
          const SizedBox(width: 3),
          Expanded(
            child: Text(
              parts.join('  |  '),
              style: TextStyle(color: _grey, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ] else ...[
          const SizedBox(width: 6),
          Text(
            isMovie ? 'Film' : 'Série',
            style: TextStyle(color: _grey, fontSize: 12),
          ),
        ],
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
      backgroundColor: Colors.transparent,
      // barrierColor stays default (dim)
      builder: (sheetCtx) {
        final screen  = MediaQuery.of(ctx).size.height;
        final statusH = MediaQuery.of(ctx).padding.top;
        final maxH    = screen - 230 - statusH; // never cover player

        return Container(
          height: maxH,
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
            label: isFav ? 'Dans ma liste' : 'Ajouter à la liste',
            onTap: _toggleFavorite,
            active: isFav,
          ),
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
              icon: Icons.download_for_offline_outlined,
              label: 'Voir téléchargements',
              onTap: () => Navigator.of(context).pushNamed('/downloadQueue')),
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
    final genres =
        (widget.manga.genre ?? []).map((g) => g.toLowerCase().trim()).toList();
    if (genres.contains('film') || genres.contains('movie')) return true;
    if (chapters.length == 1) return true;
    return false;
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
    final languages = _detectLanguages(chapters);
    final filtered  = _filterChapters(chapters);

    final source = getSource(
        widget.manga.lang ?? '',
        widget.manga.source ?? '',
        widget.manga.sourceId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header: "Ressources   Ajouté par [icon] [name]  [?]" ─────────────
        Row(
          children: [
            Text(
              'Ressources',
              style: TextStyle(
                  color: _textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600),
            ),
            if (source != null) ...[
              const SizedBox(width: 10),
              Text(
                'Ajouté par',
                style: TextStyle(color: _grey, fontSize: 12),
              ),
              const SizedBox(width: 5),
              // Extension icon
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
              // Extension name
              Text(
                source.name,
                style: TextStyle(
                    color: _grey,
                    fontSize: 12,
                    fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 6),
              // Help icon
              GestureDetector(
                onTap: () => _showOptionsSheet(context, chapters),
                child: Icon(Icons.help_outline_rounded,
                    size: 15, color: _grey),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),

        // ── Language selector (only if multiple languages) ────────────────────
        if (languages.length > 1) ...[
          _buildSelectorRow(
            icon: Icons.language_outlined,
            items: languages,
            selected: _selectedLanguage,
            onSelected: (v) =>
                setState(() => _selectedLanguage = v),
          ),
          const SizedBox(height: 10),
        ],

        // ── Season selector ───────────────────────────────────────────────────
        if (!isMovie && seasons.length > 1) ...[
          _buildSelectorRow(
            icon: Icons.layers_outlined,
            items: seasons,
            selected: _selectedSeason,
            onSelected: (v) =>
                setState(() => _selectedSeason = v),
          ),
          const SizedBox(height: 12),
        ],

        // ── Content ───────────────────────────────────────────────────────────
        if (chapters.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Icon(Icons.video_library_outlined,
                      color: _grey, size: 40),
                  const SizedBox(height: 8),
                  Text('Aucun épisode disponible',
                      style: TextStyle(color: _grey)),
                ],
              ),
            ),
          )
        else if (isMovie)
          _buildMovieBox(
              filtered.isNotEmpty ? filtered.first : chapters.first)
        else
          _buildEpisodeGrid(filtered),
      ],
    );
  }

  Widget _buildSelectorRow({
    required IconData icon,
    required List<String> items,
    required String? selected,
    required void Function(String?) onSelected,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Icon(icon, color: _grey, size: 16),
          const SizedBox(width: 8),
          ...items.map((item) {
            final isSel = selected == item;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => onSelected(isSel ? null : item),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: isSel
                        ? _accent.withValues(alpha: 0.12)
                        : _card,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSel ? _accent : _faint,
                      width: isSel ? 1.2 : 0.8,
                    ),
                  ),
                  child: Text(
                    item,
                    style: TextStyle(
                      color: isSel ? _accent : _onSurface.withValues(alpha: 0.7),
                      fontSize: 13,
                      fontWeight: isSel ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

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
          child: Text(
            chapter.name?.isNotEmpty == true
                ? chapter.name!
                : widget.manga.name ?? 'Regarder',
            style: TextStyle(
              color: _accent,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  // ─── EPISODE GRID ───────────────────────────────────────────────────────────

  Widget _buildEpisodeGrid(List<Chapter> chapters) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(chapters.length, (i) {
        final chapter = chapters[i];
        final watched = chapter.isRead ?? false;
        final numMatch = RegExp(r'\d+').firstMatch(chapter.name ?? '');
        final epNum = numMatch != null
            ? (int.tryParse(numMatch.group(0)!) ?? (i + 1))
            : (i + 1);
        final label = epNum.toString().padLeft(2, '0');

        return GestureDetector(
          onTap: () =>
              chapter.pushToReaderView(context, ignoreIsRead: true),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 52,
            height: 40,
            decoration: BoxDecoration(
              color: watched
                  ? _card
                  : _accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: watched
                    ? _faint
                    : _accent.withValues(alpha: 0.50),
                width: 1,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                color: watched
                    ? _grey
                    : _textPrimary,
                fontSize: 13,
                fontWeight:
                    watched ? FontWeight.normal : FontWeight.w600,
              ),
            ),
          ),
        );
      }),
    );
  }

  // ─── TABS ────────────────────────────────────────────────────────────────────

  Widget _buildRecommendationsTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: _card,
              shape: BoxShape.circle,
              border: Border.all(color: _faint, width: 1.5),
            ),
            child: Icon(Icons.movie_filter_outlined, color: _grey, size: 36),
          ),
          const SizedBox(height: 16),
          Text('Les recommandations arrivent bientôt',
              style: TextStyle(color: _onSurface.withValues(alpha: 0.7),
                  fontSize: 14)),
          const SizedBox(height: 6),
          Text(
            'Découvrez du contenu similaire dans la bibliothèque',
            style: TextStyle(color: _grey, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: _card,
              shape: BoxShape.circle,
              border: Border.all(color: _faint, width: 1.5),
            ),
            child: Icon(Icons.chat_bubble_outline, color: _grey, size: 32),
          ),
          const SizedBox(height: 16),
          Text('Aucun commentaire',
              style: TextStyle(
                  color: _onSurface.withValues(alpha: 0.7),
                  fontSize: 14,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Text(
            'Les commentaires apparaissent ici\nsi l\'extension les fournit.',
            style: TextStyle(color: _grey, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ─── DOWNLOAD SHEET ─────────────────────────────────────────────────────────

  void _showDownloadSheet(BuildContext ctx, List<Chapter> chapters) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: _surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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

  void _showOptionsSheet(BuildContext ctx, List<Chapter> chapters) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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

// ─── DOWNLOAD SHEET WIDGET ──────────────────────────────────────────────────

class _DownloadSheet extends StatefulWidget {
  final Manga manga;
  final List<Chapter> chapters;
  final void Function(List<Chapter> selected) onDownload;

  const _DownloadSheet({
    required this.manga,
    required this.chapters,
    required this.onDownload,
  });

  @override
  State<_DownloadSheet> createState() => _DownloadSheetState();
}

class _DownloadSheetState extends State<_DownloadSheet> {
  // ── Theme helpers ────────────────────────────────────────────────────────────
  Color get _accent   => Theme.of(context).primaryColor;
  Color get _bg       => Theme.of(context).scaffoldBackgroundColor;
  Color get _card     => Theme.of(context).colorScheme.surfaceContainerHighest;
  Color get _surface  => Theme.of(context).colorScheme.surface;
  Color get _grey     => Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.50);
  Color get _faint    => Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.25);
  Color get _text     => Theme.of(context).colorScheme.onSurface;

  String _selectedQuality = '1080P';
  final Set<int> _selected = {};
  bool _selectAll = false;

  final List<String> _qualities = ['360P', '480P', '720P', '1080P'];

  @override
  Widget build(BuildContext context) {
    final chapters = widget.chapters;
    final maxH = MediaQuery.of(context).size.height * 0.85;

    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      color: _bg,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHandle(),
          _buildHeader(),
          _buildResourcesCard(),
          _buildQualityChips(),
          Divider(height: 1, color: _faint),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 4),
              itemCount: chapters.length,
              itemBuilder: (_, i) => _buildEpisodeRow(i, chapters[i]),
            ),
          ),
          _buildBottomBar(chapters),
        ],
      ),
    );
  }

  Widget _buildHandle() => Container(
        width: 38, height: 4,
        margin: const EdgeInsets.only(top: 10, bottom: 4),
        decoration: BoxDecoration(
            color: _faint, borderRadius: BorderRadius.circular(2)),
      );

  Widget _buildHeader() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Text('Télécharger',
                style: TextStyle(
                    color: _text,
                    fontSize: 17,
                    fontWeight: FontWeight.w700)),
            const Spacer(),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Icon(Icons.close, color: _grey, size: 22),
            ),
          ],
        ),
      );

  Widget _buildResourcesCard() {
    final source = getSource(widget.manga.lang ?? '',
        widget.manga.source ?? '', widget.manga.sourceId);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _faint, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.storage_outlined, color: _grey, size: 14),
              const SizedBox(width: 6),
              Text('Ressources',
                  style: TextStyle(
                      color: _text,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              if (source != null) ...[
                const SizedBox(width: 6),
                Text('· ${source.name}',
                    style: TextStyle(color: _grey, fontSize: 12)),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _dropdownChip(label: 'French dub', icon: Icons.language_outlined),
              const SizedBox(width: 8),
              _dropdownChip(label: 'Saison 01', icon: Icons.expand_more),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dropdownChip({required String label, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _faint, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: TextStyle(
                  color: _text.withValues(alpha: 0.7), fontSize: 13)),
          const SizedBox(width: 4),
          Icon(icon, color: _grey, size: 16),
        ],
      ),
    );
  }

  Widget _buildQualityChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: _qualities.map((q) {
          final sel = q == _selectedQuality;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _selectedQuality = q),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: sel ? _accent : _card,
                  borderRadius: BorderRadius.circular(7),
                  border:
                      Border.all(color: sel ? _accent : _faint, width: 0.8),
                ),
                child: Text(
                  q,
                  style: TextStyle(
                    color: sel ? Colors.white : _grey,
                    fontSize: 13,
                    fontWeight:
                        sel ? FontWeight.w700 : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEpisodeRow(int index, Chapter chapter) {
    final sel = _selected.contains(index);
    return InkWell(
      onTap: () => setState(() {
        sel ? _selected.remove(index) : _selected.add(index);
        _selectAll = _selected.length == widget.chapters.length;
      }),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 22, height: 22,
              child: sel
                  ? Icon(Icons.radio_button_checked,
                      color: _accent, size: 22)
                  : Icon(Icons.radio_button_unchecked,
                      color: _faint, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                chapter.name ?? 'Épisode ${index + 1}',
                style: TextStyle(color: _text, fontSize: 14),
              ),
            ),
            Text(
              chapter.duration?.isNotEmpty == true ? chapter.duration! : '',
              style: TextStyle(color: _grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(List<Chapter> chapters) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: _faint)),
        color: _bg,
      ),
      child: SafeArea(
        child: Row(
          children: [
            GestureDetector(
              onTap: () => setState(() {
                _selectAll = !_selectAll;
                if (_selectAll) {
                  _selected.addAll(
                      List.generate(chapters.length, (i) => i));
                } else {
                  _selected.clear();
                }
              }),
              child: Row(
                children: [
                  SizedBox(
                    width: 22, height: 22,
                    child: _selectAll
                        ? Icon(Icons.radio_button_checked,
                            color: _accent, size: 22)
                        : Icon(Icons.radio_button_unchecked,
                            color: _faint, size: 22),
                  ),
                  const SizedBox(width: 8),
                  Text('Tout sélectionner',
                      style: TextStyle(
                          color: _text.withValues(alpha: 0.7),
                          fontSize: 14)),
                ],
              ),
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: _selected.isEmpty
                  ? null
                  : () => widget
                      .onDownload(_selected.map((i) => chapters[i]).toList()),
              icon: const Icon(Icons.download_outlined, size: 18),
              label: Text(_selected.isEmpty
                  ? 'Télécharger'
                  : 'Télécharger (${_selected.length})'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                disabledBackgroundColor: _card,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── SLIVER TAB BAR DELEGATE ────────────────────────────────────────────────

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final Color color;

  const _TabBarDelegate(this.tabBar, {this.color = Colors.black});

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
          BuildContext context, double shrinkOffset, bool overlapsContent) =>
      ColoredBox(color: color, child: tabBar);

  @override
  bool shouldRebuild(_TabBarDelegate old) =>
      old.tabBar != tabBar || old.color != color;
}
