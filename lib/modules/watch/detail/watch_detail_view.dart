import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
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
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:watchtower/services/get_video_list.dart';

/// Dedicated detail page for watch/video content (films, series).
/// Portrait: inline auto-play player in banner area.
/// Landscape: fullscreen player.
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
  bool _isDescriptionExpanded = false;

  // ── Inline video player ──────────────────────────────────────────────────────
  Player? _player;
  VideoController? _videoController;
  bool _hasVideoUrl = false;
  int? _loadedChapterId;

  static const _teal = Color(0xFF1DB954);
  static const _bg = Color(0xFF0E0E0E);
  static const _card = Color(0xFF1A1A1A);
  static const _grey = Color(0xFF9E9E9E);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    if (!kIsWeb) {
      _player = Player();
      _videoController = VideoController(_player!);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _player?.dispose();
    super.dispose();
  }

  // ─── VIDEO LOADING ──────────────────────────────────────────────────────────

  void _maybeStartVideo(List<Chapter> chapters) {
    if (kIsWeb || _player == null || chapters.isEmpty) return;
    final chapterId = chapters.first.id;
    if (_loadedChapterId == chapterId) return;
    _loadedChapterId = chapterId;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        final data = await ref.read(
          getVideoListProvider(episode: chapters.first).future,
        );
        if (!mounted) return;
        final (videos, _, __, ___) = data;
        if (videos.isNotEmpty) {
          final v = videos.first;
          await _player!.open(
            Media(v.url, httpHeaders: v.headers),
            play: true,
          );
          if (mounted) setState(() => _hasVideoUrl = true);
        }
      } catch (_) {
        // Silently fall back to poster image
      }
    });
  }

  // ─── ACTIONS ────────────────────────────────────────────────────────────────

  void _toggleFavorite() {
    final manga = widget.manga;
    isar.writeTxnSync(() {
      manga.favorite = !(manga.favorite ?? false);
      if (manga.favorite!) {
        manga.dateAdded = DateTime.now().millisecondsSinceEpoch;
      }
      isar.mangas.putSync(manga);
    });
    setState(() {});
  }

  void _share(BuildContext context) {
    final source =
        getSource(widget.manga.lang!, widget.manga.source!, widget.manga.sourceId);
    if (source == null) return;
    final url =
        '${source.baseUrl}${widget.manga.link!.getUrlWithoutDomain}';
    SharePlus.instance.share(ShareParams(text: url));
  }

  void _downloadChapter(Chapter chapter) {
    final entry =
        isar.downloads.filter().idEqualTo(chapter.id).findFirstSync();
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
          loading: () =>
              widget.manga.chapters.toList().reversed.toList(),
          error: (_, __) => <Chapter>[],
        );

    // Kick off video load (deferred, guarded by _loadedChapterId)
    _maybeStartVideo(chapters);

    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    if (isLandscape) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: _buildFullscreenLandscape(chapters),
      );
    }

    return Scaffold(
      body: _buildPortrait(chapters),
    );
  }

  // ─── FULLSCREEN LANDSCAPE ───────────────────────────────────────────────────

  Widget _buildFullscreenLandscape(List<Chapter> chapters) {
    return Stack(
      children: [
        if (!kIsWeb && _videoController != null)
          SizedBox.expand(
            child: Video(
              controller: _videoController!,
              fit: BoxFit.contain,
              controls: MaterialVideoControls,
            ),
          )
        else ...[
          SizedBox(
            width: 280,
            height: double.infinity,
            child: _buildBannerImage(),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _buildTitleRow(),
                const SizedBox(height: 6),
                _buildMetaRow(),
                const SizedBox(height: 10),
                if ((widget.manga.description ?? '').isNotEmpty)
                  _buildDescription(),
                const SizedBox(height: 14),
                _buildActionButtons(chapters),
              ],
            ),
          ),
        ],
        SafeArea(
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ],
    );
  }

  // ─── PORTRAIT ───────────────────────────────────────────────────────────────

  Widget _buildPortrait(List<Chapter> chapters) {
    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        // ── Player banner ──
        SliverAppBar(
          expandedHeight: 230,
          pinned: true,
          backgroundColor: Colors.black,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: [
            if (widget.isLoading)
              const Padding(
                padding: EdgeInsets.all(14),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _teal,
                  ),
                ),
              ),
            IconButton(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onPressed: () => _showOptionsSheet(context, chapters),
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: _buildPlayerBanner(chapters),
          ),
        ),

        // ── Metadata + actions + episodes ──
        SliverToBoxAdapter(
          child: _buildMetadataBlock(chapters),
        ),

        // ── Pinned TabBar ──
        SliverPersistentHeader(
          pinned: true,
          delegate: _TabBarDelegate(
            TabBar(
              controller: _tabController,
              indicatorColor: _teal,
              indicatorWeight: 2.5,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey,
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

  // ─── PLAYER BANNER ──────────────────────────────────────────────────────────

  Widget _buildPlayerBanner(List<Chapter> chapters) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Poster always shown as background / placeholder
        _buildBannerImage(),

        // Inline video player — overlaid once URL is ready (native only)
        if (!kIsWeb && _videoController != null && _hasVideoUrl)
          Video(
            controller: _videoController!,
            fit: BoxFit.cover,
            controls: NoVideoControls,
          ),

        // Loading spinner while fetching video URL
        if (!kIsWeb && chapters.isNotEmpty && !_hasVideoUrl)
          const Center(
            child: SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: _teal,
              ),
            ),
          ),

        // Bottom gradient
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0.0, 0.25, 0.65, 1.0],
              colors: [
                Color(0xAA0E0E0E),
                Color(0x000E0E0E),
                Color(0x550E0E0E),
                Color(0xFF0E0E0E),
              ],
            ),
          ),
        ),

        // Fullscreen button (tap to open full player)
        if (!kIsWeb && _hasVideoUrl && chapters.isNotEmpty)
          Positioned(
            bottom: 10,
            right: 10,
            child: GestureDetector(
              onTap: () => chapters.first
                  .pushToReaderView(context, ignoreIsRead: true),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.fullscreen,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ─── BANNER IMAGE (poster fallback) ─────────────────────────────────────────

  Widget _buildBannerImage() {
    final manga = widget.manga;
    final headers = (manga.isLocalArchive ?? false)
        ? null
        : ref.watch(headersProvider(
            source: manga.source!,
            lang: manga.lang!,
            sourceId: manga.sourceId,
          ));
    final imgUrl =
        toImgUrl(manga.customCoverFromTracker ?? manga.imageUrl ?? '');

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
          const SizedBox(height: 6),
          _buildMetaRow(),
          const SizedBox(height: 10),
          if ((widget.manga.description ?? '').isNotEmpty) _buildDescription(),
          const SizedBox(height: 14),
          _buildActionButtons(chapters),
          const SizedBox(height: 20),
          _buildEpisodesSection(chapters),
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
              fontSize: 20,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () {},
          child: const Row(
            children: [
              Text(
                'Info',
                style: TextStyle(color: _teal, fontSize: 13),
              ),
              Icon(Icons.chevron_right, color: _teal, size: 18),
            ],
          ),
        ),
      ],
    );
  }

  // ─── META ROW ───────────────────────────────────────────────────────────────

  Widget _buildMetaRow() {
    final parts = <String>[];
    final author = widget.manga.author ?? '';
    if (author.isNotEmpty) parts.add(author);
    final genres = widget.manga.genre?.take(3).toList() ?? [];
    parts.addAll(genres);
    if (parts.isEmpty) return const SizedBox.shrink();

    return Row(
      children: [
        const Icon(Icons.star_rounded, color: Color(0xFFFFD700), size: 15),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            parts.join('  ·  '),
            style: const TextStyle(color: _grey, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // ─── DESCRIPTION ────────────────────────────────────────────────────────────

  Widget _buildDescription() {
    return GestureDetector(
      onTap: () =>
          setState(() => _isDescriptionExpanded = !_isDescriptionExpanded),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.manga.description ?? '',
            maxLines: _isDescriptionExpanded ? null : 3,
            overflow: _isDescriptionExpanded
                ? TextOverflow.visible
                : TextOverflow.ellipsis,
            style: const TextStyle(
              color: _grey,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _isDescriptionExpanded ? 'Réduire' : 'Lire plus',
            style: const TextStyle(color: _teal, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ─── ACTION BUTTONS ─────────────────────────────────────────────────────────

  Widget _buildActionButtons(List<Chapter> chapters) {
    final isFav = widget.manga.favorite ?? false;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _chip(
            icon: isFav ? Icons.playlist_add_check : Icons.playlist_add,
            label: isFav ? 'Dans la liste' : 'Ajouter à la liste',
            onTap: _toggleFavorite,
            active: isFav,
          ),
          const SizedBox(width: 8),
          _chip(
            icon: Icons.share_outlined,
            label: 'Partager',
            onTap: () => _share(context),
          ),
          const SizedBox(width: 8),
          _chip(
            icon: Icons.download_outlined,
            label: 'Télécharger',
            onTap: () => _showDownloadSheet(context, chapters),
          ),
          const SizedBox(width: 8),
          _chip(
            icon: Icons.tv_outlined,
            label: 'Voir le télé',
            onTap: () => botToast('Cast non disponible'),
          ),
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
          border: Border.all(
            color: active ? _teal : const Color(0xFF3A3A3A),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 17, color: active ? _teal : Colors.white70),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: active ? _teal : Colors.white70,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── EPISODES SECTION ───────────────────────────────────────────────────────
  // Replaces the old "Ressources/Film" block.
  // • 0 chapters  → empty state
  // • 1 chapter   → compact play row (movie-style)
  // • >1 chapters → section header + full episode list (series)

  Widget _buildEpisodesSection(List<Chapter> chapters) {
    final source = getSource(
      widget.manga.lang ?? '',
      widget.manga.source ?? '',
      widget.manga.sourceId,
    );

    if (chapters.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Column(
            children: [
              Icon(Icons.video_library_outlined,
                  color: Colors.grey, size: 40),
              SizedBox(height: 8),
              Text(
                'Aucun épisode disponible',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    // ── Movie: single compact row ────────────────────────────────────────────
    if (chapters.length == 1) {
      return _buildCompactSingleEpisode(chapters.first, source?.name);
    }

    // ── Series: full episode list ────────────────────────────────────────────
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Épisodes · ${chapters.length}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (source != null) ...[
              const SizedBox(width: 8),
              Text(
                'via ${source.name}',
                style: const TextStyle(color: _grey, fontSize: 12),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        ...chapters.map((ch) => _buildEpisodeTile(ch)),
      ],
    );
  }

  // Compact single-episode row (films / OVAs)
  Widget _buildCompactSingleEpisode(Chapter chapter, String? sourceName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (sourceName != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'via $sourceName',
              style: const TextStyle(color: _grey, fontSize: 12),
            ),
          ),
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () =>
                chapter.pushToReaderView(context, ignoreIsRead: true),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              child: Row(
                children: [
                  const Icon(Icons.play_circle_outline,
                      color: _teal, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      chapter.name ?? 'Regarder',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if ((chapter.duration ?? '').isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(
                      chapter.duration!,
                      style: const TextStyle(
                          color: _grey, fontSize: 12),
                    ),
                  ],
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.download_outlined,
                        color: Colors.white54, size: 20),
                    onPressed: () => _downloadChapter(chapter),
                    tooltip: 'Télécharger',
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Individual episode tile (used in series list)
  Widget _buildEpisodeTile(Chapter chapter) {
    final watched = chapter.isRead ?? false;
    final hasThumb = (chapter.thumbnailUrl ?? '').isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => chapter.pushToReaderView(context, ignoreIsRead: true),
          child: Container(
            decoration: BoxDecoration(
              color: watched ? const Color(0xFF171717) : _card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: watched
                    ? const Color(0xFF2D2D2D)
                    : _teal.withValues(alpha: 0.5),
                width: 0.8,
              ),
            ),
            child: Row(
              children: [
                // Thumbnail or play icon
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(9),
                    bottomLeft: Radius.circular(9),
                  ),
                  child: hasThumb
                      ? cachedNetworkImage(
                          imageUrl: chapter.thumbnailUrl!,
                          width: 80,
                          height: 52,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          width: 80,
                          height: 52,
                          color: const Color(0xFF252525),
                          child: Icon(
                            watched
                                ? Icons.check_circle_outline
                                : Icons.play_circle_outline,
                            color: _teal,
                            size: 26,
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        chapter.name ?? 'Épisode',
                        style: TextStyle(
                          color: watched ? Colors.grey : Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if ((chapter.duration ?? '').isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          chapter.duration!,
                          style: const TextStyle(
                            color: _grey,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.download_outlined,
                      color: Colors.white54, size: 20),
                  onPressed: () => _downloadChapter(chapter),
                  tooltip: 'Télécharger',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── TABS ────────────────────────────────────────────────────────────────────

  Widget _buildRecommendationsTab() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.movie_filter_outlined, color: Colors.grey, size: 52),
          SizedBox(height: 14),
          Text(
            'Les recommandations arrivent bientôt',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          SizedBox(height: 6),
          Text(
            'Découvrez du contenu similaire dans la bibliothèque',
            style: TextStyle(color: Color(0xFF555555), fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsTab() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, color: Colors.grey, size: 52),
          SizedBox(height: 14),
          Text(
            'Aucun commentaire pour le moment',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          SizedBox(height: 6),
          Text(
            'Les commentaires sont affichés si l\'extension les fournit',
            style: TextStyle(color: Color(0xFF555555), fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ─── DOWNLOAD SHEET ─────────────────────────────────────────────────────────

  void _showDownloadSheet(BuildContext context, List<Chapter> chapters) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1C),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _DownloadSheet(
        manga: widget.manga,
        chapters: chapters,
        onDownload: (selected) {
          Navigator.pop(context);
          for (final ch in selected) {
            final entry =
                isar.downloads.filter().idEqualTo(ch.id).findFirstSync();
            if (entry == null || !(entry.isDownload ?? false)) {
              ref.read(addDownloadToQueueProvider(chapter: ch));
            }
          }
          ref.read(processDownloadsProvider());
          if (selected.isNotEmpty) {
            _showAfterDownloadSheet(context, selected.length);
          }
        },
      ),
    );
  }

  void _showAfterDownloadSheet(BuildContext context, int count) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
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
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close,
                        color: Colors.white54, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Regardez-le maintenant pendant le téléchargement, sans utilisation de données supplémentaire.',
                style: TextStyle(
                    color: Color(0xFF9E9E9E), fontSize: 13, height: 1.4),
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
                        side: const BorderSide(color: Color(0xFF444444)),
                        padding:
                            const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
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
                        padding:
                            const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
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
      backgroundColor: const Color(0xFF1C1C1C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.refresh, color: Colors.white),
              title: const Text('Actualiser',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                widget.checkForUpdate(true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share, color: Colors.white),
              title: const Text('Partager',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _share(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.download, color: Colors.white),
              title: const Text('Tout télécharger',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
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
  static const _bg = Color(0xFF1C1C1C);
  static const _card = Color(0xFF242424);

  String _selectedQuality = '360P';
  final Set<int> _selected = {};
  bool _selectAll = false;

  final List<String> _qualities = ['360P', '480P', '1080P'];

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
          const Divider(height: 1, color: Color(0xFF2A2A2A)),
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
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(top: 10, bottom: 4),
        decoration: BoxDecoration(
          color: Colors.grey[700],
          borderRadius: BorderRadius.circular(2),
        ),
      );

  Widget _buildHeader() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            const Text(
              'Télécharger',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Icon(Icons.close, color: Colors.white54, size: 22),
            ),
          ],
        ),
      );

  Widget _buildResourcesCard() {
    final source = getSource(
      widget.manga.lang ?? '',
      widget.manga.source ?? '',
      widget.manga.sourceId,
    );
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Ressources',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600),
              ),
              if (source != null) ...[
                const SizedBox(width: 6),
                Text(
                  'via ${source.name}',
                  style:
                      const TextStyle(color: Color(0xFF9E9E9E), fontSize: 12),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _dropdownChip(
                  label: 'French dub', icon: Icons.language_outlined),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF303030),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: sel ? _teal : const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  q,
                  style: TextStyle(
                    color: sel ? Colors.white : Colors.white54,
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
        if (sel) {
          _selected.remove(index);
        } else {
          _selected.add(index);
        }
        _selectAll = _selected.length == widget.chapters.length;
      }),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: sel
                  ? const Icon(Icons.radio_button_checked,
                      color: _teal, size: 22)
                  : const Icon(Icons.radio_button_unchecked,
                      color: Colors.white38, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                chapter.name ?? 'Épisode ${index + 1}',
                style: const TextStyle(
                    color: Colors.white, fontSize: 14),
              ),
            ),
            Text(
              chapter.duration?.isNotEmpty == true
                  ? chapter.duration!
                  : '',
              style: const TextStyle(
                  color: Color(0xFF666666), fontSize: 12),
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
        border: Border(top: BorderSide(color: Color(0xFF2A2A2A))),
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
                    width: 22,
                    height: 22,
                    child: _selectAll
                        ? const Icon(Icons.radio_button_checked,
                            color: _teal, size: 22)
                        : const Icon(Icons.radio_button_unchecked,
                            color: Colors.white38, size: 22),
                  ),
                  const SizedBox(width: 8),
                  const Text('Tout sélectionner',
                      style:
                          TextStyle(color: Colors.white70, fontSize: 14)),
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
                backgroundColor: _teal,
                disabledBackgroundColor: const Color(0xFF2A2A2A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
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
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return ColoredBox(color: color, child: tabBar);
  }

  @override
  bool shouldRebuild(_TabBarDelegate old) =>
      old.tabBar != tabBar || old.color != color;
}
