import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/modules/media/app_ui_components.dart';
import 'package:watchtower/modules/music/collections/routes.dart';
import 'package:watchtower/modules/music/models/metadata/metadata.dart';
import 'package:watchtower/modules/music/provider/audio_player/audio_player.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/browse/sections.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/metadata_plugin_provider.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/search/all.dart';
import 'package:watchtower/modules/music/services/metadata/errors/exceptions.dart';
import 'package:watchtower/modules/music/widgets/music_cached_image.dart';
import 'package:watchtower/ui/widgets/namida_app_bar.dart';
import 'package:watchtower/utils/adaptive_overlay_menu.dart';

// ─── Provider : logo du plugin metadata actif ─────────────────────────────────

final _activePluginLogoProvider = FutureProvider<File?>((ref) async {
  final state = ref.watch(metadataPluginsProvider);
  final pluginConfig = state.asData?.value.defaultMetadataPluginConfig;
  if (pluginConfig == null) return null;
  final notifier = ref.read(metadataPluginsProvider.notifier);
  return notifier.getLogoPath(pluginConfig);
});

// ─── Helpers ──────────────────────────────────────────────────────────────────

String _artistNames(List<SpotubeSimpleArtistObject> artists) =>
    artists.map((a) => a.name).join(', ');

String _fmtDuration(int ms) {
  final total = Duration(milliseconds: ms);
  final m = total.inMinutes;
  final s = total.inSeconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

// ─── Navigation via le navigator global du module music ───────────────────────

void _toAlbum(BuildContext context, SpotubeSimpleAlbumObject album) {
  context.navigateTo(AlbumRoute(id: album.id, album: album));
}

void _toPlaylist(BuildContext context, SpotubeSimplePlaylistObject playlist) {
  context.navigateTo(PlaylistRoute(id: playlist.id, playlist: playlist));
}

void _toArtist(BuildContext context, SpotubeFullArtistObject artist) {
  context.navigateTo(ArtistRoute(artistId: artist.id));
}

void _toBrowseSection(BuildContext context, SpotubeBrowseSectionObject<Object> section) {
  context.navigateTo(HomeBrowseSectionItemsRoute(sectionId: section.id, section: section));
}

// ─── Écran principal ──────────────────────────────────────────────────────────

class MusicSearchScreen extends ConsumerStatefulWidget {
  const MusicSearchScreen({super.key});

  @override
  ConsumerState<MusicSearchScreen> createState() => _MusicSearchScreenState();
}

class _MusicSearchScreenState extends ConsumerState<MusicSearchScreen> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  String _query = '';
  String _selectedChip = 'all';

  // Progress of the header collapse: 0 = fully expanded (search bar visible),
  // 1 = fully collapsed (search bar hidden, replaced by a small icon).
  double _collapseT = 0.0;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      if (mounted) setState(() => _query = _ctrl.text.trim());
    });
    _focus.addListener(() {
      if (mounted) setState(() {});
    });
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _ctrl.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    final maxShrink = _headerHeight(context) - _collapsedHeaderHeight(context);
    final t = maxShrink <= 0
        ? 0.0
        : (_scroll.offset / maxShrink).clamp(0.0, 1.0);
    if ((t - _collapseT).abs() > 0.01) {
      setState(() => _collapseT = t);
    }
  }

  // Expand the header back and focus the search field — used by the
  // collapsed-state search icon so the bar behaves like a real shortcut
  // instead of a dead button.
  void _expandAndFocusSearch() {
    _scroll.animateTo(
      0,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
    Future.delayed(const Duration(milliseconds: 260), () {
      if (mounted) _focus.requestFocus();
    });
  }

  double _headerHeight(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return topPad + 52 + 8 + 48 + 10 + 36 + 24;
  }

  // Height of the header once fully collapsed: just the title row, matching
  // the collapsing-app-bar behavior used on the Manga Discovery screen.
  double _collapsedHeaderHeight(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return topPad + 52 + 12;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: CustomScrollView(
        controller: _scroll,
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverPersistentHeader(
            pinned: true,
            delegate: _StickyHeaderDelegate(
              minHeight: _collapsedHeaderHeight(context),
              maxHeight: _headerHeight(context),
              child: _buildHeader(context),
            ),
          ),
          if (_query.isEmpty) ...[
            _buildMoodsSection(),
            _buildBrowseSection(),
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ] else ...[
            _buildSearchResults(),
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ],
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final t = _collapseT;
    final cs = Theme.of(context).colorScheme;

    return Container(
      color: cs.surface,
      padding: EdgeInsets.only(top: top, left: 16, right: 16, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Ligne avatar + titre — reste toujours visible ; un icône de
          // recherche apparaît ici au fil du scroll, quand la barre de
          // recherche complète disparaît (comme sur Manga Discovery).
          Row(
            children: [
              Opacity(
                opacity: (1 - t * 1.4).clamp(0.0, 1.0),
                child: _PluginAvatar(size: 36),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Opacity(
                  opacity: (1 - t * 1.4).clamp(0.0, 1.0),
                  child: Text(
                    'Rechercher',
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (t > 0.4)
                NamidaAppBarIcon(
                  icon: Broken.search_normal_1,
                  onPressed: _expandAndFocusSearch,
                ),
              NamidaAppBarIcon(
                icon: Broken.camera,
                onPressed: () {},
              ),
            ],
          ),

          // Barre de recherche + pills — s'estompent et se réduisent au scroll
          // pour laisser place à la simple icône de recherche ci-dessus.
          ClipRect(
            child: Align(
              alignment: Alignment.topCenter,
              heightFactor: (1 - t).clamp(0.0, 1.0),
              child: Opacity(
                opacity: (1 - t * 1.6).clamp(0.0, 1.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 10),
                    // Barre de recherche
                    GestureDetector(
                      onTap: () => _focus.requestFocus(),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 46,
                        decoration: BoxDecoration(
                          color: _focus.hasFocus
                              ? cs.surfaceContainer
                              : cs.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(width: 14),
                            Icon(
                              Broken.search_normal_1,
                              size: 20,
                              color: _focus.hasFocus
                                  ? cs.onSurface
                                  : cs.onSurfaceVariant,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _ctrl,
                                focusNode: _focus,
                                textInputAction: TextInputAction.search,
                                style: TextStyle(
                                  color: cs.onSurface,
                                  fontSize: 15,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Que souhaitez-vous écouter ?',
                                  hintStyle: TextStyle(
                                    color: cs.onSurfaceVariant
                                        .withValues(alpha: 0.6),
                                    fontSize: 15,
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                onSubmitted: (_) => _focus.unfocus(),
                              ),
                            ),
                            if (_query.isNotEmpty)
                              GestureDetector(
                                onTap: () {
                                  _ctrl.clear();
                                  _focus.unfocus();
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10),
                                  child: Icon(Broken.close_circle,
                                      size: 18,
                                      color: cs.onSurfaceVariant),
                                ),
                              )
                            else
                              const SizedBox(width: 14),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Bouton filtre — visible uniquement quand une recherche
                    // est active. Ouvre le popup de filtres partagé
                    // (AdaptiveOverlayMenuButton), pas un sheet en bas.
                    if (_query.isNotEmpty)
                      AdaptiveOverlayMenuButton(
                        menuWidth: 210,
                        trigger: _MusicFilterButton(
                          label: _chipLabel(_selectedChip),
                          isActive: _selectedChip != 'all',
                        ),
                        contentBuilder: (close) {
                          final chips = ref
                                  .read(metadataPluginSearchChipsProvider)
                                  .asData
                                  ?.value ??
                              ['all', 'tracks', 'albums', 'artists', 'playlists'];
                          final cs = Theme.of(context).colorScheme;
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (final chip in chips)
                                InkWell(
                                  onTap: () {
                                    setState(() => _selectedChip = chip);
                                    close();
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 11),
                                    child: Row(
                                      children: [
                                        Icon(
                                          _selectedChip == chip
                                              ? Broken.tick_circle
                                              : Broken.record,
                                          size: 18,
                                          color: _selectedChip == chip
                                              ? cs.primary
                                              : cs.onSurfaceVariant
                                                  .withValues(alpha: 0.5),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          _chipLabel(chip),
                                          style: TextStyle(
                                            color: _selectedChip == chip
                                                ? cs.onSurface
                                                : cs.onSurfaceVariant,
                                            fontWeight: _selectedChip == chip
                                                ? FontWeight.w600
                                                : FontWeight.w400,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _chipLabel(String chip) {
    switch (chip) {
      case 'all':
        return 'Tout';
      case 'tracks':
        return 'Titres';
      case 'albums':
        return 'Albums';
      case 'artists':
        return 'Artistes';
      case 'playlists':
        return 'Playlists';
      default:
        return chip[0].toUpperCase() + chip.substring(1);
    }
  }

  // ── Section Moods (sections browse horizontales) ───────────────────────────

  SliverToBoxAdapter _buildMoodsSection() {
    final browseAsync = ref.watch(metadataPluginBrowseSectionsProvider);

    return SliverToBoxAdapter(
      child: browseAsync.when(
        loading: () => SizedBox(
          height: 180,
          child: Center(
            child: CircularProgressIndicator(
              color: Theme.of(context).colorScheme.primary,
              strokeWidth: 2,
            ),
          ),
        ),
        error: (err, _) {
          // Pas de plugin installé → section silencieuse
          if (err is MetadataPluginException) return const SizedBox.shrink();
          return const SizedBox.shrink();
        },
        data: (page) {
          if (page.items.isEmpty) return const SizedBox.shrink();
          final sections = page.items.take(7).toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppSectionHeader(title: 'Découvrez de nouveaux horizons'),
              SizedBox(
                height: 148,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: sections.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (_, i) => _SectionMoodCard(
                    section: sections[i],
                    onTap: () => _toBrowseSection(context, sections[i]),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Section "Tout parcourir" (grille de sections) ─────────────────────────

  SliverToBoxAdapter _buildBrowseSection() {
    final browseAsync = ref.watch(metadataPluginBrowseSectionsProvider);

    return SliverToBoxAdapter(
      child: browseAsync.when(
        loading: () => const SizedBox.shrink(),
        error: (_, _) => const SizedBox.shrink(),
        data: (page) {
          if (page.items.isEmpty) return const SizedBox.shrink();
          final sections = page.items;
          final padding = AppUI.pagePadding(context);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSectionHeader(title: 'Tout parcourir'),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: padding),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: AppUI.mediaGridCrossAxisSpacing,
                    crossAxisSpacing: AppUI.mediaGridCrossAxisSpacing,
                    childAspectRatio: 1.7,
                  ),
                  itemCount: sections.length,
                  itemBuilder: (_, i) => AppGenreTile(
                    label: sections[i].title,
                    icon: Broken.music_library_2,
                    onTap: () => _toBrowseSection(context, sections[i]),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Résultats de recherche ─────────────────────────────────────────────────

  SliverToBoxAdapter _buildSearchResults() {
    final searchAsync =
        ref.watch(metadataPluginSearchAllProvider(_query));

    return SliverToBoxAdapter(
      child: searchAsync.when(
        loading: () => Padding(
          padding: const EdgeInsets.only(top: 60),
          child: Center(
            child: CircularProgressIndicator(
              color: Theme.of(context).colorScheme.primary,
              strokeWidth: 2,
            ),
          ),
        ),
        error: (err, _) {
          if (err is MetadataPluginException &&
              err.errorCode ==
                  MetadataPluginErrorCode.noDefaultMetadataPlugin) {
            return _NoPluginPlaceholder(query: _query);
          }
          return _NoPluginPlaceholder(query: _query);
        },
        data: (results) {
          final showTracks = _selectedChip == 'all' ||
              _selectedChip == 'tracks';
          final showAlbums = _selectedChip == 'all' ||
              _selectedChip == 'albums';
          final showArtists = _selectedChip == 'all' ||
              _selectedChip == 'artists';
          final showPlaylists = _selectedChip == 'all' ||
              _selectedChip == 'playlists';

          final hasAny = results.tracks.isNotEmpty ||
              results.albums.isNotEmpty ||
              results.artists.isNotEmpty ||
              results.playlists.isNotEmpty;

          if (!hasAny) {
            return _EmptyResults(query: _query);
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),

              // ── Titres ─────────────────────────────────────────────────
              if (showTracks && results.tracks.isNotEmpty)
                _TrackResultsSection(
                  tracks: results.tracks,
                  onPlay: (track) {
                    ref
                        .read(audioPlayerProvider.notifier)
                        .load([track], autoPlay: true);
                  },
                ),

              // ── Albums ─────────────────────────────────────────────────
              if (showAlbums && results.albums.isNotEmpty)
                _HorizontalSection<SpotubeSimpleAlbumObject>(
                  title: 'Albums',
                  items: results.albums,
                  imageUrl: (a) => a.images.isEmpty
                      ? ''
                      : a.images.first.url,
                  label: (a) => a.name,
                  sublabel: (a) =>
                      _artistNames(a.artists),
                  onTap: (a) => _toAlbum(context, a),
                ),

              // ── Artistes ───────────────────────────────────────────────
              if (showArtists && results.artists.isNotEmpty)
                _HorizontalSection<SpotubeFullArtistObject>(
                  title: 'Artistes',
                  items: results.artists,
                  imageUrl: (a) => a.images.isEmpty
                      ? ''
                      : a.images.first.url,
                  label: (a) => a.name,
                  sublabel: (a) => 'Artiste',
                  onTap: (a) => _toArtist(context, a),
                  circular: true,
                ),

              // ── Playlists ──────────────────────────────────────────────
              if (showPlaylists && results.playlists.isNotEmpty)
                _HorizontalSection<SpotubeSimplePlaylistObject>(
                  title: 'Playlists',
                  items: results.playlists,
                  imageUrl: (p) => p.images.isEmpty
                      ? ''
                      : p.images.first.url,
                  label: (p) => p.name,
                  sublabel: (p) => p.owner.name,
                  onTap: (p) => _toPlaylist(context, p),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Section titres (liste verticale) ────────────────────────────────────────

class _TrackResultsSection extends ConsumerWidget {
  final List<SpotubeFullTrackObject> tracks;
  final void Function(SpotubeFullTrackObject) onPlay;

  const _TrackResultsSection({
    required this.tracks,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlist = ref.watch(audioPlayerProvider);
    final activeId = playlist.activeTrack?.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppSectionHeader(title: 'Titres'),
        ...tracks.take(5).map((track) {
          final isActive = track.id == activeId;
          final cs = Theme.of(context).colorScheme;
          final imageUrl = track.album.images.isEmpty
              ? ''
              : track.album.images.first.url;
          return Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: () => onPlay(track),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    // Artwork
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: MusicCachedImage(
                        url: imageUrl,
                        width: 46,
                        height: 46,
                        placeholder: Icon(Broken.note,
                            color: cs.onSurfaceVariant),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Titre + artistes
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            track.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isActive ? cs.primary : cs.onSurface,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              if (track.explicit)
                                Container(
                                  margin: const EdgeInsets.only(right: 4),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 3, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: cs.onSurface.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: Text('E',
                                      style: TextStyle(
                                          color: cs.onSurface,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800)),
                                ),
                              Flexible(
                                child: Text(
                                  _artistNames(track.artists),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: cs.onSurfaceVariant,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Durée
                    Text(
                      _fmtDuration(track.durationMs),
                      style: TextStyle(
                        color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // More
                    Icon(Broken.more_2,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
                  ],
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ─── Section horizontale générique (albums / artistes / playlists) ────────────

class _HorizontalSection<T> extends StatelessWidget {
  final String title;
  final List<T> items;
  final String Function(T) imageUrl;
  final String Function(T) label;
  final String Function(T) sublabel;
  final void Function(T) onTap;
  final bool circular;

  const _HorizontalSection({
    required this.title,
    required this.items,
    required this.imageUrl,
    required this.label,
    required this.sublabel,
    required this.onTap,
    this.circular = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(title: title),
        SizedBox(
          height: 190,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final item = items[i];
              final url = imageUrl(item);
              final cs = Theme.of(context).colorScheme;
              return GestureDetector(
                onTap: () => onTap(item),
                child: SizedBox(
                  width: 130,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      circular
                          ? CircleAvatar(
                              radius: 65,
                              backgroundColor: cs.surfaceContainerHigh,
                              child: ClipOval(
                                child: MusicCachedImage(
                                  url: url,
                                  width: 130,
                                  height: 130,
                                  placeholder: Icon(
                                      Broken.user,
                                      color: cs.onSurfaceVariant),
                                ),
                              ),
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: MusicCachedImage(
                                url: url,
                                width: 130,
                                height: 130,
                                placeholder: Icon(Broken.music_square,
                                    color: cs.onSurfaceVariant),
                              ),
                            ),
                      const SizedBox(height: 8),
                      Text(
                        label(item),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        sublabel(item),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],
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

// ─── Carte mood (section browse en mode horizontal) ───────────────────────────

class _SectionMoodCard extends StatelessWidget {
  final SpotubeBrowseSectionObject<Object> section;
  final VoidCallback onTap;

  const _SectionMoodCard({
    required this.section,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppUI.cardRadius + 3),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 148,
          height: 148,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Thème neutre : le dégradé vient des couleurs de surface de
              // Watchtower, jamais d'une palette propre à l'ancienne app.
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      cs.primaryContainer.withValues(alpha: 0.55),
                      cs.surfaceContainerHighest,
                    ],
                  ),
                ),
              ),
              // Dégradé bas pour garder le titre lisible sur n'importe quel
              // fond de thème.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xE6000000)],
                  ),
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        section.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          shadows: [
                            Shadow(color: Colors.black, blurRadius: 6),
                          ],
                        ),
                      ),
                    ),
                    const Icon(
                      Broken.arrow_right_3,
                      size: 18,
                      color: Colors.white70,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Placeholder "aucun plugin" ───────────────────────────────────────────────

class _NoPluginPlaceholder extends StatelessWidget {
  final String query;
  const _NoPluginPlaceholder({required this.query});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 48, 32, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Broken.element_plus,
              size: 56, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.18)),
          const SizedBox(height: 16),
          Text(
            'Aucune extension music installée',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Installe une extension depuis le\nMarketplace pour chercher "$query"',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.primary,
              side: BorderSide(color: Theme.of(context).colorScheme.outline),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            onPressed: () => GoRouter.of(rootNavigatorKey.currentContext!).push('/marketplace'),
            icon: const Icon(Broken.shop),
            label: const Text('Marketplace'),
          ),
        ],
      ),
    );
  }
}

// ─── Placeholder "aucun résultat" ─────────────────────────────────────────────

class _EmptyResults extends StatelessWidget {
  final String query;
  const _EmptyResults({required this.query});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 48, 32, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Broken.search_zoom_in,
              size: 56, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.18)),
          const SizedBox(height: 16),
          Text(
            'Aucun résultat pour\n"$query"',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Avatar du plugin actif ───────────────────────────────────────────────────

class _PluginAvatar extends ConsumerWidget {
  final double size;
  const _PluginAvatar({required this.size});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logoAsync = ref.watch(_activePluginLogoProvider);
    final pluginState = ref.watch(metadataPluginsProvider);
    final pluginName =
        pluginState.asData?.value.defaultMetadataPluginConfig?.name ?? '';
    final initials = pluginName.isNotEmpty
        ? pluginName
            .split(RegExp(r'[\s\-_]+'))
            .where((w) => w.isNotEmpty)
            .take(2)
            .map((w) => w[0].toUpperCase())
            .join()
        : '♪';

    return logoAsync.when(
      data: (file) {
        if (file != null && file.existsSync()) {
          return CircleAvatar(
            radius: size / 2,
            backgroundImage: FileImage(file),
            backgroundColor: Colors.transparent,
          );
        }
        return _InitialsAvatar(initials: initials, size: size);
      },
      loading: () => _InitialsAvatar(initials: initials, size: size),
      error: (_, _) => _InitialsAvatar(initials: initials, size: size),
    );
  }
}

class _InitialsAvatar extends StatelessWidget {
  final String initials;
  final double size;
  const _InitialsAvatar({required this.initials, required this.size});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      child: Text(
        initials,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.38,
        ),
      ),
    );
  }
}

// ─── Bouton "Filtrer" (déclencheur du popup de filtres) ───────────────────────

class _MusicFilterButton extends StatelessWidget {
  final String label;
  final bool isActive;

  const _MusicFilterButton({
    required this.label,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: isActive
            ? cs.primaryContainer.withValues(alpha: 0.5)
            : cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive ? cs.primary : cs.outlineVariant,
          width: isActive ? 1.2 : 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isActive ? cs.primary : cs.onSurfaceVariant,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 6),
          Icon(Broken.filter,
              size: 16,
              color: isActive ? cs.primary : cs.onSurfaceVariant),
        ],
      ),
    );
  }
}

// ─── Sticky header delegate ───────────────────────────────────────────────────

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double minHeight;
  final double maxHeight;
  final Widget child;
  const _StickyHeaderDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.child,
  });

  @override
  double get minExtent => minHeight;
  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(
          BuildContext context, double shrinkOffset, bool overlapsContent) =>
      ClipRect(child: child);

  @override
  bool shouldRebuild(_StickyHeaderDelegate old) =>
      old.minHeight != minHeight ||
      old.maxHeight != maxHeight ||
      old.child != child;
}
