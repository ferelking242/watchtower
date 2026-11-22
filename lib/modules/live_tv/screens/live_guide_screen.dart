import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/modules/live_tv/data/live_countries.dart';
import 'package:watchtower/modules/live_tv/epg/epg_matcher.dart';
import 'package:watchtower/modules/live_tv/epg/epg_models.dart';
import 'package:watchtower/modules/live_tv/epg/epg_providers.dart';
import 'package:watchtower/modules/live_tv/models/live_provider.dart';
import 'package:watchtower/modules/live_tv/providers/live_providers.dart';
import 'package:watchtower/modules/live_tv/screens/live_player_screen.dart';
import 'package:watchtower/modules/live_tv/widgets/live_common.dart';

/// Width of the fixed channel column.
const _channelColumn = 148.0;

/// Height of one channel row in the grid.
const _rowHeight = 74.0;

/// Height of the time ruler above the grid.
const _rulerHeight = 30.0;

/// Pixels per minute. 3 px makes a 30-minute slot 90 px wide, which fits a
/// title on a phone without truncating every other programme.
const _pixelsPerMinute = 3.0;

/// The EPG grid.
///
/// Layout mirrors a classic TV guide: a fixed channel column, a scrolling time
/// ruler, one row per channel, and a programme detail panel underneath. The
/// "now" line is drawn on top of the grid and the current programme carries a
/// progress bar, so the guide answers "what is on" before it answers "what is
/// scheduled".
class LiveGuideScreen extends ConsumerStatefulWidget {
  const LiveGuideScreen({super.key, this.embedded = false});

  /// True when hosted inside [LiveTvScreen], which already provides a header.
  final bool embedded;

  @override
  ConsumerState<LiveGuideScreen> createState() => _LiveGuideScreenState();
}

class _LiveGuideScreenState extends ConsumerState<LiveGuideScreen> {
  final _horizontal = ScrollController();
  final _vertical = ScrollController();
  Timer? _clock;

  /// Selected programme, shown in the panel under the grid.
  EpgProgramme? _selected;
  String? _selectedChannelName;

  @override
  void initState() {
    super.initState();
    // A minute tick keeps the now-line and the progress bars honest without
    // rebuilding on every frame.
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToNow());
  }

  @override
  void dispose() {
    _clock?.cancel();
    _horizontal.dispose();
    _vertical.dispose();
    super.dispose();
  }

  /// Centres the ruler slightly before the current time on first open.
  void _scrollToNow() {
    if (!_horizontal.hasClients) return;
    final guide = ref.read(epgProvider).guide;
    final now = DateTime.now();
    final start = _windowStart(guide, now);
    final offset =
        now.difference(start).inMinutes * _pixelsPerMinute -
        _horizontal.position.viewportDimension / 3;
    _horizontal.jumpTo(offset.clamp(0, _horizontal.position.maxScrollExtent));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(epgProvider);
    final channelsAsync = ref.watch(allLiveChannelsProvider);
    final body = _body(state, channelsAsync);
    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(title: const Text('Guide des programmes')),
      body: body,
    );
  }

  Widget _body(EpgState state, AsyncValue<List<LiveChannel>> channelsAsync) {
    final guide = state.guide;
    if (guide == null) {
      return LiveEmptyState(
        icon: Icons.calendar_month_rounded,
        title: state.loading ? 'Téléchargement du guide…' : 'Aucun guide',
        message: state.loading
            ? '${state.progress} programmes lus'
            : 'Choisissez une source de guide pour voir les programmes.',
        action: state.loading
            ? const SizedBox(
                width: 160,
                child: LinearProgressIndicator(minHeight: 4),
              )
            : FilledButton.icon(
                onPressed: () => _download(epgSources.first),
                icon: const Icon(Icons.download_rounded),
                label: const Text('Télécharger le guide'),
              ),
      );
    }

    return channelsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => LiveEmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Chaînes indisponibles',
        message: '$error',
      ),
      data: (channels) {
        final matcher = EpgMatcher(guide);
        final rows = <(LiveChannel, String)>[
          for (final channel in channels)
            if (matcher.guideIdFor(channel) case final id?) (channel, id),
        ];
        if (rows.isEmpty) {
          return LiveEmptyState(
            icon: Icons.link_off_rounded,
            title: 'Aucune chaîne reconnue',
            message:
                'Le guide couvre ${guide.channels.length} chaînes, mais aucune '
                'ne correspond à votre liste. Essayez une autre source.',
            action: FilledButton.icon(
              onPressed: () => _download(epgSources.first),
              icon: const Icon(Icons.download_rounded),
              label: const Text('Changer de source'),
            ),
          );
        }

        final now = DateTime.now();
        final start = _windowStart(guide, now);
        final end = start.add(const Duration(hours: 6));
        final minutes = end.difference(start).inMinutes;
        final width = minutes * _pixelsPerMinute;

        return Column(
          children: [
            _GuideToolbar(
              state: state,
              rowCount: rows.length,
              onRefresh: () => ref.read(epgProvider.notifier).refresh(),
              onSource: _pickSource,
            ),
            if (state.loading)
              LinearProgressIndicator(
                minHeight: 2,
                value: state.progress == 0 ? null : null,
              ),
            Expanded(
              child: SingleChildScrollView(
                controller: _vertical,
                child: Column(
                  children: [
                    SizedBox(
                      height: _rulerHeight + _rowHeight * rows.length,
                      child: Row(
                        children: [
                          _ChannelColumnHeader(),
                          Expanded(
                            child: SingleChildScrollView(
                              controller: _horizontal,
                              scrollDirection: Axis.horizontal,
                              child: SizedBox(
                                width: width,
                                child: Stack(
                                  children: [
                                    Column(
                                      children: [
                                        _TimeRuler(
                                          start: start,
                                          end: end,
                                          width: width,
                                        ),
                                        for (final (channel, guideId) in rows)
                                          _GuideRow(
                                            channel: channel,
                                            programmes: guide.windowOn(
                                              guideId,
                                              start,
                                              end,
                                            ),
                                            start: start,
                                            end: end,
                                            now: now,
                                            width: width,
                                            selected: _selected,
                                            onSelect: (programme) =>
                                                setState(() {
                                                  _selected = programme;
                                                  _selectedChannelName =
                                                      channel.name;
                                                }),
                                            onPlay: () =>
                                                _play(channels, rows, channel),
                                          ),
                                      ],
                                    ),
                                    // The now-line is painted over every row.
                                    Positioned(
                                      left:
                                          now.difference(start).inMinutes *
                                          _pixelsPerMinute,
                                      top: _rulerHeight,
                                      bottom: 0,
                                      child: IgnorePointer(
                                        child: Container(
                                          width: 2,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                        ),
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
                    _DetailPanel(
                      programme: _selected,
                      channelName: _selectedChannelName,
                      now: now,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Grid origin: the top of the current hour, two hours back.
  ///
  /// Starting in the past keeps "what did I miss" visible, which is what a
  /// guide is opened for as often as "what is next".
  static DateTime _windowStart(EpgGuide? guide, DateTime now) {
    final base = DateTime(now.year, now.month, now.day, now.hour);
    return base.subtract(const Duration(hours: 2));
  }

  Future<void> _download(EpgSource source) =>
      ref.read(epgProvider.notifier).load(source);

  Future<void> _pickSource() async {
    final current = ref.read(epgProvider).sourceUrl;
    final picked = await showModalBottomSheet<EpgSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Source du guide')),
            for (final source in epgSources)
              ListTile(
                leading: Icon(
                  source.url == current
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                ),
                title: Text(source.label),
                subtitle: Text(source.url, maxLines: 1),
                onTap: () => Navigator.of(context).pop(source),
              ),
          ],
        ),
      ),
    );
    if (picked != null) await _download(picked);
  }

  void _play(
    List<LiveChannel> channels,
    List<(LiveChannel, String)> rows,
    LiveChannel channel,
  ) {
    final index = channels.indexOf(channel);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LivePlayerScreen(
          channels: channels,
          initialIndex: index < 0 ? 0 : index,
        ),
      ),
    );
  }
}

class _GuideToolbar extends StatelessWidget {
  const _GuideToolbar({
    required this.state,
    required this.rowCount,
    required this.onRefresh,
    required this.onSource,
  });

  final EpgState state;
  final int rowCount;
  final VoidCallback onRefresh;
  final VoidCallback onSource;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final guide = state.guide;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      child: Row(
        children: [
          Flexible(
            child: _ToolbarChip(
              icon: Icons.today_rounded,
              label: guide == null
                  ? 'Aujourd\'hui'
                  : dayLabel(guide.fetchedAt, DateTime.now()),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: _ToolbarChip(
              icon: Icons.tv_rounded,
              label: '$rowCount chaînes',
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Changer de source',
            onPressed: onSource,
            icon: const Icon(Icons.source_rounded, size: 20),
          ),
          IconButton(
            tooltip: 'Rafraîchir',
            onPressed: state.loading ? null : onRefresh,
            icon: state.loading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.primary,
                    ),
                  )
                : const Icon(Icons.refresh_rounded, size: 20),
          ),
        ],
      ),
    );
  }
}

class _ToolbarChip extends StatelessWidget {
  const _ToolbarChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium,
            ),
          ),
          const SizedBox(width: 2),
          const Icon(Icons.expand_more_rounded, size: 14),
        ],
      ),
    );
  }
}

class _ChannelColumnHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: _channelColumn,
      height: _rulerHeight,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border(
          right: BorderSide(color: Colors.white10),
          bottom: BorderSide(color: Colors.white10),
        ),
      ),
      child: Text(
        'Chaîne',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _TimeRuler extends StatelessWidget {
  const _TimeRuler({
    required this.start,
    required this.end,
    required this.width,
  });

  final DateTime start;
  final DateTime end;
  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final slots = <Widget>[];
    var cursor = start;
    while (cursor.isBefore(end)) {
      final offset = cursor.difference(start).inMinutes * _pixelsPerMinute;
      slots.add(
        Positioned(
          left: offset,
          top: 0,
          bottom: 0,
          width: 90,
          child: Padding(
            padding: const EdgeInsets.only(left: 6, top: 8),
            child: Text(
              clockLabel(cursor),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
      cursor = cursor.add(const Duration(minutes: 30));
    }
    return Container(
      width: width,
      height: _rulerHeight,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Stack(children: slots),
    );
  }
}

/// One channel: its fixed label, then its programmes on the time axis.
class _GuideRow extends StatelessWidget {
  const _GuideRow({
    required this.channel,
    required this.programmes,
    required this.start,
    required this.end,
    required this.now,
    required this.width,
    required this.selected,
    required this.onSelect,
    required this.onPlay,
  });

  final LiveChannel channel;
  final List<EpgProgramme> programmes;
  final DateTime start;
  final DateTime end;
  final DateTime now;
  final double width;
  final EpgProgramme? selected;
  final ValueChanged<EpgProgramme> onSelect;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: _rowHeight,
      child: Row(
        children: [
          Container(
            width: _channelColumn,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh,
              border: Border(
                right: BorderSide(color: Colors.white10),
                bottom: BorderSide(color: Colors.white10),
              ),
            ),
            child: Row(
              children: [
                ChannelLogo(
                  name: channel.name,
                  logoUrl: channel.logoUrl,
                  size: 26,
                  radius: 7,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        channel.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if ((channel.country ?? channel.group) != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Row(
                            children: [
                              flagFor(
                                channel.country ?? channel.group,
                                size: 10,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  channel.country ?? channel.group ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontSize: 9,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              width: width,
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.white10)),
              ),
              child: Stack(
                children: [
                  for (final programme in programmes)
                    _ProgrammeBlock(
                      programme: programme,
                      start: start,
                      end: end,
                      now: now,
                      selected:
                          selected?.start == programme.start &&
                          selected?.channelId == programme.channelId,
                      onTap: () => onSelect(programme),
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

class _ProgrammeBlock extends StatelessWidget {
  const _ProgrammeBlock({
    required this.programme,
    required this.start,
    required this.end,
    required this.now,
    required this.selected,
    required this.onTap,
  });

  final EpgProgramme programme;
  final DateTime start;
  final DateTime end;
  final DateTime now;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visibleStart = programme.start.isBefore(start)
        ? start
        : programme.start;
    final visibleEnd = programme.stop.isAfter(end) ? end : programme.stop;
    final left = visibleStart.difference(start).inMinutes * _pixelsPerMinute;
    final blockWidth =
        visibleEnd.difference(visibleStart).inMinutes * _pixelsPerMinute;
    final live = programme.isLiveAt(now);

    final base = live
        ? theme.colorScheme.primary.withValues(alpha: 0.26)
        : theme.colorScheme.surfaceContainerHighest;

    return Positioned(
      left: left,
      top: 6,
      height: _rowHeight - 12,
      width: blockWidth.clamp(24, double.infinity),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(right: 2),
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
          decoration: BoxDecoration(
            color: base,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? Colors.white
                  : live
                  ? theme.colorScheme.primary
                  : Colors.transparent,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                programme.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                clockLabel(programme.start),
                maxLines: 1,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 9,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (live) ...[
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: programme.progressAt(now),
                    minHeight: 3,
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation(
                      theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Detail panel under the grid: the selected programme, or a hint.
class _DetailPanel extends StatelessWidget {
  const _DetailPanel({
    required this.programme,
    required this.channelName,
    required this.now,
  });

  final EpgProgramme? programme;
  final String? channelName;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = programme;
    if (selected == null) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          'Touchez un programme pour voir son détail.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    final live = selected.isLiveAt(now);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 86,
            height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary.withValues(alpha: 0.5),
                  theme.colorScheme.surfaceContainerHighest,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Icon(
              Icons.movie_filter_rounded,
              color: Colors.white70,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (live)
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'EN DIRECT',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            color: theme.colorScheme.onPrimary,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    Expanded(
                      child: Text(
                        selected.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${clockLabel(selected.start)} – ${clockLabel(selected.stop)}'
                  ' · ${durationLabel(selected.duration)}'
                  '${channelName == null ? '' : ' · $channelName'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (live) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: selected.progressAt(now),
                      minHeight: 4,
                      backgroundColor: Colors.white12,
                      valueColor: AlwaysStoppedAnimation(
                        theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    scheduleLabel(selected, now),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
                if (selected.description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    selected.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
