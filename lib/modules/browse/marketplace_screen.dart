import 'package:flutter/material.dart';

/// Full-featured Marketplace — discover and download community extensions,
/// binary packages and theme packs.
class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  int _categoryIndex = 0;
  final _searchController = TextEditingController();
  bool _isSearching = false;

  static const _categories = [
    (label: 'Tout',          icon: Icons.apps_rounded),
    (label: 'Extensions',    icon: Icons.extension_outlined),
    (label: 'Thèmes',        icon: Icons.palette_outlined),
    (label: 'Binaires',      icon: Icons.code_rounded),
    (label: 'Packs',         icon: Icons.inventory_2_outlined),
  ];

  static const _featured = [
    _MarketItem(
      name: 'AnimeStar Pro',
      author: 'ferelking242',
      description: 'Extension anime HD avec 1000+ sources en streaming.',
      category: 'Extension',
      categoryIcon: Icons.live_tv_rounded,
      emoji: '⭐',
      color: Color(0xFF6C63FF),
      downloads: '12.4k',
      rating: 4.8,
      featured: true,
    ),
    _MarketItem(
      name: 'Dark Amoled',
      author: 'themes_team',
      description: 'Pack de thème sombre AMOLED pour Watchtower.',
      category: 'Thème',
      categoryIcon: Icons.palette_rounded,
      emoji: '🌑',
      color: Color(0xFF222222),
      downloads: '8.1k',
      rating: 4.9,
      featured: true,
    ),
  ];

  static const _popular = [
    _MarketItem(
      name: 'MangaWorld',
      author: 'community',
      description: 'Manga scan FR/EN — mise à jour quotidienne.',
      category: 'Extension',
      categoryIcon: Icons.auto_stories_rounded,
      emoji: '📚',
      color: Color(0xFFFF6B6B),
      downloads: '34.2k',
      rating: 4.6,
    ),
    _MarketItem(
      name: 'Novel Hub',
      author: 'litfan',
      description: 'Light novel et web novel — JP/CN/EN.',
      category: 'Extension',
      categoryIcon: Icons.text_snippet_rounded,
      emoji: '📖',
      color: Color(0xFF4ECDC4),
      downloads: '18.7k',
      rating: 4.5,
    ),
    _MarketItem(
      name: 'MusicStream',
      author: 'audiodev',
      description: 'Streaming musical — 20+ plateformes supportées.',
      category: 'Extension',
      categoryIcon: Icons.music_note_rounded,
      emoji: '🎵',
      color: Color(0xFFFFBE0B),
      downloads: '9.3k',
      rating: 4.3,
    ),
    _MarketItem(
      name: 'GameVault',
      author: 'gamer_42',
      description: 'Fiches de jeux, ROMs et émulateurs supportés.',
      category: 'Extension',
      categoryIcon: Icons.sports_esports_rounded,
      emoji: '🎮',
      color: Color(0xFF06D6A0),
      downloads: '6.8k',
      rating: 4.2,
    ),
    _MarketItem(
      name: 'Ocean Theme',
      author: 'ux_lab',
      description: 'Thème bleu océan avec dégradés animés.',
      category: 'Thème',
      categoryIcon: Icons.palette_rounded,
      emoji: '🌊',
      color: Color(0xFF118AB2),
      downloads: '4.5k',
      rating: 4.7,
    ),
    _MarketItem(
      name: 'Sakura Pack',
      author: 'jp_studio',
      description: 'Pack d\'icônes style japonais pour toute l\'app.',
      category: 'Pack',
      categoryIcon: Icons.inventory_2_rounded,
      emoji: '🌸',
      color: Color(0xFFFF84B7),
      downloads: '3.2k',
      rating: 4.4,
    ),
  ];

  static const _binaries = [
    _MarketItem(
      name: 'yt-dlp ARM64',
      author: 'ffmpeg_builds',
      description: 'Binaire yt-dlp compilé pour Android ARM64.',
      category: 'Binaire',
      categoryIcon: Icons.download_rounded,
      emoji: '⚙️',
      color: Color(0xFF8D99AE),
      downloads: '22.1k',
      rating: 4.9,
    ),
    _MarketItem(
      name: 'FFmpeg Lite',
      author: 'ffmpeg_builds',
      description: 'FFmpeg allégé pour le transcodage vidéo.',
      category: 'Binaire',
      categoryIcon: Icons.video_settings_rounded,
      emoji: '🎞️',
      color: Color(0xFF457B9D),
      downloads: '15.3k',
      rating: 4.7,
    ),
  ];

  List<_MarketItem> get _filteredItems {
    final query = _searchController.text.toLowerCase();
    List<_MarketItem> all;
    switch (_categoryIndex) {
      case 1:
        all = _popular.where((i) => i.category == 'Extension').toList();
      case 2:
        all = [..._featured, ..._popular].where((i) => i.category == 'Thème').toList();
      case 3:
        all = _binaries;
      case 4:
        all = _popular.where((i) => i.category == 'Pack').toList();
      default:
        all = [..._featured, ..._popular, ..._binaries];
    }
    if (query.isEmpty) return all;
    return all.where((i) =>
        i.name.toLowerCase().contains(query) ||
        i.description.toLowerCase().contains(query) ||
        i.author.toLowerCase().contains(query)).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          // ── Header ──────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _buildHeader(cs, isDark),
          ),

          // ── Category chips ───────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _buildCategoryChips(cs),
          ),

          if (!_isSearching && _categoryIndex == 0) ...[
            // ── Featured ──────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _buildSectionTitle(cs, 'À la une', Icons.star_rounded),
            ),
            SliverToBoxAdapter(
              child: _buildFeaturedCarousel(cs),
            ),

            // ── Popular extensions ────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _buildSectionTitle(cs, 'Populaires', Icons.trending_up_rounded),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _ItemCard(item: _popular[i]),
                childCount: _popular.length,
              ),
            ),

            // ── Binaries ──────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _buildSectionTitle(cs, 'Binaires', Icons.terminal_rounded),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _ItemCard(item: _binaries[i]),
                childCount: _binaries.length,
              ),
            ),
          ] else ...[
            // ── Filtered list ─────────────────────────────────────────────────
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _ItemCard(item: _filteredItems[i]),
                childCount: _filteredItems.length,
              ),
            ),
            if (_filteredItems.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off_rounded,
                          size: 56,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
                      const SizedBox(height: 12),
                      Text('Aucun résultat',
                          style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
          ],

          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }

  Widget _buildHeader(ColorScheme cs, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [cs.primary, cs.tertiary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: cs.primary.withValues(alpha: 0.30),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.storefront_rounded,
                    color: Colors.white, size: 26),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Marketplace',
                      style: TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w800)),
                  Text(
                    'Extensions · Thèmes · Binaires',
                    style: TextStyle(
                        fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _isSearching = v.isNotEmpty),
            onTap: () => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Rechercher extensions, thèmes…',
              hintStyle: TextStyle(
                  fontSize: 13,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
              prefixIcon:
                  Icon(Icons.search_rounded, color: cs.primary, size: 20),
              suffixIcon: _isSearching
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _isSearching = false);
                      },
                    )
                  : null,
              filled: true,
              fillColor: cs.surfaceContainerHigh,
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildCategoryChips(ColorScheme cs) {
    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: _categories.length,
        itemBuilder: (ctx, i) {
          final cat = _categories[i];
          final active = _categoryIndex == i;
          return GestureDetector(
            onTap: () => setState(() {
              _categoryIndex = i;
              _isSearching = _searchController.text.isNotEmpty;
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              margin: const EdgeInsets.only(right: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: active ? cs.primary : cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color:
                        active ? cs.primary : cs.outline.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(cat.icon,
                      size: 14,
                      color: active ? cs.onPrimary : cs.onSurfaceVariant),
                  const SizedBox(width: 5),
                  Text(
                    cat.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: active ? cs.onPrimary : cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(ColorScheme cs, String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: cs.primary),
          const SizedBox(width: 7),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedCarousel(ColorScheme cs) {
    return SizedBox(
      height: 170,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _featured.length,
        itemBuilder: (ctx, i) => _FeaturedCard(item: _featured[i]),
      ),
    );
  }
}

// ─── Data model ────────────────────────────────────────────────────────────────

class _MarketItem {
  final String name;
  final String author;
  final String description;
  final String category;
  final IconData categoryIcon;
  final String emoji;
  final Color color;
  final String downloads;
  final double rating;
  final bool featured;

  const _MarketItem({
    required this.name,
    required this.author,
    required this.description,
    required this.category,
    required this.categoryIcon,
    required this.emoji,
    required this.color,
    required this.downloads,
    required this.rating,
    this.featured = false,
  });
}

// ─── Featured card ─────────────────────────────────────────────────────────────

class _FeaturedCard extends StatelessWidget {
  final _MarketItem item;
  const _FeaturedCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 260,
      margin: const EdgeInsets.only(right: 12, bottom: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            item.color.withValues(alpha: 0.85),
            item.color.withValues(alpha: 0.55),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: item.color.withValues(alpha: 0.28),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(item.emoji, style: const TextStyle(fontSize: 32)),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded,
                          size: 11, color: Colors.white),
                      const SizedBox(width: 3),
                      Text(
                        item.rating.toStringAsFixed(1),
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(item.name,
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
            const SizedBox(height: 3),
            Text(item.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 11.5,
                    color: Colors.white.withValues(alpha: 0.85))),
            const Spacer(),
            Row(
              children: [
                Icon(Icons.download_rounded,
                    size: 12, color: Colors.white.withValues(alpha: 0.8)),
                const SizedBox(width: 4),
                Text(item.downloads,
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.8))),
                const Spacer(),
                _DownloadButton(small: true, color: Colors.white),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── List item card ─────────────────────────────────────────────────────────────

class _ItemCard extends StatelessWidget {
  final _MarketItem item;
  const _ItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(item.emoji,
                  style: const TextStyle(fontSize: 26)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(item.name,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: item.color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(item.categoryIcon,
                              size: 10, color: item.color),
                          const SizedBox(width: 3),
                          Text(item.category,
                              style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: item.color)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(item.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12, color: cs.onSurfaceVariant)),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Icon(Icons.person_rounded,
                        size: 11,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
                    const SizedBox(width: 3),
                    Text(item.author,
                        style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.7))),
                    const SizedBox(width: 10),
                    Icon(Icons.download_rounded,
                        size: 11,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
                    const SizedBox(width: 3),
                    Text(item.downloads,
                        style: TextStyle(
                            fontSize: 11,
                            color:
                                cs.onSurfaceVariant.withValues(alpha: 0.7))),
                    const SizedBox(width: 8),
                    Icon(Icons.star_rounded,
                        size: 11, color: Colors.amber),
                    const SizedBox(width: 2),
                    Text(item.rating.toStringAsFixed(1),
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.amber)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _DownloadButton(color: null),
        ],
      ),
    );
  }
}

// ─── Download button ───────────────────────────────────────────────────────────

class _DownloadButton extends StatefulWidget {
  final bool small;
  final Color? color;
  const _DownloadButton({this.small = false, this.color});

  @override
  State<_DownloadButton> createState() => _DownloadButtonState();
}

class _DownloadButtonState extends State<_DownloadButton> {
  bool _installed = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final buttonColor = widget.color ?? cs.primary;
    if (_installed) {
      return Container(
        padding: widget.small
            ? const EdgeInsets.symmetric(horizontal: 10, vertical: 5)
            : const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: buttonColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_rounded,
                size: widget.small ? 12 : 14, color: buttonColor),
            const SizedBox(width: 4),
            Text('Installé',
                style: TextStyle(
                    fontSize: widget.small ? 10 : 11,
                    fontWeight: FontWeight.w700,
                    color: buttonColor)),
          ],
        ),
      );
    }
    return GestureDetector(
      onTap: () => setState(() => _installed = true),
      child: Container(
        padding: widget.small
            ? const EdgeInsets.symmetric(horizontal: 10, vertical: 5)
            : const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: buttonColor.withValues(alpha: widget.small ? 0.22 : 1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.download_rounded,
                size: widget.small ? 12 : 14,
                color: widget.small ? buttonColor : cs.onPrimary),
            const SizedBox(width: 4),
            Text(
              'Installer',
              style: TextStyle(
                  fontSize: widget.small ? 10 : 11,
                  fontWeight: FontWeight.w700,
                  color: widget.small ? buttonColor : cs.onPrimary),
            ),
          ],
        ),
      ),
    );
  }
}
