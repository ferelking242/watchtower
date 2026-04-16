import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/l10n/generated/app_localizations.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/modules/more/settings/reader/providers/reader_state_provider.dart';
import 'package:watchtower/modules/more/statistics/statistics_provider.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/utils/extensions/build_context_extensions.dart';
import 'package:watchtower/utils/item_type_filters.dart';
import 'package:watchtower/utils/item_type_localization.dart';
import 'dart:math' as math;

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
    if (_visibleTabTypes.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.statistics)),
        body: const Center(child: Text("No data yet.")),
      );
    }
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.statistics),
        bottom: TabBar(
          controller: _tabController,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: _visibleTabTypes.map((type) {
            return Tab(text: type.localized(l10n));
          }).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _visibleTabTypes.map((type) {
          return _StatisticsTabView(itemType: type);
        }).toList(),
      ),
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
                      icon: Icons.video_library_outlined,
                      value: '${stats.totalItems}',
                      label: l10n.in_library,
                      color: const Color(0xFF7C3AED),
                    ),
                    _GridStat(
                      icon: Icons.check_circle_outline,
                      value: '${stats.completedItems}',
                      label: l10n.completed,
                      color: Colors.green,
                    ),
                    _GridStat(
                      icon: Icons.play_circle_outline,
                      value: '${stats.ongoingItems}',
                      label: l10n.ongoing,
                      color: Colors.blue,
                    ),
                    _GridStat(
                      icon: Icons.pause_circle_outline,
                      value: '${stats.onHoldItems}',
                      label: l10n.on_hold,
                      color: Colors.orange,
                    ),
                    _GridStat(
                      icon: Icons.cancel_outlined,
                      value: '${stats.droppedItems}',
                      label: l10n.dropped,
                      color: Colors.red,
                    ),
                    _GridStat(
                      icon: Icons.update_outlined,
                      value: '${stats.updatedThisWeek}',
                      label: 'This Week',
                      color: Colors.teal,
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

class _OverviewGrid extends StatelessWidget {
  final List<_GridStat> items;
  const _OverviewGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GridView.count(
      crossAxisCount: 3,
      childAspectRatio: 1.05,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: items.map((s) {
        return Container(
          decoration: BoxDecoration(
            color: isDark
                ? cs.surfaceContainerHigh.withOpacity(0.7)
                : cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: s.color.withOpacity(0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: s.color.withOpacity(isDark ? 0.15 : 0.08),
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
                  color: s.color.withOpacity(0.12),
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
                  color: cs.onSurface.withOpacity(0.6),
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final total = stats.totalItems;

    final bars = [
      (
        'Completed',
        stats.completedItems,
        Colors.green,
        Icons.check_circle_outline,
      ),
      ('Ongoing', stats.ongoingItems, Colors.blue, Icons.play_circle_outline),
      ('On Hold', stats.onHoldItems, Colors.orange, Icons.pause_circle_outline),
      ('Dropped', stats.droppedItems, Colors.red, Icons.cancel_outlined),
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
                            color: cs.onSurface.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${bar.$2}  (${(pct * 100).toStringAsFixed(1)}%)',
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurface.withOpacity(0.5),
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
                        backgroundColor: bar.$3.withOpacity(0.1),
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
                  Icons.format_list_numbered,
                  cs.primary,
                ),
                _MiniStat(
                  '$readChapters',
                  readLabel,
                  Icons.done_all,
                  Colors.green,
                ),
                _MiniStat(
                  '$unreadChapters',
                  unreadLabel,
                  Icons.remove_circle_outline,
                  Colors.orange,
                ),
                _MiniStat(
                  '$downloadedChapters',
                  l10n.downloaded,
                  Icons.download_done,
                  Colors.blue,
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
                              background: cs.primary.withOpacity(0.12),
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
                                  color: cs.onSurface.withOpacity(0.5),
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
                        color: cs.onSurface.withOpacity(0.6),
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
              isAnime ? Icons.play_circle_outline : Icons.auto_stories,
              cs.primary,
            ),
            Container(
              width: 1,
              height: 50,
              color: cs.outline.withOpacity(0.2),
            ),
            _MiniStat(
              formatDuration(avg),
              'Per Title',
              Icons.timer_outlined,
              Colors.teal,
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
      const Color(0xFF7C3AED),
      Colors.blue,
      Colors.teal,
      Colors.green,
      Colors.orange,
      const Color(0xFFE91E8C),
      Colors.red,
      Colors.indigo,
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
                        color: cs.onSurface.withOpacity(0.8),
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
                            backgroundColor: color.withOpacity(0.1),
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
                      color: cs.onSurface.withOpacity(0.5),
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
              Icons.folder_special_outlined,
              Colors.blue,
            ),
            Container(
              width: 1,
              height: 50,
              color: cs.outline.withOpacity(0.2),
            ),
            _MiniStat(
              '$downloadedChapters',
              'Episodes / Chapters',
              Icons.download_done_outlined,
              Colors.teal,
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
            color: cs.onSurface.withOpacity(0.55),
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
            ? cs.surfaceContainerHigh.withOpacity(0.72)
            : cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outline.withOpacity(0.1), width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.15 : 0.05),
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
