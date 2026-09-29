import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:isar_community/isar.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/modules/calendar/providers/calendar_provider.dart';
import 'package:watchtower/modules/more/settings/appearance/providers/nav_display_state_provider.dart';
import 'package:watchtower/modules/more/settings/reader/providers/reader_state_provider.dart';
import 'package:watchtower/modules/widgets/custom_extended_image_provider.dart';
import 'package:watchtower/utils/fetch_interval.dart';
import 'package:watchtower/utils/headers.dart';
import 'package:watchtower/utils/item_type_filters.dart';

// ── Filter status (separate from model Status enum) ───────────────────────────

enum ScheduleFilterStatus { watching, planning, completed, paused }

// ── Settings state ────────────────────────────────────────────────────────────

class _ScheduleSettings {
  final bool weekStartsMonday;
  final Set<ScheduleFilterStatus> visibleStatuses;
  final bool indicateWatched;
  final bool disableImageTransitions;

  const _ScheduleSettings({
    required this.weekStartsMonday,
    required this.visibleStatuses,
    required this.indicateWatched,
    required this.disableImageTransitions,
  });

  _ScheduleSettings copyWith({
    bool? weekStartsMonday,
    Set<ScheduleFilterStatus>? visibleStatuses,
    bool? indicateWatched,
    bool? disableImageTransitions,
  }) {
    return _ScheduleSettings(
      weekStartsMonday: weekStartsMonday ?? this.weekStartsMonday,
      visibleStatuses: visibleStatuses ?? this.visibleStatuses,
      indicateWatched: indicateWatched ?? this.indicateWatched,
      disableImageTransitions:
          disableImageTransitions ?? this.disableImageTransitions,
    );
  }
}

class _ScheduleSettingsNotifier extends Notifier<_ScheduleSettings> {
  @override
  _ScheduleSettings build() => _ScheduleSettings(
        weekStartsMonday: true,
        visibleStatuses: {
          ScheduleFilterStatus.watching,
          ScheduleFilterStatus.planning,
          ScheduleFilterStatus.completed,
          ScheduleFilterStatus.paused,
        },
        indicateWatched: true,
        disableImageTransitions: false,
      );
}

final _scheduleSettingsProvider =
    NotifierProvider<_ScheduleSettingsNotifier, _ScheduleSettings>(
        _ScheduleSettingsNotifier.new);

// ── Screen ────────────────────────────────────────────────────────────────────

class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key});

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> {
  late DateTime _selectedMonth;
  bool _settingsOpen = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
  }

  void _prevMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    });
  }

  String _monthLabel(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final hideItems = ref.watch(hideItemsStateProvider);
    final visibleTypes = hiddenItemTypes(hideItems);
    final settings = ref.watch(_scheduleSettingsProvider);
    final animeVisible = visibleTypes.contains(ItemType.anime);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0C) : cs.surface,
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              monthLabel: _monthLabel(_selectedMonth),
              onPrev: _prevMonth,
              onNext: _nextMonth,
              settingsOpen: _settingsOpen,
              onToggleSettings: () =>
                  setState(() => _settingsOpen = !_settingsOpen),
            ),
            if (_settingsOpen)
              _SettingsPanel(
                settings: settings,
                onChanged: (s) =>
                    ref.read(_scheduleSettingsProvider.notifier).state = s,
              ),
            Expanded(
              child: animeVisible
                  ? _ScheduleBody(
                      month: _selectedMonth,
                      settings: settings,
                    )
                  : Center(
                      child: Text(
                        'Anime library is hidden',
                        style: TextStyle(
                          color: isDark ? Colors.white54 : Colors.black45,
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

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final String monthLabel;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final bool settingsOpen;
  final VoidCallback onToggleSettings;

  const _Header({
    required this.monthLabel,
    required this.onPrev,
    required this.onNext,
    required this.settingsOpen,
    required this.onToggleSettings,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? Colors.white70 : Colors.black54;

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 8, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).maybePop();
            },
            icon: Icon(Icons.arrow_back_rounded, color: fg),
          ),
          IconButton(
            icon: Icon(Icons.chevron_left_rounded, color: fg),
            onPressed: onPrev,
          ),
          Expanded(
            child: Text(
              monthLabel,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.chevron_right_rounded, color: fg),
            onPressed: onNext,
          ),
          IconButton(
            icon: Icon(
              settingsOpen
                  ? Icons.settings_rounded
                  : Icons.settings_outlined,
              color: settingsOpen ? cs.primary : fg,
            ),
            onPressed: onToggleSettings,
          ),
        ],
      ),
    );
  }
}

// ── Settings Panel ────────────────────────────────────────────────────────────

class _SettingsPanel extends StatelessWidget {
  final _ScheduleSettings settings;
  final void Function(_ScheduleSettings) onChanged;

  const _SettingsPanel({required this.settings, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final panelColor =
        isDark ? const Color(0xFF1A1A1E) : cs.surfaceContainerLow;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      decoration: BoxDecoration(
        color: panelColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.07)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Text(
              'Week starts on',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ),
          Row(
            children: [
              _RadioRow(
                label: 'Monday',
                selected: settings.weekStartsMonday,
                onTap: () =>
                    onChanged(settings.copyWith(weekStartsMonday: true)),
              ),
              _RadioRow(
                label: 'Sunday',
                selected: !settings.weekStartsMonday,
                onTap: () =>
                    onChanged(settings.copyWith(weekStartsMonday: false)),
              ),
            ],
          ),
          Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: isDark ? Colors.white12 : Colors.black12,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Text(
              'Status',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
            child: Wrap(
              children: [
                for (final entry in [
                  (ScheduleFilterStatus.watching, 'Watching'),
                  (ScheduleFilterStatus.planning, 'Planning'),
                  (ScheduleFilterStatus.completed, 'Completed'),
                  (ScheduleFilterStatus.paused, 'Paused'),
                ])
                  _CheckRow(
                    label: entry.$2,
                    checked: settings.visibleStatuses.contains(entry.$1),
                    onTap: () {
                      final next =
                          Set<ScheduleFilterStatus>.from(settings.visibleStatuses);
                      if (next.contains(entry.$1)) {
                        next.remove(entry.$1);
                      } else {
                        next.add(entry.$1);
                      }
                      onChanged(settings.copyWith(visibleStatuses: next));
                    },
                    cs: cs,
                  ),
              ],
            ),
          ),
          Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: isDark ? Colors.white12 : Colors.black12,
          ),
          _SwitchRow(
            label: 'Indicate watched episodes',
            value: settings.indicateWatched,
            onChanged: (v) =>
                onChanged(settings.copyWith(indicateWatched: v)),
            cs: cs,
          ),
          _SwitchRow(
            label: 'Disable image transitions',
            value: settings.disableImageTransitions,
            onChanged: (v) =>
                onChanged(settings.copyWith(disableImageTransitions: v)),
            cs: cs,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _RadioRow extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RadioRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 18,
              color: selected ? cs.primary : Colors.grey,
            ),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  final String label;
  final bool checked;
  final VoidCallback onTap;
  final ColorScheme cs;

  const _CheckRow({
    required this.label,
    required this.checked,
    required this.onTap,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              checked
                  ? Icons.check_box_rounded
                  : Icons.check_box_outline_blank_rounded,
              size: 18,
              color: checked ? cs.primary : Colors.grey,
            ),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String label;
  final bool value;
  final void Function(bool) onChanged;
  final ColorScheme cs;

  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: cs.primary,
          ),
        ],
      ),
    );
  }
}

// ── Schedule Body ─────────────────────────────────────────────────────────────

class _ScheduleBody extends ConsumerWidget {
  final DateTime month;
  final _ScheduleSettings settings;

  const _ScheduleBody({required this.month, required this.settings});

  static bool _matchesFilter(Manga manga, Set<ScheduleFilterStatus> filters) {
    final s = manga.status;
    for (final f in filters) {
      switch (f) {
        case ScheduleFilterStatus.watching:
          if (s == Status.ongoing) return true;
        case ScheduleFilterStatus.planning:
          if (s == Status.unknown) return true;
        case ScheduleFilterStatus.completed:
          if (s == Status.completed ||
              s == Status.publishingFinished) return true;
        case ScheduleFilterStatus.paused:
          if (s == Status.onHiatus || s == Status.canceled) return true;
      }
    }
    return false;
  }

  DateTime? _computeExpectedDate(Manga manga) {
    if (manga.smartUpdateDays == null || manga.smartUpdateDays! <= 0) {
      return null;
    }
    final _chapterList = manga.chapters.toList()
      ..sort((a, b) => (b.dateUpload ?? '0').compareTo(a.dateUpload ?? '0'));
    final lastChapter = _chapterList.isEmpty ? null : _chapterList.first;
    final lastChapterMs = int.tryParse(lastChapter?.dateUpload ?? '');
    return FetchInterval.computeExpectedDate(
      lastChapterDateMs: lastChapterMs,
      lastUpdateMs: manga.lastUpdate,
      interval: manga.smartUpdateDays,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stream =
        ref.watch(getCalendarStreamProvider(itemType: ItemType.anime));

    return stream.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (mangas) {
        final filtered = settings.visibleStatuses.isEmpty
            ? mangas
            : mangas
                .where((m) => _matchesFilter(m, settings.visibleStatuses))
                .toList();

        final Map<DateTime, List<Manga>> byDay = {};

        final monthStart = DateTime(month.year, month.month, 1);
        final monthEnd = DateTime(month.year, month.month + 1, 0);

        for (final manga in filtered) {
          DateTime? baseDate = _computeExpectedDate(manga);
          if (baseDate == null) continue;
          final interval = manga.smartUpdateDays ?? 7;

          DateTime cur = baseDate;
          while (cur.isAfter(monthEnd)) {
            cur = cur.subtract(Duration(days: interval));
          }
          while (cur.isBefore(monthStart)) {
            cur = cur.add(Duration(days: interval));
          }

          while (!cur.isAfter(monthEnd)) {
            if (!cur.isBefore(monthStart)) {
              final key = DateTime(cur.year, cur.month, cur.day);
              byDay.putIfAbsent(key, () => []).add(manga);
            }
            cur = cur.add(Duration(days: interval));
          }
        }

        final sortedDays = byDay.keys.toList()..sort();

        if (sortedDays.isEmpty) {
          return _EmptySchedule();
        }

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 120),
          itemCount: sortedDays.length,
          itemBuilder: (context, i) {
            final day = sortedDays[i];
            return _DayGroup(
              date: day,
              items: byDay[day]!,
              settings: settings,
            );
          },
        );
      },
    );
  }
}

class _EmptySchedule extends StatelessWidget {
  const _EmptySchedule();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 56,
            color: isDark ? Colors.white24 : Colors.black26,
          ),
          const SizedBox(height: 16),
          Text(
            'No schedule for this month',
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Add anime to your library with smart updates enabled',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Day Group ─────────────────────────────────────────────────────────────────

class _DayGroup extends StatelessWidget {
  final DateTime date;
  final List<Manga> items;
  final _ScheduleSettings settings;

  const _DayGroup({
    required this.date,
    required this.items,
    required this.settings,
  });

  static const _dayNames = [
    '',
    'Monday', 'Tuesday', 'Wednesday', 'Thursday',
    'Friday', 'Saturday', 'Sunday',
  ];

  static const _monthNames = [
    '',
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isToday = date == today;
    final isPast = date.isBefore(today);

    final dayBg = isToday
        ? cs.primary
        : isPast
            ? (isDark ? Colors.white12 : Colors.black12)
            : (isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: dayBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    '${date.day}',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: isToday
                          ? Colors.white
                          : (isDark ? Colors.white : Colors.black87),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _dayNames[date.weekday],
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  Text(
                    '${_monthNames[date.month]} ${date.day}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${items.length} episode${items.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ),
            ],
          ),
        ),
        for (final manga in items)
          _ScheduleItem(manga: manga, settings: settings),
      ],
    );
  }
}

// ── Schedule Item ─────────────────────────────────────────────────────────────

class _ScheduleItem extends ConsumerWidget {
  final Manga manga;
  final _ScheduleSettings settings;

  const _ScheduleItem({required this.manga, required this.settings});

  int get _nextEpisodeNum {
    final count = manga.chapters.filter().countSync();
    return count + 1;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    ImageProvider? imgProvider;
    if (manga.customCoverImage != null) {
      imgProvider = MemoryImage(manga.customCoverImage as Uint8List);
    } else if ((manga.customCoverFromTracker ?? manga.imageUrl ?? '').isNotEmpty) {
      imgProvider = CustomExtendedNetworkImageProvider(
        manga.customCoverFromTracker ?? manga.imageUrl!,
        headers: ref.watch(headersProvider(
          source: manga.source ?? '',
          lang: manga.lang ?? '',
          sourceId: manga.sourceId,
        )),
        cache: !settings.disableImageTransitions,
      );
    }

    return InkWell(
      onTap: () {
        if (manga.id != null) {
          context.push('/manga-reader/detail', extra: manga.id);
        }
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 52,
                height: 74,
                child: imgProvider != null
                    ? Image(
                        image: imgProvider,
                        fit: BoxFit.cover,
                        gaplessPlayback: settings.disableImageTransitions,
                        errorBuilder: (_, __, ___) => _PlaceholderCover(),
                      )
                    : _PlaceholderCover(),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    manga.name ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Icon(
                        Icons.play_circle_outline_rounded,
                        size: 13,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Episode $_nextEpisodeNum',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                      ),
                      if (settings.indicateWatched) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: cs.primary.withValues(alpha: 0.7),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderCover extends StatelessWidget {
  const _PlaceholderCover();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFE0E0E0),
      child: Icon(
        Icons.live_tv_outlined,
        size: 24,
        color: isDark ? Colors.white24 : Colors.black26,
      ),
    );
  }
}
