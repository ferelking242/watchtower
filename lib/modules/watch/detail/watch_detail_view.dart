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

/// Dedicated detail page for watch/video content (films, series).
/// Renders the MovieBox-style UI with banner, metadata, episode buttons,
/// tab bar (Pour vous / Commentaires) and landscape support.
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

  static const _teal = Color(0xFF1DB954);
  static const _bg = Color(0xFF0E0E0E);
  static const _card = Color(0xFF1A1A1A);
  static const _grey = Color(0xFF9E9E9E);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        // ── Banner ──
        SliverAppBar(
          expandedHeight: 230,
          pinned: true,
          backgroundColor: _bg,
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
            background: _buildBanner(),
          ),
        ),

        // ── Metadata + actions + ressources ──
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

  // ─── LANDSCAPE ──────────────────────────────────────────────────────────────

  Widget _buildLandscape(List<Chapter> chapters) {
    return Row(
      children: [
        // Left – thumbnail
        Stack(
          children: [
            SizedBox(width: 280, height: double.infinity, child: _buildBanner()),
            SafeArea(
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),

        // Right – scrollable content
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
              const SizedBox(height: 18),
              _buildRessourcesSection(chapters),
            ],
          ),
        ),
      ],
    );
  }

  // ─── BANNER ─────────────────────────────────────────────────────────────────

  Widget _buildBanner() {
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

    Widget img = manga.customCoverImage != null
        ? Image.memory(
            manga.customCoverImage as Uint8List,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          )
        : cachedNetworkImage(
            headers: headers,
            imageUrl: imgUrl,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
          );

    return Stack(
      fit: StackFit.expand,
      children: [
        img,
        DecoratedBox(
          decoration: const BoxDecoration(
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
      ],
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
              fontSize: 20,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () {}, // future: navigate to full info screen
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
            onTap: () => _downloadAll(chapters),
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

  // ─── RESSOURCES / EPISODES ──────────────────────────────────────────────────

  Widget _buildRessourcesSection(List<Chapter> chapters) {
    final source = getSource(
      widget.manga.lang ?? '',
      widget.manga.source ?? '',
      widget.manga.sourceId,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Ressources',
              style: TextStyle(
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
        if (chapters.isEmpty)
          const Center(
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
          )
        else
          ...chapters.map((ch) => _buildEpisodeTile(ch)),
      ],
    );
  }

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
                // Download button
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
            textAlign: TextAlign.center,
          ),
        ],
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
