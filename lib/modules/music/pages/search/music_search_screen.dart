import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/metadata_plugin_provider.dart';

// ── Provider: logo du plugin metadata actif ────────────────────────────────

final _activePluginLogoProvider = FutureProvider<File?>((ref) async {
  final state = ref.watch(metadataPluginsProvider);
  final pluginConfig = state.asData?.value.defaultMetadataPluginConfig;
  if (pluginConfig == null) return null;
  final notifier = ref.read(metadataPluginsProvider.notifier);
  return notifier.getLogoPath(pluginConfig);
});

// ── Constantes design ──────────────────────────────────────────────────────

const _kBg = Color(0xFF121212);
const _kSurface = Color(0xFF1E1E1E);
const _kSearchFill = Color(0xFF2A2A2A);

const _kMoods = [
  _MoodCard('#surf crush', Color(0xFF6D4C41), Color(0xFFBF8660)),
  _MoodCard('#energetic', Color(0xFF0D1B2A), Color(0xFF1565C0)),
  _MoodCard('#uptown', Color(0xFF2C2C2C), Color(0xFF546E7A)),
  _MoodCard('#chill', Color(0xFF1A3A2A), Color(0xFF2E7D52)),
  _MoodCard('#focus', Color(0xFF1A1A2E), Color(0xFF4527A0)),
];

const _kCategories = [
  _Category('Musique', Color(0xFFE91E8C), Icons.music_note_rounded),
  _Category('Événements live', Color(0xFF7B52AB), Icons.event_rounded),
  _Category('Conçu pour vous', Color(0xFF2E6A59), Icons.auto_awesome_rounded),
  _Category('Sorties à venir', Color(0xFF3B7A46), Icons.new_releases_rounded),
  _Category('Dernières sorties', Color(0xFFE05E2A), Icons.fiber_new_rounded),
  _Category('Pop', Color(0xFF537AA1), Icons.star_rounded),
  _Category('Hip-Hop', Color(0xFFBA5D07), Icons.mic_external_on_rounded),
  _Category('Rock', Color(0xFF8C1932), Icons.bolt_rounded),
  _Category('Électronique', Color(0xFF1E3264), Icons.graphic_eq_rounded),
  _Category('R&B', Color(0xFF056952), Icons.audiotrack_rounded),
  _Category('Jazz', Color(0xFF0D73EC), Icons.piano_rounded),
  _Category('Podcasts', Color(0xFF6A3093), Icons.podcasts_rounded),
];

// ── Data classes ────────────────────────────────────────────────────────────

class _MoodCard {
  final String label;
  final Color colorA;
  final Color colorB;
  const _MoodCard(this.label, this.colorA, this.colorB);
}

class _Category {
  final String label;
  final Color color;
  final IconData icon;
  const _Category(this.label, this.color, this.icon);
}

// ── Écran principal ────────────────────────────────────────────────────────

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
  int _chipIdx = 0;

  static const _chips = ['Tout', 'Titres', 'Albums', 'Artistes', 'Playlists'];

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      if (mounted) setState(() => _query = _ctrl.text);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ── Header height ──────────────────────────────────────────────────────────

  double _headerHeight(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    // avatar row 52 + gap 8 + searchbar 48 + gap 10 + pills 36 + padding 24
    return topPad + 52 + 8 + 48 + 10 + 36 + 24;
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: CustomScrollView(
        controller: _scroll,
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Sticky header ────────────────────────────────────────────────
          SliverPersistentHeader(
            pinned: true,
            delegate: _StickyHeaderDelegate(
              height: _headerHeight(context),
              child: _buildHeader(context),
            ),
          ),

          // ── Corps scrollable ─────────────────────────────────────────────
          if (_query.isEmpty) ...[
            _buildMoodsSection(context),
            _buildBrowseSection(context),
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ] else ...[
            _buildSearchResults(context),
          ],
        ],
      ),
    );
  }

  // ── Header (avatar + barre + pills) ───────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      color: _kBg,
      padding: EdgeInsets.only(top: top, left: 16, right: 16, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Ligne avatar + titre + caméra ──────────────────────────────
          Row(
            children: [
              _PluginAvatar(size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Rechercher',
                  style: const TextStyle(
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
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),

          const SizedBox(height: 10),

          // ── Barre de recherche ─────────────────────────────────────────
          GestureDetector(
            onTap: () => _focus.requestFocus(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 46,
              decoration: BoxDecoration(
                color: _focus.hasFocus
                    ? Colors.white
                    : _kSearchFill,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 14),
                  Icon(
                    Icons.search_rounded,
                    size: 20,
                    color: _focus.hasFocus
                        ? Colors.black87
                        : Colors.white70,
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

          // ── Pills de découverte ────────────────────────────────────────
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
                _NavPill(
                  label: 'Music search',
                  icon: Icons.music_note_rounded,
                  selected: true,
                  onTap: () {},
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
          ),
        ],
      ),
    );
  }

  // ── Section "Découvrez de nouveaux horizons" ───────────────────────────────

  SliverToBoxAdapter _buildMoodsSection(BuildContext context) {
    return SliverToBoxAdapter(
      child: Column(
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
              itemCount: _kMoods.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) => _MoodCardWidget(mood: _kMoods[i]),
            ),
          ),
        ],
      ),
    );
  }

  // ── Section "Tout parcourir" ───────────────────────────────────────────────

  SliverPadding _buildBrowseSection(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      sliver: SliverMainAxisGroup(
        slivers: [
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(bottom: 14),
              child: Text(
                'Tout parcourir',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.7,
            ),
            itemCount: _kCategories.length,
            itemBuilder: (_, i) => _CategoryCard(cat: _kCategories[i]),
          ),
        ],
      ),
    );
  }

  // ── Résultats de recherche ─────────────────────────────────────────────────

  SliverToBoxAdapter _buildSearchResults(BuildContext context) {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Chips filtres ─────────────────────────────────────────────
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              itemCount: _chips.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final sel = i == _chipIdx;
                return GestureDetector(
                  onTap: () => setState(() => _chipIdx = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: sel
                          ? Colors.white
                          : const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _chips[i],
                      style: TextStyle(
                        color: sel ? Colors.black : Colors.white70,
                        fontWeight: sel
                            ? FontWeight.w700
                            : FontWeight.w400,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 32),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search_off_rounded,
                      size: 56,
                      color: Colors.white.withValues(alpha: 0.12)),
                  const SizedBox(height: 16),
                  Text(
                    'Aucun résultat pour\n"$_query"',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Installe une extension music depuis le\nMarketplace pour lancer des recherches.',
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
                    icon: const Icon(Icons.store_rounded, size: 16),
                    label: const Text('Marketplace'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Avatar du plugin actif ─────────────────────────────────────────────────

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
      backgroundColor: const Color(0xFF1DB954),
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

// ── Pill de navigation ─────────────────────────────────────────────────────

class _NavPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
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
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF1DB954)
              : const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(20),
          border: selected
              ? null
              : Border.all(color: Colors.white12),
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
                fontWeight:
                    selected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Carte mood/hashtag ─────────────────────────────────────────────────────

class _MoodCardWidget extends StatelessWidget {
  final _MoodCard mood;
  const _MoodCardWidget({required this.mood});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 148,
        height: 148,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Gradient de fond
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [mood.colorB, mood.colorA],
                ),
              ),
            ),
            // Motif abstrait avec circles décalés
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
            // Dégradé bas → label
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.6),
                    ],
                    stops: const [0.4, 1.0],
                  ),
                ),
              ),
            ),
            // Label hashtag
            Positioned(
              left: 12,
              bottom: 12,
              right: 12,
              child: Text(
                mood.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  shadows: [
                    Shadow(blurRadius: 4, color: Colors.black54),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Carte catégorie Spotify ────────────────────────────────────────────────

class _CategoryCard extends StatelessWidget {
  final _Category cat;
  const _CategoryCard({required this.cat});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: cat.color),
          // Icône décorative grande, décalée bas-droite
          Positioned(
            right: -8,
            bottom: -8,
            child: Transform.rotate(
              angle: math.pi / 8,
              child: Icon(
                cat.icon,
                size: 64,
                color: Colors.black.withValues(alpha: 0.18),
              ),
            ),
          ),
          // Icône plus petite en haut-droite style Spotify
          Positioned(
            right: 10,
            top: 10,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(cat.icon, color: Colors.white70, size: 20),
            ),
          ),
          // Label
          Positioned(
            left: 12,
            top: 12,
            right: 56,
            child: Text(
              cat.label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14,
                height: 1.2,
              ),
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }
}

// ── SliverPersistentHeaderDelegate ────────────────────────────────────────

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double height;
  final Widget child;
  const _StickyHeaderDelegate({required this.height, required this.child});

  @override
  Widget build(
          BuildContext context, double shrinkOffset, bool overlapsContent) =>
      child;

  @override
  double get maxExtent => height;

  @override
  double get minExtent => height;

  @override
  bool shouldRebuild(_StickyHeaderDelegate old) =>
      old.height != height || old.child != child;
}
