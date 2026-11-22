import 'package:flutter/material.dart';
import 'package:watchtower/modules/live_tv/data/live_countries.dart';
import 'package:watchtower/modules/live_tv/epg/epg_models.dart';
import 'package:watchtower/modules/live_tv/models/live_provider.dart';

/// "20:45" — the time of day, no date.
String clockLabel(DateTime moment) =>
    '${moment.hour.toString().padLeft(2, '0')}:'
    '${moment.minute.toString().padLeft(2, '0')}';

/// "1 h 25" / "45 min" — a programme's length.
String durationLabel(Duration duration) {
  final minutes = duration.inMinutes;
  if (minutes < 1) return '< 1 min';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  if (hours == 0) return '$rest min';
  if (rest == 0) return '$hours h';
  return '$hours h ${rest.toString().padLeft(2, '0')}';
}

/// "En cours · 45 min restantes" / "À 21:00".
String scheduleLabel(EpgProgramme programme, DateTime now) {
  if (programme.isLiveAt(now)) {
    final remaining = programme.stop.difference(now);
    return 'En cours · ${durationLabel(remaining)} restantes';
  }
  if (programme.start.isAfter(now)) {
    return 'À ${clockLabel(programme.start)}';
  }
  return 'Terminé';
}

/// Day header for a guide, e.g. "Aujourd'hui" / "Demain" / "lundi 24".
String dayLabel(DateTime day, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(day.year, day.month, day.day);
  final delta = target.difference(today).inDays;
  if (delta == 0) return "Aujourd'hui";
  if (delta == 1) return 'Demain';
  if (delta == -1) return 'Hier';
  const names = [
    'lundi',
    'mardi',
    'mercredi',
    'jeudi',
    'vendredi',
    'samedi',
    'dimanche',
  ];
  return '${names[target.weekday - 1]} ${target.day}';
}

/// The square logo tile a channel is drawn with.
///
/// A logo URL that fails to load must not leave a blank hole in a grid, so the
/// fallback is the channel's initials on a colour derived from its name — the
/// same channel always gets the same tile.
class ChannelLogo extends StatelessWidget {
  const ChannelLogo({
    super.key,
    required this.name,
    this.logoUrl,
    this.size = 48,
    this.radius = 12,
  });

  final String name;
  final String? logoUrl;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final url = logoUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: url == null || url.isEmpty
            ? _initials(context)
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _initials(context),
                loadingBuilder: (context, child, progress) =>
                    progress == null ? child : _initials(context),
              ),
      ),
    );
  }

  Widget _initials(BuildContext context) {
    final hash = name.codeUnits.fold<int>(0, (sum, unit) => sum + unit);
    final hue = (hash * 37) % 360;
    final base = HSLColor.fromAHSL(1, hue.toDouble(), 0.42, 0.38).toColor();
    final initials = name
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .take(2)
        .map((word) => word[0].toUpperCase())
        .join();
    return ColoredBox(
      color: base,
      child: Center(
        child: Text(
          initials.isEmpty ? '?' : initials,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: size * 0.34,
          ),
        ),
      ),
    );
  }
}

/// One row of the channel list: flag, name, language, favourite, play.
class ChannelRow extends StatelessWidget {
  const ChannelRow({
    super.key,
    required this.channel,
    required this.onTap,
    this.epg,
    this.now,
    this.isFavorite = false,
    this.onFavorite,
    this.showCountry = true,
  });

  final LiveChannel channel;
  final VoidCallback onTap;

  /// What is airing now, when the guide covers this channel.
  final EpgProgramme? epg;

  final DateTime? now;
  final bool isFavorite;
  final VoidCallback? onFavorite;
  final bool showCountry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final country = channel.country ?? channel.group;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(
          children: [
            if (showCountry && country != null) ...[
              flagFor(country, size: 20),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    channel.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (epg != null && now != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        epg!.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (channel.language case final language? when language.isNotEmpty)
              Text(
                language.toUpperCase().substring(
                  0,
                  language.length >= 3 ? 3 : language.length,
                ),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            if (onFavorite != null)
              IconButton(
                tooltip: isFavorite
                    ? 'Retirer des favoris'
                    : 'Ajouter aux favoris',
                onPressed: onFavorite,
                icon: Icon(
                  isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                  size: 20,
                  color: isFavorite
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.graphic_eq_rounded,
                size: 17,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The square "Top Picks" tile of the MovieBox home.
class TopPickTile extends StatelessWidget {
  const TopPickTile({
    super.key,
    required this.channel,
    required this.onTap,
    this.nowPlaying,
  });

  final LiveChannel channel;
  final VoidCallback onTap;
  final String? nowPlaying;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white10),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ChannelLogo(
                    name: channel.name,
                    logoUrl: channel.logoUrl,
                    size: double.infinity,
                    radius: 0,
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black54],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 8,
                    right: 8,
                    bottom: 6,
                    child: Text(
                      nowPlaying ?? channel.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            channel.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// A section title with an optional trailing action.
class LiveSectionTitle extends StatelessWidget {
  const LiveSectionTitle({
    super.key,
    required this.title,
    this.trailing,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Centred message for an empty list, with an optional action.
class LiveEmptyState extends StatelessWidget {
  const LiveEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}
