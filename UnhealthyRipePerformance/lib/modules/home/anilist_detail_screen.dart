import 'dart:ui';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:isar_community/isar.dart';
import 'package:share_plus/share_plus.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/modules/home/services/anilist_discovery_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Detail screen — otraku-inspired with 11 tabs
// Overview | Related | Characters | Staff | Reviews | Threads | Following |
// Activities | Recommendations | Statistics | Watch Order
// ─────────────────────────────────────────────────────────────────────────────

class AnilistDetailScreen extends ConsumerStatefulWidget {
  final AnilistMedia media;
  const AnilistDetailScreen({super.key, required this.media});

  @override
  ConsumerState<AnilistDetailScreen> createState() => _AnilistDetailScreenState();
}

class _AnilistDetailScreenState extends ConsumerState<AnilistDetailScreen>
    with TickerProviderStateMixin {
  late final TabController _tab;
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;
  bool _statsExpanded = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 12, vsync: this);
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _tab.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── helpers ────────────────────────────────────────────────────────────────

  void _share(AnilistMedia m) {
    final url = 'https://anilist.co/${m.type.toLowerCase()}/${m.id}';
    SharePlus.instance.share(ShareParams(text: '${m.displayTitle}\n$url'));
  }

  void _openWebview(String url, String title) {
    context.push('/mangawebview', extra: {'url': url, 'title': title});
  }

  void _showPersonSheet(
    BuildContext ctx,
    String name,
    String? imageUrl,
    String? subtitle,
    String kind,
    String? siteUrl,
  ) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _PersonSheet(
        name: name,
        imageUrl: imageUrl,
        subtitle: subtitle,
        kind: kind,
        siteUrl: siteUrl,
        onOpenWeb: siteUrl != null
            ? () {
                Navigator.pop(ctx);
                _openWebview(siteUrl, name);
              }
            : null,
      ),
    );
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
    final s = season != null ? '${season[0]}${season.substring(1).toLowerCase()}' : '';
    return [s, if (year != null) year.toString()].where((e) => e.isNotEmpty).join(' ');
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
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
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

  String _fmtCount(int? n) {
    if (n == null) return '—';
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  // Sort index for Watch Order
  int _watchOrderSort(String? type) => switch (type) {
        'PREQUEL' => 0,
        'PARENT' => 1,
        'ADAPTATION' => 2,
        'SUMMARY' => 3,
        'ALTERNATIVE' => 4,
        'SEQUEL' => 5,
        'SPIN_OFF' => 6,
        'SIDE_STORY' => 7,
        _ => 8,
      };

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final m = widget.media;
    final detail = ref.watch(anilistMediaDetailProvider(m.id));
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final banner = m.bannerImage ?? m.bestCover;
    final scaffoldBg = theme.scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: Stack(
        children: [
          // ── Blurred background ────────────────────────────────────────────
          if (banner != null)
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 35, sigmaY: 35),
                child: ExtendedImage.network(
                  banner,
                  fit: BoxFit.cover,
                  cache: true,
                ),
              ),
            ),

          // ── Animated gradient (accent-tinted) ───────────────────────────
          Positioned.fill(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      cs.primary.withValues(alpha: 0.18),
                      Colors.black.withValues(alpha: 0.55),
                      scaffoldBg.withValues(alpha: 0.92),
                      scaffoldBg,
                    ],
                    stops: const [0.0, 0.2, 0.5, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // ── Content ───────────────────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                // Nav bar — always pinned, never scrolls
                _buildNavBar(context, m, cs),

                // Scrollable hero + sticky tab bar + tab views
                Expanded(
                  child: NestedScrollView(
                    headerSliverBuilder: (ctx, _) => [
                      // Hero: cover + title + action buttons
                      SliverToBoxAdapter(child: _buildHero(context, m, cs, theme)),
                      // Sticky tab bar
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _StickyTabBarDelegate(
                          tabBar: TabBar(
                            controller: _tab,
                            isScrollable: true,
                            tabAlignment: TabAlignment.start,
                            dividerColor: Colors.transparent,
                            indicatorColor: cs.primary,
                            indicatorWeight: 2.5,
                            labelColor: cs.primary,
                            unselectedLabelColor: cs.onSurface.withValues(alpha: 0.5),
                            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                            tabs: const [
                              Tab(icon: Icon(Broken.info_circle, size: 13), text: 'Overview'),
                              Tab(icon: Icon(Broken.video, size: 13), text: 'Episodes'),
                              Tab(icon: Icon(Broken.link_2, size: 13), text: 'Related'),
                              Tab(icon: Icon(Broken.user, size: 13), text: 'Characters'),
                              Tab(icon: Icon(Broken.people, size: 13), text: 'Staff'),
                              Tab(icon: Icon(Broken.star, size: 13), text: 'Reviews'),
                              Tab(icon: Icon(Broken.messages, size: 13), text: 'Threads'),
                              Tab(icon: Icon(Broken.heart, size: 13), text: 'Following'),
                              Tab(icon: Icon(Broken.activity, size: 13), text: 'Activities'),
                              Tab(icon: Icon(Broken.like, size: 13), text: 'Recommendations'),
                              Tab(icon: Icon(Broken.chart_2, size: 13), text: 'Statistics'),
                              Tab(icon: Icon(Broken.video_time, size: 13), text: 'Watch Order'),
                            ],
                          ),
                          bgColor: scaffoldBg,
                          dividerColor: cs.outlineVariant.withValues(alpha: 0.25),
                        ),
                      ),
                    ],
                    body: TabBarView(
                      controller: _tab,
                      children: [
                        _buildOverview(context, m, detail, cs, theme),
                        _buildEpisodes(context, m, cs),
                        _buildRelated(context, detail, cs),
                        _buildCharacters(context, detail, cs, m),
                        _buildStaff(context, detail, cs),
                        _buildReviews(context, detail),
                        _buildThreads(context, m),
                        _buildFollowing(context, m, cs),
                        _buildActivities(context, m),
                        _buildRecommendations(context, detail, cs),
                        _buildStatistics(context, m, detail, cs),
                        _buildWatchOrder(context, detail, cs),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Nav bar (always visible) ───────────────────────────────────────────────

  Widget _buildNavBar(BuildContext context, AnilistMedia m, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          _CircleBtn(
            icon: Broken.arrow_left,
            onTap: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ScrollingTitle(text: m.displayTitle),
          ),
          const SizedBox(width: 8),
          _CircleBtn(
            icon: Broken.menu_1,
            onTap: () => _showMoreMenu(context, m),
          ),
        ],
      ),
    );
  }

  void _showMoreMenu(BuildContext context, AnilistMedia m) {
    final anilistUrl = 'https://anilist.co/${m.type.toLowerCase()}/${m.id}';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return _MoreMenuSheet(
          cs: cs,
          options: [
            _MoreMenuOption(
              icon: Broken.global,
              label: 'Open in WebView',
              onTap: () {
                Navigator.pop(ctx);
                _openWebview(anilistUrl, m.displayTitle);
              },
            ),
            _MoreMenuOption(
              icon: Broken.global_search,
              label: 'Find on Extensions',
              onTap: () {
                Navigator.pop(ctx);
                final type = m.type == 'MANGA' ? ItemType.manga : ItemType.anime;
                context.push('/globalSearch', extra: (m.displayTitle, type));
              },
            ),
            _MoreMenuOption(
              icon: Broken.share,
              label: 'Share',
              onTap: () {
                Navigator.pop(ctx);
                _share(m);
              },
            ),
            _MoreMenuOption(
              icon: Broken.flag,
              label: 'Report',
              isDestructive: true,
              onTap: () {
                Navigator.pop(ctx);
                _openWebview(
                  'https://anilist.co/forum/thread/14/',
                  'Report',
                );
              },
            ),
          ],
        );
      },
    );
  }

  // ── Hero section (cover + title + action buttons) ─────────────────────────

  Widget _buildHero(BuildContext context, AnilistMedia m, ColorScheme cs, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover + title row
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Cover image
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.45),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: 110,
                    height: 165,
                    child: m.bestCover != null
                        ? ExtendedImage.network(m.bestCover!, fit: BoxFit.cover, cache: true)
                        : Container(
                            color: cs.surfaceContainerHighest,
                            child: const Icon(Icons.image_not_supported_outlined, size: 32),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Title + badges
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
                        fontSize: 20,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (m.titleRomaji != null && m.titleRomaji != m.displayTitle) ...[
                      const SizedBox(height: 4),
                      Text(
                        m.titleRomaji!,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withValues(alpha: 0.5),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    // Format subtitle like otraku: "TV • Ep 1166 in 1d 57m"
                    const SizedBox(height: 6),
                    _buildSubtitle(m, cs),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Action buttons: [Share] [Add to Library →]
          Row(
            children: [
              // Share — square button on the LEFT
              _ActionBtn(
                icon: Icons.share_outlined,
                onTap: () => _share(m),
                width: 54,
              ),
              const SizedBox(width: 10),
              // Add to Library — expanded
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
        ],
      ),
    );
  }

  Widget _buildSubtitle(AnilistMedia m, ColorScheme cs) {
    final parts = <String>[];
    if (m.format != null && m.format != 'TV') {
      parts.add(m.format!);
    } else {
      parts.add(m.type == 'ANIME' ? 'TV' : 'Manga');
    }
    if (m.episodes != null) parts.add('Ep ${m.episodes}');
    if (m.chapters != null) parts.add('Ch ${m.chapters}');
    if (parts.isEmpty) return const SizedBox.shrink();
    return Text(
      parts.join(' • '),
      style: TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.65)),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 0 — Overview
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildOverview(
    BuildContext context,
    AnilistMedia m,
    AsyncValue<AnilistMediaDetail> detail,
    ColorScheme cs,
    ThemeData theme,
  ) {
    return _OverviewTab(
      media: m,
      detail: detail,
      cs: cs,
      theme: theme,
      statsExpanded: _statsExpanded,
      onStatsToggle: () => setState(() => _statsExpanded = !_statsExpanded),
      fmtCount: _fmtCount,
      formatStatus: _formatStatus,
      formatSeason: _formatSeason,
      formatSource: _formatSource,
      formatDate: _formatDate,
      onMediaTap: (media) => context.push('/anilistDetail', extra: media),
      openWebview: _openWebview,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 1 — Episodes (AniZip: title, synopsis, thumbnail, duration)
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildEpisodes(BuildContext context, AnilistMedia m, ColorScheme cs) {
    return _EpisodesTab(media: m, cs: cs);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 2 — Related
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildRelated(BuildContext context, AsyncValue<AnilistMediaDetail> detail, ColorScheme cs) {
    return detail.when(
      loading: () => const _LoadingView(),
      error: (e, _) => _ErrorView(message: e.toString()),
      data: (d) {
        if (d.relations.isEmpty) return const _EmptyView(message: 'No related media');
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
          itemCount: d.relations.length,
          itemBuilder: (_, i) {
            final r = d.relations[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _RelationListTile(
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
              ),
            );
          },
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 2 — Characters (with language filter)
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildCharacters(
    BuildContext context,
    AsyncValue<AnilistMediaDetail> detail,
    ColorScheme cs,
    AnilistMedia m,
  ) {
    return detail.when(
      loading: () => const _LoadingView(),
      error: (e, _) => _ErrorView(message: e.toString()),
      data: (d) {
        if (d.characters.isEmpty) return const _EmptyView(message: 'No characters');
        return _CharactersWithFilter(
          characters: d.characters,
          onCharTap: (c) {
            _showPersonSheet(context, c.name, c.imageUrl, c.role, 'Character', c.siteUrl);
          },
          onVATap: (va) {
            _showPersonSheet(context, va.name, va.imageUrl, va.language, 'Voice Actor', va.siteUrl);
          },
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 3 — Staff
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildStaff(BuildContext context, AsyncValue<AnilistMediaDetail> detail, ColorScheme cs) {
    return detail.when(
      loading: () => const _LoadingView(),
      error: (e, _) => _ErrorView(message: e.toString()),
      data: (d) {
        if (d.staff.isEmpty) return const _EmptyView(message: 'No staff information');
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 80),
          itemCount: d.staff.length,
          separatorBuilder: (_, __) => Divider(
            height: 1,
            thickness: 0.5,
            color: cs.outlineVariant.withValues(alpha: 0.2),
          ),
          itemBuilder: (_, i) {
            final s = d.staff[i];
            return _StaffRow(
              staff: s,
              onTap: () => _showPersonSheet(context, s.name, s.imageUrl, s.role, 'Staff', s.siteUrl),
            );
          },
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 4 — Reviews
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildReviews(BuildContext context, AsyncValue<AnilistMediaDetail> detail) {
    return detail.when(
      loading: () => const _LoadingView(),
      error: (e, _) => _ErrorView(message: e.toString()),
      data: (d) {
        if (d.reviews.isEmpty) return const _EmptyView(message: 'No reviews yet');
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
          itemCount: d.reviews.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final r = d.reviews[i];
            return _ReviewCard(
              review: r,
              onTap: r.siteUrl != null ? () => _openWebview(r.siteUrl!, r.authorName ?? 'Review') : null,
            );
          },
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 5 — Threads (native AniList API)
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildThreads(BuildContext context, AnilistMedia m) {
    final threads = ref.watch(threadsProvider(m.id));
    return threads.when(
      loading: () => const _LoadingView(),
      error: (e, _) => _ErrorView(message: e.toString()),
      data: (list) {
        if (list.isEmpty) return const _EmptyView(message: 'No threads yet');
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
          itemCount: list.length,
          separatorBuilder: (_, __) => Divider(
            height: 1,
            thickness: 0.5,
            color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.2),
          ),
          itemBuilder: (_, i) => _ThreadCard(
            thread: list[i],
            mediaTitleForCategories: m.displayTitle,
            onTap: () => _openWebview(list[i].siteUrl, list[i].title),
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 6 — Following (requires AniList auth)
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildFollowing(BuildContext context, AnilistMedia m, ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline_rounded, size: 56, color: cs.onSurface.withValues(alpha: 0.25)),
            const SizedBox(height: 16),
            Text(
              'Sign in to AniList',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: cs.onSurface),
            ),
            const SizedBox(height: 8),
            Text(
              'Following activity requires an AniList account linked to Watchtower.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.55), height: 1.5),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => context.push(
                '/mangawebview',
                extra: {
                  'url': 'https://anilist.co/api/v2/oauth/authorize?client_id=_&response_type=token',
                  'title': 'AniList Login',
                },
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Connect AniList',
                  style: TextStyle(color: cs.onPrimary, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 7 — Activities (native AniList API)
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildActivities(BuildContext context, AnilistMedia m) {
    return _ActivitiesTab(mediaId: m.id);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 8 — Recommendations (list style, otraku-inspired)
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildRecommendations(
    BuildContext context,
    AsyncValue<AnilistMediaDetail> detail,
    ColorScheme cs,
  ) {
    return detail.when(
      loading: () => const _LoadingView(),
      error: (e, _) => _ErrorView(message: e.toString()),
      data: (d) {
        if (d.recommendations.isEmpty) return const _EmptyView(message: 'No recommendations');
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
          itemCount: d.recommendations.length,
          separatorBuilder: (_, __) => Divider(
            height: 1,
            thickness: 0.5,
            color: cs.outlineVariant.withValues(alpha: 0.2),
          ),
          itemBuilder: (_, i) {
            final r = d.recommendations[i];
            return _RecommendationRow(
              media: r,
              onTap: () => context.push('/anilistDetail', extra: r),
              onVote: () => _openWebview(
                'https://anilist.co/${r.type.toLowerCase()}/${r.id}/recommendations',
                r.displayTitle,
              ),
            );
          },
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 9 — Statistics
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildStatistics(
    BuildContext context,
    AnilistMedia m,
    AsyncValue<AnilistMediaDetail> detail,
    ColorScheme cs,
  ) {
    return detail.when(
      loading: () => const _LoadingView(),
      error: (e, _) => _ErrorView(message: e.toString()),
      data: (d) => _StatisticsContent(media: m, detail: d),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 10 — Watch Order (sorted relations timeline)
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildWatchOrder(
    BuildContext context,
    AsyncValue<AnilistMediaDetail> detail,
    ColorScheme cs,
  ) {
    return detail.when(
      loading: () => const _LoadingView(),
      error: (e, _) => _ErrorView(message: e.toString()),
      data: (d) {
        if (d.relations.isEmpty) return const _EmptyView(message: 'No watch order available');
        return _WatchOrderTab(
          relations: d.relations,
          friendlyRelationType: _friendlyRelationType,
          watchOrderSort: _watchOrderSort,
          onRelationTap: (r) => context.push('/anilistDetail',
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
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sticky tab bar delegate
// ─────────────────────────────────────────────────────────────────────────────

class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final Color bgColor;
  final Color dividerColor;

  const _StickyTabBarDelegate({
    required this.tabBar,
    required this.bgColor,
    required this.dividerColor,
  });

  @override
  double get minExtent => tabBar.preferredSize.height + 1;
  @override
  double get maxExtent => tabBar.preferredSize.height + 1;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: bgColor,
      child: Column(
        children: [
          tabBar,
          Divider(height: 1, thickness: 0.5, color: dividerColor),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_StickyTabBarDelegate old) =>
      tabBar != old.tabBar || bgColor != old.bgColor;
}

// ─────────────────────────────────────────────────────────────────────────────
// Overview Tab (StatefulWidget for desc expand + stats collapse)
// ─────────────────────────────────────────────────────────────────────────────

class _OverviewTab extends StatefulWidget {
  final AnilistMedia media;
  final AsyncValue<AnilistMediaDetail> detail;
  final ColorScheme cs;
  final ThemeData theme;
  final bool statsExpanded;
  final VoidCallback onStatsToggle;
  final String Function(int?) fmtCount;
  final String Function(String?) formatStatus;
  final String Function(String?, int?) formatSeason;
  final String Function(String?) formatSource;
  final String Function(int?, int?, int?) formatDate;
  final void Function(AnilistMedia) onMediaTap;
  final void Function(String, String) openWebview;

  const _OverviewTab({
    required this.media,
    required this.detail,
    required this.cs,
    required this.theme,
    required this.statsExpanded,
    required this.onStatsToggle,
    required this.fmtCount,
    required this.formatStatus,
    required this.formatSeason,
    required this.formatSource,
    required this.formatDate,
    required this.onMediaTap,
    required this.openWebview,
  });

  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> {
  bool _descExpanded = false;

  @override
  Widget build(BuildContext context) {
    final m = widget.media;
    final cs = widget.cs;
    final theme = widget.theme;
    // Use description from detail query (full) falling back to base media
    final description = widget.detail.value?.base.description ?? widget.media.description;

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 80),
      children: [
        // ── Episode progress + hours box ──────────────────────────────────
        _EpisodeHoursBox(media: m, cs: cs),
        const SizedBox(height: 12),

        // ── Statistics box (collapsible) ───────────────────────────────────
        widget.detail.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (d) => _StatsBox(
            media: m,
            detail: d,
            expanded: widget.statsExpanded,
            onToggle: widget.onStatsToggle,
            cs: cs,
            formatStatus: widget.formatStatus,
            formatSeason: widget.formatSeason,
            formatSource: widget.formatSource,
            formatDate: widget.formatDate,
          ),
        ),
        const SizedBox(height: 12),

        // ── Synopsis ───────────────────────────────────────────────────────
        if (description != null && description.isNotEmpty) ...[
          _GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedSize(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOut,
                  child: Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      height: 1.6,
                      color: cs.onSurface.withValues(alpha: 0.8),
                    ),
                    maxLines: _descExpanded ? null : 5,
                    overflow: _descExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: GestureDetector(
                    onTap: () => setState(() => _descExpanded = !_descExpanded),
                    child: AnimatedRotation(
                      turns: _descExpanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 280),
                      child: Icon(
                        Icons.expand_more_rounded,
                        size: 28,
                        color: cs.onSurface.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // ── Genres ─────────────────────────────────────────────────────────
        if (m.genres.isNotEmpty) ...[
          const _SectionLabel(label: 'Genres'),
          const SizedBox(height: 8),
          SizedBox(
            height: 68,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: m.genres.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => _GenreCategoryCard(genre: m.genres[i]),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // ── Relations ──────────────────────────────────────────────────────
        widget.detail.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (d) {
            if (d.relations.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionLabel(label: 'Relations'),
                const SizedBox(height: 8),
                SizedBox(
                  height: 180,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: d.relations.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (_, i) {
                      final r = d.relations[i];
                      return SizedBox(
                        width: 110,
                        child: _RelationCard(
                          relation: r,
                          friendlyType: _friendlyRelationType(r.relationType),
                          onTap: () => widget.onMediaTap(AnilistMedia(
                            id: r.id,
                            type: r.type,
                            format: r.format,
                            titleRomaji: r.title,
                            coverLarge: r.coverImage,
                          )),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],
            );
          },
        ),

        // ── Recommendations preview ─────────────────────────────────────────
        widget.detail.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (d) {
            if (d.recommendations.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionLabel(label: 'Recommendations'),
                const SizedBox(height: 8),
                SizedBox(
                  height: 175,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: d.recommendations.take(8).length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (_, i) {
                      final r = d.recommendations[i];
                      return SizedBox(
                        width: 100,
                        child: _RelationCard(
                          relation: AnilistRelation(
                            id: r.id,
                            title: r.displayTitle,
                            type: r.type,
                            format: r.format,
                            coverImage: r.bestCover,
                            relationType: null,
                          ),
                          friendlyType: r.averageScore != null
                              ? '★ ${(r.averageScore! / 10).toStringAsFixed(1)}'
                              : '',
                          onTap: () => widget.onMediaTap(r),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  String _friendlyRelationType(String? r) => switch (r) {
        'SEQUEL' => 'Sequel',
        'PREQUEL' => 'Prequel',
        'PARENT' => 'Parent',
        'SIDE_STORY' => 'Side Story',
        'ALTERNATIVE' => 'Alternative',
        'SPIN_OFF' => 'Spin-off',
        'ADAPTATION' => 'Adaptation',
        _ => r ?? '',
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// Episode + Hours box
// ─────────────────────────────────────────────────────────────────────────────

class _EpisodeHoursBox extends StatelessWidget {
  final AnilistMedia media;
  final ColorScheme cs;

  const _EpisodeHoursBox({required this.media, required this.cs});

  @override
  Widget build(BuildContext context) {
    final eps = media.episodes ?? media.chapters;
    final isAnime = media.type == 'ANIME';
    final label = isAnime ? 'Episode' : 'Chapter';
    final total = eps ?? 0;

    return _GlassCard(
      child: Column(
        children: [
          // Episode row
          Row(
            children: [
              Icon(
                isAnime ? Icons.videocam_outlined : Icons.menu_book_outlined,
                size: 20,
                color: cs.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  eps != null ? '$label 0 of $total' : label,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '0.00%',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cs.onSurface),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: 0,
              minHeight: 5,
              backgroundColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
              valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
            ),
          ),
          const SizedBox(height: 12),
          // Hours row
          IntrinsicHeight(
            child: Row(
              children: [
                _HourItem(label: 'Total', value: _totalHours(), cs: cs),
                VerticalDivider(color: cs.outlineVariant.withValues(alpha: 0.4), thickness: 0.5),
                _HourItem(label: 'Watched', value: '—', cs: cs),
                VerticalDivider(color: cs.outlineVariant.withValues(alpha: 0.4), thickness: 0.5),
                _HourItem(label: 'Remaining', value: _totalHours(), cs: cs, accent: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _totalHours() {
    // media.episodes is available, we don't have duration here
    // Rough estimate: 24min per anime ep, 10min per manga chapter read
    final eps = media.episodes ?? media.chapters;
    if (eps == null) return '—';
    if (media.type == 'ANIME') {
      final minutes = eps * 24;
      if (minutes >= 60) return '${(minutes / 60).toStringAsFixed(0)}h';
      return '${minutes}m';
    } else {
      final minutes = eps * 10;
      if (minutes >= 60) return '${(minutes / 60).toStringAsFixed(0)}h';
      return '${minutes}m';
    }
  }
}

class _HourItem extends StatelessWidget {
  final String label;
  final String value;
  final ColorScheme cs;
  final bool accent;

  const _HourItem({
    required this.label,
    required this.value,
    required this.cs,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: cs.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: accent && value != '—' ? cs.primary : cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Statistics box (collapsible, like otraku)
// ─────────────────────────────────────────────────────────────────────────────

class _StatsBox extends StatelessWidget {
  final AnilistMedia media;
  final AnilistMediaDetail detail;
  final bool expanded;
  final VoidCallback onToggle;
  final ColorScheme cs;
  final String Function(String?) formatStatus;
  final String Function(String?, int?) formatSeason;
  final String Function(String?) formatSource;
  final String Function(int?, int?, int?) formatDate;

  const _StatsBox({
    required this.media,
    required this.detail,
    required this.expanded,
    required this.onToggle,
    required this.cs,
    required this.formatStatus,
    required this.formatSeason,
    required this.formatSource,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          GestureDetector(
            onTap: onToggle,
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                Icon(Icons.bar_chart_rounded, size: 20, color: cs.primary),
                const SizedBox(width: 8),
                const Text(
                  'Statistics',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const Spacer(),
                AnimatedRotation(
                  turns: expanded ? 0 : 0.5,
                  duration: const Duration(milliseconds: 250),
                  child: Icon(
                    Icons.keyboard_arrow_up_rounded,
                    color: cs.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),

          // Collapsible content
          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOut,
            child: expanded
                ? Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: _buildGrid(context),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(BuildContext context) {
    final m = media;
    final d = detail;
    final items = <_StatGridItem>[];

    items.add(_StatGridItem(
      label: 'Type',
      value: m.type == 'ANIME' ? 'Anime' : 'Manga',
    ));
    if (m.averageScore != null) {
      items.add(_StatGridItem(
        label: 'Rating',
        value: '${(m.averageScore! / 10).toStringAsFixed(1)}/10',
        accent: true,
      ));
    }
    if (m.format != null) {
      items.add(_StatGridItem(label: 'Format', value: m.format!));
    }
    if (d.status != null) {
      items.add(_StatGridItem(label: 'Status', value: formatStatus(d.status)));
    }
    if (d.popularity != null) {
      items.add(_StatGridItem(label: 'Popularity', value: '${d.popularity}'));
    }
    if (m.episodes != null) {
      items.add(_StatGridItem(label: 'Episodes', value: '${m.episodes}'));
    } else if (m.chapters != null) {
      items.add(_StatGridItem(label: 'Chapters', value: '${m.chapters}'));
    }
    if (d.season != null || d.seasonYear != null) {
      items.add(_StatGridItem(label: 'Season', value: formatSeason(d.season, d.seasonYear)));
    }
    if (d.source != null) {
      items.add(_StatGridItem(label: 'Source', value: formatSource(d.source)));
    }
    if (d.meanScore != null) {
      items.add(_StatGridItem(
        label: 'Mean Score',
        value: '${(d.meanScore! / 10).toStringAsFixed(1)}/10',
        accent: true,
      ));
    }
    if (d.favourites != null) {
      items.add(_StatGridItem(label: 'Favourites', value: '${d.favourites}'));
    }
    if (d.duration != null) {
      items.add(_StatGridItem(label: 'Duration', value: '${d.duration} min'));
    }
    if (d.startYear != null) {
      items.add(_StatGridItem(label: 'Start Date', value: formatDate(d.startYear, d.startMonth, d.startDay)));
    }
    if (d.endYear != null) {
      items.add(_StatGridItem(label: 'End Date', value: formatDate(d.endYear, d.endMonth, d.endDay)));
    }
    if (d.studios.isNotEmpty) {
      items.add(_StatGridItem(label: 'Studio', value: d.studios.first));
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisExtent: 60,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => _StatGridTile(item: items[i], cs: cs),
    );
  }
}

class _StatGridItem {
  final String label;
  final String value;
  final bool accent;
  const _StatGridItem({required this.label, required this.value, this.accent = false});
}

class _StatGridTile extends StatelessWidget {
  final _StatGridItem item;
  final ColorScheme cs;
  const _StatGridTile({required this.item, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            item.label,
            style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 3),
          Text(
            item.value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: item.accent ? cs.primary : cs.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Characters tab with language filter
// ─────────────────────────────────────────────────────────────────────────────

class _CharactersWithFilter extends StatefulWidget {
  final List<AnilistCharacter> characters;
  final void Function(AnilistCharacter) onCharTap;
  final void Function(AnilistVoiceActor) onVATap;

  const _CharactersWithFilter({
    required this.characters,
    required this.onCharTap,
    required this.onVATap,
  });

  @override
  State<_CharactersWithFilter> createState() => _CharactersWithFilterState();
}

class _CharactersWithFilterState extends State<_CharactersWithFilter> {
  String? _selectedLang;

  @override
  void initState() {
    super.initState();
    // Default to Japanese if available
    final langs = _uniqueLangs();
    if (langs.contains('Japanese')) {
      _selectedLang = 'Japanese';
    } else if (langs.isNotEmpty) {
      _selectedLang = langs.first;
    }
  }

  List<String> _uniqueLangs() {
    final seen = <String>{};
    final langs = <String>[];
    for (final c in widget.characters) {
      final lang = c.voiceActor?.language;
      if (lang != null && seen.add(lang)) langs.add(lang);
    }
    return langs;
  }

  List<AnilistCharacter> _filtered() {
    if (_selectedLang == null) return widget.characters;
    return widget.characters
        .where((c) => c.voiceActor == null || c.voiceActor!.language == _selectedLang)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final langs = _uniqueLangs();
    final filtered = _filtered();

    return Column(
      children: [
        // Language filter pills
        if (langs.isNotEmpty)
          SizedBox(
            height: 44,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              scrollDirection: Axis.horizontal,
              itemCount: langs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final lang = langs[i];
                final selected = lang == _selectedLang;
                return GestureDetector(
                  onTap: () => setState(() => _selectedLang = lang),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? cs.primary.withValues(alpha: 0.15)
                          : cs.surfaceContainerHigh.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected ? cs.primary.withValues(alpha: 0.5) : Colors.transparent,
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (selected) ...[
                          Icon(Icons.check_rounded, size: 13, color: cs.primary),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          lang,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                            color: selected ? cs.primary : cs.onSurface.withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        if (langs.isNotEmpty)
          Divider(height: 1, thickness: 0.5, color: cs.outlineVariant.withValues(alpha: 0.2)),

        // Character list
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              thickness: 0.5,
              color: cs.outlineVariant.withValues(alpha: 0.2),
            ),
            itemBuilder: (_, i) => _CharacterRow(
              character: filtered[i],
              onCharTap: () => widget.onCharTap(filtered[i]),
              onVATap: filtered[i].voiceActor != null
                  ? () => widget.onVATap(filtered[i].voiceActor!)
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Character row — rounded avatars, otraku style
// ─────────────────────────────────────────────────────────────────────────────

class _CharacterRow extends StatelessWidget {
  final AnilistCharacter character;
  final VoidCallback onCharTap;
  final VoidCallback? onVATap;

  const _CharacterRow({
    required this.character,
    required this.onCharTap,
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
      height: 90,
      child: Row(
        children: [
          // Character side
          Expanded(
            child: GestureDetector(
              onTap: onCharTap,
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  _RoundedAvatar(url: character.imageUrl, size: 90),
                  const SizedBox(width: 12),
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

          // Divider
          Container(
            width: 0.5,
            height: 56,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            color: cs.outlineVariant.withValues(alpha: 0.35),
          ),

          // VA side (right)
          if (va != null)
            Expanded(
              child: GestureDetector(
                onTap: onVATap,
                behavior: HitTestBehavior.opaque,
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
                    const SizedBox(width: 12),
                    _RoundedAvatar(url: va.imageUrl, size: 90, isRight: true),
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
// Rounded avatar (with well-rounded corners)
// ─────────────────────────────────────────────────────────────────────────────

class _RoundedAvatar extends StatelessWidget {
  final String? url;
  final double size;
  final bool isRight;

  const _RoundedAvatar({this.url, required this.size, this.isRight = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final radius = BorderRadius.only(
      topLeft: isRight ? const Radius.circular(10) : Radius.zero,
      topRight: isRight ? Radius.zero : const Radius.circular(10),
      bottomLeft: isRight ? const Radius.circular(10) : Radius.zero,
      bottomRight: isRight ? Radius.zero : const Radius.circular(10),
    );
    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        width: size * 0.62,
        height: size,
        child: url != null
            ? ExtendedImage.network(url!, fit: BoxFit.cover, cache: true)
            : Container(
                color: cs.surfaceContainerHighest,
                child: const Icon(Icons.person_rounded, size: 28),
              ),
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
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 84,
        child: Row(
          children: [
            _RoundedAvatar(url: staff.imageUrl, size: 84),
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
              Icon(Icons.chevron_right_rounded, color: cs.onSurface.withValues(alpha: 0.3)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Review card (otraku style from capture)
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
          // Author row
          Row(
            children: [
              if (r.authorAvatar != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: ExtendedImage.network(r.authorAvatar!, fit: BoxFit.cover, cache: true),
                  ),
                )
              else
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_rounded, size: 22),
                ),
              Container(
                width: 0.5,
                height: 36,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                color: cs.outlineVariant.withValues(alpha: 0.4),
              ),
              Expanded(
                child: Text(
                  r.authorName ?? 'Anonymous',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
              if (r.score != null) ...[
                Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                const SizedBox(width: 3),
                Text(
                  '${r.score}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.amber),
                ),
              ],
              if (r.rating != null) ...[
                const SizedBox(width: 12),
                Icon(Icons.thumb_up_outlined, size: 14, color: cs.primary),
                const SizedBox(width: 3),
                Text(
                  '${r.rating}',
                  style: TextStyle(fontSize: 12, color: cs.primary),
                ),
              ],
            ],
          ),

          if (r.summary != null) ...[
            const SizedBox(height: 10),
            Text(
              r.summary!,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, height: 1.4),
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
                  height: 1.55,
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
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Thread card (native, from Threads_screen capture)
// ─────────────────────────────────────────────────────────────────────────────

class _ThreadCard extends StatelessWidget {
  final AnilistThread thread;
  final String mediaTitleForCategories;
  final VoidCallback onTap;

  const _ThreadCard({required this.thread, required this.mediaTitleForCategories, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = thread;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User + time
          Row(
            children: [
              if (t.userAvatar != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: SizedBox(
                    width: 36,
                    height: 36,
                    child: ExtendedImage.network(t.userAvatar!, fit: BoxFit.cover, cache: true),
                  ),
                )
              else
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_rounded, size: 20),
                ),
              const SizedBox(width: 10),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: DefaultTextStyle.of(context).style,
                    children: [
                      TextSpan(
                        text: t.userName,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                      ),
                      TextSpan(
                        text: '  replied ${t.timeAgo()}',
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Thread title
          Text(
            t.title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 4),

          // Categories
          if (t.categories.isNotEmpty)
            Text(
              [...t.categories, mediaTitleForCategories].join(' • '),
              style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.5)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: 10),

          // Stats row
          Row(
            children: [
              Icon(Icons.remove_red_eye_outlined, size: 14, color: cs.onSurface.withValues(alpha: 0.5)),
              const SizedBox(width: 4),
              Text('${t.viewCount}',
                  style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.5))),
              const SizedBox(width: 16),
              Icon(Icons.reply_rounded, size: 14, color: cs.onSurface.withValues(alpha: 0.5)),
              const SizedBox(width: 4),
              Text('${t.replyCount}',
                  style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.5))),
              const SizedBox(width: 16),
              Icon(Icons.favorite_border_rounded, size: 14, color: cs.onSurface.withValues(alpha: 0.5)),
              const SizedBox(width: 4),
              Text('${t.likeCount}',
                  style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.5))),
            ],
          ),
        ],
      ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Activities tab (with Global/Following/Self filter pills)
// ─────────────────────────────────────────────────────────────────────────────

class _ActivitiesTab extends ConsumerStatefulWidget {
  final int mediaId;
  const _ActivitiesTab({required this.mediaId});

  @override
  ConsumerState<_ActivitiesTab> createState() => _ActivitiesTabState();
}

class _ActivitiesTabState extends ConsumerState<_ActivitiesTab> {
  int _filter = 0; // 0=Global, 1=Following, 2=Self

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Only Global is supported without auth
    final activities = ref.watch(activitiesProvider(widget.mediaId));

    return Column(
      children: [
        // Filter pills
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: Row(
            children: [
              _FilterPill(label: 'Global', selected: _filter == 0, cs: cs,
                  onTap: () => setState(() => _filter = 0)),
              const SizedBox(width: 8),
              _FilterPill(label: 'Following', selected: _filter == 1, cs: cs,
                  onTap: () => setState(() => _filter = 1)),
              const SizedBox(width: 8),
              _FilterPill(label: 'Self', selected: _filter == 2, cs: cs,
                  onTap: () => setState(() => _filter = 2)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Divider(height: 1, thickness: 0.5, color: cs.outlineVariant.withValues(alpha: 0.2)),

        // Content
        Expanded(
          child: _filter != 0
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_outline_rounded, size: 48,
                            color: cs.onSurface.withValues(alpha: 0.25)),
                        const SizedBox(height: 12),
                        Text(
                          _filter == 1 ? 'Following requires AniList sign-in' : 'Self requires AniList sign-in',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, color: cs.onSurface.withValues(alpha: 0.6)),
                        ),
                      ],
                    ),
                  ),
                )
              : activities.when(
                  loading: () => const _LoadingView(),
                  error: (e, _) => _ErrorView(message: e.toString()),
                  data: (list) {
                    if (list.isEmpty) return const _EmptyView(message: 'No recent activities');
                    return ListView.separated(
                      padding: const EdgeInsets.only(bottom: 80),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        thickness: 0.5,
                        color: cs.outlineVariant.withValues(alpha: 0.2),
                      ),
                      itemBuilder: (_, i) => _ActivityCard(activity: list[i]),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final bool selected;
  final ColorScheme cs;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    required this.selected,
    required this.cs,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? cs.primary.withValues(alpha: 0.15)
              : cs.surfaceContainerHigh.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? cs.primary.withValues(alpha: 0.4) : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              Icon(Icons.check_rounded, size: 12, color: cs.primary),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? cs.primary : cs.onSurface.withValues(alpha: 0.75),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final AnilistActivity activity;
  const _ActivityCard({required this.activity});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final a = activity;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User row
          Row(
            children: [
              if (a.userAvatar != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: SizedBox(
                    width: 36,
                    height: 36,
                    child: ExtendedImage.network(a.userAvatar!, fit: BoxFit.cover, cache: true),
                  ),
                )
              else
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_rounded, size: 20),
                ),
              const SizedBox(width: 10),
              Text(
                a.userName,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Activity content
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (a.mediaCover != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 42,
                    height: 56,
                    child: ExtendedImage.network(a.mediaCover!, fit: BoxFit.cover, cache: true),
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: DefaultTextStyle.of(context).style.copyWith(fontSize: 13.5),
                        children: [
                          TextSpan(text: '${a.actionText} of '),
                          TextSpan(
                            text: a.mediaTitle ?? '',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 3),
                    if (a.mediaType != null)
                      Text(
                        a.mediaType == 'ANIME' ? 'Tv' : 'Manga',
                        style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.5)),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Time + actions
          Row(
            children: [
              Icon(Icons.access_time_rounded, size: 13, color: cs.onSurface.withValues(alpha: 0.45)),
              const SizedBox(width: 4),
              Text(
                a.timeAgo(),
                style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.45)),
              ),
              const Spacer(),
              Icon(Icons.more_horiz, size: 18, color: cs.onSurface.withValues(alpha: 0.4)),
              const SizedBox(width: 12),
              Icon(Icons.reply_rounded, size: 15, color: cs.onSurface.withValues(alpha: 0.4)),
              const SizedBox(width: 4),
              Text('0', style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.4))),
              const SizedBox(width: 12),
              Icon(Icons.favorite_border_rounded, size: 15, color: cs.onSurface.withValues(alpha: 0.4)),
              const SizedBox(width: 4),
              Text('0', style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.4))),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Recommendation row (list style, otraku capture)
// ─────────────────────────────────────────────────────────────────────────────

class _RecommendationRow extends StatelessWidget {
  final AnilistMedia media;
  final VoidCallback onTap;
  final VoidCallback? onVote;

  const _RecommendationRow({required this.media, required this.onTap, this.onVote});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final m = media;
    final year = m.titleRomaji != null ? _guessYear(m) : null;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 0),
        child: Row(
          children: [
            // Cover
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 52,
                height: 72,
                child: m.bestCover != null
                    ? ExtendedImage.network(m.bestCover!, fit: BoxFit.cover, cache: true)
                    : Container(color: cs.surfaceContainerHighest),
              ),
            ),
            const SizedBox(width: 14),

            // Title + info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    m.displayTitle,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      m.type == 'ANIME' ? 'TV' : 'Manga',
                      if (year != null) year,
                    ].join(' • '),
                    style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.5)),
                  ),
                ],
              ),
            ),

            // Vote count + thumbs
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (m.averageScore != null)
                  Text(
                    '${m.averageScore}',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    GestureDetector(
                      onTap: onVote,
                      child: Icon(Broken.like, size: 18, color: cs.primary.withValues(alpha: 0.8)),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: onVote,
                      child: Icon(Broken.dislike, size: 18, color: cs.onSurface.withValues(alpha: 0.5)),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String? _guessYear(AnilistMedia m) => null; // no year in base model without detail
}

// ─────────────────────────────────────────────────────────────────────────────
// Statistics content (from Statics_page capture)
// ─────────────────────────────────────────────────────────────────────────────

class _StatisticsContent extends StatelessWidget {
  final AnilistMedia media;
  final AnilistMediaDetail detail;

  const _StatisticsContent({required this.media, required this.detail});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final m = detail;

    if (m.rankings.isEmpty && m.scoreDistribution.isEmpty && m.statusDistribution.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bar_chart_rounded, size: 48, color: cs.onSurface.withValues(alpha: 0.25)),
            const SizedBox(height: 12),
            Text('No statistics available',
                style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5))),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 80),
      children: [
        // Rankings — 2-column grid like otraku
        if (m.rankings.isNotEmpty) ...[
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisExtent: 60,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: m.rankings.length > 4 ? 4 : m.rankings.length,
            itemBuilder: (_, i) => _RankingBadge(ranking: m.rankings[i]),
          ),
          const SizedBox(height: 20),
        ],

        // Score Distribution
        if (m.scoreDistribution.isNotEmpty) ...[
          const _SectionLabel(label: 'Score Distribution'),
          const SizedBox(height: 12),
          _GlassCard(
            child: Column(
              children: () {
                final maxAmt = m.scoreDistribution.map((s) => s.amount).fold(0, (a, b) => a > b ? a : b);
                return m.scoreDistribution.map((s) {
                  final pct = maxAmt > 0 ? s.amount / maxAmt : 0.0;
                  final totalAll = m.scoreDistribution.map((x) => x.amount).fold(0, (a, b) => a + b);
                  final pctStr = totalAll > 0
                      ? '${(s.amount / totalAll * 100).toStringAsFixed(1)}%'
                      : '0%';
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 32,
                          child: Text('${s.score}',
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w600,
                                  color: cs.onSurface.withValues(alpha: 0.7))),
                        ),
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
                          child: Text(pctStr,
                              textAlign: TextAlign.end,
                              style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.5))),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 52,
                          child: Text('${s.amount}',
                              textAlign: TextAlign.end,
                              style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.5))),
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
          const _SectionLabel(label: 'Status Distribution'),
          const SizedBox(height: 12),
          _GlassCard(
            child: Column(
              children: () {
                final total = m.statusDistribution.map((s) => s.amount).fold(0, (a, b) => a + b);
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
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 80,
                          child: Text(label,
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600,
                                  color: cs.onSurface.withValues(alpha: 0.85))),
                        ),
                        Expanded(
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
                        SizedBox(
                          width: 60,
                          child: Text('${s.amount}',
                              textAlign: TextAlign.end,
                              style: TextStyle(
                                  fontSize: 12, color: cs.onSurface.withValues(alpha: 0.55))),
                        ),
                      ],
                    ),
                  );
                }).toList();
              }(),
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ranking badge (2-column card style from capture)
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '#${ranking.rank} ${ranking.context}',
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Watch Order item (numbered timeline)
// ─────────────────────────────────────────────────────────────────────────────

class _WatchOrderItem extends StatelessWidget {
  final int index;
  final AnilistRelation relation;
  final String friendlyType;
  final bool isLast;
  final VoidCallback onTap;

  const _WatchOrderItem({
    required this.index,
    required this.relation,
    required this.friendlyType,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Timeline column
            SizedBox(
              width: 44,
              child: Column(
                children: [
                  // Number circle
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: cs.primary.withValues(alpha: 0.4), width: 1.5),
                    ),
                    child: Center(
                      child: Text(
                        '$index',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: cs.primary,
                        ),
                      ),
                    ),
                  ),
                  // Vertical line
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 1.5,
                        color: cs.outlineVariant.withValues(alpha: 0.3),
                      ),
                    ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: 8, bottom: isLast ? 0 : 16),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLow.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      // Cover
                      ClipRRect(
                        borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
                        child: SizedBox(
                          width: 80,
                          height: 110,
                          child: relation.coverImage != null
                              ? ExtendedImage.network(
                                  relation.coverImage!,
                                  fit: BoxFit.cover,
                                  cache: true,
                                )
                              : Container(color: cs.surfaceContainerHighest),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (friendlyType.isNotEmpty)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: cs.primary.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    friendlyType,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: cs.primary,
                                    ),
                                  ),
                                ),
                              Text(
                                relation.title,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  height: 1.3,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (relation.type.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  _friendlyMediaType(relation.type, relation.format),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: cs.onSurface.withValues(alpha: 0.5),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: Icon(Icons.chevron_right_rounded,
                            color: cs.onSurface.withValues(alpha: 0.3)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Relation card (grid, used in Related tab + Overview)
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
                  if (friendlyType.isNotEmpty)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black.withValues(alpha: 0.75)],
                          ),
                        ),
                        child: Text(
                          friendlyType,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                          ),
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
// Shared UI helpers
// ─────────────────────────────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  const _LoadingView();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: CircularProgressIndicator(
        color: Theme.of(context).colorScheme.primary,
        strokeWidth: 2.5,
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 48, color: cs.onSurface.withValues(alpha: 0.25)),
            const SizedBox(height: 12),
            Text(
              message.length > 120 ? '${message.substring(0, 120)}…' : message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.6)),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final String message;
  const _EmptyView({required this.message});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Text(message, style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5))),
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
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.09)
                : Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.28),
              width: 0.8,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Scrolling title (marquee when text overflows)
// ─────────────────────────────────────────────────────────────────────────────

class _ScrollingTitle extends StatefulWidget {
  final String text;
  const _ScrollingTitle({required this.text});

  @override
  State<_ScrollingTitle> createState() => _ScrollingTitleState();
}

class _ScrollingTitleState extends State<_ScrollingTitle>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 4))
      ..addStatusListener((s) {
        if (!mounted) return;
        if (s == AnimationStatus.completed) {
          Future.delayed(const Duration(milliseconds: 800), () {
            if (mounted) _ctrl.reverse();
          });
        } else if (s == AnimationStatus.dismissed) {
          Future.delayed(const Duration(milliseconds: 800), () {
            if (mounted) _ctrl.forward();
          });
        }
      })
      ..addListener(() {
        if (!_scrollCtrl.hasClients) return;
        final max = _scrollCtrl.position.maxScrollExtent;
        if (max <= 0) return;
        _scrollCtrl.jumpTo(_ctrl.value * max);
      });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollCtrl.hasClients) return;
      if (_scrollCtrl.position.maxScrollExtent > 0) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollCtrl,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Text(
          widget.text,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, height: 1.2),
          maxLines: 1,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// More-menu bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _MoreMenuOption {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;
  const _MoreMenuOption({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });
}

class _MoreMenuSheet extends StatelessWidget {
  final ColorScheme cs;
  final List<_MoreMenuOption> options;
  const _MoreMenuSheet({required this.cs, required this.options});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          decoration: BoxDecoration(
            color: cs.surface.withValues(alpha: 0.96),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: cs.onSurface.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...options.map((o) {
                    final color = o.isDestructive ? Colors.redAccent : cs.onSurface;
                    return InkWell(
                      onTap: o.onTap,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                        child: Row(
                          children: [
                            Icon(o.icon, size: 22, color: color.withValues(alpha: 0.8)),
                            const SizedBox(width: 16),
                            Text(
                              o.label,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Friendly media type label (handles Novel vs Manga)
// ─────────────────────────────────────────────────────────────────────────────

String _friendlyMediaType(String type, String? format) {
  if (format == 'NOVEL') return 'Novel';
  if (format == 'ONE_SHOT') return 'One-shot';
  if (format == 'MANHWA') return 'Manhwa';
  if (format == 'MANHUA') return 'Manhua';
  if (type == 'ANIME') return 'Anime';
  if (type == 'MANGA') return 'Manga';
  return type;
}

// ─────────────────────────────────────────────────────────────────────────────

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
        width: 40,
        height: 40,
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
        height: 50,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 19, color: fg),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _label(),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cs.onPrimaryContainer),
      ),
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

// ─────────────────────────────────────────────────────────────────────────────
// Episodes Tab — AniZip data
// ─────────────────────────────────────────────────────────────────────────────

class _EpisodesTab extends ConsumerStatefulWidget {
  final AnilistMedia media;
  final ColorScheme cs;
  const _EpisodesTab({required this.media, required this.cs});

  @override
  ConsumerState<_EpisodesTab> createState() => _EpisodesTabState();
}

class _EpisodesTabState extends ConsumerState<_EpisodesTab> {
  bool _showSpecials = false;

  @override
  Widget build(BuildContext context) {
    final m = widget.media;
    final cs = widget.cs;

    if (m.type != 'ANIME') {
      return const _EmptyView(message: 'Episode data is only available for anime');
    }

    final episodesAsync = ref.watch(aniZipEpisodesProvider(m.id));

    return episodesAsync.when(
      loading: () => const _LoadingView(),
      error: (e, _) => _ErrorView(message: 'Could not load episodes: ${e.toString()}'),
      data: (list) {
        if (list.isEmpty) {
          return const _EmptyView(message: 'No episode data available yet');
        }

        final specials = list.where((e) => e.episodeNumber == 0).toList();
        final regular = list.where((e) => e.episodeNumber > 0).toList();
        final displayed = _showSpecials ? list : regular;

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
          itemCount: displayed.length + 1,
          itemBuilder: (ctx, i) {
            if (i == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Text(
                      '${regular.length} Episodes',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    if (specials.isNotEmpty)
                      GestureDetector(
                        onTap: () => setState(() => _showSpecials = !_showSpecials),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: cs.primary.withValues(alpha: _showSpecials ? 0.2 : 0.08),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Specials',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: cs.primary,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }
            final ep = displayed[i - 1];
            return _EpisodeRow(episode: ep, media: m, cs: cs);
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Single Episode Row
// ─────────────────────────────────────────────────────────────────────────────

class _EpisodeRow extends StatefulWidget {
  final AniZipEpisode episode;
  final AnilistMedia media;
  final ColorScheme cs;
  const _EpisodeRow({
    required this.episode,
    required this.media,
    required this.cs,
    super.key,
  });

  @override
  State<_EpisodeRow> createState() => _EpisodeRowState();
}

class _EpisodeRowState extends State<_EpisodeRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final ep = widget.episode;
    final cs = widget.cs;
    final title = ep.displayTitle;
    final hasOverview = ep.overview != null && ep.overview!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: cs.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _showStreamSheet(context),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: cs.outlineVariant.withValues(alpha: 0.18),
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Thumbnail ─────────────────────────────────────────────
                SizedBox(
                  width: 120,
                  height: 90,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          bottomLeft: Radius.circular(12),
                        ),
                        child: ep.image != null
                            ? Image.network(
                                ep.image!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const _EpisodePlaceholder(),
                              )
                            : const _EpisodePlaceholder(),
                      ),
                      Positioned(
                        bottom: 5,
                        right: 5,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            ep.episodeNumber == 0
                                ? 'S'
                                : 'EP ${ep.episodeNumber}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Info ───────────────────────────────────────────────────
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title + duration
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  height: 1.3,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (ep.runtime != null) ...[
                              const SizedBox(width: 6),
                              Text(
                                '${ep.runtime}m',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: cs.onSurface.withValues(alpha: 0.45),
                                ),
                              ),
                            ],
                          ],
                        ),

                        // Air date
                        if (ep.airDate != null && ep.airDate!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            ep.airDate!,
                            style: TextStyle(
                              fontSize: 11,
                              color: cs.onSurface.withValues(alpha: 0.4),
                            ),
                          ),
                        ],

                        // Synopsis (collapsible)
                        if (hasOverview) ...[
                          const SizedBox(height: 5),
                          GestureDetector(
                            onTap: () =>
                                setState(() => _expanded = !_expanded),
                            child: Text(
                              ep.overview!,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: cs.onSurface.withValues(alpha: 0.62),
                                height: 1.45,
                              ),
                              maxLines: _expanded ? null : 2,
                              overflow: _expanded
                                  ? TextOverflow.visible
                                  : TextOverflow.ellipsis,
                            ),
                          ),
                        ],

                        // Play button — full-width
                        const SizedBox(height: 8),
                        _SmallPlayButton(
                          icon: Icons.play_circle_filled_rounded,
                          label: 'Watch',
                          cs: cs,
                          fullWidth: true,
                          onTap: () => _showStreamSheet(context),
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
    );
  }

  void _showStreamSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _StreamSheet(
        episode: widget.episode,
        media: widget.media,
        cs: widget.cs,
      ),
    );
  }
}

class _SmallPlayButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final ColorScheme cs;
  final VoidCallback onTap;
  final bool fullWidth;
  const _SmallPlayButton({
    required this.icon,
    required this.label,
    required this.cs,
    required this.onTap,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: fullWidth ? double.infinity : null,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: cs.primary),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: cs.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EpisodePlaceholder extends StatelessWidget {
  const _EpisodePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context)
          .colorScheme
          .surfaceContainerHighest
          .withValues(alpha: 0.45),
      child: const Icon(Icons.videocam_outlined,
          color: Colors.white24, size: 28),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stream Source Sheet — Local · Online (Extensions) · Manual URL
// ─────────────────────────────────────────────────────────────────────────────

class _StreamSheet extends ConsumerStatefulWidget {
  final AniZipEpisode episode;
  final AnilistMedia media;
  final ColorScheme cs;
  const _StreamSheet({
    required this.episode,
    required this.media,
    required this.cs,
  });

  @override
  ConsumerState<_StreamSheet> createState() => _StreamSheetState();
}

class _StreamSheetState extends ConsumerState<_StreamSheet> {
  final _urlCtrl = TextEditingController();
  bool _showUrl = false;

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  // ── Local: look up Isar for a matching anime Manga ──────────────────────────
  void _playLocal(BuildContext context) {
    Navigator.pop(context);
    final names = <String>{
      if (widget.media.titleRomaji != null) widget.media.titleRomaji!,
      if (widget.media.titleEnglish != null) widget.media.titleEnglish!,
      if (widget.media.titleNative != null) widget.media.titleNative!,
    };
    Manga? found;
    for (final name in names) {
      found = isar.mangas
          .filter()
          .itemTypeEqualTo(ItemType.anime)
          .nameContains(name, caseSensitive: false)
          .findFirstSync();
      if (found != null) break;
    }
    if (found != null && context.mounted) {
      context.push('/manga-reader/detail', extra: found.id!);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This anime is not in your library yet. '
            'Find it via "Extensions" first.',
          ),
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  // ── Extensions: global search pre-filled with the title ────────────────────
  void _searchExtension(BuildContext context) {
    Navigator.pop(context);
    final query = widget.media.titleEnglish ??
        widget.media.titleRomaji ??
        widget.media.displayTitle;
    context.push('/globalSearch', extra: (query, ItemType.anime));
  }

  // ── Manual URL: open in webview ─────────────────────────────────────────────
  void _playManualUrl(BuildContext context) {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) return;
    Navigator.pop(context);
    context.push('/mangawebview', extra: {
      'url': url,
      'title':
          'EP ${widget.episode.episodeNumber} · ${widget.episode.displayTitle}',
    });
  }

  @override
  Widget build(BuildContext context) {
    final ep = widget.episode;
    final cs = widget.cs;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Episode label
          Text(
            widget.media.displayTitle,
            style: TextStyle(
                fontSize: 12,
                color: cs.onSurface.withValues(alpha: 0.5),
                fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            'EP ${ep.episodeNumber} · ${ep.displayTitle}',
            style: const TextStyle(
                fontSize: 17, fontWeight: FontWeight.w700, height: 1.2),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 22),

          // ── Local library ─────────────────────────────────────────────────
          _StreamOption(
            icon: Icons.folder_outlined,
            label: 'Local Library',
            subtitle: 'Play from files already in your library',
            cs: cs,
            onTap: () => _playLocal(context),
          ),
          const SizedBox(height: 10),

          // ── Extensions (online) ────────────────────────────────────────────
          _StreamOption(
            icon: Icons.extension_outlined,
            label: 'Extensions — Online',
            subtitle: 'Smart search via your installed anime sources',
            cs: cs,
            onTap: () => _searchExtension(context),
          ),
          const SizedBox(height: 10),

          // ── Manual URL ────────────────────────────────────────────────────
          _StreamOption(
            icon: Icons.link_rounded,
            label: 'Manual URL',
            subtitle: 'Paste a direct stream link to watch',
            cs: cs,
            onTap: () => setState(() => _showUrl = !_showUrl),
            trailing: Icon(
              _showUrl ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              color: cs.onSurface.withValues(alpha: 0.35),
            ),
          ),

          if (_showUrl) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _urlCtrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'https://...',
                filled: true,
                fillColor:
                    cs.surfaceContainerHighest.withValues(alpha: 0.5),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: IconButton(
                  icon: Icon(Icons.play_circle_filled_rounded,
                      color: cs.primary, size: 26),
                  onPressed: () => _playManualUrl(context),
                ),
              ),
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.go,
              onSubmitted: (_) => _playManualUrl(context),
            ),
          ],
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _StreamOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final ColorScheme cs;
  final VoidCallback onTap;
  final Widget? trailing;
  const _StreamOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.cs,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            border: Border.all(
                color: cs.outlineVariant.withValues(alpha: 0.2)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: cs.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha: 0.52),
                      ),
                    ),
                  ],
                ),
              ),
              trailing ??
                  Icon(Icons.chevron_right_rounded,
                      color: cs.onSurface.withValues(alpha: 0.3)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Genre category card — gradient tile with genre name
// ─────────────────────────────────────────────────────────────────────────────

class _GenreCategoryCard extends StatelessWidget {
  final String genre;
  const _GenreCategoryCard({required this.genre});

  static const _colors = <String, List<Color>>{
    'Action':       [Color(0xFFE53935), Color(0xFFB71C1C)],
    'Adventure':    [Color(0xFF43A047), Color(0xFF1B5E20)],
    'Comedy':       [Color(0xFFFFB300), Color(0xFFF57F17)],
    'Drama':        [Color(0xFF8E24AA), Color(0xFF4A148C)],
    'Fantasy':      [Color(0xFF1E88E5), Color(0xFF0D47A1)],
    'Horror':       [Color(0xFF616161), Color(0xFF212121)],
    'Mecha':        [Color(0xFF546E7A), Color(0xFF263238)],
    'Music':        [Color(0xFFD81B60), Color(0xFF880E4F)],
    'Mystery':      [Color(0xFF5E35B1), Color(0xFF311B92)],
    'Romance':      [Color(0xFFEC407A), Color(0xFFC2185B)],
    'Sci-Fi':       [Color(0xFF00ACC1), Color(0xFF006064)],
    'Slice of Life':[Color(0xFF26A69A), Color(0xFF004D40)],
    'Sports':       [Color(0xFF7CB342), Color(0xFF33691E)],
    'Supernatural': [Color(0xFF7E57C2), Color(0xFF4527A0)],
    'Thriller':     [Color(0xFF6D4C41), Color(0xFF3E2723)],
    'Ecchi':        [Color(0xFFFF7043), Color(0xFFBF360C)],
    'Hentai':       [Color(0xFFEF5350), Color(0xFFB71C1C)],
    'Psychological':[Color(0xFF455A64), Color(0xFF263238)],
    'Mahou Shoujo': [Color(0xFFAD1457), Color(0xFF880E4F)],
    'Martial Arts': [Color(0xFFE64A19), Color(0xFFBF360C)],
  };

  @override
  Widget build(BuildContext context) {
    final colors = _colors[genre] ?? [const Color(0xFF455A64), const Color(0xFF263238)];
    return Container(
      width: 120,
      height: 68,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            genre,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
              shadows: [Shadow(color: Colors.black38, blurRadius: 4)],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Relation list tile — horizontal card for the Related tab
// ─────────────────────────────────────────────────────────────────────────────

class _RelationListTile extends StatelessWidget {
  final AnilistRelation relation;
  final String friendlyType;
  final VoidCallback onTap;

  const _RelationListTile({
    required this.relation,
    required this.friendlyType,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
              child: SizedBox(
                width: 70,
                height: 100,
                child: relation.coverImage != null
                    ? ExtendedImage.network(
                        relation.coverImage!,
                        fit: BoxFit.cover,
                        cache: true,
                      )
                    : Container(color: cs.surfaceContainerHighest),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (friendlyType.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          friendlyType,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: cs.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                    ],
                    Text(
                      relation.title,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (relation.type.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        _friendlyMediaType(relation.type, relation.format),
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(
                Icons.chevron_right_rounded,
                color: cs.onSurface.withValues(alpha: 0.3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Person bottom sheet — native profile view for character / staff / VA
// ─────────────────────────────────────────────────────────────────────────────

class _PersonSheet extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final String? subtitle;
  final String kind;
  final String? siteUrl;
  final VoidCallback? onOpenWeb;

  const _PersonSheet({
    required this.name,
    this.imageUrl,
    this.subtitle,
    required this.kind,
    this.siteUrl,
    this.onOpenWeb,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          decoration: BoxDecoration(
            color: cs.surface.withValues(alpha: 0.93),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(color: cs.outline.withValues(alpha: 0.10), width: 0.8),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: cs.onSurface.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Avatar + name row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: SizedBox(
                          width: 90,
                          height: 120,
                          child: imageUrl != null
                              ? ExtendedImage.network(
                                  imageUrl!,
                                  fit: BoxFit.cover,
                                  cache: true,
                                )
                              : Container(
                                  color: cs.surfaceContainerHighest,
                                  child: const Icon(Icons.person_rounded, size: 40),
                                ),
                        ),
                      ),
                      const SizedBox(width: 18),

                      // Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: cs.primaryContainer.withValues(alpha: 0.75),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                kind,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: cs.onPrimaryContainer,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                height: 1.2,
                              ),
                            ),
                            if (subtitle != null && subtitle!.isNotEmpty) ...[
                              const SizedBox(height: 5),
                              Text(
                                subtitle!,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: cs.onSurface.withValues(alpha: 0.55),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Open AniList button
                  if (onOpenWeb != null)
                    SizedBox(
                      width: double.infinity,
                      child: GestureDetector(
                        onTap: onOpenWeb,
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: cs.primary,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.open_in_new_rounded, size: 17, color: Colors.white),
                              const SizedBox(width: 8),
                              Text(
                                'Voir sur AniList',
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
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Watch Order tab — media type selector (Anime / Manga / Novel)
// ─────────────────────────────────────────────────────────────────────────────

class _WatchOrderTab extends StatefulWidget {
  final List<AnilistRelation> relations;
  final String Function(String?) friendlyRelationType;
  final int Function(String?) watchOrderSort;
  final void Function(AnilistRelation) onRelationTap;

  const _WatchOrderTab({
    required this.relations,
    required this.friendlyRelationType,
    required this.watchOrderSort,
    required this.onRelationTap,
  });

  @override
  State<_WatchOrderTab> createState() => _WatchOrderTabState();
}

class _WatchOrderTabState extends State<_WatchOrderTab> {
  int _typeIdx = 0; // 0=Anime, 1=Manga, 2=Novel

  static const _typeLabels = ['Anime', 'Manga', 'Novel'];

  List<AnilistRelation> _filtered() {
    final all = widget.relations;
    final List<AnilistRelation> subset;

    switch (_typeIdx) {
      case 0:
        subset = all.where((r) => r.type == 'ANIME').toList();
        break;
      case 1:
        subset = all.where((r) => r.type == 'MANGA' && r.format != 'NOVEL').toList();
        break;
      case 2:
        subset = all.where((r) => r.format == 'NOVEL').toList();
        break;
      default:
        subset = all;
    }

    if (subset.isEmpty) return subset;
    return [...subset]
      ..sort((a, b) => widget.watchOrderSort(a.relationType).compareTo(widget.watchOrderSort(b.relationType)));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final displayed = _filtered();

    return Column(
      children: [
        // Type selector pills
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: Row(
            children: List.generate(_typeLabels.length, (i) {
              final selected = i == _typeIdx;
              return Padding(
                padding: EdgeInsets.only(right: i < _typeLabels.length - 1 ? 8 : 0),
                child: GestureDetector(
                  onTap: () => setState(() => _typeIdx = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? cs.primary.withValues(alpha: 0.15)
                          : cs.surfaceContainerHigh.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected ? cs.primary.withValues(alpha: 0.5) : Colors.transparent,
                        width: 1.2,
                      ),
                    ),
                    child: Text(
                      _typeLabels[i],
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected ? cs.primary : cs.onSurface.withValues(alpha: 0.75),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 8),
        Divider(height: 1, thickness: 0.5, color: cs.outlineVariant.withValues(alpha: 0.2)),

        // List
        Expanded(
          child: displayed.isEmpty
              ? Center(
                  child: Text(
                    'Pas de ${_typeLabels[_typeIdx].toLowerCase()} lié',
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.5),
                      fontSize: 14,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  itemCount: displayed.length,
                  itemBuilder: (_, i) {
                    final r = displayed[i];
                    final isLast = i == displayed.length - 1;
                    return _WatchOrderItem(
                      index: i + 1,
                      relation: r,
                      friendlyType: widget.friendlyRelationType(r.relationType),
                      isLast: isLast,
                      onTap: () => widget.onRelationTap(r),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
