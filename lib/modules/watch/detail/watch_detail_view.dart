import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  // ─── Palette ────────────────────────────────────────────────────────────────
  static const _teal    = Color(0xFF1DB954);
  static const _bg      = Color(0xFF0F0F17);   // deep blue-black instead of pure black
  static const _card    = Color(0xFF1C1B27);   // warmer dark card
  static const _surface = Color(0xFF252434);   // sheet / modal surface
  static const _grey    = Color(0xFF9E9E9E);

  String? _selectedSeason;
  String? _selectedLanguage;
  bool _isDescriptionExpanded = false;

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

  void _share(BuildContext context) {
    final source = getSource(widget.manga.lang!, widget.manga.source!, widget.manga.sourceId);
    if (source == null) return;
    final url = '${source.baseUrl}${widget.manga.link!.getUrlWithoutDomain}';
    SharePlus.instance.share(ShareParams(text: url));
  }

  void _downloadChapter(Chapter chapter) {
    final entry = isar.downloads.filter().idEqualTo(chapter.id).findFirstSync();
    if (entry == null || !(entry.isDownload ?? false)) {
      ref.read(addDownloadToQueueProvider(chapter: chapter));
    }
    ref.read(processDownloadsProvider());
    botToast('Téléchargement lancé');
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

    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

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
      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        SliverAppBar(
          expandedHeight: 230,
          pinned: true,
          backgroundColor: _bg,
          automaticallyImplyLeading: false,
          actions: [
            if (widget.isLoading)
              const Padding(
                padding: EdgeInsets.all(14),
                child: SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _teal),
                ),
              ),
            IconButton(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onPressed: () => _showOptionsSheet(context, chapters),
            ),
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
              indicatorColor: _teal,
              indicatorWeight: 2.5,
              labelColor: Colors.white,
              unselectedLabelColor: const Color(0xFF666688),
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

  // ─── BANNER (poster + inline video overlay) ──────────────────────────────────

  Widget _buildBanner(List<Chapter> chapters) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildBannerImageOnly(),

        // Inline video overlay (no-op on web)
        _player.buildBannerOverlay(context: context, chapters: chapters),

        // Loading spinner while video URL is being fetched
        if (!_player.hasVideoUrl && chapters.isNotEmpty)
          const Center(
            child: SizedBox(
              width: 34, height: 34,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: _teal),
            ),
          ),

        // Gradient to blend into page bg
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0.0, 0.3, 0.65, 1.0],
              colors: [
                Color(0xBB0F0F17),
                Color(0x000F0F17),
                Color(0x440F0F17),
                Color(0xFF0F0F17),
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
          const SizedBox(height: 8),
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

  Widget _buildTitleRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            widget.manga.name ?? '',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => _showInfoSheet(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _teal.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _teal.withValues(alpha: 0.4), width: 0.8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.info_outline, color: _teal, size: 13),
                SizedBox(width: 4),
                Text('Info', style: TextStyle(color: _teal, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── META ROW ───────────────────────────────────────────────────────────────

  Widget _buildMetaRow(List<Chapter> chapters) {
    final isMovie = _isMovie(chapters);
    final parts = <String>[];
    final author = widget.manga.author ?? '';
    if (author.isNotEmpty) parts.add(author);
    final genres = widget.manga.genre?.take(2).toList() ?? [];
    parts.addAll(genres);

    return Row(
      children: [
        // Type pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: isMovie ? const Color(0xFF2A1A0A) : const Color(0xFF0A0A1E),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: isMovie ? const Color(0xFFE87820).withValues(alpha: 0.7) : _teal.withValues(alpha: 0.7),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isMovie ? Icons.movie_outlined : Icons.live_tv_outlined,
                size: 11,
                color: isMovie ? const Color(0xFFE87820) : _teal,
              ),
              const SizedBox(width: 4),
              Text(
                isMovie ? 'Film' : 'Série',
                style: TextStyle(
                  color: isMovie ? const Color(0xFFE87820) : _teal,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        const Icon(Icons.star_rounded, color: Color(0xFFFFD700), size: 14),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            parts.isEmpty ? '' : parts.join('  ·  '),
            style: const TextStyle(color: _grey, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // ─── INFO SHEET (full details) ───────────────────────────────────────────────

  void _showInfoSheet(BuildContext context) {
    final manga = widget.manga;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.78,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF191826),
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                width: 38, height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 0),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: ctrl,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  children: [
                    // Header: poster + title side by side
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: cachedNetworkImage(
                            imageUrl: toImgUrl(manga.customCoverFromTracker ?? manga.imageUrl ?? ''),
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
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if ((manga.author ?? '').isNotEmpty)
                                Text(
                                  manga.author!,
                                  style: const TextStyle(color: _grey, fontSize: 13),
                                ),
                              const SizedBox(height: 10),
                              // Info pills
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  _infoPill(Icons.language, (manga.lang ?? '').toUpperCase()),
                                  _infoPill(Icons.circle, _statusLabel(manga.status)),
                                  if ((manga.source ?? '').isNotEmpty)
                                    _infoPill(Icons.storage_outlined, manga.source!),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Synopsis
                    if ((manga.description ?? '').isNotEmpty) ...[
                      _sectionLabel('Synopsis'),
                      const SizedBox(height: 8),
                      StatefulBuilder(
                        builder: (ctx, setSt) {
                          return GestureDetector(
                            onTap: () => setSt(() => _isDescriptionExpanded = !_isDescriptionExpanded),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  manga.description ?? '',
                                  maxLines: _isDescriptionExpanded ? null : 4,
                                  overflow: _isDescriptionExpanded
                                      ? TextOverflow.visible
                                      : TextOverflow.ellipsis,
                                  style: const TextStyle(color: _grey, fontSize: 13, height: 1.55),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _isDescriptionExpanded ? 'Voir moins' : 'Voir plus',
                                  style: const TextStyle(color: _teal, fontSize: 12),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                    ],
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
                              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
                              decoration: BoxDecoration(
                                color: _teal.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: _teal.withValues(alpha: 0.35), width: 0.8),
                              ),
                              child: Text(
                                g,
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
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
        ),
      ),
    );
  }

  Widget _infoPill(IconData icon, String label) {
    if (label.trim().isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2940),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: _grey),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: _grey, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Row(
      children: [
        Container(width: 3, height: 14, decoration: BoxDecoration(color: _teal, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
      ],
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
            label: isFav ? 'Dans ma liste' : 'Ajouter à ma liste',
            onTap: _toggleFavorite,
            active: isFav,
          ),
          const SizedBox(width: 8),
          _chip(icon: Icons.share_outlined, label: 'Partager', onTap: () => _share(context)),
          const SizedBox(width: 8),
          _chip(icon: Icons.download_outlined, label: 'Télécharger', onTap: () => _showDownloadSheet(context, chapters)),
          const SizedBox(width: 8),
          _chip(icon: Icons.download_for_offline_outlined, label: 'Voir téléchargements',
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
          color: active ? _teal.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: active ? _teal : const Color(0xFF3A3A50), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: active ? _teal : Colors.white60),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: active ? _teal : Colors.white60, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  // ─── MOVIE / SERIES DETECTION ───────────────────────────────────────────────

  bool _isMovie(List<Chapter> chapters) {
    if (widget.isLoading) return false;
    if (chapters.isEmpty) return false;
    final genres = (widget.manga.genre ?? []).map((g) => g.toLowerCase().trim()).toList();
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
        final na = int.tryParse(a.replaceAll(RegExp(r'\D'), '')) ?? 0;
        final nb = int.tryParse(b.replaceAll(RegExp(r'\D'), '')) ?? 0;
        return na.compareTo(nb);
      });
  }

  List<String> _detectLanguages(List<Chapter> chapters) {
    final langRx = RegExp(
        r'\b(VF|VOSTFR|VO|French|English|Français|Dub|Sub|MULTI|VOSTA)\b',
        caseSensitive: false);
    final seen = <String>{};
    for (final ch in chapters) {
      for (final m in langRx.allMatches('${ch.scanlator ?? ''} ${ch.name ?? ''}')) {
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
          r'(?:Saison|Season|Partie|Part)\s*' + num + r'|S' + num.padLeft(2, '0'),
          caseSensitive: false);
      final filtered = result.where((ch) => rx.hasMatch(ch.name ?? '')).toList();
      if (filtered.isNotEmpty) result = filtered;
    }
    final lang = _selectedLanguage;
    if (lang != null) {
      final filtered = result.where((ch) =>
          (ch.scanlator ?? '').toUpperCase().contains(lang) ||
          (ch.name ?? '').toUpperCase().contains(lang)).toList();
      if (filtered.isNotEmpty) result = filtered;
    }
    return result;
  }

  // ─── RESSOURCES / EPISODES ──────────────────────────────────────────────────

  Widget _buildRessourcesSection(List<Chapter> chapters) {
    final isMovie   = _isMovie(chapters);
    final seasons   = isMovie ? <String>[] : _detectSeasons(chapters);
    final languages = _detectLanguages(chapters);
    final filtered  = _filterChapters(chapters);

    final source = getSource(widget.manga.lang ?? '', widget.manga.source ?? '', widget.manga.sourceId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ──
        Row(
          children: [
            Text(
              isMovie ? 'Film' : 'Épisodes',
              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
            ),
            if (!isMovie && chapters.isNotEmpty)
              Text('  ${filtered.length}', style: const TextStyle(color: _grey, fontSize: 13)),
            if (source != null) ...[
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1D2E),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'via ${source.name}',
                  style: const TextStyle(color: _grey, fontSize: 11),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),

        // ── Language selector ──
        if (languages.length > 1) ...[
          _buildSelectorRow(
            icon: Icons.language_outlined,
            items: languages,
            selected: _selectedLanguage,
            onSelected: (v) => setState(() => _selectedLanguage = v),
          ),
          const SizedBox(height: 10),
        ],

        // ── Season selector ──
        if (!isMovie && seasons.length > 1) ...[
          _buildSelectorRow(
            icon: Icons.layers_outlined,
            items: seasons,
            selected: _selectedSeason,
            onSelected: (v) => setState(() => _selectedSeason = v),
          ),
          const SizedBox(height: 12),
        ],

        // ── Content ──
        if (chapters.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Icon(Icons.video_library_outlined, color: Colors.grey, size: 40),
                  SizedBox(height: 8),
                  Text('Aucun épisode disponible', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          )
        else if (isMovie)
          _buildMovieBox(filtered.isNotEmpty ? filtered.first : chapters.first)
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
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: isSel ? _teal.withValues(alpha: 0.15) : const Color(0xFF252434),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSel ? _teal : const Color(0xFF3A3A52),
                      width: isSel ? 1.2 : 0.8,
                    ),
                  ),
                  child: Text(
                    item,
                    style: TextStyle(
                      color: isSel ? _teal : Colors.white70,
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

  Widget _buildMovieBox(Chapter chapter) {
    final hasThumb = (chapter.thumbnailUrl ?? '').isNotEmpty;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => chapter.pushToReaderView(context, ignoreIsRead: true),
        child: Container(
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _teal.withValues(alpha: 0.45), width: 0.8),
            boxShadow: [
              BoxShadow(color: _teal.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4)),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: hasThumb
                    ? cachedNetworkImage(imageUrl: chapter.thumbnailUrl!, width: double.infinity, height: 180, fit: BoxFit.cover)
                    : Container(width: double.infinity, height: 180, color: const Color(0xFF1E1D2E)),
              ),
              Container(
                height: 180,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Color(0xCC000000)],
                  ),
                ),
              ),
              Container(
                width: 62, height: 62,
                decoration: BoxDecoration(
                  color: _teal.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: _teal.withValues(alpha: 0.4), blurRadius: 16, spreadRadius: 2)],
                ),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 36),
              ),
              if ((chapter.name ?? '').isNotEmpty || (chapter.duration ?? '').isNotEmpty)
                Positioned(
                  bottom: 12, left: 14, right: 14,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          chapter.name ?? 'Film',
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if ((chapter.duration ?? '').isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(chapter.duration!, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── EPISODE GRID (numbered chips, MovieBox style) ──────────────────────────

  Widget _buildEpisodeGrid(List<Chapter> chapters) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(chapters.length, (i) {
        final chapter = chapters[i];
        final watched = chapter.isRead ?? false;
        final numMatch = RegExp(r'\d+').firstMatch(chapter.name ?? '');
        final epNum = numMatch != null ? (int.tryParse(numMatch.group(0)!) ?? (i + 1)) : (i + 1);
        final label = epNum.toString().padLeft(2, '0');

        return GestureDetector(
          onTap: () => chapter.pushToReaderView(context, ignoreIsRead: true),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 52, height: 40,
            decoration: BoxDecoration(
              color: watched ? const Color(0xFF1A1928) : _teal.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: watched ? const Color(0xFF32304A) : _teal.withValues(alpha: 0.55),
                width: 1,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                color: watched ? const Color(0xFF555575) : Colors.white,
                fontSize: 13,
                fontWeight: watched ? FontWeight.normal : FontWeight.w600,
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
              border: Border.all(color: const Color(0xFF32304A), width: 1.5),
            ),
            child: const Icon(Icons.movie_filter_outlined, color: Color(0xFF555575), size: 36),
          ),
          const SizedBox(height: 16),
          const Text('Les recommandations arrivent bientôt', style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 6),
          const Text(
            'Découvrez du contenu similaire dans la bibliothèque',
            style: TextStyle(color: Color(0xFF555575), fontSize: 12),
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
              border: Border.all(color: const Color(0xFF32304A), width: 1.5),
            ),
            child: const Icon(Icons.chat_bubble_outline, color: Color(0xFF555575), size: 32),
          ),
          const SizedBox(height: 16),
          const Text('Aucun commentaire', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          const Text(
            'Les commentaires apparaissent ici\nsi l\'extension les fournit.',
            style: TextStyle(color: Color(0xFF555575), fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ─── DOWNLOAD SHEET ─────────────────────────────────────────────────────────

  void _showDownloadSheet(BuildContext context, List<Chapter> chapters) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF191826),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _DownloadSheet(
        manga: widget.manga,
        chapters: chapters,
        onDownload: (selected) {
          Navigator.pop(context);
          for (final ch in selected) {
            final entry = isar.downloads.filter().idEqualTo(ch.id).findFirstSync();
            if (entry == null || !(entry.isDownload ?? false)) {
              ref.read(addDownloadToQueueProvider(chapter: ch));
            }
          }
          ref.read(processDownloadsProvider());
          if (selected.isNotEmpty) _showAfterDownloadSheet(context, selected.length);
        },
      ),
    );
  }

  void _showAfterDownloadSheet(BuildContext context, int count) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF191826),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.download_rounded, color: _teal, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Téléchargement $count fichier(s)',
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close, color: Colors.white54, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Regardez pendant le téléchargement, sans données supplémentaires.',
                style: TextStyle(color: _grey, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.of(context).pushNamed('/downloadQueue');
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFF3A3A52)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Voir le téléchargement'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

  void _showOptionsSheet(BuildContext context, List<Chapter> chapters) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF191826),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38, height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
            ListTile(
              leading: const Icon(Icons.refresh, color: Colors.white70),
              title: const Text('Actualiser', style: TextStyle(color: Colors.white)),
              onTap: () { Navigator.pop(context); widget.checkForUpdate(true); },
            ),
            ListTile(
              leading: const Icon(Icons.share, color: Colors.white70),
              title: const Text('Partager', style: TextStyle(color: Colors.white)),
              onTap: () { Navigator.pop(context); _share(context); },
            ),
            ListTile(
              leading: const Icon(Icons.download, color: Colors.white70),
              title: const Text('Tout télécharger', style: TextStyle(color: Colors.white)),
              onTap: () { Navigator.pop(context); _downloadAll(chapters); },
            ),
            const SizedBox(height: 8),
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
  static const _teal = Color(0xFF1DB954);
  static const _bg   = Color(0xFF191826);
  static const _card = Color(0xFF232234);

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
          const Divider(height: 1, color: Color(0xFF2A2840)),
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
        decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
      );

  Widget _buildHeader() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            const Text('Télécharger',
                style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
            const Spacer(),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Icon(Icons.close, color: Colors.white54, size: 22),
            ),
          ],
        ),
      );

  Widget _buildResourcesCard() {
    final source = getSource(widget.manga.lang ?? '', widget.manga.source ?? '', widget.manga.sourceId);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF3A3A52), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.storage_outlined, color: Color(0xFF9E9E9E), size: 14),
              const SizedBox(width: 6),
              const Text('Ressources', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
              if (source != null) ...[
                const SizedBox(width: 6),
                Text('· ${source.name}', style: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 12)),
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
        color: const Color(0xFF2A2840),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF3A3A52), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(width: 4),
          Icon(icon, color: Colors.white54, size: 16),
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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: sel ? _teal : const Color(0xFF2A2840),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: sel ? _teal : const Color(0xFF3A3A52), width: 0.8),
                ),
                child: Text(
                  q,
                  style: TextStyle(
                    color: sel ? Colors.white : Colors.white54,
                    fontSize: 13,
                    fontWeight: sel ? FontWeight.w700 : FontWeight.normal,
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
                  ? const Icon(Icons.radio_button_checked, color: _teal, size: 22)
                  : const Icon(Icons.radio_button_unchecked, color: Colors.white24, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                chapter.name ?? 'Épisode ${index + 1}',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
            Text(
              chapter.duration?.isNotEmpty == true ? chapter.duration! : '',
              style: const TextStyle(color: Color(0xFF555575), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(List<Chapter> chapters) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFF2A2840))),
        color: _bg,
      ),
      child: SafeArea(
        child: Row(
          children: [
            GestureDetector(
              onTap: () => setState(() {
                _selectAll = !_selectAll;
                if (_selectAll) {
                  _selected.addAll(List.generate(chapters.length, (i) => i));
                } else {
                  _selected.clear();
                }
              }),
              child: Row(
                children: [
                  SizedBox(
                    width: 22, height: 22,
                    child: _selectAll
                        ? const Icon(Icons.radio_button_checked, color: _teal, size: 22)
                        : const Icon(Icons.radio_button_unchecked, color: Colors.white24, size: 22),
                  ),
                  const SizedBox(width: 8),
                  const Text('Tout sélectionner', style: TextStyle(color: Colors.white70, fontSize: 14)),
                ],
              ),
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: _selected.isEmpty
                  ? null
                  : () => widget.onDownload(_selected.map((i) => chapters[i]).toList()),
              icon: const Icon(Icons.download_outlined, size: 18),
              label: Text(_selected.isEmpty ? 'Télécharger' : 'Télécharger (${_selected.length})'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _teal,
                disabledBackgroundColor: const Color(0xFF252434),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

  @override double get minExtent => tabBar.preferredSize.height;
  @override double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) =>
      ColoredBox(color: color, child: tabBar);

  @override
  bool shouldRebuild(_TabBarDelegate old) => old.tabBar != tabBar || old.color != color;
}
