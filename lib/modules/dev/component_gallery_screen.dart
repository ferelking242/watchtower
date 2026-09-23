import 'package:flutter/material.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/modules/media/flixquest_app_ui_components.dart';

enum _GalleryFilter { all, cards, loading, layouts }

class ComponentGalleryScreen extends StatefulWidget {
  const ComponentGalleryScreen({super.key});

  @override
  State<ComponentGalleryScreen> createState() => _ComponentGalleryScreenState();
}

class _ComponentGalleryScreenState extends State<ComponentGalleryScreen> {
  _GalleryFilter _filter = _GalleryFilter.all;

  bool _shows(bool isLoading, bool isLayout) {
    return switch (_filter) {
      _GalleryFilter.all => true,
      _GalleryFilter.cards => !isLoading && !isLayout,
      _GalleryFilter.loading => isLoading,
      _GalleryFilter.layouts => isLayout,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0D12),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            elevation: 0,
            backgroundColor: const Color(0xFF0B0D12).withValues(alpha: .94),
            surfaceTintColor: Colors.transparent,
            titleSpacing: AppUI.pagePadding(context),
            title: const Row(
              children: [
                _GalleryLogo(),
                SizedBox(width: 12),
                Text('Component library'),
              ],
            ),
            actions: [
              Padding(
                padding: EdgeInsets.only(right: AppUI.pagePadding(context) - 8),
                child: IconButton(
                  tooltip: 'Fermer',
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Broken.close_circle),
                ),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                AppUI.pagePadding(context),
                30,
                AppUI.pagePadding(context),
                24,
              ),
              child: _GalleryIntro(
                filter: _filter,
                onFilterChanged: (value) => setState(() => _filter = value),
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.only(
              left: AppUI.pagePadding(context),
              right: AppUI.pagePadding(context),
              bottom: 80,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate(
                [
                  if (_shows(false, false))
                    _GallerySection(
                      eyebrow: '01 · Cards',
                      title: 'Poster cards',
                      description:
                          'La base des rails Popular, Latest et des grilles catalogue.',
                      child: _PosterShowcase(),
                    ),
                  if (_shows(false, false))
                    _GallerySection(
                      eyebrow: '02 · Cards',
                      title: 'Landscape & backdrop',
                      description:
                          'Pour les rails vidéo, les studios et les contenus éditoriaux.',
                      child: _LandscapeShowcase(),
                    ),
                  if (_shows(false, false))
                    _GallerySection(
                      eyebrow: '03 · Cards',
                      title: 'Ranked, creator & studio',
                      description:
                          'Les cartes dédiées aux classements, personnes et collections.',
                      child: _EditorialShowcase(),
                    ),
                  if (_shows(false, true))
                    _GallerySection(
                      eyebrow: '04 · Layout',
                      title: 'Hero, banner & rails',
                      description:
                          'Les compositions de page qui combinent plusieurs cards.',
                      child: const _LayoutShowcase(),
                    ),
                  if (_shows(false, true))
                    _GallerySection(
                      eyebrow: '05 · Layout',
                      title: 'Tags & category grid',
                      description:
                          'La grille horizontale 3×3 et les pills de catégories.',
                      child: const _TagShowcase(),
                    ),
                  if (_shows(true, false))
                    _GallerySection(
                      eyebrow: '06 · Loading',
                      title: 'Skeleton states',
                      description:
                          'Les placeholders à vérifier avant chaque intégration de layout.',
                      child: const _SkeletonShowcase(),
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

class _GalleryLogo extends StatelessWidget {
  const _GalleryLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(11),
      ),
      child: const Icon(Icons.auto_awesome_rounded, size: 18),
    );
  }
}

class _GalleryIntro extends StatelessWidget {
  final _GalleryFilter filter;
  final ValueChanged<_GalleryFilter> onFilterChanged;

  const _GalleryIntro({
    required this.filter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Toutes les pièces d’interface, au même endroit.',
          style: theme.textTheme.displaySmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            letterSpacing: -.8,
          ),
        ),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Text(
            'Une bibliothèque rapide pour comparer les cards, les rails, les '
            'layouts et leurs skeleton loading avant de les brancher aux données.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: Colors.white60,
              height: 1.45,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _GalleryFilterChip(
              label: 'Tout',
              icon: Icons.dashboard_customize_outlined,
              selected: filter == _GalleryFilter.all,
              onTap: () => onFilterChanged(_GalleryFilter.all),
            ),
            _GalleryFilterChip(
              label: 'Cards',
              icon: Icons.crop_portrait_outlined,
              selected: filter == _GalleryFilter.cards,
              onTap: () => onFilterChanged(_GalleryFilter.cards),
            ),
            _GalleryFilterChip(
              label: 'Skeletons',
              icon: Icons.hourglass_empty_rounded,
              selected: filter == _GalleryFilter.loading,
              onTap: () => onFilterChanged(_GalleryFilter.loading),
            ),
            _GalleryFilterChip(
              label: 'Layouts',
              icon: Icons.view_quilt_outlined,
              selected: filter == _GalleryFilter.layouts,
              onTap: () => onFilterChanged(_GalleryFilter.layouts),
            ),
          ],
        ),
      ],
    );
  }
}

class _GalleryFilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _GalleryFilterChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      selected: selected,
      onSelected: (_) => onTap(),
      avatar: Icon(
        icon,
        size: 16,
        color: selected ? Colors.white : Colors.white54,
      ),
      label: Text(label),
      labelStyle: TextStyle(
        color: selected ? Colors.white : Colors.white70,
        fontWeight: FontWeight.w700,
      ),
      backgroundColor: const Color(0xFF171A23),
      selectedColor: const Color(0xFF7048D8),
      checkmarkColor: Colors.white,
      side: BorderSide(
        color: selected ? const Color(0xFF9C7BFF) : Colors.white12,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}

class _GallerySection extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String description;
  final Widget child;

  const _GallerySection({
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 44),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow.toUpperCase(),
            style: const TextStyle(
              color: Color(0xFFB193FF),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.w800,
              letterSpacing: -.4,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            description,
            style: const TextStyle(color: Colors.white54, height: 1.35),
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _PosterShowcase extends StatelessWidget {
  const _PosterShowcase();

  @override
  Widget build(BuildContext context) {
    return _GalleryPanel(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth < 640 ? 108.0 : 132.0;
          return Wrap(
            spacing: 12,
            runSpacing: 22,
            children: [
              for (final item in const [
                ('Dune: Part Two', '2024 · 8.7', Color(0xFFB26E45)),
                ('The Last of Us', 'S02 · 9.1', Color(0xFF355D65)),
                ('Arcane', 'S01 · 8.8', Color(0xFF59426F)),
                ('The Bear', 'S03 · 8.5', Color(0xFF8E4D31)),
                ('Severance', 'S02 · 8.9', Color(0xFF426B73)),
              ])
                _GalleryPosterCard(
                  title: item.$1,
                  subtitle: item.$2,
                  width: width,
                  color: item.$3,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _LandscapeShowcase extends StatelessWidget {
  const _LandscapeShowcase();

  @override
  Widget build(BuildContext context) {
    return _GalleryPanel(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth < 640 ? 220.0 : 270.0;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final item in const [
                  ('Studio feature', 'A large banner with metadata', Color(0xFF5C3E87)),
                  ('Landscape card', '16:9 video rail', Color(0xFF1E6871)),
                  ('Backdrop card', 'Editorial discovery', Color(0xFF8A4933)),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: _GalleryLandscapeCard(
                      title: item.$1,
                      subtitle: item.$2,
                      width: width,
                      color: item.$3,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _EditorialShowcase extends StatelessWidget {
  const _EditorialShowcase();

  @override
  Widget build(BuildContext context) {
    return _GalleryPanel(
      child: Wrap(
        spacing: 22,
        runSpacing: 26,
        children: [
          _GalleryRankedCard(
            title: 'Top Rated',
            items: const ['The Bear', 'Dune', 'Arcane'],
          ),
          const _GalleryCreatorCard(
            name: 'Sofia Hart',
            role: 'Pornstar / Creator',
            color: Color(0xFF8656A4),
          ),
          const _GalleryStudioCard(
            name: 'Neon Studios',
            videos: '24 videos',
            color: Color(0xFF305F67),
          ),
        ],
      ),
    );
  }
}

class _LayoutShowcase extends StatelessWidget {
  const _LayoutShowcase();

  @override
  Widget build(BuildContext context) {
    return _GalleryPanel(
      child: Column(
        children: [
          _GalleryHeroCard(
            title: 'Hero / banner',
            subtitle: 'The first content card anchors the whole page.',
            color: const Color(0xFF563A83),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _GalleryMiniLayout(
                  icon: Icons.view_carousel_outlined,
                  title: 'Horizontal rail',
                  detail: 'Popular · Latest · Compact',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _GalleryMiniLayout(
                  icon: Icons.grid_view_rounded,
                  title: 'Catalogue grid',
                  detail: '3 columns · poster cards',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TagShowcase extends StatelessWidget {
  const _TagShowcase();

  @override
  Widget build(BuildContext context) {
    // Row-major Flutter grid data that renders column-major visually:
    // 1 4 7 / 2 5 8 / 3 6 9.
    const tags = [
      (1, 'Anal'),
      (4, 'Big Tits'),
      (7, 'Lesbian'),
      (2, 'Asian'),
      (5, 'Casting'),
      (8, 'Mature'),
      (3, 'BDSM'),
      (6, 'Homemade'),
      (9, 'Russian'),
    ];
    return _GalleryPanel(
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: tags.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          mainAxisExtent: 76,
        ),
        itemBuilder: (context, index) => _GalleryTagCard(
          number: tags[index].$1,
          title: tags[index].$2,
          width: double.infinity,
          color: Color.lerp(
            const Color(0xFF245D67),
            const Color(0xFF7F4C82),
            index / 8,
          )!,
        ),
      ),
    );
  }
}

class _SkeletonShowcase extends StatelessWidget {
  const _SkeletonShowcase();

  @override
  Widget build(BuildContext context) {
    return _GalleryPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SkeletonLabel(label: 'Poster row'),
          SizedBox(
            height: 210,
            child: AppMediaRowShimmer(
              itemWidth: MediaQuery.sizeOf(context).width < 650 ? 88 : 112,
            ),
          ),
          const SizedBox(height: 20),
          const _SkeletonLabel(label: 'Poster grid'),
          const SizedBox(height: 340, child: AppMediaGridShimmer()),
          const SizedBox(height: 20),
          const _SkeletonLabel(label: 'Hero + ranked + landscape'),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              return Column(
                children: [
                  AppHeroShimmer(
                    height: width < 600 ? 190 : 240,
                  ),
                  const SizedBox(height: 18),
                  const SizedBox(height: 190, child: AppRankedRowShimmer()),
                  const SizedBox(height: 18),
                  const SizedBox(height: 165, child: AppLandscapeRowShimmer()),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SkeletonLabel extends StatelessWidget {
  final String label;

  const _SkeletonLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          const Icon(Icons.animation_rounded, size: 14, color: Colors.white38),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _GalleryPanel extends StatelessWidget {
  final Widget child;

  const _GalleryPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF12151D),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Padding(padding: const EdgeInsets.all(18), child: child),
    );
  }
}

class _GalleryPosterCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final double width;
  final Color color;

  const _GalleryPosterCard({
    required this.title,
    required this.subtitle,
    required this.width,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 2 / 3,
            child: _GalleryImage(
              color: color,
              icon: Icons.movie_creation_outlined,
              label: 'POSTER',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _GalleryLandscapeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final double width;
  final Color color;

  const _GalleryLandscapeCard({
    required this.title,
    required this.subtitle,
    required this.width,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _GalleryImage(
                  color: color,
                  icon: Icons.play_circle_outline_rounded,
                  label: '16 : 9',
                ),
                const Positioned(
                  right: 10,
                  bottom: 10,
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.white24,
                    child: Icon(Icons.play_arrow_rounded, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _GalleryRankedCard extends StatelessWidget {
  final String title;
  final List<String> items;

  const _GalleryRankedCard({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 250,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < items.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                children: [
                  SizedBox(
                    width: 30,
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        color: i == 0 ? const Color(0xFFFFC857) : Colors.white38,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      items[i],
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                  const SizedBox(width: 4),
                  Text(
                    '${8 + i}.${7 - i}',
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _GalleryCreatorCard extends StatelessWidget {
  final String name;
  final String role;
  final Color color;

  const _GalleryCreatorCard({
    required this.name,
    required this.role,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Column(
        children: [
          CircleAvatar(
            radius: 48,
            backgroundColor: color,
            child: const Icon(Icons.person_rounded, size: 48, color: Colors.white70),
          ),
          const SizedBox(height: 10),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 3),
          Text(
            role,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _GalleryStudioCard extends StatelessWidget {
  final String name;
  final String videos;
  final Color color;

  const _GalleryStudioCard({
    required this.name,
    required this.videos,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Stack(
        children: [
          AspectRatio(
            aspectRatio: 1.65,
            child: _GalleryImage(
              color: color,
              icon: Icons.business_rounded,
              label: 'STUDIO',
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 10,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  videos,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GalleryHeroCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;

  const _GalleryHeroCard({
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 190,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _GalleryImage(
            color: color,
            icon: Icons.auto_awesome_motion_rounded,
            label: 'HERO / BANNER',
          ),
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
            left: 18,
            right: 18,
            bottom: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GalleryMiniLayout extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;

  const _GalleryMiniLayout({
    required this.icon,
    required this.title,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .04),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFAE92FF)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  detail,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GalleryTagCard extends StatelessWidget {
  final int number;
  final String title;
  final double width;
  final Color color;

  const _GalleryTagCard({
    required this.number,
    required this.title,
    required this.width,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 76,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: ColoredBox(
          color: color,
          child: Stack(
            children: [
              Positioned(
                right: -7,
                top: -15,
                child: Text(
                  '$number',
                  style: const TextStyle(
                    color: Colors.white12,
                    fontSize: 72,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Positioned(
                left: 13,
                right: 10,
                bottom: 11,
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
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

class _GalleryImage extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;

  const _GalleryImage({
    required this.color,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, Color.lerp(color, Colors.black, .58)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            right: -16,
            top: -22,
            child: Icon(icon, size: 120, color: Colors.white.withValues(alpha: .08)),
          ),
          Center(
            child: Icon(icon, size: 30, color: Colors.white.withValues(alpha: .72)),
          ),
          Positioned(
            left: 12,
            bottom: 10,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}