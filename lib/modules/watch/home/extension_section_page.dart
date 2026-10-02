import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/eval/model/m_manga.dart';
import 'package:watchtower/eval/model/m_pages.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/modules/media/app_ui_components.dart';
import 'package:watchtower/modules/widgets/manga_image_card_widget.dart';
import 'package:watchtower/modules/media/content_cards.dart';
import 'package:watchtower/modules/watch/home/extension_collection_route.dart';
import 'package:watchtower/modules/watch/home/extension_video_preview.dart';
import 'package:watchtower/services/get_custom_list.dart';
import 'package:watchtower/services/get_latest_updates.dart';
import 'package:watchtower/services/get_popular.dart';
import 'package:watchtower/utils/cached_network.dart';

/// Paginated destination for a layout section's "All" action.
class ExtensionSectionPage extends ConsumerStatefulWidget {
  final Source source;
  final String sectionId;
  final String title;
  final String? cardStyle;

  const ExtensionSectionPage({
    required this.source,
    required this.sectionId,
    required this.title,
    this.cardStyle,
    super.key,
  });

  @override
  ConsumerState<ExtensionSectionPage> createState() =>
      _ExtensionSectionPageState();
}

class _ExtensionSectionPageState extends ConsumerState<ExtensionSectionPage> {
  final _scrollController = ScrollController();
  final _items = <MManga>[];
  int _page = 1;
  bool _hasNextPage = true;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients ||
        _scrollController.position.pixels <
            _scrollController.position.maxScrollExtent - 240) {
      return;
    }
    _loadMore();
  }

  Future<MPages?> _fetch(int page) {
    return switch (widget.sectionId) {
      'popular' => ref.read(
        getPopularProvider(source: widget.source, page: page).future,
      ),
      'latest' => ref.read(
        getLatestUpdatesProvider(source: widget.source, page: page).future,
      ),
      _ => ref.read(
        getCustomListProvider(
          source: widget.source,
          listId: widget.sectionId,
          page: page,
        ).future,
      ),
    };
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasNextPage) return;
    setState(() => _loadingMore = true);
    try {
      final nextPage = _page + 1;
      final result = await _fetch(nextPage);
      if (!mounted) return;
      if (result == null || result.list.isEmpty) {
        setState(() {
          _hasNextPage = false;
          _loadingMore = false;
        });
        return;
      }
      final seen = {
        for (final item in _items)
          item.link ?? item.name ?? '${item.hashCode}',
      };
      final nextItems = result.list
          .where(
            (item) => seen.add(item.link ?? item.name ?? '${item.hashCode}'),
          )
          .toList(growable: false);
      setState(() {
        _items.addAll(nextItems);
        _page = nextPage;
        _hasNextPage = result.hasNextPage;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _openItem(MManga item) {
    if (item.link?.isNotEmpty != true) return;
    final collection = ExtensionCollectionRoute.fromItem(item);
    if (collection != null) {
      if (collection.listId.startsWith('playlist_')) {
        _playFirstFromCollection(collection.listId);
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ExtensionSectionPage(
            source: widget.source,
            sectionId: collection.listId,
            title: item.name?.trim().isNotEmpty == true
                ? item.name!.trim()
                : 'Collection',
            cardStyle: collection.listId.startsWith('search_')
                ? 'landscape'
                : null,
          ),
        ),
      );
      return;
    }
    if (widget.source.touchToPreview &&
        item.previewUrl?.trim().isNotEmpty == true) {
      unawaited(
        showExtensionVideoPreview(
          context: context,
          item: item,
          previewUrl: item.previewUrl!.trim(),
          onOpen: () => _openFullVideo(item),
        ),
      );
      return;
    }
    _openFullVideo(item);
  }

  void _openFullVideo(MManga item) {
    pushToMangaReaderDetail(
      ref: ref,
      context: context,
      getManga: item,
      lang: widget.source.lang ?? '',
      source: widget.source.name ?? '',
      sourceId: widget.source.id,
      itemType: widget.source.itemType,
    );
  }

  Future<void> _playFirstFromCollection(String listId) async {
    try {
      final result = await ref.read(
        getCustomListProvider(
          source: widget.source,
          listId: listId,
          page: 1,
        ).future,
      );
      MManga? first;
      for (final item in result?.list ?? const <MManga>[]) {
        if (item.link?.trim().isNotEmpty == true) {
          first = item;
          break;
        }
      }
      if (!mounted) return;
      if (first == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aucune vidéo disponible dans cette playlist.')),
        );
        return;
      }
      _openItem(first);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible de charger la playlist : $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final firstPage = switch (widget.sectionId) {
      'popular' => ref.watch(
        getPopularProvider(source: widget.source, page: 1),
      ),
      'latest' => ref.watch(
        getLatestUpdatesProvider(source: widget.source, page: 1),
      ),
      _ => ref.watch(
        getCustomListProvider(
          source: widget.source,
          listId: widget.sectionId,
          page: 1,
        ),
      ),
    };

    final initialItems = firstPage.value?.list ?? const <MManga>[];
    if (firstPage.hasValue && _items.isEmpty && initialItems.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _items.isNotEmpty) return;
        setState(() {
          _items.addAll(initialItems);
          _hasNextPage = firstPage.value?.hasNextPage ?? false;
        });
      });
    }
    final visibleItems = _items.isEmpty ? initialItems : _items;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B11),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          tooltip: 'Retour',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Broken.arrow_left),
        ),
        title: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: firstPage.when(
        loading: () => visibleItems.isEmpty
            ? const AppMediaGridShimmer()
            : _buildContent(visibleItems),
        error: (error, _) => visibleItems.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Impossible de charger cette section.\n$error',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : _buildContent(visibleItems),
        data: (_) => _buildContent(visibleItems),
      ),
    );
  }

  Widget _buildContent(List<MManga> items) {
    if (items.isEmpty) {
      return const Center(child: Text('Aucun résultat'));
    }
    if (widget.cardStyle != 'tag' &&
        items.every(
          (item) => ExtensionCollectionRoute.fromItem(item) != null,
        )) {
      return ListView(
        padding: EdgeInsets.fromLTRB(
          AppUI.pagePadding(context),
          18,
          AppUI.pagePadding(context),
          110,
        ),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in items)
                ActionChip(
                  onPressed: () => _openItem(item),
                  visualDensity: const VisualDensity(
                    horizontal: -3,
                    vertical: -3,
                  ),
                  backgroundColor: const Color(0xFF1C2529),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.primary.withValues(
                      alpha: .38,
                    ),
                  ),
                  labelStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  label: Text(item.name?.trim().isNotEmpty == true
                      ? item.name!.trim()
                      : 'Browse'),
                ),
            ],
          ),
        ],
      );
    }
    final isTagGrid = widget.cardStyle == 'tag';
    final isLandscapeGrid = widget.cardStyle == 'landscape';
    return GridView.builder(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(
        AppUI.pagePadding(context),
        12,
        AppUI.pagePadding(context),
        110,
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: AppUI.mediaGridColumns(context),
        childAspectRatio: isTagGrid
            ? 2.6
            : isLandscapeGrid
            ? 1.25
            : AppUI.mediaGridChildAspectRatio(context),
        crossAxisSpacing: AppUI.mediaGridCrossAxisSpacing,
        mainAxisSpacing: 16,
      ),
      itemCount: items.length + (_loadingMore ? 1 : 0),
      itemBuilder: (_, index) {
        if (index >= items.length) {
          return const AppShimmerBlock(radius: AppUI.cardRadius);
        }
        final item = items[index];
        if (isTagGrid) {
          return TagCard(
            item: ContentItem.fromManga(item),
            onTap: () => _openItem(item),
          );
        }
        if (isLandscapeGrid) {
          return LandscapeCard(
            item: ContentItem.fromManga(item),
            width: double.infinity,
            onTap: () => _openItem(item),
          );
        }
        return PosterCard(
          item: ContentItem.fromManga(item),
          width: double.infinity,
          onTap: () => _openItem(item),
        );
      },
    );
  }
}
