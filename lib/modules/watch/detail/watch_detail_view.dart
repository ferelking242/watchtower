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
                    if (widget.isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: 4, vertical: 14),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        ),
                      ),
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
                    indicatorColor: _accent,
                    indicatorWeight: 2.5,
                    labelColor: _textPrimary,
                    unselectedLabelColor: _grey,
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

        _player.buildBannerOverlay(context: context),

        if (!_player.hasVideoUrl && chapters.isNotEmpty)
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
        Text('N/A', style: TextStyle(color: _grey, fontSize: 12)),
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

        // ── Dropdown pills row (MovieBox style) ──────────────────────────────
        if (languages.isNotEmpty || (!isMovie && seasons.length > 1)) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                if (languages.isNotEmpty)
                  _buildDropdownPill(
                    label: _selectedLanguage ?? languages.first,
                    items: languages,
                    onSelect: (v) => setState(() => _selectedLanguage = v),
                  ),
                if (languages.isNotEmpty && !isMovie && seasons.length > 1)
                  const SizedBox(width: 8),
                if (!isMovie && seasons.length > 1)
                  _buildDropdownPill(
                    label: _selectedSeason ?? seasons.first,
                    items: seasons,
                    onSelect: (v) => setState(() => _selectedSeason = v),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

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
          _buildEpisodeStrip(
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
          color: _card,
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
    final m = RegExp(r'\d+').firstMatch(name);
    return m != null ? (int.tryParse(m.group(0)!) ?? fallback) : fallback;
  }

  // ─── EPISODE STRIP (MovieBox style) ─────────────────────────────────────────

  Widget _buildEpisodeStrip(List<Chapter> chapters, List<Chapter> allChapters) {
    return SizedBox(
      height: 72,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: chapters.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => _showAllEpisodesSheet(context, allChapters),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 56,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _card,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _accent.withValues(alpha: 0.6), width: 1),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Tous',
                    style: TextStyle(
                      color: _accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            );
          }
          final chapter = chapters[index - 1];
          final watched = chapter.isRead ?? false;
          final numMatch = RegExp(r'\d+').firstMatch(chapter.name ?? '');
          final epNum = numMatch != null
              ? (int.tryParse(numMatch.group(0)!) ?? index)
              : index;
          final label = epNum.toString().padLeft(2, '0');

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () =>
                  chapter.pushToReaderView(context, ignoreIsRead: true),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 48,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _faint,
                        width: 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      label,
                      style: TextStyle(
                        color: watched ? _faint : _textPrimary,
                        fontSize: 13,
                        fontWeight: watched
                            ? FontWeight.normal
                            : FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
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
                                ch.pushToReaderView(ctx,
                                    ignoreIsRead: true);
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

    // Status badge
    String statusLabel = '';
    Color statusColor = _grey;
    switch (manga.status) {
      case Status.ongoing:
        statusLabel = 'En cours';
        statusColor = Colors.green.shade400;
        break;
      case Status.completed:
        statusLabel = 'Terminé';
        statusColor = _accent;
        break;
      case Status.publishingFinished:
        statusLabel = 'Terminé';
        statusColor = _accent;
        break;
      case Status.canceled:
        statusLabel = 'Annulé';
        statusColor = Colors.red.shade400;
        break;
      case Status.onHiatus:
        statusLabel = 'En pause';
        statusColor = Colors.orange.shade400;
        break;
      default:
        statusLabel = '';
    }

    // Detect type keyword from genres (TV, Movie, OVA, etc.)
    const typeKws = ['TV', 'Movie', 'Film', 'OVA', 'ONA', 'Special', 'Music'];
    final typeTag = (manga.genre ?? [])
        .where((g) => typeKws.any((k) => g.toLowerCase() == k.toLowerCase()))
        .firstOrNull;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Synopsis
          if ((manga.description ?? '').isNotEmpty) ...[
            _sectionLabel('Synopsis'),
            const SizedBox(height: 8),
            StatefulBuilder(
              builder: (c, setSt) => GestureDetector(
                onTap: () => setSt(
                    () => _isDescriptionExpanded = !_isDescriptionExpanded),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      manga.description ?? '',
                      maxLines: _isDescriptionExpanded ? null : 5,
                      overflow: _isDescriptionExpanded
                          ? TextOverflow.visible
                          : TextOverflow.ellipsis,
                      style: TextStyle(
                          color: _grey, fontSize: 13, height: 1.55),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isDescriptionExpanded ? 'Voir moins' : 'Voir plus',
                      style: TextStyle(color: _accent, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
          // Informations générales
          _sectionLabel('Informations'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              // Nombre d'épisodes
              if (chapters.isNotEmpty)
                _infoChip(
                  Icons.play_circle_outline_rounded,
                  '${chapters.length} épisode${chapters.length > 1 ? 's' : ''}',
                  _accent.withValues(alpha: 0.10),
                  _accent,
                ),
              // Statut
              if (statusLabel.isNotEmpty)
                _infoChip(
                  Icons.circle,
                  statusLabel,
                  statusColor.withValues(alpha: 0.10),
                  statusColor,
                ),
              // Langue
              if ((manga.lang?.isNotEmpty ?? false))
                _infoChip(
                  Icons.language_rounded,
                  manga.lang!.toUpperCase(),
                  _card,
                  _grey,
                ),
              // Type (TV / Movie / OVA …)
              if (typeTag != null)
                _infoChip(
                  Icons.videocam_outlined,
                  typeTag,
                  _card,
                  _grey,
                ),
              // Source
              if ((manga.source?.isNotEmpty ?? false))
                _infoChip(
                  Icons.storage_outlined,
                  manga.source!,
                  _card,
                  _grey,
                ),
            ],
          ),
          const SizedBox(height: 20),
          // Genres
          if ((manga.genre?.isNotEmpty ?? false)) ...[
            _sectionLabel('Genres'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final g in (manga.genre ?? []))
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
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
                          fontSize: 11.5),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
          ],
          // Réalisateur / auteur
          if ((manga.author ?? '').isNotEmpty) ...[
            _sectionLabel('Réalisateur'),
            const SizedBox(height: 8),
            _detailRow(Icons.person_outline_rounded, manga.author!),
            const SizedBox(height: 16),
          ],
          // Casting / artiste
          if ((manga.artist ?? '').isNotEmpty) ...[
            _sectionLabel('Casting'),
            const SizedBox(height: 8),
            _detailRow(Icons.groups_2_outlined, manga.artist!),
            const SizedBox(height: 16),
          ],
          const SizedBox(height: 4),
          Divider(color: _faint, thickness: 0.8),
        ],
      ),
    );
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(color: _faint, thickness: 0.8, height: 1),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: _card,
                    shape: BoxShape.circle,
                    border: Border.all(color: _faint, width: 1.5),
                  ),
                  child: Icon(Icons.movie_filter_outlined, color: _grey, size: 26),
                ),
                const SizedBox(height: 14),
                Text(
                  'Les recommandations arrivent bientôt',
                  style: TextStyle(
                      color: _onSurface.withValues(alpha: 0.7),
                      fontSize: 14,
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 6),
                Text(
                  'Découvrez du contenu similaire dans la bibliothèque.',
                  style: TextStyle(color: _grey, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ],
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

  Future<void> _openInBrowser() async {
    final source = getSource(
        widget.manga.lang ?? '',
        widget.manga.source ?? '',
        widget.manga.sourceId);
    if (source == null || (widget.manga.link ?? '').isEmpty) return;
    final raw = '${source.baseUrl}${widget.manga.link!.getUrlWithoutDomain}';
    final uri = Uri.tryParse(raw);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
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

// ─── DOWNLOAD SHEET — engine + external downloader ───────────────────────────

enum _Downloader { hydra, zeus, aria2, external }

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
  // ── Theme ────────────────────────────────────────────────────────────────────
  Color get _accent => Theme.of(context).primaryColor;
  Color get _bg     => Theme.of(context).scaffoldBackgroundColor;
  Color get _text   => Theme.of(context).colorScheme.onSurface;
  Color get _grey   => _text.withValues(alpha: 0.48);
  Color get _faint  => _text.withValues(alpha: 0.13);

  // ── State ────────────────────────────────────────────────────────────────────
  bool _loading = true;
  List<Video> _videos = [];
  String? _selectedQuality;
  String? _selectedLang;
  String? _selectedSeason;
  _Downloader _downloader = _Downloader.hydra;
  String _externalApp = 'adm';
  final Set<Chapter> _selected = {};
  bool _selectAll = false;

  static final _langRe =
      RegExp(r'\b(VF|VO|VOSTFR|VOSTA|MULTI|EN|FR|JAP?|ENG?)\b',
          caseSensitive: false);
  static final _seasonRe =
      RegExp(r'(?:[Ss]aison|[Ss]eason|\bS)[ ]*(\d+)');

  // ── Init ─────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    final pref =
        DownloadSettingsService.instance.preferredExternalDownloader ?? '';
    if (pref.isNotEmpty) _externalApp = pref;
    _loadVideos();
  }

  Future<void> _loadVideos() async {
    if (widget.chapters.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final result = await ref
          .read(getVideoListProvider(episode: widget.chapters.first).future);
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

  // ── Data derivations ─────────────────────────────────────────────────────────

  /// Language tags found in video quality strings — only shown if > 1.
  List<String> get _langs {
    final s = <String>{};
    for (final v in _videos) {
      final m = _langRe.firstMatch(v.quality);
      if (m != null) s.add(m.group(0)!.toUpperCase());
    }
    return s.toList()..sort();
  }

  /// Distinct season labels from chapter names — only shown if > 1.
  List<String> get _seasons {
    final s = <String>{};
    for (final ch in widget.chapters) {
      final m = _seasonRe.firstMatch(ch.name ?? '');
      if (m != null) s.add('Saison ${m.group(1)}');
    }
    return s.toList()..sort();
  }

  /// Chapters filtered by selected season (none selected = all).
  List<Chapter> get _displayChapters {
    if (_selectedSeason == null) return widget.chapters;
    final num = _selectedSeason!.replaceAll('Saison ', '');
    return widget.chapters.where((ch) {
      final m = _seasonRe.firstMatch(ch.name ?? '');
      return m != null && m.group(1) == num;
    }).toList();
  }

  /// Real quality labels from fetched videos (filtered by lang if any).
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
    if (raw.trim().isEmpty) return 'Inconnu';
    final m = RegExp(r'^(\d{3,4})[pP]').firstMatch(raw);
    if (m != null) return '${m.group(1)}p';
    final s = raw.toLowerCase();
    if (s.contains('4k') || s.contains('2160')) return '4K';
    if (s.contains('1080') || s.contains('fhd')) return '1080p';
    if (s.contains('720') || s.contains('hd')) return '720p';
    if (s.contains('480') || s.contains('sd')) return '480p';
    if (s.contains('360')) return '360p';
    if (s.contains('240')) return '240p';
    return raw.trim();
  }

  // ── Download action ───────────────────────────────────────────────────────────

  Future<void> _startDownload() async {
    if (_selected.isEmpty) return;
    final chapters = _selected.toList();

    if (_downloader == _Downloader.external) {
      // Close sheet first, then fetch each chapter's URL and launch external app
      if (mounted) Navigator.pop(context);
      for (final ch in chapters) {
        try {
          final result =
              await ref.read(getVideoListProvider(episode: ch).future);
          final videos = result.$1;
          if (videos.isEmpty) {
            botToast('Aucun lien pour ${ch.name ?? '?'}');
            continue;
          }
          // Pick best match for selected quality, else first
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
            botToast(
                'Impossible d\'ouvrir $_externalApp — vérifiez qu\'il est installé.');
          }
        } catch (e) {
          if (mounted) botToast(e.toString().split('\n').first);
        }
      }
    } else {
      // Internal engines — set quality preference then hand off
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
    final displayed = _displayChapters;
    final screen  = MediaQuery.of(context).size.height;
    final statusH = MediaQuery.of(context).padding.top;
    final maxH    = screen - 230 - statusH; // never overlap the player
    final langs = _langs;
    final seasons = _seasons;
    final qualities = _qualities;

    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      color: _bg,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(top: 10, bottom: 2),
            decoration: BoxDecoration(
                color: _faint, borderRadius: BorderRadius.circular(2)),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: Row(children: [
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
            ]),
          ),
          // ── Filters (only real data) ────────────────────────────────────────
          if (_loading)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: LinearProgressIndicator(
                color: _accent,
                backgroundColor: _faint,
                minHeight: 2,
                borderRadius: BorderRadius.circular(1),
              ),
            )
          else ...[
            // Language — only if multiple languages available
            if (langs.length > 1)
              _filterRow(
                icon: Icons.language_rounded,
                label: 'Langue',
                items: langs,
                selected: _selectedLang,
                onSelect: (l) => setState(() {
                  _selectedLang = _selectedLang == l ? null : l;
                  _selectedQuality = null;
                }),
              ),
            // Season — only if multiple seasons detected
            if (seasons.length > 1)
              _filterRow(
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
            // Quality — only if real data available from the extension
            if (qualities.isNotEmpty)
              _filterRow(
                icon: Icons.hd_outlined,
                label: 'Qualité',
                items: qualities,
                selected: _selectedQuality,
                onSelect: (q) => setState(
                    () => _selectedQuality = _selectedQuality == q ? null : q),
              ),
          ],
          // ── Downloader picker ───────────────────────────────────────────────
          _buildDownloaderSection(),
          // ── Episode list ────────────────────────────────────────────────────
          Divider(height: 1, color: _faint),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 4),
              itemCount: displayed.length,
              itemBuilder: (_, i) => _buildEpisodeRow(displayed[i]),
            ),
          ),
          _buildBottomBar(displayed),
        ],
      ),
    );
  }

  // ── Filter row ────────────────────────────────────────────────────────────────

  Widget _filterRow({
    required IconData icon,
    required String label,
    required List<String> items,
    required String? selected,
    required void Function(String) onSelect,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: _grey),
          const SizedBox(width: 6),
          Text(label,
              style:
                  TextStyle(color: _grey, fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(width: 10),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: items.map((item) {
                  final sel = item == selected;
                  return GestureDetector(
                    onTap: () => onSelect(item),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: sel
                            ? _accent.withValues(alpha: 0.12)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color:
                              sel ? _accent : _faint,
                          width: sel ? 1.2 : 0.8,
                        ),
                      ),
                      child: Text(
                        item,
                        style: TextStyle(
                          color: sel ? _accent : _grey,
                          fontSize: 12,
                          fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
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

  // ── Downloader section ────────────────────────────────────────────────────────

  Widget _buildDownloaderSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.download_for_offline_outlined, size: 14, color: _grey),
            const SizedBox(width: 6),
            Text('Télécharger avec',
                style: TextStyle(
                    color: _grey,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
          ]),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              // ── Internal engines ────────────────────────────────────────────
              _engineChip(
                label: 'Hydra',
                icon: Icons.water_drop_outlined,
                value: _Downloader.hydra,
              ),
              const SizedBox(width: 6),
              _engineChip(
                label: 'Zeus',
                icon: Icons.bolt_outlined,
                value: _Downloader.zeus,
              ),
              const SizedBox(width: 6),
              _engineChip(
                label: 'Aria2',
                icon: Icons.multiple_stop_rounded,
                value: _Downloader.aria2,
              ),
              Container(
                width: 1, height: 24,
                margin: const EdgeInsets.symmetric(horizontal: 10),
                color: _faint,
              ),
              // ── External apps ───────────────────────────────────────────────
              _externalChip(label: 'ADM', appId: 'adm'),
              const SizedBox(width: 6),
              _externalChip(label: '1DM', appId: '1dm'),
              const SizedBox(width: 6),
              _externalChip(label: 'FDM', appId: 'fdm'),
              const SizedBox(width: 6),
              _externalChip(label: 'IDM+', appId: 'idm'),
            ]),
          ),
          if (_downloader == _Downloader.external) ...[
            const SizedBox(height: 6),
            Row(children: [
              Icon(Icons.info_outline_rounded, size: 12, color: _accent),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  'L\'URL du flux sera transmise à $_externalApp avec les en-têtes requis.',
                  style: TextStyle(color: _accent, fontSize: 11),
                ),
              ),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _engineChip({
    required String label,
    required IconData icon,
    required _Downloader value,
  }) {
    final sel =
        _downloader == value && _downloader != _Downloader.external;
    return GestureDetector(
      onTap: () => setState(() => _downloader = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: sel ? _accent.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: sel ? _accent : _faint,
            width: sel ? 1.2 : 0.8,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: sel ? _accent : _grey),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  color: sel ? _accent : _grey,
                  fontSize: 12,
                  fontWeight: sel ? FontWeight.w600 : FontWeight.normal)),
        ]),
      ),
    );
  }

  Widget _externalChip({required String label, required String appId}) {
    final sel =
        _downloader == _Downloader.external && _externalApp == appId;
    return GestureDetector(
      onTap: () => setState(() {
        _downloader = _Downloader.external;
        _externalApp = appId;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: sel ? _accent.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: sel ? _accent : _faint,
            width: sel ? 1.2 : 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: sel ? _accent : _grey,
            fontSize: 12,
            fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // ── Episode row ───────────────────────────────────────────────────────────────

  Widget _buildEpisodeRow(Chapter chapter) {
    final sel = _selected.contains(chapter);
    return InkWell(
      onTap: () => setState(() {
        sel ? _selected.remove(chapter) : _selected.add(chapter);
        _selectAll = _selected.length == _displayChapters.length;
      }),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(children: [
          Icon(
            sel ? Icons.radio_button_checked : Icons.radio_button_unchecked,
            color: sel ? _accent : _faint,
            size: 21,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              chapter.name ?? 'Épisode',
              style: TextStyle(color: _text, fontSize: 14),
            ),
          ),
          if (chapter.duration?.isNotEmpty == true)
            Text(chapter.duration!,
                style: TextStyle(color: _grey, fontSize: 12)),
        ]),
      ),
    );
  }

  // ── Bottom bar ────────────────────────────────────────────────────────────────

  Widget _buildBottomBar(List<Chapter> displayed) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: _faint)),
        color: _bg,
      ),
      child: SafeArea(
        child: Row(children: [
          GestureDetector(
            onTap: () => setState(() {
              _selectAll = !_selectAll;
              if (_selectAll) {
                _selected.addAll(displayed);
              } else {
                _selected.removeAll(displayed);
              }
            }),
            child: Row(children: [
              Icon(
                _selectAll
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: _selectAll ? _accent : _faint,
                size: 21,
              ),
              const SizedBox(width: 8),
              Text('Tout sélectionner',
                  style: TextStyle(
                      color: _text.withValues(alpha: 0.65), fontSize: 14)),
            ]),
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: _selected.isEmpty ? null : _startDownload,
            icon: const Icon(Icons.download_rounded, size: 17),
            label: Text(_selected.isEmpty
                ? 'Télécharger'
                : 'Télécharger (${_selected.length})'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              disabledBackgroundColor: _faint,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ]),
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
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Chargement…',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.70),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
