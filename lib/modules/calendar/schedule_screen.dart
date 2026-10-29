import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:isar_community/isar.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/models/chapter.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/modules/calendar/providers/calendar_provider.dart';
import 'package:watchtower/modules/more/settings/reader/providers/reader_state_provider.dart';
import 'package:watchtower/modules/widgets/animated_empty_state.dart';
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

  void set(_ScheduleSettings value) => state = value;
}

final _scheduleSettingsProvider =
    NotifierProvider<_ScheduleSettingsNotifier, _ScheduleSettings>(
      _ScheduleSettingsNotifier.new,
    );

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
      'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
      'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
    ];
    final month = d.month >= 1 && d.month <= 12 ? months[d.month - 1] : '';
    return '$month ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hideItems = ref.watch(hideItemsStateProvider);
    final visibleTypes = hiddenItemTypes(hideItems);
    final settings = ref.watch(_scheduleSettingsProvider);
    final animeVisible = visibleTypes.contains(ItemType.anime);

    return Scaffold(
      // Theme-driven surface: the page used to hard-code #0A0A0C, so it
      // ignored the app theme and accent entirely.
      backgroundColor: cs.surface,
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
                    ref.read(_scheduleSettingsProvider.notifier).set(s),
              ),
            Expanded(
              child: animeVisible
                  ? _ScheduleBody(month: _selectedMonth, settings: settings)
                  : const AnimatedEmptyState(
                      message: 'Bibliothèque anime masquée',
                      icon: Broken.video_play,
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
    final fg = cs.onSurface.withValues(alpha: 0.7);

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 8, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              // The dock is not present on this route, so the header itself
              // must provide the way back.
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/WatchtowerHome');
              }
            },
            icon: Icon(Broken.arrow_left_2, color: fg),
          ),
          IconButton(
            icon: Icon(Broken.arrow_left_3, color: fg),
            onPressed: onPrev,
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Broken.calendar_2, size: 20, color: cs.primary),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    monthLabel,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Broken.arrow_right_3, color: fg),
            onPressed: onNext,
          ),
          IconButton(
            icon: Icon(
              settingsOpen ? Broken.setting_2 : Broken.setting_4,
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

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
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
          const _SectionLabel(text: 'Début de semaine'),
          Row(
            children: [
              _RadioRow(
                label: 'Lundi',
                selected: settings.weekStartsMonday,
                onTap: () =>
                    onChanged(settings.copyWith(weekStartsMonday: true)),
              ),
              _RadioRow(
                label: 'Dimanche',
                selected: !settings.weekStartsMonday,
                onTap: () =>
                    onChanged(settings.copyWith(weekStartsMonday: false)),
              ),
            ],
          ),
          const _Divider(),
          const _SectionLabel(text: 'Statut'),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
            child: Wrap(
              children: [
                for (final entry in [
                  (ScheduleFilterStatus.watching, 'En cours'),
                  (ScheduleFilterStatus.planning, 'À voir'),
                  (ScheduleFilterStatus.completed, 'Terminé'),
                  (ScheduleFilterStatus.paused, 'En pause'),
                ])
                  _CheckRow(
                    label: entry.$2,
                    checked: settings.visibleStatuses.contains(entry.$1),
                    onTap: () {
                      final next = Set<ScheduleFilterStatus>.from(
                        settings.visibleStatuses,
                      );
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
          const _Divider(),
          _SwitchRow(
            label: 'Indiquer les épisodes vus',
            value: settings.indicateWatched,
            onChanged: (v) => onChanged(settings.copyWith(indicateWatched: v)),
            cs: cs,
          ),
          _SwitchRow(
            label: 'Désactiver les transitions d’image',
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

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
          color: cs.onSurface.withValues(alpha: 0.45),
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Divider(
      height: 1,
      indent: 16,
      endIndent: 16,
      color: isDark ? Colors.white12 : Colors.black12,
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
              selected ? Broken.radio : Broken.record_circle,
              size: 18,
              color: selected
                  ? cs.primary
                  : cs.onSurface.withValues(alpha: 0.4),
            ),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontSize: 14, color: cs.onSurface)),
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
              checked ? Broken.tick_square : Broken.square,
              size: 18,
              color: checked
                  ? cs.primary
                  : cs.onSurface.withValues(alpha: 0.4),
            ),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 14, color: cs.onSurface)),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 14, color: cs.onSurface),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: cs.primary,
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
          if (s == Status.completed || s == Status.publishingFinished) {
            return true;
          }
        case ScheduleFilterStatus.paused:
          if (s == Status.onHiatus || s == Status.canceled) return true;
      }
    }
    return false;
  }

  /// Expected release dates for [manga] inside [month].
  ///
  /// Chapters are sorted oldest → newest so the newest upload anchors the
  /// cadence, then the interval is projected across the whole window using
  /// integer arithmetic from that anchor. Projecting only backwards (the
  /// previous behaviour) left the current and next month empty for shows whose
  /// latest chapter predates the window, and the previous day-by-day walk
  /// could skip a release that landed exactly on the first of the month.
  List<DateTime> _expectedDates(Manga manga, DateTime month) {
    final chapters = manga.chapters.toList()
      ..sort((a, b) => _chapterMs(a).compareTo(_chapterMs(b)));
    if (chapters.isEmpty) return const [];

    final intervalDays = _intervalDays(manga, chapters);
    if (intervalDays <= 0) return const [];

    final anchor = _anchorDate(manga, chapters);
    if (anchor == null) return const [];

    final monthStart = DateTime(month.year, month.month, 1);
    final monthEnd = DateTime(month.year, month.month + 1, 0);
    final anchorDay = DateTime(anchor.year, anchor.month, anchor.day);

    // First multiple of the interval at or after the first day of the month.
    final offsetDays = monthStart.difference(anchorDay).inDays;
    final steps = (offsetDays / intervalDays).ceil();
    var cur = anchorDay.add(Duration(days: steps * intervalDays));

    final dates = <DateTime>[];
    while (!cur.isAfter(monthEnd)) {
      dates.add(cur);
      cur = cur.add(Duration(days: intervalDays));
    }
    return dates;
  }

  int _chapterMs(Chapter c) => int.tryParse(c.dateUpload ?? '') ?? 0;

  int _intervalDays(Manga manga, List<Chapter> chapters) {
    final fromModel = manga.smartUpdateDays ?? 0;
    if (fromModel > 0) return fromModel;
    final computed = FetchInterval.calculateInterval(chapters);
    return computed.clamp(1, FetchInterval.maxInterval);
  }

  DateTime? _anchorDate(Manga manga, List<Chapter> chapters) {
    final newest = chapters.last;
    final ms = _chapterMs(newest);
    if (ms > 0) return DateTime.fromMillisecondsSinceEpoch(ms);
    if ((manga.lastUpdate ?? 0) > 0) {
      return DateTime.fromMillisecondsSinceEpoch(manga.lastUpdate!);
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stream = ref.watch(getCalendarStreamProvider(itemType: ItemType.anime));

    return stream.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erreur : $e')),
      data: (mangas) {
        final filtered = settings.visibleStatuses.isEmpty
            ? mangas
            : mangas
                  .where((m) => _matchesFilter(m, settings.visibleStatuses))
                  .toList();

        final Map<DateTime, List<Manga>> byDay = {};
        for (final manga in filtered) {
          for (final day in _expectedDates(manga, month)) {
            byDay.putIfAbsent(day, () => []).add(manga);
          }
        }

        final sortedDays = byDay.keys.toList()..sort();
        if (sortedDays.isEmpty) {
          return const _EmptySchedule();
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
    return const AnimatedEmptyState(
      message: 'Aucune sortie ce mois-ci',
      icon: Broken.calendar_2,
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
    'Lundi', 'Mardi', 'Mercredi', 'Jeudi',
    'Vendredi', 'Samedi', 'Dimanche',
  ];

  static const _monthNames = [
    '',
    'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
    'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.',
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
        : cs.surfaceContainerHighest;

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
                      color: isToday ? cs.onPrimary : cs.onSurface,
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
                      color: cs.onSurface,
                    ),
                  ),
                  Text(
                    '${_monthNames[date.month]} ${date.day}',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${items.length} épisode${items.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface.withValues(alpha: 0.7),
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
    final cs = Theme.of(context).colorScheme;

    ImageProvider? imgProvider;
    if (manga.customCoverImage != null) {
      imgProvider = MemoryImage(manga.customCoverImage as Uint8List);
    } else if ((manga.customCoverFromTracker ?? manga.imageUrl ?? '')
        .isNotEmpty) {
      imgProvider = CustomExtendedNetworkImageProvider(
        manga.customCoverFromTracker ?? manga.imageUrl!,
        headers: ref.watch(
          headersProvider(
            source: manga.source ?? '',
            lang: manga.lang ?? '',
            sourceId: manga.sourceId,
          ),
        ),
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
                        errorBuilder: (_, _, _) => const _PlaceholderCover(),
                      )
                    : const _PlaceholderCover(),
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
                      color: cs.onSurface,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Icon(
                        Broken.play_circle,
                        size: 13,
                        color: cs.onSurface.withValues(alpha: 0.55),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Épisode $_nextEpisodeNum',
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withValues(alpha: 0.55),
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
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.surfaceContainerHighest,
      child: Icon(
        Broken.video_play,
        size: 24,
        color: cs.onSurface.withValues(alpha: 0.35),
      ),
    );
  }
}
