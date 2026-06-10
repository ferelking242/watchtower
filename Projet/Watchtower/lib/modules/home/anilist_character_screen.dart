import 'dart:ui';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:watchtower/modules/home/services/anilist_discovery_service.dart';

/// AniList-style character detail page.
/// Opened when the user taps a character in the anime detail screen.
class AnilistCharacterScreen extends ConsumerStatefulWidget {
  final int characterId;
  final String characterName;
  final String? characterImage;
  const AnilistCharacterScreen({
    super.key,
    required this.characterId,
    required this.characterName,
    this.characterImage,
  });

  @override
  ConsumerState<AnilistCharacterScreen> createState() =>
      _AnilistCharacterScreenState();
}

class _AnilistCharacterScreenState
    extends ConsumerState<AnilistCharacterScreen> {
  bool _descExpanded = false;

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(anilistCharacterDetailProvider(widget.characterId));
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Blurred background from character image
          if (widget.characterImage != null)
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                child: ExtendedImage.network(
                  widget.characterImage!,
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
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Nav bar
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
                                'https://anilist.co/character/${widget.characterId}'),
                            mode: LaunchMode.externalApplication,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Character image + name header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    child: Column(
                      children: [
                        // Large character portrait
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            width: 160,
                            height: 220,
                            color: cs.surfaceContainerHighest,
                            child: detail.when(
                              loading: () => widget.characterImage != null
                                  ? ExtendedImage.network(
                                      widget.characterImage!,
                                      fit: BoxFit.cover,
                                      cache: true,
                                    )
                                  : const Center(
                                      child: CircularProgressIndicator()),
                              error: (_, __) => widget.characterImage != null
                                  ? ExtendedImage.network(
                                      widget.characterImage!,
                                      fit: BoxFit.cover,
                                      cache: true,
                                    )
                                  : const Icon(Icons.person_rounded, size: 48),
                              data: (d) => d.imageUrl != null
                                  ? ExtendedImage.network(
                                      d.imageUrl!,
                                      fit: BoxFit.cover,
                                      cache: true,
                                    )
                                  : widget.characterImage != null
                                      ? ExtendedImage.network(
                                          widget.characterImage!,
                                          fit: BoxFit.cover,
                                          cache: true,
                                        )
                                      : const Icon(Icons.person_rounded,
                                          size: 48),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Name
                        Text(
                          detail.asData?.value?.name ?? widget.characterName,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (detail.asData?.value?.nameNative != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            detail.asData!.value!.nameNative!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: cs.onSurface.withValues(alpha: 0.55),
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

                // Info grid (gender, age, bloodType)
                if (detail.asData?.value != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _InfoGrid(detail: detail.asData!.value!),
                    ),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 16)),

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
                                style: theme.textTheme.bodySmall?.copyWith(
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

                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                // Appearances in anime/manga
                if (detail.asData?.value?.mediaRoles.isNotEmpty == true) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _SectionTitle(
                          icon: Icons.movie_outlined,
                          label: 'Apparitions'),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 10)),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) {
                          final edge =
                              detail.asData!.value!.mediaRoles[i];
                          return _AppearanceCard(
                            media: edge.media,
                            role: edge.role,
                            onTap: () => context.push('/anilistDetail',
                                extra: edge.media),
                          );
                        },
                        childCount: detail.asData!.value!.mediaRoles.length,
                      ),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 0.65,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                    ),
                  ),
                ],

                // Loading indicator
                if (detail.isLoading)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child:
                          Center(child: CircularProgressIndicator()),
                    ),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoGrid extends StatelessWidget {
  final AnilistCharacterDetail detail;
  const _InfoGrid({required this.detail});

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
          return Column(
            children: [
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
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _AppearanceCard extends StatelessWidget {
  final AnilistMedia media;
  final String? role;
  final VoidCallback onTap;
  const _AppearanceCard(
      {required this.media, this.role, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  media.bestCover != null
                      ? ExtendedImage.network(
                          media.bestCover!,
                          fit: BoxFit.cover,
                          cache: true,
                        )
                      : Container(color: cs.surfaceContainerHighest),
                  if (role != null)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 3),
                        color: Colors.black.withValues(alpha: 0.65),
                        child: Text(
                          role!,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w600),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            media.displayTitle,
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
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

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
