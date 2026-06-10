import 'dart:ui';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:watchtower/modules/home/services/anilist_discovery_service.dart';

/// AniList-style staff/voice-actor detail page.
class AnilistStaffScreen extends ConsumerStatefulWidget {
  final int staffId;
  final String staffName;
  final String? staffImage;
  const AnilistStaffScreen({
    super.key,
    required this.staffId,
    required this.staffName,
    this.staffImage,
  });

  @override
  ConsumerState<AnilistStaffScreen> createState() =>
      _AnilistStaffScreenState();
}

class _AnilistStaffScreenState extends ConsumerState<AnilistStaffScreen>
    with SingleTickerProviderStateMixin {
  bool _descExpanded = false;
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(anilistStaffDetailProvider(widget.staffId));
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Blurred background
          if (widget.staffImage != null)
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                child: ExtendedImage.network(
                  widget.staffImage!,
                  fit: BoxFit.cover,
                  cache: true,
                ),
              ),
            ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.6),
                    theme.scaffoldBackgroundColor.withValues(alpha: 0.95),
                    theme.scaffoldBackgroundColor,
                  ],
                  stops: const [0.0, 0.35, 0.7],
                ),
              ),
            ),
          ),

          SafeArea(
            child: NestedScrollView(
              headerSliverBuilder: (ctx, _) => [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        _CircleBtn(
                          icon: Icons.arrow_back_rounded,
                          onTap: () => Navigator.of(context).maybePop(),
                        ),
                        const Spacer(),
                        _CircleBtn(
                          icon: Icons.open_in_browser_rounded,
                          onTap: () => launchUrl(
                            Uri.parse(
                                'https://anilist.co/staff/${widget.staffId}'),
                            mode: LaunchMode.externalApplication,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Staff image + info header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: SizedBox(
                            width: 150,
                            height: 210,
                            child: detail.when(
                              loading: () => widget.staffImage != null
                                  ? ExtendedImage.network(widget.staffImage!,
                                      fit: BoxFit.cover, cache: true)
                                  : Container(
                                      color: cs.surfaceContainerHighest,
                                      child: const Center(
                                          child:
                                              CircularProgressIndicator())),
                              error: (_, __) => widget.staffImage != null
                                  ? ExtendedImage.network(widget.staffImage!,
                                      fit: BoxFit.cover, cache: true)
                                  : Container(
                                      color: cs.surfaceContainerHighest,
                                      child: const Icon(
                                          Icons.person_rounded, size: 48)),
                              data: (d) => d.imageUrl != null
                                  ? ExtendedImage.network(d.imageUrl!,
                                      fit: BoxFit.cover, cache: true)
                                  : widget.staffImage != null
                                      ? ExtendedImage.network(
                                          widget.staffImage!,
                                          fit: BoxFit.cover, cache: true)
                                      : Container(
                                          color: cs.surfaceContainerHighest,
                                          child: const Icon(
                                              Icons.person_rounded, size: 48)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          detail.asData?.value?.name ?? widget.staffName,
                          style:
                              theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (detail.asData?.value?.nameNative != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            detail.asData!.value!.nameNative!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurface.withValues(alpha: 0.55),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        if (detail.asData?.value?.language != null) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: cs.primaryContainer,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              detail.asData!.value!.language!,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: cs.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                        if (detail.asData?.value?.occupations.isNotEmpty ==
                            true) ...[
                          const SizedBox(height: 6),
                          Text(
                            detail.asData!.value!.occupations.join(', '),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurface.withValues(alpha: 0.6),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        if (detail.asData?.value?.favourites != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.favorite_rounded,
                                  size: 14, color: Colors.pinkAccent),
                              const SizedBox(width: 4),
                              Text(
                                '${detail.asData!.value!.favourites} favoris',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: cs.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Info grid
                if (detail.asData?.value != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _StaffInfoGrid(detail: detail.asData!.value!),
                    ),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 12)),

                // Description
                if (detail.asData?.value?.description?.isNotEmpty == true)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SectionTitle(
                                icon: Icons.description_outlined,
                                label: 'Description'),
                            const SizedBox(height: 10),
                            AnimatedSize(
                              duration: const Duration(milliseconds: 280),
                              child: Text(
                                detail.asData!.value!.description!,
                                style:
                                    theme.textTheme.bodySmall?.copyWith(
                                  height: 1.6,
                                  color: cs.onSurface.withValues(alpha: 0.8),
                                ),
                                maxLines: _descExpanded ? null : 5,
                                overflow: _descExpanded
                                    ? TextOverflow.visible
                                    : TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: () => setState(
                                  () => _descExpanded = !_descExpanded),
                              child: Text(
                                _descExpanded ? 'Voir moins' : 'Voir plus',
                                style: TextStyle(
                                    color: cs.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 12)),

                // Tab bar
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _TabBarDelegate(
                    TabBar(
                      controller: _tabCtrl,
                      labelColor: cs.primary,
                      unselectedLabelColor:
                          cs.onSurface.withValues(alpha: 0.5),
                      indicatorColor: cs.primary,
                      indicatorSize: TabBarIndicatorSize.label,
                      labelStyle: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13),
                      tabs: const [
                        Tab(text: 'Personnages'),
                        Tab(text: 'Anime'),
                      ],
                    ),
                    color: theme.scaffoldBackgroundColor,
                  ),
                ),
              ],
              body: TabBarView(
                controller: _tabCtrl,
                children: [
                  // Characters tab
                  detail.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Erreur: $e')),
                    data: (d) => _CharactersList(
                      edges: d.characterRoles,
                      onCharTap: (char) => context.push('/anilistCharacter',
                          extra: (char.id, char.name, char.imageUrl)),
                      onMediaTap: (m) =>
                          context.push('/anilistDetail', extra: m),
                    ),
                  ),
                  // Anime tab
                  detail.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Erreur: $e')),
                    data: (d) => _MediaGrid(
                      edges: d.mediaRoles,
                      onTap: (m) =>
                          context.push('/anilistDetail', extra: m),
                    ),
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

// ── Characters list (roles this staff voiced) ─────────────────────────────────

class _CharactersList extends StatelessWidget {
  final List edges;
  final void Function(AnilistCharacter) onCharTap;
  final void Function(AnilistMedia) onMediaTap;
  const _CharactersList(
      {required this.edges,
      required this.onCharTap,
      required this.onMediaTap});

  @override
  Widget build(BuildContext context) {
    if (edges.isEmpty) {
      return const Center(child: Text('Aucun personnage trouvé'));
    }
    final cs = Theme.of(context).colorScheme;
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: edges.length,
      itemBuilder: (_, i) {
        final e = edges[i] as _StaffCharEdge;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              // Character image
              GestureDetector(
                onTap: () => onCharTap(e.character),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 48,
                    height: 68,
                    child: e.character.imageUrl != null
                        ? ExtendedImage.network(
                            e.character.imageUrl!,
                            fit: BoxFit.cover,
                            cache: true,
                          )
                        : Container(color: cs.surfaceContainerHighest),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Character name + role
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.character.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    if (e.character.role != null)
                      Text(
                        e.character.role!,
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurface.withValues(alpha: 0.55),
                        ),
                      ),
                  ],
                ),
              ),
              // Media cover
              if (e.media != null)
                GestureDetector(
                  onTap: () => onMediaTap(e.media!),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      width: 38,
                      height: 54,
                      child: e.media!.bestCover != null
                          ? ExtendedImage.network(
                              e.media!.bestCover!,
                              fit: BoxFit.cover,
                              cache: true,
                            )
                          : Container(color: cs.surfaceContainerHighest),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ── Media grid (anime this staff worked on) ───────────────────────────────────

class _MediaGrid extends StatelessWidget {
  final List edges;
  final void Function(AnilistMedia) onTap;
  const _MediaGrid({required this.edges, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (edges.isEmpty) {
      return const Center(child: Text('Aucun anime trouvé'));
    }
    final cs = Theme.of(context).colorScheme;
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.62,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: edges.length,
      itemBuilder: (_, i) {
        final e = edges[i] as _StaffMediaEdge;
        return GestureDetector(
          onTap: () => onTap(e.media),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      e.media.bestCover != null
                          ? ExtendedImage.network(
                              e.media.bestCover!,
                              fit: BoxFit.cover,
                              cache: true,
                            )
                          : Container(color: cs.surfaceContainerHighest),
                      if (e.role != null)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 3),
                            color: Colors.black.withValues(alpha: 0.65),
                            child: Text(
                              e.role!,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w500),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                e.media.displayTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── TabBar delegate ────────────────────────────────────────────────────────────

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final Color color;
  const _TabBarDelegate(this.tabBar, {required this.color});

  @override
  double get minExtent => tabBar.preferredSize.height + 1;
  @override
  double get maxExtent => tabBar.preferredSize.height + 1;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: color, child: tabBar);
  }

  @override
  bool shouldRebuild(_TabBarDelegate o) => o.tabBar != tabBar;
}

// ── Shared helpers ─────────────────────────────────────────────────────────────

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.3), width: 1),
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionTitle({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 17, color: cs.primary),
        const SizedBox(width: 7),
        Text(label,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: cs.onSurface)),
      ],
    );
  }
}

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: cs.surfaceContainerLow.withValues(alpha: 0.8),
          border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.3)),
        ),
        child: Icon(icon, color: cs.onSurface, size: 20),
      ),
    );
  }
}

class _StaffInfoGrid extends StatelessWidget {
  final AnilistStaffDetail detail;
  const _StaffInfoGrid({required this.detail});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final items = <(String, String)>[
      if (detail.gender != null) ('Genre', detail.gender!),
      if (detail.age != null) ('Âge', detail.age!),
      if (detail.bloodType != null) ('Groupe sanguin', detail.bloodType!),
    ];
    if (items.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: items.map((item) {
          return Column(children: [
            Text(item.$2,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface)),
            const SizedBox(height: 2),
            Text(item.$1,
                style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurface.withValues(alpha: 0.5))),
          ]);
        }).toList(),
      ),
    );
  }
}
