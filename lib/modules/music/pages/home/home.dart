import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/modules/main_view/providers/side_drawer_provider.dart';
import 'package:watchtower/modules/main_view/widgets/namida_inner_drawer.dart';
import 'package:watchtower/modules/music/collections/routes.gr.dart';
import 'package:watchtower/modules/music/components/image/universal_image.dart';
import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:watchtower/modules/music/models/metadata/metadata.dart';
import 'package:watchtower/modules/music/modules/home/home_filter_bar.dart';
import 'package:watchtower/modules/music/modules/home/home_shelves.dart';
import 'package:watchtower/modules/music/modules/root/sidebar/music_home_drawer.dart';
import 'package:watchtower/modules/music/provider/history/top.dart';
import 'package:watchtower/modules/music/provider/history/top/albums.dart';
import 'package:watchtower/modules/music/provider/history/top/tracks.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/album/releases.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/browse/sections.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/core/auth.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/core/user.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/library/artists.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/library/playlists.dart';

/// Music hub home: a Spotify-style discovery page built on the hub's own
/// providers (account releases, playback history, saved playlists, browse
/// sections) and on the shared Watchtower card/header language.
///
/// The account drawer is the Namida inner drawer already used by Discovery;
/// devices live there instead of the old app-bar button.
class HomePage extends ConsumerStatefulWidget {
  static const name = "home";
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final _drawerKey = GlobalKey<NamidaInnerDrawerState>();

  MusicHomeFilter _filter = MusicHomeFilter.all;
  bool _musicGroupExpanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(sideDrawerCloseProvider.notifier)
          .set(() => _drawerKey.currentState?.close());
    });
  }

  @override
  void dispose() {
    ref.read(sideDrawerOpenProvider.notifier).set(false);
    super.dispose();
  }

  void _selectFilter(MusicHomeFilter filter) {
    if (filter == _filter) return;
    setState(() {
      _filter = filter;
      _musicGroupExpanded = filter != MusicHomeFilter.all;
    });
  }

  Future<void> _refresh() async {
    ref.invalidate(metadataPluginAlbumReleasesProvider);
    ref.invalidate(metadataPluginSavedArtistsProvider);
    ref.invalidate(metadataPluginSavedPlaylistsProvider);
    ref.invalidate(metadataPluginBrowseSectionsProvider);
    ref.invalidate(historyTopTracksProvider(HistoryDuration.days30));
    ref.invalidate(historyTopAlbumsProvider(HistoryDuration.days30));
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }

  void _toggleDrawer() {
    _drawerKey.currentState?.toggle();
    ref
        .read(sideDrawerOpenProvider.notifier)
        .set(_drawerKey.currentState?.isOpened ?? false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final authenticated =
        ref.watch(metadataPluginAuthenticatedProvider).asData?.value == true;

    return NamidaInnerDrawer(
      key: _drawerKey,
      maxPercentage: 0.84,
      borderRadius: 24,
      onOpenChanged: (open) =>
          ref.read(sideDrawerOpenProvider.notifier).set(open),
      drawerChild: MusicHomeDrawer(
        onClose: () {
          _drawerKey.currentState?.close();
          ref.read(sideDrawerOpenProvider.notifier).set(false);
        },
      ),
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: RefreshIndicator.adaptive(
          onRefresh: _refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _HomeHeader(
                  filter: _filter,
                  musicGroupExpanded: _musicGroupExpanded,
                  onFilterSelected: _selectFilter,
                  onOpenDrawer: _toggleDrawer,
                ),
              ),
              ..._buildShelves(authenticated: authenticated),
              SliverToBoxAdapter(
                child: SizedBox(height: bottomInset + 28),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildShelves({required bool authenticated}) {
    final following = _filter == MusicHomeFilter.following;
    final personal = _filter != MusicHomeFilter.music;

    if (!authenticated) {
      return const [
        SliverToBoxAdapter(child: _SignInCard()),
        SliverToBoxAdapter(child: HomeQuickAccessGrid()),
        SliverToBoxAdapter(child: HomeGenresRail()),
      ];
    }

    return [
      // Shortcuts come first: they never wait on a plugin round-trip, so the
      // page has usable content the instant it opens.
      const SliverToBoxAdapter(child: HomeQuickAccessGrid()),
      SliverToBoxAdapter(
        child: HomeLatestReleasesRail(followingOnly: following),
      ),
      if (following) ...[
        const SliverToBoxAdapter(child: HomeFollowedArtistsRail()),
        const SliverToBoxAdapter(child: HomeContinueRail()),
        const SliverToBoxAdapter(child: HomePopularArtistsRail()),
      ] else ...[
        const SliverToBoxAdapter(child: HomeContinueRail()),
        if (personal) const SliverToBoxAdapter(child: HomeQuickPicksRail()),
        // Every shelf the plugin advertises, each with its own "browse all".
        const SliverToBoxAdapter(child: HomePluginBrowseRails()),
        const SliverToBoxAdapter(child: HomePopularArtistsRail()),
        const SliverToBoxAdapter(child: HomePopularAlbumsRail()),
        const SliverToBoxAdapter(child: HomePlaylistsRail()),
        const SliverToBoxAdapter(child: HomeGenresRail()),
      ],
    ];
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _HomeHeader extends ConsumerWidget {
  final MusicHomeFilter filter;
  final bool musicGroupExpanded;
  final ValueChanged<MusicHomeFilter> onFilterSelected;
  final VoidCallback onOpenDrawer;

  const _HomeHeader({
    required this.filter,
    required this.musicGroupExpanded,
    required this.onFilterSelected,
    required this.onOpenDrawer,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final authenticated =
        ref.watch(metadataPluginAuthenticatedProvider).asData?.value == true;
    final user = ref.watch(metadataPluginUserProvider).asData?.value;
    final avatar = authenticated
        ? user?.images.asUrlString(
            index: 0,
            placeholder: ImagePlaceholder.artist,
          )
        : null;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            cs.primary.withValues(alpha: 0.18),
            cs.primary.withValues(alpha: 0),
          ],
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.paddingOf(context).top + 10,
        8,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _AvatarButton(image: avatar, onTap: onOpenDrawer),
              const SizedBox(width: 12),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  child: MusicFilterBar(
                    filter: filter,
                    expanded: musicGroupExpanded,
                    onSelected: onFilterSelected,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.music,
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.2,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  context.l10n.discover_new_horizons,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarButton extends StatelessWidget {
  final String? image;
  final VoidCallback onTap;

  const _AvatarButton({required this.image, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: cs.primaryContainer,
          border: Border.all(
            color: cs.onSurface.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
        child: ClipOval(
          child: image != null
              ? UniversalImage(path: image!, fit: BoxFit.cover)
              : Icon(Broken.user, size: 22, color: cs.onPrimaryContainer),
        ),
      ),
    );
  }
}


class _SignInCard extends StatelessWidget {
  const _SignInCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.alphaBlend(
                cs.primary.withValues(alpha: 0.28),
                cs.surfaceContainerHigh,
              ),
              cs.surfaceContainerHigh,
            ],
          ),
          border: Border.all(color: cs.primary.withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: cs.primary.withValues(alpha: 0.18),
                  ),
                  child: Icon(Broken.musicnote, size: 22, color: cs.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.l10n.music,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              context.l10n.login_to_your_music_account,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () =>
                  context.navigateTo(const SettingsMetadataProviderRoute()),
              icon: const Icon(Broken.login, size: 18),
              label: Text(context.l10n.login),
              style: FilledButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
