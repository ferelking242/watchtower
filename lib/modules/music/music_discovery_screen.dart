import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/modules/home/widgets/library_header_bar.dart';
import 'package:watchtower/modules/music/pages/music_home_tab.dart';
import 'package:watchtower/modules/music/pages/library/music_playlists_tab.dart';
import 'package:watchtower/modules/music/pages/library/music_artists_tab.dart';
import 'package:watchtower/modules/music/pages/library/music_albums_tab.dart';
import 'package:watchtower/modules/music/providers/music_player_provider.dart';
import 'package:watchtower/modules/music/pages/music_player_sheet.dart';
import 'package:watchtower/modules/music/pages/search/music_search_tab.dart';

/// Music section root — equivalent of Spotube's HomePage + LibraryPage combined.
///
/// Tabs (matching Spotube's navigation):
///   0 = Home       — featured / new releases / browse categories
///   1 = Search     — search field + chip filters (All/Tracks/Albums/Artists/Playlists)
///   2 = Playlists  — liked songs + user playlists
///   3 = Artists    — followed artists grid
///   4 = Albums     — saved albums list
class MusicDiscoveryScreen extends ConsumerStatefulWidget {
  const MusicDiscoveryScreen({super.key});

  @override
  ConsumerState<MusicDiscoveryScreen> createState() =>
      _MusicDiscoveryScreenState();
}

class _MusicDiscoveryScreenState extends ConsumerState<MusicDiscoveryScreen>
    with SingleTickerProviderStateMixin {
  static const _tabs = [
    (label: 'Home', icon: Icons.home_rounded),
    (label: 'Search', icon: Icons.search_rounded),
    (label: 'Playlists', icon: Icons.queue_music_rounded),
    (label: 'Artists', icon: Icons.person_rounded),
    (label: 'Albums', icon: Icons.album_rounded),
  ];

  late final TabController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TabController(length: _tabs.length, vsync: this);
    _ctrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final state = ref.watch(musicPlayerProvider);
    final hasTrack = state.activeTrack != null;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const LibraryHeaderBar(itemType: ItemType.music),
            _MusicTabBar(controller: _ctrl, tabs: _tabs),
            Expanded(
              child: TabBarView(
                controller: _ctrl,
                children: const [
                  MusicHomeTab(),
                  MusicSearchTab(),
                  MusicPlaylistsTab(),
                  MusicArtistsTab(),
                  MusicAlbumsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: hasTrack
          ? _NowPlayingFab(
              trackName: state.activeTrack!.name,
              artistName: state.activeTrack!.artistNames,
              imageUrl: state.activeTrack!.imageUrl,
              isPlaying: state.isPlaying,
              onTap: () => MusicPlayerSheet.show(context),
              onPlayPause: () =>
                  ref.read(musicPlayerProvider.notifier).playPause(),
            )
          : null,
    );
  }
}

// ─── Tab bar ──────────────────────────────────────────────────────────────────

class _MusicTabBar extends StatelessWidget {
  final TabController controller;
  final List<({String label, IconData icon})> tabs;

  const _MusicTabBar({required this.controller, required this.tabs});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      height: 44,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: cs.onSurface.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
      ),
      child: TabBar(
        controller: controller,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: cs.primary, width: 2.5),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
          insets: const EdgeInsets.symmetric(horizontal: 12),
        ),
        labelColor: cs.primary,
        unselectedLabelColor: cs.onSurface.withValues(alpha: 0.55),
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
        unselectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w500, fontSize: 13.5),
        dividerColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        tabs: tabs
            .map((t) => Tab(
                  height: 40,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(t.icon, size: 16),
                      const SizedBox(width: 6),
                      Text(t.label),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }
}

// ─── Now Playing FAB ─────────────────────────────────────────────────────────

class _NowPlayingFab extends StatelessWidget {
  final String trackName;
  final String artistName;
  final String imageUrl;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback onPlayPause;

  const _NowPlayingFab({
    required this.trackName,
    required this.artistName,
    required this.imageUrl,
    required this.isPlaying,
    required this.onTap,
    required this.onPlayPause,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: cs.primaryContainer,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: cs.primary.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: imageUrl.isEmpty
                  ? Container(
                      width: 48,
                      height: 48,
                      color: cs.primary.withValues(alpha: 0.2),
                      child: Icon(Icons.music_note_rounded,
                          color: cs.primary, size: 22),
                    )
                  : Image.network(
                      imageUrl,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 48,
                        height: 48,
                        color: cs.primary.withValues(alpha: 0.2),
                        child: Icon(Icons.music_note_rounded,
                            color: cs.primary, size: 22),
                      ),
                    ),
            ),
            const SizedBox(width: 10),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trackName,
                  style: TextStyle(
                    color: cs.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  artistName,
                  style: TextStyle(
                    color: cs.onPrimaryContainer.withValues(alpha: 0.7),
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: onPlayPause,
              child: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: cs.onPrimaryContainer,
                size: 28,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
