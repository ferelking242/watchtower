import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/modules/more/settings/browse/source_repositories.dart';
import 'package:watchtower/providers/l10n_providers.dart';

/// Unified screen that shows repo management tabs for Watch / Manga / Novel / Game / Music.
class ExtensionRepositoriesScreen extends ConsumerStatefulWidget {
  const ExtensionRepositoriesScreen({super.key});

  @override
  ConsumerState<ExtensionRepositoriesScreen> createState() =>
      _ExtensionRepositoriesScreenState();
}

class _ExtensionRepositoriesScreenState
    extends ConsumerState<ExtensionRepositoriesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = l10nLocalizations(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.extensions),
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(icon: Icon(Icons.live_tv_outlined), text: 'Watch'),
            Tab(icon: Icon(Icons.auto_stories_outlined), text: 'Manga'),
            Tab(icon: Icon(Icons.text_snippet_outlined), text: 'Novel'),
            Tab(icon: Icon(Icons.videogame_asset_outlined), text: 'Game'),
            Tab(icon: Icon(Icons.music_note_outlined), text: 'Music'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          _RepoTab(itemType: ItemType.anime),
          _RepoTab(itemType: ItemType.manga),
          _RepoTab(itemType: ItemType.novel),
          _RepoTab(itemType: ItemType.game),
          _RepoTab(itemType: ItemType.music),
        ],
      ),
    );
  }
}

/// A thin wrapper so each tab hosts a SourceRepositories widget
/// without a duplicate AppBar.
class _RepoTab extends StatelessWidget {
  final ItemType itemType;
  const _RepoTab({required this.itemType});

  @override
  Widget build(BuildContext context) {
    return SourceRepositoriesBody(itemType: itemType);
  }
}
