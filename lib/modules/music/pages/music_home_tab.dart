import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/modules/music/models/music_models.dart';
import 'package:watchtower/modules/music/providers/music_player_provider.dart';
import 'package:watchtower/modules/music/widgets/music_playbutton_card.dart';
import 'package:watchtower/modules/music/widgets/music_cached_image.dart';

// ─── Demo data provider (replace with real Spotify/extension calls) ───────────

final musicHomeFeaturedProvider = Provider<List<MusicPlaylist>>((ref) => [
      MusicPlaylist(
        id: 'featured_1',
        name: 'Today\'s Top Hits',
        description: 'The hottest tracks right now',
        images: [
          const MusicImage(
              url: 'https://i.scdn.co/image/ab67706f00000003b7b4e9e058c1c0ae4b39e1f0')
        ],
        trackCount: 50,
      ),
      MusicPlaylist(
        id: 'featured_2',
        name: 'Chill Hits',
        description: 'Kick back to the best new and recent chill hits',
        images: [
          const MusicImage(
              url: 'https://i.scdn.co/image/ab67706f000000034a592b784fa9c44dd0ddca0d')
        ],
        trackCount: 40,
      ),
      MusicPlaylist(
        id: 'featured_3',
        name: 'Rap Caviar',
        description: 'Music that defines what\'s happening in rap right now',
        images: [
          const MusicImage(
              url: 'https://i.scdn.co/image/ab67706f00000003652d6ae2e0b3b88a92e7ae72')
        ],
        trackCount: 50,
      ),
    ]);

// ─── Home tab — mirrors Spotube HomePage sections ─────────────────────────────

class MusicHomeTab extends ConsumerWidget {
  const MusicHomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final featured = ref.watch(musicHomeFeaturedProvider);
    final recentlyPlayed = ref.watch(musicRecentlyPlayedProvider);
    final queue = ref.watch(musicPlayerProvider).queue;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 8)),

        // ── Recently Played (Spotube: HomeRecentlyPlayedSection) ──────────
        if (recentlyPlayed.isNotEmpty)
          SliverToBoxAdapter(
            child: MusicHorizontalCardRow(
              title: 'Recently Played',
              cards: recentlyPlayed
                  .map((t) => MusicPlaybuttonCard(
                        imageUrl: t.imageUrl,
                        title: t.name,
                        subtitle: t.artistNames,
                        size: 130,
                        onTap: () {},
                        onPlay: () =>
                            ref.read(musicPlayerProvider.notifier).playQueue(
                          [t],
                        ),
                      ))
                  .toList(),
            ),
          ),

        // ── Featured playlists (Spotube: HomeFeaturedSection) ─────────────
        SliverToBoxAdapter(
          child: MusicHorizontalCardRow(
            title: 'Featured Playlists',
            cards: featured
                .map((p) => MusicPlaybuttonCard(
                      imageUrl: p.imageUrl,
                      title: p.name,
                      subtitle: '${p.trackCount ?? 0} tracks',
                      size: 150,
                      onTap: () {},
                      onPlay: () {},
                    ))
                .toList(),
          ),
        ),

        // ── New releases (Spotube: HomeNewReleasesSection) ────────────────
        SliverToBoxAdapter(
          child: _NewReleasesSection(),
        ),

        // ── Browse categories (Spotube: HomePageBrowseSection) ────────────
        SliverToBoxAdapter(
          child: _BrowseCategoriesSection(),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }
}

// ── New Releases ──────────────────────────────────────────────────────────────

class _NewReleasesSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final items = _demoAlbums;
    return MusicHorizontalCardRow(
      title: 'New Releases',
      cards: items
          .map((a) => MusicPlaybuttonCard(
                imageUrl: a.imageUrl,
                title: a.name,
                subtitle: a.artistNames,
                size: 140,
                onTap: () {},
                onPlay: () {},
              ))
          .toList(),
    );
  }

  static final _demoAlbums = [
    MusicAlbum(
      id: 'a1',
      name: 'Midnight Rain',
      artists: [const MusicArtist(id: 'ts', name: 'Taylor Swift')],
      images: [
        const MusicImage(
            url: 'https://i.scdn.co/image/ab67616d0000b2732b56b7dc7a3ae34ef4e54dbe')
      ],
    ),
    MusicAlbum(
      id: 'a2',
      name: 'SOS',
      artists: [const MusicArtist(id: 'sza', name: 'SZA')],
      images: [
        const MusicImage(
            url: 'https://i.scdn.co/image/ab67616d0000b273be0f7ccde44e68d8b20d7636')
      ],
    ),
    MusicAlbum(
      id: 'a3',
      name: 'One Thing at a Time',
      artists: [const MusicArtist(id: 'mw', name: 'Morgan Wallen')],
      images: [
        const MusicImage(
            url: 'https://i.scdn.co/image/ab67616d0000b273f08bfdb6dc5826cb41a43b2a')
      ],
    ),
    MusicAlbum(
      id: 'a4',
      name: 'Utopia',
      artists: [const MusicArtist(id: 'tp', name: 'Travis Scott')],
      images: [
        const MusicImage(
            url: 'https://i.scdn.co/image/ab67616d0000b2732c29dd1e1ba43285e3432756')
      ],
    ),
  ];
}

// ── Browse Categories ─────────────────────────────────────────────────────────

class _BrowseCategoriesSection extends StatelessWidget {
  static const _categories = [
    ('Pop', Color(0xFF8D67AB)),
    ('Hip-Hop', Color(0xFFBA5D07)),
    ('Rock', Color(0xFFE8115B)),
    ('Electronic', Color(0xFF1E3264)),
    ('R&B', Color(0xFF056952)),
    ('Jazz', Color(0xFF0D73EC)),
    ('Classical', Color(0xFF537AA1)),
    ('Podcasts', Color(0xFF8C1932)),
    ('Anime', Color(0xFFE51D35)),
    ('Gaming', Color(0xFF1DB954)),
  ];

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Text(
            'Browse All',
            style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.8,
            ),
            itemCount: _categories.length,
            itemBuilder: (_, i) {
              final (name, color) = _categories[i];
              return Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.centerLeft,
                child: Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── Recently played provider ─────────────────────────────────────────────────

class _RecentlyPlayedNotifier extends Notifier<List<MusicTrack>> {
  @override
  List<MusicTrack> build() => [];
}

final musicRecentlyPlayedProvider =
    NotifierProvider<_RecentlyPlayedNotifier, List<MusicTrack>>(
  _RecentlyPlayedNotifier.new,
);
