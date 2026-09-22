import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/eval/model/m_manga.dart';
import 'package:watchtower/eval/model/m_pages.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/modules/widgets/manga_image_card_widget.dart';
import 'package:watchtower/services/get_custom_list.dart';
import 'package:watchtower/services/get_latest_updates.dart';
import 'package:watchtower/services/get_popular.dart';
import 'package:watchtower/utils/cached_network.dart';

/// Paginated destination for a layout section's "All" action.
class ExtensionSectionPage extends ConsumerStatefulWidget {
  final Source source;
  final String sectionId;
  final String title;

  const ExtensionSectionPage({
    required this.source,
    required this.sectionId,
    required this.title,
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
      setState(() {
        _items.addAll(result.list);
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
            ? const Center(child: CircularProgressIndicator())
            : _buildGrid(visibleItems),
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
            : _buildGrid(visibleItems),
        data: (_) => _buildGrid(visibleItems),
      ),
    );
  }

  Widget _buildGrid(List<MManga> items) {
    if (items.isEmpty) {
      return const Center(child: Text('Aucun résultat'));
    }
    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
      itemCount: items.length + (_loadingMore ? 1 : 0),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 150,
        childAspectRatio: .56,
        crossAxisSpacing: 12,
        mainAxisSpacing: 16,
      ),
      itemBuilder: (_, index) {
        if (index >= items.length) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        return _ExtensionSectionCard(
          item: items[index],
          onTap: () => _openItem(items[index]),
        );
      },
    );
  }
}

class _ExtensionSectionCard extends StatelessWidget {
  final MManga item;
  final VoidCallback onTap;

  const _ExtensionSectionCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: item.link?.isNotEmpty == true ? onTap : null,
      borderRadius: BorderRadius.circular(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: item.imageUrl?.isNotEmpty == true
                  ? cachedNetworkImage(
                      imageUrl: item.imageUrl!,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                    )
                  : const ColoredBox(
                      color: Color(0xFF22242C),
                      child: Center(
                        child: Icon(Broken.video, color: Colors.white54),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.name ?? 'Sans titre',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
