import 'package:flutter/material.dart';
import '../data/catalog.dart';
import 'detail_screen.dart';
import 'discover_screen.dart';
import 'person_screen.dart';
import 'profile_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';

class MigShell extends StatefulWidget {
  const MigShell({super.key});

  @override
  State<MigShell> createState() => _MigShellState();
}

class _MigShellState extends State<MigShell> {
  int _index = 0;

  void _open(MediaItem item) => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DetailScreen(
            item: item,
            onPerson: (name) => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => PersonScreen(name: name)),
            ),
          ),
        ),
      );

  void _openSection(String section) {
    if (section == 'theme') {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Theme preference is local to this preview.')));
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(section,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Text(
              section == 'Server status'
                  ? 'UI check ready · backend intentionally not connected.'
                  : section == 'Check for updates'
                      ? 'Update screen ready · no downloader or remote service attached.'
                      : 'Watchtower UI migration preview · no ads, Firebase or player.',
              style: const TextStyle(height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DiscoverScreen(onOpen: _open),
      SearchScreen(onOpen: _open),
      ProfileScreen(onSection: _openSection),
      SettingsScreen(onSection: _openSection),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.explore_outlined), label: 'Discover'),
          NavigationDestination(
              icon: Icon(Icons.search), label: 'Search'),
          NavigationDestination(
              icon: Icon(Icons.person_outline), label: 'Profile'),
          NavigationDestination(
              icon: Icon(Icons.settings_outlined), label: 'Settings'),
        ],
      ),
    );
  }
}