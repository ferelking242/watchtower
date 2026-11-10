import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/l10n/generated/app_localizations.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/modules/more/settings/reader/providers/reader_state_provider.dart';
import 'package:watchtower/modules/more/statistics/statistics_provider.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/utils/item_type_filters.dart';
import 'package:watchtower/utils/item_type_localization.dart';
import 'dart:math' as math;

/// One coherent accent palette for the whole page. Every status reuses the
/// same hue across the overview grid, the breakdown bars and the mini stats so
/// the screen stops reading as a bag of unrelated colours.
class _StatsPalette {
  const _StatsPalette._();

  static const inLibrary = Color(0xFF8B7BF7);
  static const completed = Color(0xFF35C48A);
  static const ongoing = Color(0xFF3E9BFF);
  static const onHold = Color(0xFFF0A93B);
  static const dropped = Color(0xFFE5677C);
  static const updated = Color(0xFF2BB8C4);
  static const time = Color(0xFF9C6BF2);
  static const downloads = Color(0xFF3E9BFF);
}

class StatisticsScreen extends ConsumerStatefulWidget {
  const StatisticsScreen({super.key});

  @override
  ConsumerState<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends ConsumerState<StatisticsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late final List<ItemType> _visibleTabTypes;

  @override
  void initState() {
    super.initState();
    _visibleTabTypes = hiddenItemTypes(ref.read(hideItemsStateProvider));
    _tabController = TabController(
      length: _visibleTabTypes.length,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (_visibleTabTypes.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          leading: _StatsBackButton(),
          title: Text(l10n.statistics),
        ),
        body: const Center(child: Text("No data yet.")),
      );
    }
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        leading: _StatsBackButton(),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _StatsPalette.inLibrary.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Broken.presention_chart,
                size: 18,
                color: _StatsPalette.inLibrary,
              ),
            ),
            const SizedBox(width: 10),
            Text(l10n.statistics),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorSize: TabBarIndicatorSize.label,
          indicatorColor: _StatsPalette.inLibrary,
          labelColor: _StatsPalette.inLibrary,
          unselectedLabelColor: cs.onSurfaceVariant,
          dividerColor: Colors.transparent,
          tabs: _visibleTabTypes.map((type) {
            return Tab(text: type.localized(l10n));
          }).toList(),
        ),
      ),
      body: _AnimatedStatsBackground(
        child: TabBarView(
          controller: _tabController,
          children: _visibleTabTypes.map((type) {
            return _StatisticsTabView(itemType: type);
          }).toList(),
        ),
      ),
    );
  }
}

/// Back control for the statistics page. `/statistics` is a top-level shell
/// route, so popping it would empty the stack and let the platform back handler
/// close the app — always return to the home tab instead.
class _StatsBackButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Broken.arrow_left_2),
      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
      onPressed: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/WatchtowerHome');
        }
      },
    );
  }
}

class _AnimatedStatsBackground extends StatefulWidget {
  final Widget child;
  const _AnimatedStatsBackground({required this.child});

  @override
  State<_AnimatedStatsBackground> createState() =>
      _AnimatedStatsBackgroundState();
}

class _AnimatedStatsBackgroundState extends State<_AnimatedStatsBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final t = _ctrl.value;
        return Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment(-1 + t, -1),
                  end: Alignment(1 - t, 1),
                  colors: [
                    cs.primary.withValues(alpha: 0.10),
                    cs.tertiary.withValues(alpha: 0.06),
                    cs.surface,
                  ],
                ),
              ),
            ),
            Positioned(
              top: 60 + 30 * t,
              right: -40 + 20 * t,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      cs.primary.withValues(alpha: 0.18),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 80 - 40 * t,
              left: -60 + 30 * t,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      cs.tertiary.withValues(alpha: 0.14),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            child!,
          ],
        );
      },
      child: widget.child,
    );
  }
}

class _StatisticsTabView extends ConsumerStatefulWidget {
  final ItemType itemType;
  const _StatisticsTabView({required this.itemType});

  @override
  ConsumerState<_StatisticsTabView> createState() => _StatisticsTabViewState();
}

class _StatisticsTabViewState extends ConsumerState<_StatisticsTabView>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fade = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  String _formatDuration(int totalSeconds) {
    if (totalSeconds <= 0) return '0m';
    final days = totalSeconds ~/ 86400;
    final hours = (totalSeconds % 86400) ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final parts = <String>[];
    if (days > 0) parts.add('${days}d');
    if (hours > 0) parts.add('${hours}h');
    if (minutes > 0 || parts.isEmpty) parts.add('${minutes}m');
    return parts.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final statsAsync = ref.watch(
      getStatisticsProvider(itemType: widget.itemType),
    );

    return statsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text("Error: $err")),
      data: (stats) {
        _animCtrl.forward(from: 0);
        final isAnime = widget.itemType == ItemType.anime;
        final chapterLabel = isAnime ? l10n.episodes : l10n.chapters;
        final unreadLabel = isAnime ? l10n.unwatched : l10n.unread;
        final readLabel = isAnime ? l10n.watching_time : l10n.reading_time;
        final readChapters = stats.readChapters;
        final totalChapters = stats.totalChapters;
        final unreadChapters = totalChapters - readChapters;
        final readPct =
            totalChapters > 0 ? readChapters / totalChapters : 0.0;
        final completedPct =
            stats.totalItems > 0
                ? stats.completedItems / stats.totalItems
                : 0.0;
        final averageChaps =
            stats.totalItems > 0 ? totalChapters / stats.totalItems : 0.0;

        return FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 100),
              children: [
                _SectionLabel(text: l10n.entries),
                const SizedBox(height: 8),
                _OverviewGrid(
                  items: [
                    _GridStat(
                      icon: Broken.video_square,
                      value: '${stats.totalItems}',
                      label: l10n.in_library,
                      color: _StatsPalette.inLibrary,
                    ),
                    _GridStat(
                      icon: Broken.tick_circle,
                      value: '${stats.completedItems}',
                      label: l10n.completed,
                      color: _StatsPalette.completed,
                    ),
                    _GridStat(
                      icon: Broken.play_circle,
                      value: '${stats.ongoingItems}',
                      label: l10n.ongoing,
                      color: _StatsPalette.ongoing,
                    ),
                    _GridStat(
                      icon: Broken.pause_circle,
                      value: '${stats.onHoldItems}',
                      label: l10n.on_hold,
                      color: _StatsPalette.onHold,
                    ),
                    _GridStat(
                      icon: Broken.close_circle,
                      value: '${stats.droppedItems}',
                      label: l10n.dropped,
                      color: _StatsPalette.dropped,
                    ),
                    _GridStat(
                      icon: Broken.refresh_circle,
                      value: '${stats.updatedThisWeek}',
                      label: 'This Week',
                      color: _StatsPalette.updated,
                    ),
                  ],
                ),

                const SizedBox(height: 20),
                _SectionLabel(text: 'Status Breakdown'),
                const SizedBox(height: 8),
                _StatusBreakdownCard(
                  stats: stats,
                  completedPct: completedPct,
                ),

                const SizedBox(height: 20),
                _SectionLabel(text: chapterLabel),
                const SizedBox(height: 8),
                _ChaptersCard(
                  totalChapters: totalChapters,
                  readChapters: readChapters,
                  unreadChapters: unreadChapters,
                  downloadedChapters: stats.totalDownloadedChapters,
                  readPct: readPct,
                  averageChaps: averageChaps,
                  readLabel: l10n.read,
                  unreadLabel: unreadLabel,
                  title: widget.itemType.localized(l10n),
                  animCtrl: _animCtrl,
                  l10n: l10n,
                ),

                const SizedBox(height: 20),
                _SectionLabel(text: readLabel),
                const SizedBox(height: 8),
                _TimeCard(
                  totalSeconds: stats.totalReadingTimeSeconds,
                  totalItems: stats.totalItems,
                  isAnime: isAnime,
                  formatDuration: _formatDuration,
                ),

                if (stats.topGenres.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _SectionLabel(text: 'Top Genres'),
                  const SizedBox(height: 8),
                  _TopGenresCard(
                    genres: stats.topGenres,
                    animCtrl: _animCtrl,
                  ),
                ],

                const SizedBox(height: 20),
                _SectionLabel(text: 'Downloads'),
                const SizedBox(height: 8),
                _DownloadsCard(
                  downloadedTitles: stats.downloadedItems,
                  downloadedChapters: stats.totalDownloadedChapters,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: cs.primary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _GridStat {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  const _GridStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });
}

class _OverviewGrid extends StatefulWidget {
  final List<_GridStat> items;
  const _OverviewGrid({required this.items});

  @override
  State<_OverviewGrid> createState() => _OverviewGridState();
}

class _OverviewGridState extends State<_OverviewGrid>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    )..forward();
  }

  @override
  void didUpdateWidget(covariant _OverviewGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A new data snapshot (tab switch, refresh) replays the staggered reveal.
    if (oldWidget.items != widget.items) _ctrl.forward(from: 0);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final items = widget.items;
    return GridView.count(
      crossAxisCount: 3,
      childAspectRatio: 1.05,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: items.asMap().entries.map((entry) {
        final s = entry.value;
        // Each tile lands a little after the previous one (bottom-right last).
        final start = (entry.key * 0.07).clamp(0.0, 0.6);
        final interval = CurvedAnimation(
          parent: _ctrl,
          curve: Interval(start, (start + 0.5).clamp(0.0, 1.0),
              curve: Curves.easeOutBack),
        );
        final fade = CurvedAnimation(
          parent: _ctrl,
          curve: Interval(start, (start + 0.4).clamp(0.0, 1.0),
              curve: Curves.easeOut),
        );
        return FadeTransition(
          opacity: fade,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.82, end: 1).animate(interval),
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.18),
                end: Offset.zero,
              ).animate(interval),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? cs.surfaceContainerHigh.withValues(alpha: 0.7)
                      : cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: s.color.withValues(alpha: 0.2),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: s.color.withValues(alpha: isDark ? 0.15 : 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: s.color.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(s.icon, color: s.color, size: 18),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      s.value,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                        color: s.color,
                      ),
                    ),
                    Text(
                      s.label,
                      style: TextStyle(
                        fontSize: 9.5,
                        color: cs.onSurface.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _StatusBreakdownCard extends StatelessWidget {
  final StatisticsData stats;
  final double completedPct;
  const _StatusBreakdownCard({
    required this.stats,
    required this.completedPct,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final total = stats.totalItems;

    final bars = [
      (
        'Completed',
        stats.completedItems,
        _StatsPalette.completed,
        Broken.tick_circle,
      ),
      ('Ongoing', stats.ongoingItems, _StatsPalette.ongoing, Broken.play_circle),
      (
        'On Hold',
        stats.onHoldItems,
        _StatsPalette.onHold,
        Broken.pause_circle,
      ),
      ('Dropped', stats.droppedItems, _StatsPalette.dropped, Broken.close_circle),
    ];

    return _GlassCard(
      child: Column(
        children: bars.map((bar) {
          final pct = total > 0 ? bar.$2 / total : 0.0;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(bar.$4, size: 14, color: bar.$3),
                        const SizedBox(width: 6),
                        Text(
                          bar.$1,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${bar.$2}  (${(pct * 100).toStringAsFixed(1)}%)',
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurface.withValues(alpha: 0.5),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: pct),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) {
                      return LinearProgressIndicator(
                        value: value,
                        minHeight: 7,
                        backgroundColor: bar.$3.withValues(alpha: 0.1),
                        valueColor: AlwaysStoppedAnimation(bar.$3),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ChaptersCard extends StatelessWidget {
  final int totalChapters;
  final int readChapters;
  final int unreadChapters;
  final int downloadedChapters;
  final double readPct;
  final double averageChaps;
  final String readLabel;
  final String unreadLabel;
  final String title;
  final AnimationController animCtrl;
  final AppLocalizations l10n;

  const _ChaptersCard({
    required this.totalChapters,
    required this.readChapters,
    required this.unreadChapters,
    required this.downloadedChapters,
    required this.readPct,
    required this.averageChaps,
    required this.readLabel,
    required this.unreadLabel,
    required this.title,
    required this.animCtrl,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _MiniStat(
                  '$totalChapters',
                  l10n.total,
                  Broken.task_square,
                  _StatsPalette.inLibrary,
                ),
                _MiniStat(
                  '$readChapters',
                  readLabel,
                  Broken.tick_circle,
                  _StatsPalette.completed,
                ),
                _MiniStat(
                  '$unreadChapters',
                  unreadLabel,
                  Broken.close_circle,
                  _StatsPalette.onHold,
                ),
                _MiniStat(
                  '$downloadedChapters',
                  l10n.downloaded,
                  Broken.document_download,
                  _StatsPalette.downloads,
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: readPct),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) {
                    return SizedBox(
                      width: 110,
                      height: 110,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CustomPaint(
                            size: const Size(110, 110),
                            painter: _ArcPainter(
                              progress: value,
                              color: cs.primary,
                              background: cs.primary.withValues(alpha: 0.12),
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${(value * 100).toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                  color: cs.primary,
                                ),
                              ),
                              Text(
                                l10n.read_percentage,
                                style: TextStyle(
                                  fontSize: 9,
                                  color: cs.onSurface.withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(width: 24),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.average_chapters_per_title(title),
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      averageChaps.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface,
                      ),
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
}

class _ArcPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color background;

  _ArcPainter({
    required this.progress,
    required this.color,
    required this.background,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = math.min(cx, cy) - 8;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: radius);
    const startAngle = -math.pi / 2;
    const fullSweep = 2 * math.pi;

    final bgPaint = Paint()
      ..color = background
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, startAngle, fullSweep, false, bgPaint);
    if (progress > 0) {
      canvas.drawArc(
        rect,
        startAngle,
        fullSweep * progress,
        false,
        fgPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.progress != progress;
}

class _TimeCard extends StatelessWidget {
  final int totalSeconds;
  final int totalItems;
  final bool isAnime;
  final String Function(int) formatDuration;

  const _TimeCard({
    required this.totalSeconds,
    required this.totalItems,
    required this.isAnime,
    required this.formatDuration,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final avg = totalItems > 0 ? (totalSeconds / totalItems).round() : 0;
    return _GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _MiniStat(
              formatDuration(totalSeconds),
              'Total',
              isAnime ? Broken.play_circle : Broken.book_1,
              _StatsPalette.time,
            ),
            Container(
              width: 1,
              height: 50,
              color: cs.outline.withValues(alpha: 0.2),
            ),
            _MiniStat(
              formatDuration(avg),
              'Per Title',
              Broken.timer,
              _StatsPalette.updated,
            ),
          ],
        ),
      ),
    );
  }
}

class _TopGenresCard extends StatelessWidget {
  final Map<String, int> genres;
  final AnimationController animCtrl;
  const _TopGenresCard({required this.genres, required this.animCtrl});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final maxVal = genres.values.reduce(math.max).toDouble();
    final genreColors = [
      _StatsPalette.inLibrary,
      _StatsPalette.ongoing,
      _StatsPalette.updated,
      _StatsPalette.completed,
      _StatsPalette.onHold,
      const Color(0xFFE91E8C),
      _StatsPalette.dropped,
      const Color(0xFF5C6BC0),
    ];

    return _GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: genres.entries.toList().asMap().entries.map((e) {
            final idx = e.key;
            final entry = e.value;
            final pct = entry.value / maxVal;
            final color = genreColors[idx % genreColors.length];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 90,
                    child: Text(
                      entry.key,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface.withValues(alpha: 0.8),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: pct),
                        duration: Duration(milliseconds: 600 + idx * 80),
                        curve: Curves.easeOutCubic,
                        builder: (ctx, val, _) {
                          return LinearProgressIndicator(
                            value: val,
                            minHeight: 8,
                            backgroundColor: color.withValues(alpha: 0.1),
                            valueColor: AlwaysStoppedAnimation(color),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${entry.value}',
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurface.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _DownloadsCard extends StatelessWidget {
  final int downloadedTitles;
  final int downloadedChapters;
  const _DownloadsCard({
    required this.downloadedTitles,
    required this.downloadedChapters,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _MiniStat(
              '$downloadedTitles',
              'Titles',
              Broken.folder_favorite,
              _StatsPalette.downloads,
            ),
            Container(
              width: 1,
              height: 50,
              color: cs.outline.withValues(alpha: 0.2),
            ),
            _MiniStat(
              '$downloadedChapters',
              'Episodes / Chapters',
              Broken.document_download,
              _StatsPalette.updated,
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  const _MiniStat(this.value, this.label, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 17,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 9.5,
            color: cs.onSurface.withValues(alpha: 0.55),
          ),
          textAlign: TextAlign.center,
        ),
      ],
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
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? cs.surfaceContainerHigh.withValues(alpha: 0.72)
            : cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outline.withValues(alpha: 0.1), width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}
