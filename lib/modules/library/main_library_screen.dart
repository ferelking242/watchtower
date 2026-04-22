import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/modules/library/library_screen.dart';
import 'package:watchtower/modules/library/widgets/search_text_form_field.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/utils/extensions/build_context_extensions.dart';

class MainLibraryScreen extends ConsumerStatefulWidget {
  const MainLibraryScreen({super.key, this.presetInput, this.initialType});

  final String? presetInput;
  final ItemType? initialType;

  @override
  ConsumerState<MainLibraryScreen> createState() => _MainLibraryScreenState();
}

class _MainLibraryScreenState extends ConsumerState<MainLibraryScreen>
    with TickerProviderStateMixin {
  late final TabController _controller;
  late final TextEditingController _searchController;
  bool _isSearch = false;

  static const _types = [ItemType.anime, ItemType.manga, ItemType.novel];

  @override
  void initState() {
    super.initState();
    final initial = widget.initialType ?? ItemType.anime;
    final initIndex = _types.indexOf(initial).clamp(0, _types.length - 1);
    _controller = TabController(
      length: _types.length,
      vsync: this,
      initialIndex: initIndex,
    );
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
    _searchController = TextEditingController(text: widget.presetInput ?? '');
    if (widget.presetInput != null && widget.presetInput!.isNotEmpty) {
      _isSearch = true;
    }
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchController.dispose();
    super.dispose();
  }

  ItemType get _currentType => _types[_controller.index];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: _isSearch
            ? null
            : Text(
                l10n.library,
                style: TextStyle(color: theme.hintColor),
              ),
        actions: [
          if (_isSearch)
            SeachFormTextField(
              onChanged: (_) => setState(() {}),
              onSuffixPressed: () {
                _searchController.clear();
                setState(() {});
              },
              onPressed: () {
                setState(() {
                  _isSearch = false;
                  _searchController.clear();
                });
              },
              controller: _searchController,
            )
          else ...[
            IconButton(
              tooltip: 'Filter sources',
              splashRadius: 20,
              onPressed: () {
                context.push('/sourceFilter', extra: _currentType);
              },
              icon: Icon(
                Icons.public_rounded,
                color: theme.hintColor,
              ),
            ),
            IconButton(
              tooltip: l10n.search,
              splashRadius: 20,
              onPressed: () => setState(() => _isSearch = true),
              icon: Icon(
                Icons.search_rounded,
                color: theme.hintColor,
              ),
            ),
          ],
        ],
        bottom: TabBar(
          controller: _controller,
          indicatorSize: TabBarIndicatorSize.tab,
          tabAlignment: TabAlignment.fill,
          dividerColor: Colors.transparent,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.hintColor,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.live_tv_outlined, size: 16),
                  const SizedBox(width: 6),
                  Text(l10n.watch),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.auto_stories_outlined, size: 16),
                  const SizedBox(width: 6),
                  Text(l10n.manga),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.local_library_outlined, size: 16),
                  const SizedBox(width: 6),
                  Text(l10n.novel),
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _controller,
        physics: const BouncingScrollPhysics(),
        children: [
          LibraryScreen(
            itemType: ItemType.anime,
            presetInput: null,
            hideOwnAppBar: true,
            externalSearchQuery: _searchController.text,
            key: const ValueKey('anime-lib'),
          ),
          LibraryScreen(
            itemType: ItemType.manga,
            presetInput: null,
            hideOwnAppBar: true,
            externalSearchQuery: _searchController.text,
            key: const ValueKey('manga-lib'),
          ),
          LibraryScreen(
            itemType: ItemType.novel,
            presetInput: null,
            hideOwnAppBar: true,
            externalSearchQuery: _searchController.text,
            key: const ValueKey('novel-lib'),
          ),
        ],
      ),
    );
  }
}
