import 'dart:ui';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/modules/home/services/anilist_discovery_service.dart';

/// Full AniList-style detail view for an [AnilistMedia] item.
/// Sections: banner hero → stats → synopsis → info grid → characters+VA →
///           staff → episodes (streamingEpisodes) → watch → relations → recommendations.
class AnilistDetailScreen extends ConsumerStatefulWidget {
  final AnilistMedia media;
  const AnilistDetailScreen({super.key, required this.media});

  @override
  ConsumerState<AnilistDetailScreen> createState() =>
      _AnilistDetailScreenState();
}

class _AnilistDetailScreenState extends ConsumerState<AnilistDetailScreen>
    with SingleTickerProviderStateMixin {
  bool _descExpanded = false;
  late final TabController _watchTabCtrl;

  @override
  void initState() {
    super.initState();
    _watchTabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _watchTabCtrl.dispose();
    super.dispose();
  }

  // ── helpers ──────────────────────────────────────────────────────────────────

  String _fmtStatus(String? s) => switch (s) {
        'FINISHED' => 'Terminé',
        'RELEASING' => 'En cours',
        'NOT_YET_RELEASED' => 'À venir',
        'CANCELLED' => 'Annulé',
        'HIATUS' => 'En pause',
        _ => s ?? '—',
      };

  String _fmtSeason(String? season, int? year) {
    final parts = <String>[];
    if (season != null) parts.add('${season[0]}${season.substring(1).toLowerCase()}');
    if (year != null) parts.add(year.toString());
    return parts.isEmpty ? '—' : parts.join(' ');
  }

  String _fmtSource(String? s) {
    if (s == null) return '—';
    return s.replaceAll('_', ' ').split(' ').map((w) {
      if (w.isEmpty) return w;
      return '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}';
    }).join(' ');
  }

  String _fmtRelation(String? r) => switch (r) {
        'SEQUEL' => 'Suite',
        'PREQUEL' => 'Préquel',
        'PARENT' => 'Parent',
        'SIDE_STORY' => 'Histoire annexe',
        'SPIN_OFF' => 'Spin-off',
        'ADAPTATION' => 'Adaptation',
        'ALTERNATIVE' => 'Alternatif',
        'SOURCE' => 'Source',
        'COMPILATION' => 'Compilation',
        'CHARACTER' => 'Personnage',
        'SUMMARY' => 'Résumé',
        'CONTAINS' => 'Contient',
        'OTHER' => 'Autre',
        _ => r ?? '',
      };

  // ── build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final m = widget.media;
    final detail = ref.watch(anilistMediaDetailProvider(m.id));
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final screenH = MediaQuery.of(context).size.height;
    final screenW = MediaQuery.of(context).size.width;
    final banner = m.bannerImage;
    final cover = m.bestCover;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Hero banner ────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Stack(
              children: [
                // Full-width banner (sharp, like AniList)
                SizedBox(
                  width: screenW,
                  height: screenH * 0.30,
                  child: banner != null
                      ? ExtendedImage.network(
                          banner,
                          fit: BoxFit.cover,
                          alignment: Alignment.center,
                          cache: true,
                        )
                      : cover != null
                          ? Stack(
                              fit: StackFit.expand,
                              children: [
                                ExtendedImage.network(
                                  cover,
                                  fit: BoxFit.cover,
                                  alignment: Alignment.center,
                                  cache: true,
                                ),
                                BackdropFilter(
                                  filter: ImageFilter.blur(
                                      sigmaX: 18, sigmaY: 18),
                                  child: Container(
                                      color: Colors.black
                                          .withValues(alpha: 0.30)),
                                ),
                              ],
                            )
                          : Container(color: cs.surfaceContainerHighest),
                ),
                // Gradient overlay bottom
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: screenH * 0.16,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          theme.scaffoldBackgroundColor,
                        ],
                      ),
                    ),
                  ),
                ),
                // Nav bar
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    bottom: false,
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
                            onTap: () {
                              launchUrl(
                                Uri.parse(
                                    'https://anilist.co/${m.type.toLowerCase()}/${m.id}'),
                                mode: LaunchMode.externalApplication,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Cover poster overlapping bottom-left of banner
                Positioned(
                  bottom: 0,
                  left: 20,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        width: 100,
                        height: 145,
                        child: cover != null
                            ? ExtendedImage.network(
                                cover,
                                fit: BoxFit.cover,
                                cache: true,
                              )
                            : Container(
                                color: cs.surfaceContainerHighest,
                                child: const Icon(
                                    Icons.movie_outlined, size: 36),
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Title + badges ─────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(136, 8, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _TypeBadge(m.type, m.format, m.countryOfOrigin),
                      if (m.averageScore != null) ...[
                        const SizedBox(width: 8),
                        _ScorePill(m.averageScore!),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    m.displayTitle,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (m.titleRomaji != null &&
                      m.titleRomaji != m.displayTitle) ...[
                    const SizedBox(height: 3),
                    Text(
                      m.titleRomaji!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.5),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ── Extra space so cover poster clears ─────────────────────────────
          const SliverToBoxAdapter(child: SizedBox(height: 56)),

          // ── Action buttons ─────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: _ActionBtn(
                      icon: Icons.collections_bookmark_outlined,
                      label: 'Ajouter à la bibliothèque',
                      primary: true,
                      onTap: () {
                        final type = m.type == 'MANGA'
                            ? ItemType.manga
                            : ItemType.anime;
                        context.push('/globalSearch',
                            extra: (m.displayTitle, type));
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  _ActionBtn(
                    icon: Icons.play_circle_outline_rounded,
                    label: null,
                    width: 52,
                    onTap: () {
                      final type = m.type == 'MANGA'
                          ? ItemType.manga
                          : ItemType.anime;
                      context.push('/globalSearch',
                          extra: (m.displayTitle, type));
                    },
                  ),
                  const SizedBox(width: 8),
                  _ActionBtn(
                    icon: Icons.share_outlined,
                    label: null,
                    width: 52,
                    onTap: () {
                      launchUrl(
                        Uri.parse(
                            'https://anilist.co/${m.type.toLowerCase()}/${m.id}'),
                        mode: LaunchMode.externalApplication,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 18)),

          // ── Genre chips ────────────────────────────────────────────────────
          if (m.genres.isNotEmpty)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 34,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: m.genres.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => _GenreChip(m.genres[i]),
                ),
              ),
            ),

          if (m.genres.isNotEmpty)
            const SliverToBoxAdapter(child: SizedBox(height: 18)),

          // ── Information grid ───────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: detail.when(
                loading: () => _StatsGrid(media: m, detail: null),
                error: (_, __) => _StatsGrid(media: m, detail: null),
                data: (d) => _StatsGrid(media: m, detail: d),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // ── Synopsis ───────────────────────────────────────────────────────
          if (m.description != null && m.description!.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionTitle(
                          icon: Icons.description_outlined,
                          label: 'Synopsis'),
                      const SizedBox(height: 10),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                        child: Text(
                          m.description!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            height: 1.58,
                            color: cs.onSurface.withValues(alpha: 0.82),
                          ),
                          maxLines: _descExpanded ? null : 5,
                          overflow: _descExpanded
                              ? TextOverflow.visible
                              : TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () =>
                            setState(() => _descExpanded = !_descExpanded),
                        child: Text(
                          _descExpanded ? 'Voir moins' : 'Voir plus',
                          style: TextStyle(
                            color: cs.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          if (m.description != null && m.description!.isNotEmpty)
            const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // ── Studios & Tags ─────────────────────────────────────────────────
          if (detail.asData?.value?.studios.isNotEmpty == true)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionTitle(
                          icon: Icons.business_rounded, label: 'Studios'),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: detail.asData!.value!.studios
                            .map((s) => _StudioPill(s))
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          if (detail.asData?.value?.studios.isNotEmpty == true)
            const SliverToBoxAdapter(child: SizedBox(height: 16)),

          if (detail.asData?.value?.tags.isNotEmpty == true)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionTitle(
                          icon: Icons.label_outline_rounded, label: 'Tags'),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: detail.asData!.value!.tags
                            .map((t) => _TagPill(t))
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          if (detail.asData?.value?.tags.isNotEmpty == true)
            const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // ── Characters + Voice Actors (AniList row style) ──────────────────
          if (detail.asData?.value?.characters.isNotEmpty == true) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Row(
                  children: [
                    _SectionTitle(
                        icon: Icons.people_outline_rounded,
                        label: 'Personnages'),
                    const Spacer(),
                  ],
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) {
                  final c = detail.asData!.value!.characters[i];
                  return _CharacterVARow(
                    character: c,
                    onCharTap: () => context.push('/anilistCharacter',
                        extra: (c.id, c.name, c.imageUrl)),
                    onVATap: c.voiceActors.isNotEmpty
                        ? () {
                            final va = c.voiceActors.first;
                            context.push('/anilistStaff',
                                extra: (va.id, va.name, va.imageUrl));
                          }
                        : null,
                  );
                },
                childCount: detail.asData!.value!.characters.length,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
          ],

          // ── Episodes (from AniList streamingEpisodes) ──────────────────────
          if (detail.asData?.value?.streamingEpisodes.isNotEmpty == true) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: _SectionTitle(
                    icon: Icons.play_circle_outline_rounded,
                    label: 'Épisodes disponibles'),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 170,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount:
                      detail.asData!.value!.streamingEpisodes.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, i) {
                    final ep =
                        detail.asData!.value!.streamingEpisodes[i];
                    return _EpisodeCard(
                      episode: ep,
                      index: i + 1,
                      onTap: () {
                        if (ep.url != null) {
                          launchUrl(Uri.parse(ep.url!),
                              mode: LaunchMode.externalApplication);
                        }
                      },
                    );
                  },
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
          ],

          // ── Regarder (streaming) ───────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _WatchSection(
                media: m,
                episodeCount: detail.asData?.value?.base.episodes ??
                    m.episodes,
                onSearch: () {
                  final type = m.type == 'MANGA'
                      ? ItemType.manga
                      : ItemType.anime;
                  context.push('/globalSearch',
                      extra: (m.displayTitle, type));
                },
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // ── Trailer ────────────────────────────────────────────────────────
          if (detail.asData?.value?.trailerUrl != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionTitle(
                          icon: Icons.play_circle_outline_rounded,
                          label: 'Bande-annonce'),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () => launchUrl(
                          Uri.parse(
                              detail.asData!.value!.trailerUrl!),
                          mode: LaunchMode.externalApplication,
                        ),
                        child: Container(
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.red.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.play_arrow_rounded,
                                  color: Colors.red, size: 28),
                              const SizedBox(width: 8),
                              Text(
                                'Ouvrir sur YouTube',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          if (detail.asData?.value?.trailerUrl != null)
            const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // ── Relations ──────────────────────────────────────────────────────
          if (detail.asData?.value?.relations.isNotEmpty == true)
            _HorizontalSection(
              title: 'Relations',
              icon: Icons.account_tree_outlined,
              height: 190,
              itemCount: detail.asData!.value!.relations.length,
              itemBuilder: (i) {
                final r = detail.asData!.value!.relations[i];
                return _RelationCard(
                  relation: r,
                  relationLabel: _fmtRelation(r.relationType),
                  onTap: () => context.push('/anilistDetail',
                      extra: AnilistMedia(
                        id: r.id,
                        type: r.type,
                        format: r.format,
                        titleRomaji: r.title,
                        coverLarge: r.coverImage,
                      )),
                );
              },
            ),

          if (detail.asData?.value?.relations.isNotEmpty == true)
            const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // ── Recommendations ────────────────────────────────────────────────
          if (detail.asData?.value?.recommendations.isNotEmpty == true)
            _HorizontalSection(
              title: 'Dans la même veine',
              icon: Icons.thumb_up_outlined,
              height: 195,
              itemCount: detail.asData!.value!.recommendations.length,
              itemBuilder: (i) {
                final r = detail.asData!.value!.recommendations[i];
                return _RecommendCard(
                  media: r,
                  onTap: () => context.push('/anilistDetail', extra: r),
                );
              },
            ),

          if (detail.asData?.value?.recommendations.isNotEmpty == true)
            const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // ── AniList threads link ───────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GestureDetector(
                onTap: () => launchUrl(
                  Uri.parse(
                      'https://anilist.co/${m.type.toLowerCase()}/${m.id}/social'),
                  mode: LaunchMode.externalApplication,
                ),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLow.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: cs.outlineVariant.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.forum_outlined,
                          color: cs.primary, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        'Discussions & avis sur AniList',
                        style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.open_in_new_rounded,
                          size: 16,
                          color: cs.onSurface.withValues(alpha: 0.4)),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Loading indicator
          if (detail.isLoading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Character + Voice Actor row (AniList format)
// ─────────────────────────────────────────────────────────────────────────────

class _CharacterVARow extends StatelessWidget {
  final AnilistCharacter character;
  final VoidCallback? onCharTap;
  final VoidCallback? onVATap;

  const _CharacterVARow({
    required this.character,
    this.onCharTap,
    this.onVATap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final va = character.voiceActors.isNotEmpty
        ? character.voiceActors.first
        : null;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.2), width: 0.8),
      ),
      child: Row(
        children: [
          // ── Left: character ──────────────────────────────────────────────
          GestureDetector(
            onTap: onCharTap,
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(11),
                bottomLeft: Radius.circular(11),
              ),
              child: SizedBox(
                width: 52,
                height: 74,
                child: character.imageUrl != null
                    ? ExtendedImage.network(
                        character.imageUrl!,
                        fit: BoxFit.cover,
                        cache: true,
                      )
                    : Container(
                        color: cs.surfaceContainerHighest,
                        child: const Icon(Icons.person_rounded, size: 24),
                      ),
              ),
            ),
          ),
          // ── Character info ────────────────────────────────────────────────
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: onCharTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    character.name,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (character.role != null)
                    Text(
                      _roleLabel(character.role),
                      style: TextStyle(
                        fontSize: 10.5,
                        color: cs.onSurface.withValues(alpha: 0.52),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // ── VA info ───────────────────────────────────────────────────────
          if (va != null) ...[
            Expanded(
              child: GestureDetector(
                onTap: onVATap,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      va.name,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                    ),
                    Text(
                      va.language,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: cs.onSurface.withValues(alpha: 0.52),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            // VA image
            GestureDetector(
              onTap: onVATap,
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(11),
                  bottomRight: Radius.circular(11),
                ),
                child: SizedBox(
                  width: 52,
                  height: 74,
                  child: va.imageUrl != null
                      ? ExtendedImage.network(
                          va.imageUrl!,
                          fit: BoxFit.cover,
                          cache: true,
                        )
                      : Container(
                          color: cs.surfaceContainerHighest,
                          child: const Icon(Icons.person_rounded, size: 24),
                        ),
                ),
              ),
            ),
          ] else
            const SizedBox(width: 10),
        ],
      ),
    );
  }

  String _roleLabel(String? role) {
    return switch (role) {
      'MAIN' => 'Principal',
      'SUPPORTING' => 'Secondaire',
      'BACKGROUND' => 'Fond',
      _ => role ?? '',
    };
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Episode card (streamingEpisodes)
// ─────────────────────────────────────────────────────────────────────────────

class _EpisodeCard extends StatelessWidget {
  final AnilistStreamingEpisode episode;
  final int index;
  final VoidCallback onTap;

  const _EpisodeCard(
      {required this.episode, required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 200,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 200,
                height: 112,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    episode.thumbnail != null
                        ? ExtendedImage.network(
                            episode.thumbnail!,
                            fit: BoxFit.cover,
                            cache: true,
                          )
                        : Container(
                            color: cs.surfaceContainerHighest,
                            child: const Icon(Icons.play_circle_outline,
                                size: 36),
                          ),
                    // Play icon overlay
                    Container(
                      color: Colors.black.withValues(alpha: 0.20),
                      child: const Center(
                        child: Icon(Icons.play_circle_rounded,
                            color: Colors.white, size: 36),
                      ),
                    ),
                    // Episode number badge
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'EP $index',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    // Site badge
                    if (episode.site != null)
                      Positioned(
                        bottom: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            episode.site!,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              episode.title ?? 'Épisode $index',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Watch section (streaming)
// ─────────────────────────────────────────────────────────────────────────────

class _WatchSection extends StatelessWidget {
  final AnilistMedia media;
  final int? episodeCount;
  final VoidCallback onSearch;

  const _WatchSection({
    required this.media,
    this.episodeCount,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
              icon: Icons.play_circle_outline_rounded, label: 'Regarder'),
          const SizedBox(height: 12),
          if (episodeCount != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: cs.primaryContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: cs.primary.withValues(alpha: 0.3), width: 0.8),
              ),
              child: Row(
                children: [
                  Icon(Icons.download_rounded, size: 18, color: cs.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Télécharger les $episodeCount épisodes',
                    style: TextStyle(
                        color: cs.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13),
                  ),
                ],
              ),
            ),
          // Stream button (opens extension search)
          GestureDetector(
            onTap: onSearch,
            child: Container(
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                color: cs.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.search_rounded,
                      color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Rechercher une source de streaming',
                    style: TextStyle(
                      color: cs.onPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Torrent link
          GestureDetector(
            onTap: () => launchUrl(
              Uri.parse(
                  'https://nyaa.si/?f=0&c=1_2&q=${Uri.encodeComponent(media.displayTitle)}'),
              mode: LaunchMode.externalApplication,
            ),
            child: Container(
              width: double.infinity,
              height: 46,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_download_outlined,
                      color: cs.onSurface.withValues(alpha: 0.8), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Torrent (Nyaa)',
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
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

// ─────────────────────────────────────────────────────────────────────────────
// Stats grid
// ─────────────────────────────────────────────────────────────────────────────

class _StatsGrid extends StatelessWidget {
  final AnilistMedia media;
  final AnilistMediaDetail? detail;
  const _StatsGrid({required this.media, required this.detail});

  String _fmtStatus(String? s) => switch (s) {
        'FINISHED' => 'Terminé',
        'RELEASING' => 'En cours',
        'NOT_YET_RELEASED' => 'À venir',
        'CANCELLED' => 'Annulé',
        'HIATUS' => 'En pause',
        _ => s ?? '—',
      };

  String _fmtSeason(String? season, int? year) {
    final parts = <String>[];
    if (season != null) parts.add('${season[0]}${season.substring(1).toLowerCase()}');
    if (year != null) parts.add(year.toString());
    return parts.isEmpty ? '—' : parts.join(' ');
  }

  String _fmtSource(String? s) {
    if (s == null) return '—';
    return s.replaceAll('_', ' ').split(' ').map((w) {
      if (w.isEmpty) return w;
      return '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}';
    }).join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final m = media;
    final d = detail;
    final epLabel = m.type == 'MANGA' ? 'Chapitres' : 'Épisodes';
    final epVal = m.type == 'MANGA'
        ? (m.chapters?.toString() ?? '—')
        : (m.episodes?.toString() ?? '—');

    final stats = [
      _Stat(icon: Icons.category_outlined, label: 'Format',
          value: m.format?.replaceAll('_', ' ') ?? '—'),
      _Stat(icon: Icons.star_rounded, label: 'Score',
          value: m.averageScore != null
              ? '${(m.averageScore! / 10).toStringAsFixed(1)}/10'
              : '—'),
      _Stat(icon: Icons.live_tv_outlined, label: epLabel, value: epVal),
      _Stat(icon: Icons.info_outline_rounded, label: 'Statut',
          value: _fmtStatus(d?.status)),
      _Stat(icon: Icons.calendar_month_outlined, label: 'Saison',
          value: _fmtSeason(d?.season, d?.seasonYear ?? d?.startYear)),
      _Stat(icon: Icons.public_outlined, label: 'Pays',
          value: switch (m.countryOfOrigin) {
            'JP' => '🇯🇵 Japon',
            'KR' => '🇰🇷 Corée',
            'CN' => '🇨🇳 Chine',
            'TW' => '🇹🇼 Taïwan',
            _ => m.countryOfOrigin ?? '—',
          }),
      if (d?.duration != null)
        _Stat(icon: Icons.timer_outlined, label: 'Durée',
            value: '${d!.duration} min'),
      if (d?.source != null)
        _Stat(icon: Icons.menu_book_outlined, label: 'Source',
            value: _fmtSource(d!.source)),
      if (d?.popularity != null)
        _Stat(icon: Icons.trending_up_rounded, label: 'Popularité',
            value: '${d!.popularity}'),
      if (d?.favourites != null)
        _Stat(icon: Icons.favorite_rounded, label: 'Favoris',
            value: '${d!.favourites}'),
    ];

    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
              icon: Icons.bar_chart_rounded, label: 'Informations'),
          const SizedBox(height: 12),
          GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 2.8,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: stats.length,
            itemBuilder: (_, i) => _StatTile(stats[i]),
          ),
        ],
      ),
    );
  }
}

class _Stat {
  final IconData icon;
  final String label;
  final String value;
  const _Stat({required this.icon, required this.label, required this.value});
}

class _StatTile extends StatelessWidget {
  final _Stat stat;
  const _StatTile(this.stat);
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(stat.icon, size: 15, color: cs.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(stat.label,
                    style: TextStyle(
                        fontSize: 9.5,
                        color: cs.onSurface.withValues(alpha: 0.5),
                        fontWeight: FontWeight.w500)),
                Text(stat.value,
                    style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface,
                        fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Horizontal section (relations, recommendations)
// ─────────────────────────────────────────────────────────────────────────────

class _HorizontalSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final double height;
  final int itemCount;
  final Widget Function(int) itemBuilder;
  const _HorizontalSection({
    required this.title,
    required this.icon,
    required this.height,
    required this.itemCount,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _SectionTitle(icon: icon, label: title),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: height,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: itemCount,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) => itemBuilder(i),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Relation card
// ─────────────────────────────────────────────────────────────────────────────

class _RelationCard extends StatelessWidget {
  final AnilistRelation relation;
  final String relationLabel;
  final VoidCallback onTap;
  const _RelationCard(
      {required this.relation,
      required this.relationLabel,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 100,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 100,
                height: 138,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    relation.coverImage != null
                        ? ExtendedImage.network(relation.coverImage!,
                            fit: BoxFit.cover, cache: true)
                        : Container(color: cs.surfaceContainerHighest),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 4),
                        color: Colors.black.withValues(alpha: 0.65),
                        child: Text(
                          relationLabel,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              relation.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Recommend card
// ─────────────────────────────────────────────────────────────────────────────

class _RecommendCard extends StatelessWidget {
  final AnilistMedia media;
  final VoidCallback onTap;
  const _RecommendCard({required this.media, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 100,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 100,
                height: 148,
                child: media.bestCover != null
                    ? ExtendedImage.network(media.bestCover!,
                        fit: BoxFit.cover, cache: true)
                    : Container(color: cs.surfaceContainerHighest),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              media.displayTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface),
            ),
            if (media.averageScore != null)
              Row(
                children: [
                  const Icon(Icons.star_rounded,
                      size: 11, color: Colors.amber),
                  const SizedBox(width: 2),
                  Text(
                    (media.averageScore! / 10).toStringAsFixed(1),
                    style: TextStyle(
                        fontSize: 10,
                        color: cs.onSurface.withValues(alpha: 0.6)),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared helpers / primitives
// ─────────────────────────────────────────────────────────────────────────────

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
        borderRadius: BorderRadius.circular(18),
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
          color: cs.surfaceContainerLow.withValues(alpha: 0.75),
          border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.3)),
        ),
        child: Icon(icon, color: cs.onSurface, size: 20),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String? label;
  final bool primary;
  final double? width;
  final VoidCallback onTap;
  const _ActionBtn({
    required this.icon,
    required this.onTap,
    this.label,
    this.primary = false,
    this.width,
  });
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: primary
              ? cs.primary
              : cs.surfaceContainerHighest.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(14),
          border: primary
              ? null
              : Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: primary ? cs.onPrimary : cs.onSurface, size: 20),
            if (label != null) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label!,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: primary ? cs.onPrimary : cs.onSurface,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final String type;
  final String? format;
  final String? country;
  const _TypeBadge(this.type, this.format, this.country);
  String get _label {
    if (format == 'NOVEL') return 'Novel';
    if (country == 'KR') return 'Manhwa';
    if (country == 'CN') return 'Manhua';
    return type == 'MANGA' ? 'Manga' : 'Anime';
  }
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(_label,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: cs.onPrimaryContainer,
              letterSpacing: 0.5)),
    );
  }
}

class _ScorePill extends StatelessWidget {
  final int score;
  const _ScorePill(this.score);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 13, color: Colors.amber),
          const SizedBox(width: 3),
          Text(
            (score / 10).toStringAsFixed(1),
            style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: Colors.amber),
          ),
        ],
      ),
    );
  }
}

class _GenreChip extends StatelessWidget {
  final String genre;
  const _GenreChip(this.genre);
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: cs.secondaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.secondary.withValues(alpha: 0.25)),
      ),
      child: Text(genre,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: cs.onSecondaryContainer)),
    );
  }
}

class _StudioPill extends StatelessWidget {
  final String name;
  const _StudioPill(this.name);
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: cs.tertiaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.tertiary.withValues(alpha: 0.3)),
      ),
      child: Text(name,
          style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: cs.onTertiaryContainer)),
    );
  }
}

class _TagPill extends StatelessWidget {
  final String tag;
  const _TagPill(this.tag);
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(tag,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: cs.onSurface.withValues(alpha: 0.75))),
    );
  }
}
