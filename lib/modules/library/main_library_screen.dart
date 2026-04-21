import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/modules/library/library_screen.dart';
import 'package:watchtower/utils/extensions/build_context_extensions.dart';

class MainLibraryScreen extends ConsumerStatefulWidget {
  const MainLibraryScreen({super.key, this.presetInput, this.initialType});

  final String? presetInput;
  final ItemType? initialType;

  @override
  ConsumerState<MainLibraryScreen> createState() => _MainLibraryScreenState();
}

class _MainLibraryScreenState extends ConsumerState<MainLibraryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _controller;

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
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Scaffold(
      body: Column(
        children: [
          Material(
            color: theme.colorScheme.surface,
            elevation: 0,
            child: SafeArea(
              bottom: false,
              child: TabBar(
                controller: _controller,
                tabs: [
                  Tab(icon: const Icon(Icons.video_collection_outlined), text: l10n.watch),
                  Tab(icon: const Icon(Icons.collections_bookmark_outlined), text: l10n.manga),
                  Tab(icon: const Icon(Icons.local_library_outlined), text: l10n.novel),
                ],
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _controller,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                LibraryScreen(itemType: ItemType.anime, presetInput: widget.presetInput),
                LibraryScreen(itemType: ItemType.manga, presetInput: widget.presetInput),
                LibraryScreen(itemType: ItemType.novel, presetInput: widget.presetInput),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
