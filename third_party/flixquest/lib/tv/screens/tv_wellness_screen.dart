import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../models/wellness_insights.dart';
import '../../provider/wellness_provider.dart';
import '../../widgets/wellness_charts.dart';
import '../app/tv_design.dart';

class TvWellnessScreen extends StatelessWidget {
  const TvWellnessScreen({required this.metrics, super.key});

  final TvShellMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WellnessProvider>();
    final insights = WellnessInsights.fromSessions(
      provider.sessions,
      period: WellnessPeriod.forRange(WellnessRange.week, DateTime.now()),
    );
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.all(metrics.contentPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(PhosphorIcons.chartDonut(), color: colors.primary, size: 32),
              const SizedBox(width: 13),
              Text(
                'Viewing Insights',
                style: TextStyle(
                  color: colors.onSurface,
                  fontFamily: 'FigtreeSB',
                  fontSize: 34,
                ),
              ),
              const Spacer(),
              Text(
                'This week • private insights',
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 18),
              ),
            ],
          ),
          SizedBox(height: metrics.compact ? 16 : 24),
          if (provider.loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (insights.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  'Watch something and your viewing story will appear here.',
                  style:
                      TextStyle(color: colors.onSurfaceVariant, fontSize: 22),
                ),
              ),
            )
          else
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 4,
                    child: Container(
                      padding: EdgeInsets.all(metrics.compact ? 22 : 30),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [colors.primary, colors.tertiary],
                        ),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _duration(insights.totalWatchedMs),
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'FigtreeSB',
                              fontSize: 48,
                            ),
                          ),
                          Text(
                            'active playback',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: .82),
                              fontSize: 20,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Expanded(
                            child: WellnessBarChart(
                              data: _weekData(insights),
                              color: Colors.white,
                              height: double.infinity,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: metrics.compact ? 14 : 22),
                  Expanded(
                    flex: 3,
                    child: GridView.count(
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: metrics.compact ? 1.35 : 1.25,
                      children: [
                        _Metric('Movies', '${insights.completedMovies}',
                            PhosphorIcons.filmSlate()),
                        _Metric('Episodes', '${insights.completedEpisodes}',
                            PhosphorIcons.television()),
                        _Metric('Series', '${insights.uniqueSeries}',
                            PhosphorIcons.stack()),
                        _Metric('Active days', '${insights.activeDays}',
                            PhosphorIcons.calendarDots()),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, this.icon);

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: TvDesign.surfaceFor(context, emphasis: .02),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: .4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colors.primary, size: 26),
          const Spacer(),
          Text(value,
              style: const TextStyle(fontFamily: 'FigtreeSB', fontSize: 32)),
          Text(label,
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 16)),
        ],
      ),
    );
  }
}

List<WellnessBarDatum> _weekData(WellnessInsights insights) {
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day)
      .subtract(Duration(days: now.weekday - 1));
  const labels = <String>['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  return List<WellnessBarDatum>.generate(7, (index) {
    final day = start.add(Duration(days: index));
    return WellnessBarDatum(
      label: labels[index],
      value: insights.dailyWatchedMs[day] ?? 0,
    );
  });
}

String _duration(int milliseconds) {
  final minutes = Duration(milliseconds: milliseconds).inMinutes;
  return '${minutes ~/ 60}h ${minutes % 60}m';
}
