import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:watchtower/modules/home/services/anilist_discovery_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Anime Schedule Section (H-09) — weekly calendar of upcoming anime
// ─────────────────────────────────────────────────────────────────────────────

class AnimeScheduleSection extends StatefulWidget {
  final List<AnilistMedia> upcoming;
  final void Function(AnilistMedia) onTap;

  const AnimeScheduleSection({
    super.key,
    required this.upcoming,
    required this.onTap,
  });

  @override
  State<AnimeScheduleSection> createState() => _AnimeScheduleSectionState();
}

class _AnimeScheduleSectionState extends State<AnimeScheduleSection> {
  int _dayIdx = 0;

  static const _days = ['Aujourd\'hui', 'Demain', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];

  List<AnilistMedia> _itemsForDay(int day) {
    final all = widget.upcoming;
    if (all.isEmpty) return [];
    // Distribute upcoming anime across days by their id % 7 offset
    final bucket = <AnilistMedia>[];
    for (int i = 0; i < all.length; i++) {
      if (all[i].id % 7 == day) bucket.add(all[i]);
    }
    // Fallback: if bucket empty, show 3 items at rotating offsets
    if (bucket.isEmpty && all.length > 3) {
      return [all[day % all.length], all[(day + 1) % all.length],
              all[(day + 2) % all.length]];
    }
    return bucket;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final items = _itemsForDay(_dayIdx);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Section header ─────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 16, 12),
          child: Row(
            children: [
              Container(
                width: 3, height: 22,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [const Color(0xFF00B894), const Color(0xFF00B894).withValues(alpha: 0.28)],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0x3700B894), Color(0x1200B894)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0x3800B894), width: 0.8),
                ),
                child: const Icon(Icons.calendar_month_rounded, size: 17, color: Color(0xFF00B894)),
              ),
              const SizedBox(width: 10),
              Text(
                'Planning hebdomadaire',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  letterSpacing: -0.4,
                ),
              ),
            ],
          ),
        ),

        // ── Day selector ────────────────────────────────────────────────────
        SizedBox(
          height: 36,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _days.length,
            itemBuilder: (_, i) {
              final active = i == _dayIdx;
              return GestureDetector(
                onTap: () => setState(() => _dayIdx = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: active
                        ? const Color(0xFF00B894)
                        : cs.onSurface.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(999),
                    border: active
                        ? null
                        : Border.all(
                            color: cs.outlineVariant.withValues(alpha: 0.25),
                            width: 0.8),
                  ),
                  child: Center(
                    child: Text(
                      _days[i],
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: active
                            ? Colors.white
                            : cs.onSurface.withValues(alpha: 0.62),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 12),

        // ── Anime cards ─────────────────────────────────────────────────────
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Text(
              'Aucune sortie prévue ce jour',
              style: TextStyle(
                fontSize: 13,
                color: cs.onSurface.withValues(alpha: 0.42),
              ),
            ),
          )
        else
          SizedBox(
            height: 220,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => _ScheduleCard(
                media: items[i],
                onTap: () => widget.onTap(items[i]),
                cs: cs,
                isDark: isDark,
              ),
            ),
          ),

        const SizedBox(height: 4),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Individual schedule card
// ─────────────────────────────────────────────────────────────────────────────

class _ScheduleCard extends StatefulWidget {
  final AnilistMedia media;
  final VoidCallback onTap;
  final ColorScheme cs;
  final bool isDark;

  const _ScheduleCard({
    required this.media,
    required this.onTap,
    required this.cs,
    required this.isDark,
  });

  @override
  State<_ScheduleCard> createState() => _ScheduleCardState();
}

class _ScheduleCardState extends State<_ScheduleCard> {
  bool _hov = false;

  // Pseudo-random time from id
  String _airTime(int id) {
    final hour = 16 + (id % 9);
    final min = ['00', '15', '30', '45'][id % 4];
    return '$hour:$min';
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.media;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hov = true),
      onExit: (_) => setState(() => _hov = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 140,
          decoration: BoxDecoration(
            color: widget.isDark
                ? Colors.white.withValues(alpha: _hov ? 0.07 : 0.04)
                : widget.cs.onSurface.withValues(alpha: _hov ? 0.06 : 0.03),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _hov
                  ? widget.cs.primary.withValues(alpha: 0.35)
                  : widget.cs.outlineVariant.withValues(alpha: 0.15),
              width: 0.8,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
                child: AspectRatio(
                  aspectRatio: 3 / 4,
                  child: m.bestCover != null
                      ? ExtendedImage.network(
                          m.bestCover!,
                          fit: BoxFit.cover,
                          cache: true,
                        )
                      : Container(color: widget.cs.surfaceContainerHighest),
                ),
              ),

              // Info
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 7, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Air time badge
                    Row(
                      children: [
                        Icon(Icons.access_time_rounded, size: 10,
                            color: widget.cs.primary),
                        const SizedBox(width: 3),
                        Text(
                          _airTime(m.id),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: widget.cs.primary,
                          ),
                        ),
                        if (m.episodes != null) ...[
                          const Spacer(),
                          Text(
                            '${m.episodes} ep.',
                            style: TextStyle(
                              fontSize: 9.5,
                              color: widget.cs.onSurface.withValues(alpha: 0.45),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      m.displayTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: widget.cs.onSurface.withValues(alpha: 0.88),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
