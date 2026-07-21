import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/modules/music/collections/routes.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/modules/music/collections/routes.gr.dart';
import 'package:watchtower/modules/music/models/metadata/metadata.dart';
import 'package:watchtower/modules/music/provider/audio_player/audio_player.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/browse/sections.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/metadata_plugin_provider.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/search/all.dart';
import 'package:watchtower/modules/music/services/metadata/errors/exceptions.dart';
import 'package:watchtower/modules/music/widgets/music_cached_image.dart';

// ─── Provider : logo du plugin metadata actif ─────────────────────────────────

final _activePluginLogoProvider = FutureProvider<File?>((ref) async {
  final state = ref.watch(metadataPluginsProvider);
  final pluginConfig = state.asData?.value.defaultMetadataPluginConfig;
  if (pluginConfig == null) return null;
  final notifier = ref.read(metadataPluginsProvider.notifier);
  return notifier.getLogoPath(pluginConfig);
});

// ─── Constantes design ────────────────────────────────────────────────────────

// _kBg and _kSearchFill removed — now use theme colors
// _kGreen removed — now use cs.primary / Theme.of(context).colorScheme.primary

// Palette de couleurs pour les cartes de section (cyclique)
const _kSectionColors = [
  Color(0xFF8D67AB),
  Color(0xFFBA5D07),
  Color(0xFFE8115B),
  Color(0xFF1E3264),
  Color(0xFF056952),
  Color(0xFF0D73EC),
  Color(0xFF537AA1),
  Color(0xFF8C1932),
  Color(0xFF2E6A59),
  Color(0xFF6D4C41),
  Color(0xFF4527A0),
  Color(0xFF00695C),
];

// Paires de dégradés pour les mood cards
const _kMoodGradients = [
  [Color(0xFF6D4C41), Color(0xFFBF8660)],
  [Color(0xFF0D1B2A), Color(0xFF1565C0)],
  [Color(0xFF2C2C2C), Color(0xFF546E7A)],
  [Color(0xFF1A3A2A), Color(0xFF2E7D52)],
  [Color(0xFF1A1A2E), Color(0xFF4527A0)],
  [Color(0xFF8C1932), Color(0xFFE8115B)],
  [Color(0xFF0D73EC), Color(0xFF1E3264)],
];

// ─── Helpers ──────────────────────────────────────────────────────────────────

Color _sectionColor(int index) =>
    _kSectionColors[index % _kSectionColors.length];

List<Color> _moodGradient(int index) =>
    _kMoodGradients[index % _kMoodGradients.length];

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
  final _filterKey = GlobalKey();
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
                IconButton(
                  icon: Icon(Broken.search_normal_1,
                      color: cs.onSurface, size: 22),
                  onPressed: _expandAndFocusSearch,
                  visualDensity: VisualDensity.compact,
                ),
              IconButton(
                icon: Icon(Broken.camera,
                    color: cs.onSurface, size: 24),
                onPressed: () {},
                visualDensity: VisualDensity.compact,
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
                    // est active. Ouvre un popup box positionné (pas de sheet).
                    if (_query.isNotEmpty)
                      _MusicFilterButton(
                        key: _filterKey,
                        label: _chipLabel(_selectedChip),
                        isActive: _selectedChip != 'all',
                        onTap: () => _openFilterPopup(context),
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

  // ── Popup box de filtres — s'ouvre depuis le bouton, positionné en dessous ──
  // Même UX que le Discovery/Watch : une box dropdown, pas un sheet en bas.
  Future<void> _openFilterPopup(BuildContext context) async {
    final chips = ref.read(metadataPluginSearchChipsProvider).asData?.value ??
        ['all', 'tracks', 'albums', 'artists', 'playlists'];
    final cs = Theme.of(context).colorScheme;

    final RenderBox? button =
        _filterKey.currentContext?.findRenderObject() as RenderBox?;
    final RenderBox? overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (button == null || overlay == null) return;

    final Offset topLeft =
        button.localToGlobal(Offset.zero, ancestor: overlay);
    final position = RelativeRect.fromLTRB(
      topLeft.dx,
      topLeft.dy + button.size.height + 4,
      overlay.size.width - topLeft.dx - button.size.width,
      0,
    );

    final result = await showMenu<String>(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: cs.surfaceContainerHigh,
      elevation: 8,
      items: chips.map((chip) {
        final isSelected = _selectedChip == chip;
        return PopupMenuItem<String>(
          value: chip,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Icon(
                isSelected
                    ? Broken.tick_circle
                    : Broken.record,
                size: 18,
                color: isSelected
                    ? cs.primary
                    : cs.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 12),
              Text(
                _chipLabel(chip),
                style: TextStyle(
                  color: isSelected ? cs.onSurface : cs.onSurfaceVariant,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.w400,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
    if (result != null && mounted) setState(() => _selectedChip = result);
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
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 14),
                child: Text(
                  'Découvrez de nouveaux horizons',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(
                height: 148,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: sections.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, i) => _SectionMoodCard(
                    section: sections[i],
                    gradient: _moodGradient(i),
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
        error: (_, __) => const SizedBox.shrink(),
        data: (page) {
          if (page.items.isEmpty) return const SizedBox.shrink();
          final sections = page.items;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 14),
                child: Text(
                  'Tout parcourir',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
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
                    childAspectRatio: 1.7,
                  ),
                  itemCount: sections.length,
                  itemBuilder: (_, i) => _SectionGridCard(
                    section: sections[i],
                    color: _sectionColor(i),
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
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: Text(
            'Titres',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
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
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Text(
            title,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        SizedBox(
          height: 190,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
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
  final List<Color> gradient;
  final VoidCallback onTap;

  const _SectionMoodCard({
    required this.section,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 148,
          height: 148,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: gradient,
                  ),
                ),
              ),
              // Cercles décoratifs
              Positioned(
                right: -20,
                top: -20,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.07),
                  ),
                ),
              ),
              Positioned(
                right: 10,
                top: 30,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
              ),
              // Dégradé bas
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.5),
                      ],
                    ),
                  ),
                ),
              ),
              // Titre
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Text(
                  section.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    shadows: [
                      Shadow(color: Colors.black45, blurRadius: 4),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Carte grid de section ────────────────────────────────────────────────────

class _SectionGridCard extends StatelessWidget {
  final SpotubeBrowseSectionObject<Object> section;
  final Color color;
  final VoidCallback onTap;

  const _SectionGridCard({
    required this.section,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              section.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            Align(
              alignment: Alignment.bottomRight,
              child: Icon(
                Broken.music_library_2,
                color: Colors.white.withValues(alpha: 0.3),
                size: 28,
              ),
            ),
          ],
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
      error: (_, __) => _InitialsAvatar(initials: initials, size: size),
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
      backgroundColor: Theme.of(context).colorScheme.primary,
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.38,
        ),
      ),
    );
  }
}

// ─── Pill de navigation ───────────────────────────────────────────────────────

class _NavPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  const _NavPill({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
          border: selected
              ? null
              : Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14,
                color: selected
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Bouton "Filtrer" (ouvre le bottom sheet de filtres) ──────────────────────

class _MusicFilterButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _MusicFilterButton({
    super.key,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
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
