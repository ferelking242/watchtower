import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:watchtower/modules/home/services/anilist_discovery_service.dart';
import 'package:watchtower/modules/home/widgets/discovery_card.dart';

/// Paginated grid of AniList media filtered by an [AnilistBrowseFilter].
/// Used as the destination of "See all" links and category cards.
class AnilistBrowseScreen extends ConsumerStatefulWidget {
  final AnilistBrowseFilter filter;
  final String title;

  const AnilistBrowseScreen({
    super.key,
    required this.filter,
    required this.title,
  });

  @override
  ConsumerState<AnilistBrowseScreen> createState() =>
      _AnilistBrowseScreenState();
}

class _AnilistBrowseScreenState extends ConsumerState<AnilistBrowseScreen> {
  final ScrollController _scroll = ScrollController();
  final List<AnilistMedia> _items = [];
  int _page = 1;
  bool _hasNext = true;
  bool _loading = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadMore();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    if (pos.pixels > pos.maxScrollExtent - 600 && !_loading && _hasNext) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasNext) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final f = widget.filter.copyWith(page: _page);
      final res = await ref.read(anilistBrowseProvider(f).future);
      if (!mounted) return;
      setState(() {
        _items.addAll(res.items);
        _hasNext = res.hasNextPage;
        _page = res.currentPage + 1;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        elevation: 0,
      ),
      body: _items.isEmpty && _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty && _error != null
              ? _ErrorState(error: _error!, onRetry: _loadMore)
              : RefreshIndicator(
                  onRefresh: () async {
                    setState(() {
                      _items.clear();
                      _page = 1;
                      _hasNext = true;
                    });
                    await _loadMore();
                  },
                  child: GridView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
                    physics: const AlwaysScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 130,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 10,
                      childAspectRatio: 0.55,
                    ),
                    itemCount: _items.length + (_hasNext ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i >= _items.length) {
                        return _error != null
                            ? Center(
                                child: TextButton.icon(
                                  onPressed: _loadMore,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Retry'),
                                ),
                              )
                            : const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                    ),
                                  ),
                                ),
                              );
                      }
                      final m = _items[i];
                      return DiscoveryCard(
                        media: m,
                        width: 130,
                        onTap: () =>
                            context.push('/anilistDetail', extra: m),
                      );
                    },
                  ),
                ),
      backgroundColor: theme.colorScheme.surface,
    );
  }
}

class _ErrorState extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined,
                size: 56, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 14),
            const Text('Could not load AniList browse'),
            const SizedBox(height: 8),
            Text(
              '$error',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
