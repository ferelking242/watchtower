import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/modules/music/collections/routes.dart'
    show rootNavigatorKey; // kept for _NavPill go_router usage
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

const _kBg = Color(0xFF121212);
const _kSearchFill = Color(0xFF2A2A2A);
const _kGreen = Color(0xFF1DB954);

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
  String _query = '';
  String _selectedChip = 'all';

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      if (mounted) setState(() => _query = _ctrl.text.trim());
    });
    _focus.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  double _headerHeight(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return topPad + 52 + 8 + 48 + 10 + 36 + 24;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: CustomScrollView(
        controller: _scroll,
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverPersistentHeader(
            pinned: true,
            delegate: _StickyHeaderDelegate(
              height: _headerHeight(context),
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

    // Chips depuis le provider, fallback statique
    final chipsAsync = ref.watch(metadataPluginSearchChipsProvider);
    final chips = chipsAsync.asData?.value ?? ['all', 'tracks', 'albums', 'artists', 'playlists'];

    return Container(
      color: _kBg,
      padding: EdgeInsets.only(top: top, left: 16, right: 16, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Ligne avatar + titre
          Row(
            children: [
              _PluginAvatar(size: 36),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Rechercher',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.camera_alt_outlined,
                    color: Colors.white, size: 24),
                onPressed: () {},
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Barre de recherche
          GestureDetector(
            onTap: () => _focus.requestFocus(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 46,
              decoration: BoxDecoration(
                color: _focus.hasFocus ? Colors.white : _kSearchFill,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 14),
                  Icon(
                    Icons.search_rounded,
                    size: 20,
                    color: _focus.hasFocus ? Colors.black87 : Colors.white70,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      focusNode: _focus,
                      textInputAction: TextInputAction.search,
                      style: TextStyle(
                        color: _focus.hasFocus ? Colors.black : Colors.white,
                        fontSize: 15,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Que souhaitez-vous écouter ?',
                        hintStyle: TextStyle(
                          color: _focus.hasFocus
                              ? Colors.black45
                              : Colors.white54,
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
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Icon(Icons.close_rounded,
                            size: 18,
                            color: _focus.hasFocus
                                ? Colors.black54
                                : Colors.white54),
                      ),
                    )
                  else
                    const SizedBox(width: 14),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Pills de navigation (Découverte / Music search / Sources custom)
          // + chips de filtre quand une recherche est active
          if (_query.isEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _NavPill(
                    label: 'Découverte',
                    icon: Icons.compass_calibration_outlined,
                    selected: false,
                    onTap: () => context.go('/discover'),
                  ),
                  const SizedBox(width: 8),
                  const _NavPill(
                    label: 'Music search',
                    icon: Icons.music_note_rounded,
                    selected: true,
                    onTap: null,
                  ),
                  const SizedBox(width: 8),
                  _NavPill(
                    label: 'Sources custom',
                    icon: Icons.add_circle_outline_rounded,
                    selected: false,
                    onTap: () => context.push(
                      '/globalSearch',
                      extra: (null, ItemType.anime),
                    ),
                  ),
                ],
              ),
            )
          else
            // Chips de filtre depuis le provider
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (int i = 0; i < chips.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    _FilterChip(
                      label: _chipLabel(chips[i]),
                      selected: _selectedChip == chips[i],
                      onTap: () =>
                          setState(() => _selectedChip = chips[i]),
                    ),
                  ],
                ],
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
        loading: () => const SizedBox(
          height: 180,
          child: Center(
            child: CircularProgressIndicator(
              color: _kGreen,
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
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 20, 16, 14),
                child: Text(
                  'Découvrez de nouveaux horizons',
                  style: TextStyle(
                    color: Colors.white,
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
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 24, 16, 14),
                child: Text(
                  'Tout parcourir',
                  style: TextStyle(
                    color: Colors.white,
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
                    onTap: () => _toBrowseSection(sections[i]),
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
        loading: () => const Padding(
          padding: EdgeInsets.only(top: 60),
          child: Center(
            child: CircularProgressIndicator(
              color: _kGreen,
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
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: Text(
            'Titres',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        ...tracks.take(5).map((track) {
          final isActive = track.id == activeId;
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
                        placeholder: const Icon(Icons.music_note_rounded,
                            color: Colors.white54),
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
                              color: isActive ? _kGreen : Colors.white,
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
                                    color: Colors.white24,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: const Text('E',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800)),
                                ),
                              Flexible(
                                child: Text(
                                  _artistNames(track.artists),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white60,
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
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // More
                    const Icon(Icons.more_vert_rounded,
                        color: Colors.white38),
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
            style: const TextStyle(
              color: Colors.white,
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
              return GestureDetector(
                onTap: () => onTap(item),
                child: SizedBox(
                  width: 130,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      circular
                          ? CircleAvatar(
                              radius: 65,
                              backgroundColor: const Color(0xFF2A2A2A),
                              child: ClipOval(
                                child: MusicCachedImage(
                                  url: url,
                                  width: 130,
                                  height: 130,
                                  placeholder: const Icon(
                                      Icons.person_rounded,
                                      color: Colors.white54),
                                ),
                              ),
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: MusicCachedImage(
                                url: url,
                                width: 130,
                                height: 130,
                                placeholder: const Icon(Icons.album_rounded,
                                    color: Colors.white54),
                              ),
                            ),
                      const SizedBox(height: 8),
                      Text(
                        label(item),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        sublabel(item),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white54,
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
                Icons.library_music_rounded,
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
          Icon(Icons.extension_rounded,
              size: 56, color: Colors.white.withValues(alpha: 0.12)),
          const SizedBox(height: 16),
          Text(
            'Aucune extension music installée',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Installe une extension depuis le\nMarketplace pour chercher "$query"',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.3),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white30),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            onPressed: () => context.push('/marketplace'),
            icon: const Icon(Icons.store_rounded),
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
          Icon(Icons.search_off_rounded,
              size: 56, color: Colors.white.withValues(alpha: 0.12)),
          const SizedBox(height: 16),
          Text(
            'Aucun résultat pour\n"$query"',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
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
      backgroundColor: _kGreen,
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
          color: selected ? _kGreen : const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(20),
          border: selected ? null : Border.all(color: Colors.white12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14,
                color: selected ? Colors.black : Colors.white70),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.black : Colors.white70,
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

// ─── Chip de filtre de recherche ──────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? Colors.white : const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black : Colors.white70,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// ─── Sticky header delegate ───────────────────────────────────────────────────

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double height;
  final Widget child;
  const _StickyHeaderDelegate({required this.height, required this.child});

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;

  @override
  Widget build(
          BuildContext context, double shrinkOffset, bool overlapsContent) =>
      child;

  @override
  bool shouldRebuild(_StickyHeaderDelegate old) =>
      old.height != height || old.child != child;
}
