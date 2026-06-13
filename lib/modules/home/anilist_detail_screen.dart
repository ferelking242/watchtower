import 'dart:ui';
  import 'package:extended_image/extended_image.dart';
  import 'package:flutter/material.dart';
  import 'package:flutter_riverpod/flutter_riverpod.dart';
  import 'package:go_router/go_router.dart';
  import 'package:watchtower/models/manga.dart';
  import 'package:watchtower/modules/home/services/anilist_discovery_service.dart';

  /// Otraku-style detail screen with tabbed layout:
  /// Overview | Related | Characters | Staff | Reviews
  class AnilistDetailScreen extends ConsumerStatefulWidget {
    final AnilistMedia media;
    const AnilistDetailScreen({super.key, required this.media});

    @override
    ConsumerState<AnilistDetailScreen> createState() =>
        _AnilistDetailScreenState();
  }

  class _AnilistDetailScreenState extends ConsumerState<AnilistDetailScreen>
      with SingleTickerProviderStateMixin {
    late final TabController _tab;
    bool _descExpanded = false;

    @override
    void initState() {
      super.initState();
      _tab = TabController(length: 10, vsync: this);
    }

    @override
    void dispose() {
      _tab.dispose();
      super.dispose();
    }

    // ── helpers ──────────────────────────────────────────────────────────────

    void _openWebview(String url, String title) {
      context.push('/mangawebview', extra: {'url': url, 'title': title});
    }

    String _formatStatus(String? s) => switch (s) {
          'FINISHED' => 'Finished',
          'RELEASING' => 'Releasing',
          'NOT_YET_RELEASED' => 'Not Yet Released',
          'CANCELLED' => 'Cancelled',
          'HIATUS' => 'On Hiatus',
          _ => s ?? '—',
        };

    String _formatSeason(String? season, int? year) {
      if (season == null && year == null) return '—';
      final s =
          season != null ? '${season[0]}${season.substring(1).toLowerCase()}' : '';
      return [s, if (year != null) year.toString()]
          .where((e) => e.isNotEmpty)
          .join(' ');
    }

    String _formatSource(String? s) {
      if (s == null) return '—';
      return s.replaceAll('_', ' ').split(' ').map((w) {
        if (w.isEmpty) return w;
        return '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}';
      }).join(' ');
    }

    String _formatDate(int? y, int? mo, int? d) {
      if (y == null) return '—';
      final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      final mStr = (mo != null && mo >= 1 && mo <= 12) ? months[mo - 1] : '';
      final dStr = d != null ? '$d ' : '';
      return '$dStr$mStr $y'.trim();
    }

    String _friendlyRelationType(String? r) => switch (r) {
          'SEQUEL' => 'Sequel',
          'PREQUEL' => 'Prequel',
          'PARENT' => 'Parent',
          'SIDE_STORY' => 'Side Story',
          'CHARACTER' => 'Character',
          'SUMMARY' => 'Summary',
          'ALTERNATIVE' => 'Alternative',
          'SPIN_OFF' => 'Spin-off',
          'OTHER' => 'Other',
          'SOURCE' => 'Source',
          'COMPILATION' => 'Compilation',
          'CONTAINS' => 'Contains',
          'ADAPTATION' => 'Adaptation',
          _ => r ?? '',
        };

    // ── build ────────────────────────────────────────────────────────────────

    @override
    Widget build(BuildContext context) {
      final m = widget.media;
      final detail = ref.watch(anilistMediaDetailProvider(m.id));
      final theme = Theme.of(context);
      final cs = theme.colorScheme;
      final banner = m.bannerImage ?? m.bestCover;

      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Stack(
          children: [
            // blurred background
            if (banner != null)
              Positioned.fill(
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                  child: ExtendedImage.network(
                    banner,
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
                      Colors.black.withValues(alpha: 0.55),
                      theme.scaffoldBackgroundColor.withValues(alpha: 0.95),
                      theme.scaffoldBackgroundColor,
                    ],
                    stops: const [0.0, 0.45, 1.0],
                  ),
                ),
              ),
            ),

            // content
            SafeArea(
              child: NestedScrollView(
                headerSliverBuilder: (ctx, _) => [
                  // nav bar
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          _CircleBtn(
                            icon: Icons.arrow_back_rounded,
                            onTap: () => Navigator.of(context).maybePop(),
                          ),
                          const SizedBox(width: 10),
                          _CircleBtn(
                            icon: Icons.share_outlined,
                            onTap: () => _openWebview(
                              'https://anilist.co/${m.type.toLowerCase()}/${m.id}',
                              m.displayTitle,
                            ),
                          ),
                          const Spacer(),
                          _CircleBtn(
                            icon: Icons.open_in_browser_rounded,
                            onTap: () => _openWebview(
                              'https://anilist.co/${m.type.toLowerCase()}/${m.id}',
                              m.displayTitle,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // hero: cover + title
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.45),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: SizedBox(
                                width: 110,
                                height: 160,
                                child: m.bestCover != null
                                    ? ExtendedImage.network(m.bestCover!, fit: BoxFit.cover, cache: true)
                                    : Container(
                                        color: cs.surfaceContainerHighest,
                                        child: const Icon(Icons.image_not_supported_outlined),
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
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
                                const SizedBox(height: 8),
                                Text(
                                  m.displayTitle,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    height: 1.2,
                                  ),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (m.titleRomaji != null && m.titleRomaji != m.displayTitle) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    m.titleRomaji!,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: cs.onSurface.withValues(alpha: 0.55),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 20)),

                  // action buttons: [Add to Library]
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: _ActionBtn(
                              icon: Icons.collections_bookmark_outlined,
                              label: 'Add to Library',
                              primary: true,
                              onTap: () {
                                final type = m.type == 'MANGA' ? ItemType.manga : ItemType.anime;
                                context.push('/globalSearch', extra: (m.displayTitle, type));
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 16)),

                  // ── TAB BAR ──────────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: TabBar(
                      controller: _tab,
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      dividerColor: Colors.transparent,
                      indicatorColor: cs.primary,
                      indicatorWeight: 2.5,
                      labelColor: cs.primary,
                      unselectedLabelColor: cs.onSurface.withValues(alpha: 0.5),
                      labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13.5),
                      tabs: const [
                        Tab(text: 'Overview'),
                        Tab(text: 'Related'),
                        Tab(text: 'Characters'),
                        Tab(text: 'Staff'),
                        Tab(text: 'Reviews'),
                        Tab(text: 'Threads'),
                        Tab(text: 'Following'),
                        Tab(text: 'Activities'),
                        Tab(text: 'Recommendations'),
                        Tab(text: 'Statistics'),
                      ],
                    ),
                  ),

                  SliverToBoxAdapter(
                    child: Divider(
                      height: 1,
                      thickness: 1,
                      color: cs.outlineVariant.withValues(alpha: 0.3),
                    ),
                  ),
                ],
                body: TabBarView(
                  controller: _tab,
                  children: [
                    // ── Overview ──────────────────────────────────────────
                    _buildOverview(context, m, detail),
                    // ── Related ───────────────────────────────────────────
                    _buildRelated(context, detail),
                    // ── Characters ────────────────────────────────────────
                    _buildCharacters(context, detail),
                    // ── Staff ─────────────────────────────────────────────
                    _buildStaff(context, detail),
                    // ── Reviews ───────────────────────────────────────────
                    _buildReviews(context, detail),
                    // ── Threads ───────────────────────────────────────────
                    _buildWebviewTab(
                      context, m,
                      'https://anilist.co/${m.type.toLowerCase()}/${m.id}/social',
                      'Threads',
                      Icons.forum_outlined,
                    ),
                    // ── Following ─────────────────────────────────────────
                    _buildWebviewTab(
                      context, m,
                      'https://anilist.co/${m.type.toLowerCase()}/${m.id}/social',
                      'Following',
                      Icons.people_outline_rounded,
                    ),
                    // ── Activities ────────────────────────────────────────
                    _buildWebviewTab(
                      context, m,
                      'https://anilist.co/${m.type.toLowerCase()}/${m.id}/social',
                      'Activities',
                      Icons.local_activity_outlined,
                    ),
                    // ── Recommendations ───────────────────────────────────
                    _buildRecommendations(context, detail),
                    // ── Statistics ────────────────────────────────────────
                    _buildStatistics(context, m, detail),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ── Overview tab ─────────────────────────────────────────────────────────

    Widget _buildOverview(
      BuildContext context,
      AnilistMedia m,
      AsyncValue<AnilistMediaDetail> detail,
    ) {
      final theme = Theme.of(context);
      final cs = theme.colorScheme;
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          // stats row (favorites / members / score / popularity)
          detail.when(
            loading: () => _buildStatsRow(cs, null),
            error: (_, __) => _buildStatsRow(cs, null),
            data: (d) => _buildStatsRow(cs, d),
          ),
          const SizedBox(height: 16),

          // description
          if (m.description != null && m.description!.isNotEmpty)
            _GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedSize(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOut,
                    child: Text(
                      m.description!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        height: 1.55,
                        color: cs.onSurface.withValues(alpha: 0.8),
                      ),
                      maxLines: _descExpanded ? null : 4,
                      overflow: _descExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => setState(() => _descExpanded = !_descExpanded),
                    child: Text(
                      _descExpanded ? 'Show less' : 'Read more',
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

          if (m.description != null && m.description!.isNotEmpty)
            const SizedBox(height: 16),

          // info grid (release, status, season, source, origin)
          detail.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (d) => _buildInfoTable(context, m, d),
          ),

          const SizedBox(height: 16),

          // tags with percentage
          detail.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (d) {
              if (d.tags.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionLabel(label: 'Tags'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: d.tags.map((t) => _TagPill(t)).toList(),
                  ),
                  const SizedBox(height: 16),
                ],
              );
            },
          ),

          // studios
          detail.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (d) {
              if (d.studios.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionLabel(label: 'Studios'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: d.studios.map((s) => _StudioPill(s)).toList(),
                  ),
                  const SizedBox(height: 16),
                ],
              );
            },
          ),

          // external links
          detail.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (d) {
              if (d.externalLinks.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionLabel(label: 'Links'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: d.externalLinks
                        .take(8)
                        .map((l) => _LinkChip(
                              label: l['site'] ?? '',
                              onTap: () => _openWebview(l['url'] ?? '', l['site'] ?? ''),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                ],
              );
            },
          ),

          // trailer button
          detail.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (d) {
              if (d.trailerUrl == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _GlassCard(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _openWebview(d.trailerUrl!, 'Trailer'),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.play_circle_outline_rounded,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Watch Trailer',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      );
    }

    Widget _buildStatsRow(ColorScheme cs, AnilistMediaDetail? d) {
      return _GlassCard(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _StatIconItem(
              icon: Icons.favorite_border_rounded,
              value: _fmtCount(d?.favourites),
              label: 'Favorites',
              color: Colors.pinkAccent,
            ),
            _StatIconItem(
              icon: Icons.people_outline_rounded,
              value: _fmtCount(d?.popularity),
              label: 'Members',
              color: cs.primary,
            ),
            _StatIconItem(
              icon: Icons.percent_rounded,
              value: d?.meanScore != null ? '${d!.meanScore}' : '—',
              label: 'Mean Score',
              color: Colors.greenAccent,
            ),
            _StatIconItem(
              icon: Icons.star_border_rounded,
              value: _fmtCount(d?.base.averageScore),
              label: 'Score',
              color: Colors.amber,
            ),
          ],
        ),
      );
    }

    String _fmtCount(int? n) {
      if (n == null) return '—';
      if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
      if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
      return n.toString();
    }

    Widget _buildInfoTable(BuildContext context, AnilistMedia m, AnilistMediaDetail d) {
      final rows = <_InfoRow>[];
      // release date
      final startStr = _formatDate(d.startYear, d.startMonth, d.startDay);
      final endStr = d.endYear != null ? _formatDate(d.endYear, d.endMonth, d.endDay) : '?';
      if (d.startYear != null) {
        rows.add(_InfoRow(label: 'Release', value: '$startStr – $endStr'));
      }
      if (d.status != null) rows.add(_InfoRow(label: 'Status', value: _formatStatus(d.status)));
      if (d.season != null || d.seasonYear != null) {
        rows.add(_InfoRow(label: 'Season', value: _formatSeason(d.season, d.seasonYear)));
      }
      if (m.episodes != null) rows.add(_InfoRow(label: 'Episodes', value: '${m.episodes}'));
      if (m.chapters != null) rows.add(_InfoRow(label: 'Chapters', value: '${m.chapters}'));
      if (d.duration != null) rows.add(_InfoRow(label: 'Duration', value: '${d.duration} min'));
      if (d.source != null) rows.add(_InfoRow(label: 'Source', value: _formatSource(d.source)));
      if (m.countryOfOrigin != null) {
        rows.add(_InfoRow(
          label: 'Origin',
          value: switch (m.countryOfOrigin) {
            'JP' => 'Japan',
            'KR' => 'South Korea',
            'CN' => 'China',
            'TW' => 'Taiwan',
            _ => m.countryOfOrigin!,
          },
        ));
      }
      if (rows.isEmpty) return const SizedBox.shrink();
      return _GlassCard(
        child: Column(
          children: List.generate(rows.length, (i) {
            final row = rows[i];
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          row.label,
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          row.value,
                          textAlign: TextAlign.end,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                if (i < rows.length - 1)
                  Divider(
                    height: 1,
                    thickness: 0.5,
                    color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
              ],
            );
          }),
        ),
      );
    }

    // ── Related tab ──────────────────────────────────────────────────────────

    Widget _buildRelated(BuildContext context, AsyncValue<AnilistMediaDetail> detail) {
      return detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (d) {
          if (d.relations.isEmpty) {
            return const Center(child: Text('No related media'));
          }
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.58,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: d.relations.length,
            itemBuilder: (_, i) {
              final r = d.relations[i];
              return _RelationCard(
                relation: r,
                friendlyType: _friendlyRelationType(r.relationType),
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
          );
        },
      );
    }

    // ── Characters tab ───────────────────────────────────────────────────────

    Widget _buildCharacters(BuildContext context, AsyncValue<AnilistMediaDetail> detail) {
      return detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (d) {
          if (d.characters.isEmpty) {
            return const Center(child: Text('No characters'));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 100),
            itemCount: d.characters.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              thickness: 0.5,
              color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.25),
            ),
            itemBuilder: (_, i) {
              final c = d.characters[i];
              return _CharacterRow(
                character: c,
                onCharTap: c.siteUrl != null
                    ? () => _openWebview(c.siteUrl!, c.name)
                    : null,
                onVATap: c.voiceActor?.siteUrl != null
                    ? () => _openWebview(c.voiceActor!.siteUrl!, c.voiceActor!.name)
                    : null,
              );
            },
          );
        },
      );
    }

    // ── Staff tab ────────────────────────────────────────────────────────────

    Widget _buildStaff(BuildContext context, AsyncValue<AnilistMediaDetail> detail) {
      return detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (d) {
          if (d.staff.isEmpty) {
            return const Center(child: Text('No staff information'));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 100),
            itemCount: d.staff.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              thickness: 0.5,
              color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.25),
            ),
            itemBuilder: (_, i) {
              final s = d.staff[i];
              return _StaffRow(
                staff: s,
                onTap: s.siteUrl != null ? () => _openWebview(s.siteUrl!, s.name) : null,
              );
            },
          );
        },
      );
    }

    // ── Webview tab (Threads / Following / Activities) ───────────────────────

    Widget _buildWebviewTab(
      BuildContext context,
      AnilistMedia m,
      String url,
      String label,
      IconData icon,
    ) {
      final cs = Theme.of(context).colorScheme;
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: cs.onSurface.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'View on AniList',
              style: TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.55)),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => _openWebview(url, label),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Open $label',
                  style: TextStyle(
                    color: cs.onPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ── Recommendations tab ──────────────────────────────────────────────────

    Widget _buildRecommendations(BuildContext context, AsyncValue<AnilistMediaDetail> detail) {
      return detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (d) {
          if (d.recommendations.isEmpty) {
            return const Center(child: Text('No recommendations'));
          }
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.58,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: d.recommendations.length,
            itemBuilder: (_, i) {
              final r = d.recommendations[i];
              return _RelationCard(
                relation: AnilistRelation(
                  id: r.id,
                  title: r.displayTitle,
                  type: r.type,
                  format: r.format,
                  coverImage: r.bestCover,
                  relationType: null,
                ),
                friendlyType: r.averageScore != null ? '★ ${(r.averageScore! / 10).toStringAsFixed(1)}' : '',
                onTap: () => context.push('/anilistDetail', extra: r),
              );
            },
          );
        },
      );
    }

    // ── Statistics tab ───────────────────────────────────────────────────────

    Widget _buildStatistics(
      BuildContext context,
      AnilistMedia m,
      AsyncValue<AnilistMediaDetail> detail,
    ) {
      return detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (d) => _StatisticsContent(media: m, detail: d, openWebview: _openWebview),
      );
    }

    // ── Reviews tab ──────────────────────────────────────────────────────────

    Widget _buildReviews(BuildContext context, AsyncValue<AnilistMediaDetail> detail) {
      return detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (d) {
          if (d.reviews.isEmpty) {
            return const Center(child: Text('No reviews yet'));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: d.reviews.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final r = d.reviews[i];
              return _ReviewCard(
                review: r,
                onTap: r.siteUrl != null
                    ? () => _openWebview(r.siteUrl!, r.authorName ?? 'Review')
                    : null,
              );
            },
          );
        },
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Statistics content widget
  // ─────────────────────────────────────────────────────────────────────────────

  class _StatisticsContent extends StatelessWidget {
    final AnilistMedia media;
    final AnilistMediaDetail detail;
    final void Function(String url, String title) openWebview;

    const _StatisticsContent({
      required this.media,
      required this.detail,
      required this.openWebview,
    });

    @override
    Widget build(BuildContext context) {
      final cs = Theme.of(context).colorScheme;
      final m = detail;

      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          // Rankings
          if (m.rankings.isNotEmpty) ...[
            _SectionLabel(label: 'Rankings'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: m.rankings
                  .take(6)
                  .map((r) => _RankingBadge(ranking: r))
                  .toList(),
            ),
            const SizedBox(height: 20),
          ],

          // Score Distribution
          if (m.scoreDistribution.isNotEmpty) ...[
            _SectionLabel(label: 'Score Distribution'),
            const SizedBox(height: 12),
            _GlassCard(
              child: Column(
                children: () {
                  final maxAmount = m.scoreDistribution
                      .map((s) => s.amount)
                      .fold(0, (a, b) => a > b ? a : b);
                  return m.scoreDistribution.map((s) {
                    final pct = maxAmount > 0 ? s.amount / maxAmount : 0.0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 28,
                            child: Text(
                              '${s.score}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: pct.toDouble(),
                                minHeight: 8,
                                backgroundColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                                valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 40,
                            child: Text(
                              '${s.amount}',
                              textAlign: TextAlign.end,
                              style: TextStyle(
                                fontSize: 11,
                                color: cs.onSurface.withValues(alpha: 0.55),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList();
                }(),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Status Distribution
          if (m.statusDistribution.isNotEmpty) ...[
            _SectionLabel(label: 'Status Distribution'),
            const SizedBox(height: 12),
            _GlassCard(
              child: Column(
                children: () {
                  final total = m.statusDistribution
                      .map((s) => s.amount)
                      .fold(0, (a, b) => a + b);
                  const statusColors = {
                    'CURRENT': Color(0xFF4CAF50),
                    'PLANNING': Color(0xFF2196F3),
                    'COMPLETED': Color(0xFF9C27B0),
                    'PAUSED': Color(0xFFFF9800),
                    'DROPPED': Color(0xFFF44336),
                  };
                  const statusLabels = {
                    'CURRENT': 'Watching',
                    'PLANNING': 'Planning',
                    'COMPLETED': 'Completed',
                    'PAUSED': 'Paused',
                    'DROPPED': 'Dropped',
                  };
                  return m.statusDistribution.map((s) {
                    final pct = total > 0 ? s.amount / total : 0.0;
                    final color = statusColors[s.status] ?? const Color(0xFF9E9E9E);
                    final label = statusLabels[s.status] ?? s.status;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 3,
                            child: Text(
                              label,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface.withValues(alpha: 0.85),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: pct.toDouble(),
                                minHeight: 6,
                                backgroundColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                                valueColor: AlwaysStoppedAnimation<Color>(color),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            s.amount.toString(),
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurface.withValues(alpha: 0.55),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList();
                }(),
              ),
            ),
          ],

          if (m.rankings.isEmpty && m.scoreDistribution.isEmpty && m.statusDistribution.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 60),
                child: Column(
                  children: [
                    Icon(Icons.bar_chart_rounded, size: 48, color: cs.onSurface.withValues(alpha: 0.25)),
                    const SizedBox(height: 12),
                    Text(
                      'No statistics available',
                      style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5)),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Ranking badge
  // ─────────────────────────────────────────────────────────────────────────────

  class _RankingBadge extends StatelessWidget {
    final AnilistRanking ranking;
    const _RankingBadge({required this.ranking});

    @override
    Widget build(BuildContext context) {
      final cs = Theme.of(context).colorScheme;
      final isRated = ranking.type == 'RATED';
      final color = isRated ? Colors.amber : Colors.pinkAccent;
      final icon = isRated ? Icons.star_rounded : Icons.favorite_rounded;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
            Text(
              '#${ranking.rank} ${ranking.context}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: cs.onSurface.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Character row (Otraku style)
  // char image left | name + role — divider — VA name + lang | VA image right
  // ─────────────────────────────────────────────────────────────────────────────

  class _CharacterRow extends StatelessWidget {
    final AnilistCharacter character;
    final VoidCallback? onCharTap;
    final VoidCallback? onVATap;

    const _CharacterRow({
      required this.character,
      this.onCharTap,
      this.onVATap,
    });

    @override
    Widget build(BuildContext context) {
      final cs = Theme.of(context).colorScheme;
      final role = character.role != null
          ? '${character.role![0]}${character.role!.substring(1).toLowerCase()}'
          : '';
      final va = character.voiceActor;

      return SizedBox(
        height: 84,
        child: Row(
          children: [
            // character side
            Expanded(
              child: GestureDetector(
                onTap: onCharTap,
                child: Row(
                  children: [
                    _SquareAvatar(url: character.imageUrl, size: 84),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            character.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                          if (role.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              role,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: cs.onSurface.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // divider
            Container(
              width: 1,
              height: 56,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              color: cs.outlineVariant.withValues(alpha: 0.35),
            ),

            // VA side (right aligned)
            if (va != null)
              Expanded(
                child: GestureDetector(
                  onTap: onVATap,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              va.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.end,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              va.language,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: cs.onSurface.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      _SquareAvatar(url: va.imageUrl, size: 84),
                    ],
                  ),
                ),
              )
            else
              const Expanded(child: SizedBox()),
          ],
        ),
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Staff row
  // ─────────────────────────────────────────────────────────────────────────────

  class _StaffRow extends StatelessWidget {
    final AnilistStaff staff;
    final VoidCallback? onTap;

    const _StaffRow({required this.staff, this.onTap});

    @override
    Widget build(BuildContext context) {
      final cs = Theme.of(context).colorScheme;
      return GestureDetector(
        onTap: onTap,
        child: SizedBox(
          height: 84,
          child: Row(
            children: [
              _SquareAvatar(url: staff.imageUrl, size: 84),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      staff.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                    ),
                    if (staff.role != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        staff.role!,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right_rounded,
                    color: cs.onSurface.withValues(alpha: 0.3)),
            ],
          ),
        ),
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Review card
  // ─────────────────────────────────────────────────────────────────────────────

  class _ReviewCard extends StatefulWidget {
    final AnilistReview review;
    final VoidCallback? onTap;
    const _ReviewCard({required this.review, this.onTap});

    @override
    State<_ReviewCard> createState() => _ReviewCardState();
  }

  class _ReviewCardState extends State<_ReviewCard> {
    bool _expanded = false;

    @override
    Widget build(BuildContext context) {
      final cs = Theme.of(context).colorScheme;
      final r = widget.review;
      return _GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // author row
            Row(
              children: [
                if (r.authorAvatar != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: SizedBox(
                      width: 36,
                      height: 36,
                      child: ExtendedImage.network(r.authorAvatar!, fit: BoxFit.cover, cache: true),
                    ),
                  ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.authorName ?? 'Anonymous',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                      if (r.score != null)
                        Text(
                          'Score: ${r.score}/100',
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurface.withValues(alpha: 0.55),
                          ),
                        ),
                    ],
                  ),
                ),
                if (r.rating != null)
                  Row(
                    children: [
                      Icon(Icons.thumb_up_outlined, size: 14, color: cs.primary),
                      const SizedBox(width: 3),
                      Text('${r.rating}',
                          style: TextStyle(fontSize: 12, color: cs.primary)),
                    ],
                  ),
              ],
            ),
            if (r.summary != null) ...[
              const SizedBox(height: 10),
              Text(
                r.summary!,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ],
            if (r.body != null && r.body!.isNotEmpty) ...[
              const SizedBox(height: 8),
              AnimatedSize(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOut,
                child: Text(
                  r.body!,
                  maxLines: _expanded ? null : 3,
                  overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.5,
                    color: cs.onSurface.withValues(alpha: 0.75),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Text(
                  _expanded ? 'Show less' : 'Read more',
                  style: TextStyle(color: cs.primary, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
            if (widget.onTap != null) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: widget.onTap,
                child: Text(
                  'Open full review on Anilist',
                  style: TextStyle(color: cs.primary, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ],
        ),
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Relation card (grid style)
  // ─────────────────────────────────────────────────────────────────────────────

  class _RelationCard extends StatelessWidget {
    final AnilistRelation relation;
    final String friendlyType;
    final VoidCallback onTap;

    const _RelationCard({
      required this.relation,
      required this.friendlyType,
      required this.onTap,
    });

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
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    relation.coverImage != null
                        ? ExtendedImage.network(relation.coverImage!, fit: BoxFit.cover, cache: true)
                        : Container(color: cs.surfaceContainerHighest),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black.withValues(alpha: 0.75)],
                          ),
                        ),
                        child: Text(
                          friendlyType,
                          style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w700),
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
              relation.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Shared helpers
  // ─────────────────────────────────────────────────────────────────────────────

  class _InfoRow {
    final String label;
    final String value;
    const _InfoRow({required this.label, required this.value});
  }

  class _SquareAvatar extends StatelessWidget {
    final String? url;
    final double size;

    const _SquareAvatar({this.url, required this.size});

    @override
    Widget build(BuildContext context) {
      final cs = Theme.of(context).colorScheme;
      return SizedBox(
        width: size * 0.62,
        height: size,
        child: url != null
            ? ExtendedImage.network(url!, fit: BoxFit.cover, cache: true)
            : Container(
                color: cs.surfaceContainerHighest,
                child: const Icon(Icons.person_rounded, size: 28),
              ),
      );
    }
  }

  class _StatIconItem extends StatelessWidget {
    final IconData icon;
    final String value;
    final String label;
    final Color color;

    const _StatIconItem({
      required this.icon,
      required this.value,
      required this.label,
      required this.color,
    });

    @override
    Widget build(BuildContext context) {
      final cs = Theme.of(context).colorScheme;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: cs.onSurface.withValues(alpha: 0.55)),
          ),
        ],
      );
    }
  }

  class _SectionLabel extends StatelessWidget {
    final String label;
    const _SectionLabel({required this.label});

    @override
    Widget build(BuildContext context) {
      return Text(
        label,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      );
    }
  }

  class _GlassCard extends StatelessWidget {
    final Widget child;
    const _GlassCard({required this.child});

    @override
    Widget build(BuildContext context) {
      final cs = Theme.of(context).colorScheme;
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3), width: 1),
        ),
        child: child,
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
            color: cs.surfaceContainerHigh.withValues(alpha: 0.75),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: cs.onSurface),
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
      this.label,
      this.primary = false,
      this.width,
      required this.onTap,
    });

    @override
    Widget build(BuildContext context) {
      final cs = Theme.of(context).colorScheme;
      final bg = primary ? cs.primary : cs.surfaceContainerHigh.withValues(alpha: 0.85);
      final fg = primary ? cs.onPrimary : cs.onSurface;
      return GestureDetector(
        onTap: onTap,
        child: Container(
          width: width,
          height: 48,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: fg),
              if (label != null) ...[
                const SizedBox(width: 8),
                Text(label!, style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 14)),
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

    @override
    Widget build(BuildContext context) {
      final cs = Theme.of(context).colorScheme;
      final label = _label();
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: cs.primaryContainer.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: cs.onPrimaryContainer)),
      );
    }

    String _label() {
      if (format == 'MOVIE') return 'Movie';
      if (format == 'OVA') return 'OVA';
      if (format == 'ONA') return 'ONA';
      if (format == 'SPECIAL') return 'Special';
      if (format == 'MUSIC') return 'Music';
      if (format == 'NOVEL') return 'Novel';
      if (format == 'ONE_SHOT') return 'One Shot';
      if (format == 'MANHWA' || country == 'KR') return 'Manhwa';
      if (format == 'MANHUA' || country == 'CN') return 'Manhua';
      return type == 'ANIME' ? 'Anime' : 'Manga';
    }
  }

  class _ScorePill extends StatelessWidget {
    final int score;
    const _ScorePill(this.score);

    @override
    Widget build(BuildContext context) {
      final cs = Theme.of(context).colorScheme;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star_rounded, size: 11, color: Colors.amber),
            const SizedBox(width: 3),
            Text(
              (score / 10).toStringAsFixed(1),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.amber),
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
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: cs.secondaryContainer.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(genre,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSecondaryContainer)),
      );
    }
  }

  class _TagPill extends StatelessWidget {
    final AnilistTag tag;
    const _TagPill(this.tag);

    @override
    Widget build(BuildContext context) {
      final cs = Theme.of(context).colorScheme;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
        ),
        child: Text(
          '${tag.name} ${tag.rank}%',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      );
    }
  }

  class _StudioPill extends StatelessWidget {
    final String studio;
    const _StudioPill(this.studio);

    @override
    Widget build(BuildContext context) {
      final cs = Theme.of(context).colorScheme;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: cs.primaryContainer.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
        ),
        child: Text(
          studio,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onPrimaryContainer),
        ),
      );
    }
  }

  class _LinkChip extends StatelessWidget {
    final String label;
    final VoidCallback onTap;
    const _LinkChip({required this.label, required this.onTap});

    @override
    Widget build(BuildContext context) {
      final cs = Theme.of(context).colorScheme;
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: cs.tertiaryContainer.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cs.tertiary.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.link_rounded, size: 14, color: cs.onTertiaryContainer),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: cs.onTertiaryContainer),
              ),
            ],
          ),
        ),
      );
    }
  }