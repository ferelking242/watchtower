import 'dart:math' as math;

import 'package:flutter/material.dart';

/// What a [MediaBadge] describes.
enum MediaBadgeKind { language, censored, uncensored, leak, subtitle, dub, vr }

/// A compact, source-provided label attached to one video.
///
/// Extensions describe it with short tokens so a layout never needs a new
/// column: `lang:ja`, `censored`, `uncensored`, `leak`, `sub:en`, `dub:fr`,
/// `vr`. Unknown tokens are ignored instead of breaking the card.
@immutable
class MediaBadge {
  const MediaBadge(this.kind, {this.code, this.label});

  final MediaBadgeKind kind;

  /// ISO language (or country) code used to draw the flag.
  final String? code;

  /// Explicit text, used when the token carried a free-form value.
  final String? label;

  bool get hasFlag => code != null && code!.trim().isNotEmpty;

  static MediaBadge? parse(Object? raw) {
    final token = raw?.toString().trim().toLowerCase();
    if (token == null || token.isEmpty) return null;
    final parts = token.split(':');
    final head = parts.first.trim();
    final value = parts.length > 1 ? parts[1].trim() : null;
    switch (head) {
      case 'lang':
      case 'language':
        if (value == null || value.isEmpty) return null;
        return MediaBadge(MediaBadgeKind.language, code: value);
      case 'censored':
      case 'censure':
      case 'censored-video':
        return const MediaBadge(MediaBadgeKind.censored);
      case 'uncensored':
      case 'uncensored-leak':
        return const MediaBadge(MediaBadgeKind.uncensored);
      case 'leak':
        return const MediaBadge(MediaBadgeKind.leak);
      case 'sub':
      case 'subs':
      case 'subtitle':
      case 'subtitles':
        if (value == null || value.isEmpty) return null;
        return MediaBadge(MediaBadgeKind.subtitle, code: value);
      case 'dub':
      case 'dubs':
      case 'dubbed':
        if (value == null || value.isEmpty) return null;
        return MediaBadge(MediaBadgeKind.dub, code: value);
      case 'vr':
        return const MediaBadge(MediaBadgeKind.vr);
      default:
        return null;
    }
  }

  static List<MediaBadge> parseAll(Iterable<Object?>? raw) {
    if (raw == null) return const [];
    final seen = <String>{};
    final result = <MediaBadge>[];
    for (final token in raw) {
      final badge = parse(token);
      if (badge == null) continue;
      final key = '${badge.kind.name}:${badge.code ?? ''}';
      if (seen.add(key)) result.add(badge);
    }
    return List<MediaBadge>.unmodifiable(result);
  }
}

/// Language codes the app can draw as a flag.
///
/// The badge tokens describe a *language* (`ja`, `en`, `fr`), while a flag is a
/// country. This is the single mapping used everywhere, so a card, a gallery
/// preview and the detail screen never disagree.
const Map<String, String> _countryForLanguage = {
  'ja': 'jp',
  'jp': 'jp',
  'en': 'gb',
  'zh': 'cn',
  'cn': 'cn',
  'tw': 'tw',
  'ko': 'kr',
  'kr': 'kr',
  'th': 'th',
  'vi': 'vn',
  'id': 'id',
  'ms': 'my',
  'my': 'my',
  'ar': 'sa',
  'sa': 'sa',
  'hi': 'in',
  'in': 'in',
  'de': 'de',
  'fr': 'fr',
  'es': 'es',
  'it': 'it',
  'pt': 'pt',
  'br': 'br',
  'ru': 'ru',
  'tr': 'tr',
  'pl': 'pl',
  'nl': 'nl',
  'uk': 'ua',
  'ua': 'ua',
  'sv': 'se',
  'se': 'se',
  'fil': 'ph',
  'tl': 'ph',
  'ph': 'ph',
  'us': 'us',
  'gb': 'gb',
};

String _flagKey(String? code) {
  final normalized = code?.trim().toLowerCase();
  if (normalized == null || normalized.isEmpty) return '';
  return _countryForLanguage[normalized] ?? normalized;
}

/// A flag drawn with the painter below rather than an emoji glyph.
///
/// Android's emoji font has no regional-indicator flags, so `🇯🇵` renders as
/// two letters on many phones. Drawing the flag keeps every platform
/// consistent.
class CountryFlag extends StatelessWidget {
  const CountryFlag({
    super.key,
    required this.code,
    this.width = 18,
    this.height = 12,
    this.radius = 2.5,
  });

  final String? code;
  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final key = _flagKey(code);
    if (key.isEmpty) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: CustomPaint(
        size: Size(width, height),
        painter: _FlagPainter(key),
      ),
    );
  }
}

/// One badge pill: flag + short label.
class MediaBadgeChip extends StatelessWidget {
  const MediaBadgeChip({
    super.key,
    required this.badge,
    this.dense = false,
    this.onPoster = false,
  });

  final MediaBadge badge;
  final bool dense;

  /// Poster overlay: black glass instead of the surface tint.
  final bool onPoster;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = _accentFor(badge.kind, cs);
    final label = _label();
    final height = dense ? 16.0 : 20.0;
    final background = onPoster
        ? Colors.black.withValues(alpha: .72)
        : accent.withValues(alpha: .18);

    return Container(
      height: height,
      padding: EdgeInsets.symmetric(horizontal: dense ? 4 : 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(dense ? 4 : 6),
        border: onPoster ? null : Border.all(color: accent.withValues(alpha: .5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (badge.hasFlag) ...[
            CountryFlag(
              code: badge.code,
              width: dense ? 11 : 14,
              height: dense ? 7.5 : 9.5,
              radius: 1.5,
            ),
            SizedBox(width: dense ? 2.5 : 4),
          ] else
            Icon(_iconFor(badge.kind), size: dense ? 9 : 11, color: accent),
          if (!badge.hasFlag) SizedBox(width: dense ? 2 : 3),
          Text(
            label,
            style: TextStyle(
              color: onPoster ? Colors.white : accent,
              fontSize: dense ? 7.5 : 9,
              fontWeight: FontWeight.w800,
              letterSpacing: .2,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  String _label() {
    switch (badge.kind) {
      case MediaBadgeKind.language:
        return _languageLabel(badge.code);
      case MediaBadgeKind.censored:
        return 'CENS';
      case MediaBadgeKind.uncensored:
        return 'UNCENS';
      case MediaBadgeKind.leak:
        return 'LEAK';
      case MediaBadgeKind.subtitle:
        return 'SUB ${_languageLabel(badge.code)}';
      case MediaBadgeKind.dub:
        return 'DUB ${_languageLabel(badge.code)}';
      case MediaBadgeKind.vr:
        return 'VR';
    }
  }

  static String _languageLabel(String? code) {
    final normalized = code?.trim().toUpperCase();
    if (normalized == null || normalized.isEmpty) return '';
    // Japanese / Chinese / Korean keep their two-letter code: it is already
    // the shortest unambiguous form and fits a 7.5 px badge.
    return normalized;
  }

  static IconData _iconFor(MediaBadgeKind kind) {
    switch (kind) {
      case MediaBadgeKind.language:
        return Icons.translate_rounded;
      case MediaBadgeKind.censored:
        return Icons.blur_on_rounded;
      case MediaBadgeKind.uncensored:
        return Icons.lock_open_rounded;
      case MediaBadgeKind.leak:
        return Icons.report_gmailerrorred_rounded;
      case MediaBadgeKind.subtitle:
        return Icons.subtitles_rounded;
      case MediaBadgeKind.dub:
        return Icons.record_voice_over_rounded;
      case MediaBadgeKind.vr:
        return Icons.view_in_ar_rounded;
    }
  }

  static Color _accentFor(MediaBadgeKind kind, ColorScheme cs) {
    switch (kind) {
      case MediaBadgeKind.language:
        return cs.primary;
      case MediaBadgeKind.censored:
        return const Color(0xFFF5A623);
      case MediaBadgeKind.uncensored:
        return const Color(0xFF4CD08A);
      case MediaBadgeKind.leak:
        return const Color(0xFFFF6B6B);
      case MediaBadgeKind.subtitle:
        return const Color(0xFF4FC3F7);
      case MediaBadgeKind.dub:
        return const Color(0xFFB388FF);
      case MediaBadgeKind.vr:
        return const Color(0xFF7E57C2);
    }
  }
}

/// A wrapping row of badges for one video.
class MediaBadgeStrip extends StatelessWidget {
  const MediaBadgeStrip({
    super.key,
    required this.tokens,
    this.dense = false,
    this.max = 4,
    this.onPoster = false,
    this.alignment = MainAxisAlignment.start,
    this.axis = Axis.horizontal,
  });

  /// Raw extension tokens (`lang:ja`, `censored`, `sub:en`…).
  final Iterable<Object?> tokens;
  final bool dense;
  final int max;
  final bool onPoster;
  final MainAxisAlignment alignment;

  /// Poster cards stack the badges instead of widening them: a 120 px card
  /// cannot hold three labels side by side, but it can hold three rows.
  final Axis axis;

  @override
  Widget build(BuildContext context) {
    final badges = MediaBadge.parseAll(tokens);
    if (badges.isEmpty) return const SizedBox.shrink();
    final visible = badges.take(max).toList(growable: false);
    final chips = [
      for (var index = 0; index < visible.length; index++)
        MediaBadgeChip(
          badge: visible[index],
          dense: dense,
          onPoster: onPoster,
        ),
    ];
    if (axis == Axis.vertical) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var index = 0; index < chips.length; index++) ...[
            if (index > 0) SizedBox(height: dense ? 2 : 4),
            chips[index],
          ],
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: alignment,
      children: [
        for (var index = 0; index < chips.length; index++) ...[
          if (index > 0) SizedBox(width: dense ? 2 : 4),
          chips[index],
        ],
      ],
    );
  }
}

/// One labelled block of the badge legend: used by the gallery and the
/// extension settings screen to document what a source can publish.
class MediaBadgeGroup extends StatelessWidget {
  const MediaBadgeGroup({
    super.key,
    required this.title,
    required this.tokens,
    this.description,
  });

  final String title;
  final List<String> tokens;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: .45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: .4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (description != null) ...[
            const SizedBox(height: 2),
            Text(
              description!,
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 10.5,
                height: 1.25,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final token in tokens)
                if (MediaBadge.parse(token) case final badge?)
                  MediaBadgeChip(badge: badge),
            ],
          ),
        ],
      ),
    );
  }
}

/// Composite section: one row per video showing its badges.
///
/// This is the reusable "badges" component a layout can select; it lets a
/// source publish language / censorship / subtitle metadata without the app
/// inventing per-source widgets.
class MediaBadgeShowcaseCard extends StatelessWidget {
  const MediaBadgeShowcaseCard({
    super.key,
    required this.entries,
    this.title,
    this.emptyLabel = 'Aucun badge publié par cette source.',
  });

  /// Title + tokens pairs, in display order.
  final List<({String title, List<String> tokens})> entries;
  final String? title;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final rows = entries
        .where((entry) => MediaBadge.parseAll(entry.tokens).isNotEmpty)
        .toList(growable: false);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: .4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: .35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null && title!.trim().isNotEmpty) ...[
            Text(
              title!,
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (rows.isEmpty)
            Text(
              emptyLabel,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11),
            )
          else
            for (var index = 0; index < rows.length; index++) ...[
              if (index > 0) const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      rows[index].title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  MediaBadgeStrip(tokens: rows[index].tokens),
                ],
              ),
            ],
        ],
      ),
    );
  }
}

/// Full badge legend: every language the source publishes a flag for, then the
/// censored / uncensored and subtitle / dub families.
class MediaBadgeLegend extends StatelessWidget {
  const MediaBadgeLegend({
    super.key,
    this.languages = const [
      'ja',
      'en',
      'zh',
      'tw',
      'ko',
      'th',
      'vi',
      'id',
      'ms',
      'ar',
      'hi',
      'de',
      'fr',
      'es',
      'it',
      'pt',
      'ru',
      'tr',
      'pl',
      'nl',
    ],
    this.subtitleLanguages = const ['en', 'fr', 'es', 'de', 'pt', 'zh'],
    this.dubLanguages = const ['en', 'fr', 'es', 'de', 'pt'],
  });

  final List<String> languages;
  final List<String> subtitleLanguages;
  final List<String> dubLanguages;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MediaBadgeGroup(
          title: 'Langue de la vidéo',
          description: 'Drapeau du pays associé à la langue publiée.',
          tokens: [for (final code in languages) 'lang:$code'],
        ),
        const SizedBox(height: 10),
        const MediaBadgeGroup(
          title: 'Censure',
          description: 'Indique si la vidéo est censurée, non censurée ou fuie.',
          tokens: ['censored', 'uncensored', 'leak'],
        ),
        const SizedBox(height: 10),
        MediaBadgeGroup(
          title: 'Sous-titres',
          description: 'Drapeau de la langue des sous-titres disponibles.',
          tokens: [for (final code in subtitleLanguages) 'sub:$code'],
        ),
        const SizedBox(height: 10),
        MediaBadgeGroup(
          title: 'Doublage',
          description: 'Drapeau de la langue du doublage disponible.',
          tokens: [for (final code in dubLanguages) 'dub:$code'],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Flag painting
// ─────────────────────────────────────────────────────────────────────────────

class _FlagPainter extends CustomPainter {
  const _FlagPainter(this.flag);

  final String flag;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Offset.zero & size;
    void fill(Color color) =>
        canvas.drawRect(rect, Paint()..color = color);
    void hBands(List<Color> colors) {
      final height = h / colors.length;
      for (var index = 0; index < colors.length; index++) {
        canvas.drawRect(
          Rect.fromLTWH(0, index * height, w, height + .5),
          Paint()..color = colors[index],
        );
      }
    }

    void vBands(List<Color> colors) {
      final width = w / colors.length;
      for (var index = 0; index < colors.length; index++) {
        canvas.drawRect(
          Rect.fromLTWH(index * width, 0, width + .5, h),
          Paint()..color = colors[index],
        );
      }
    }

    void circle(double cx, double cy, double radius, Color color) {
      canvas.drawCircle(
        Offset(w * cx, h * cy),
        h * radius,
        Paint()..color = color,
      );
    }

    void box(
      double left,
      double top,
      double right,
      double bottom,
      Color color,
    ) {
      canvas.drawRect(
        Rect.fromLTRB(w * left, h * top, w * right, h * bottom),
        Paint()..color = color,
      );
    }

    void star(double cx, double cy, double radius, Color color) {
      final path = Path();
      final center = Offset(w * cx, h * cy);
      final r = h * radius;
      for (var i = 0; i < 10; i++) {
        final angle = -math.pi / 2 + i * math.pi / 5;
        final length = i.isEven ? r : r * .42;
        final point = center + Offset(math.cos(angle), math.sin(angle)) * length;
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      path.close();
      canvas.drawPath(path, Paint()..color = color);
    }

    void crescent(
      double cx,
      double cy,
      double radius,
      Color color,
      Color cut,
    ) {
      final center = Offset(w * cx, h * cy);
      final r = h * radius;
      canvas.drawCircle(center, r, Paint()..color = color);
      canvas.drawCircle(
        center + Offset(r * .45, 0),
        r * .82,
        Paint()..color = cut,
      );
    }

    switch (flag) {
      case 'jp':
        fill(const Color(0xFFFFFFFF));
        circle(.5, .5, .3, const Color(0xFFBC002D));
        break;
      case 'cn':
        fill(const Color(0xFFDE2910));
        star(.2, .32, .2, const Color(0xFFFFDE00));
        break;
      case 'tw':
        fill(const Color(0xFFFE0000));
        box(0, 0, .5, .55, const Color(0xFF000095));
        circle(.25, .275, .2, const Color(0xFFFFFFFF));
        break;
      case 'kr':
        fill(const Color(0xFFFFFFFF));
        circle(.5, .5, .26, const Color(0xFFCD2E3A));
        canvas.drawArc(
          Rect.fromCircle(center: Offset(w * .5, h * .5), radius: h * .26),
          0,
          math.pi,
          true,
          Paint()..color = const Color(0xFF0047A0),
        );
        break;
      case 'th':
        hBands(const [
          Color(0xFFA51931),
          Color(0xFFF4F5F8),
          Color(0xFF2D2A4A),
          Color(0xFF2D2A4A),
          Color(0xFFF4F5F8),
          Color(0xFFA51931),
        ]);
        break;
      case 'vn':
        fill(const Color(0xFFDA251D));
        star(.5, .5, .3, const Color(0xFFFFFF00));
        break;
      case 'id':
        hBands(const [Color(0xFFCE1126), Color(0xFFFFFFFF)]);
        break;
      case 'my':
        hBands(const [
          Color(0xFFCC0001),
          Color(0xFFFFFFFF),
          Color(0xFFCC0001),
          Color(0xFFFFFFFF),
          Color(0xFFCC0001),
          Color(0xFFFFFFFF),
          Color(0xFFCC0001),
        ]);
        box(0, 0, .5, .57, const Color(0xFF010066));
        crescent(
          .22,
          .3,
          .16,
          const Color(0xFFFFCC00),
          const Color(0xFF010066),
        );
        break;
      case 'sa':
        fill(const Color(0xFF006C35));
        box(.12, .48, .88, .6, const Color(0xFFFFFFFF));
        break;
      case 'in':
        hBands(const [
          Color(0xFFFF9933),
          Color(0xFFFFFFFF),
          Color(0xFF138808),
        ]);
        circle(.5, .5, .14, const Color(0xFF000080));
        break;
      case 'de':
        hBands(const [
          Color(0xFF000000),
          Color(0xFFDD0000),
          Color(0xFFFFCE00),
        ]);
        break;
      case 'fr':
        vBands(const [
          Color(0xFF002395),
          Color(0xFFFFFFFF),
          Color(0xFFED2939),
        ]);
        break;
      case 'es':
        hBands(const [
          Color(0xFFAA151B),
          Color(0xFFF1BF00),
          Color(0xFFF1BF00),
          Color(0xFFAA151B),
        ]);
        break;
      case 'it':
        vBands(const [
          Color(0xFF009246),
          Color(0xFFFFFFFF),
          Color(0xFFCE2B37),
        ]);
        break;
      case 'pt':
        box(0, 0, .4, 1, const Color(0xFF046A38));
        box(.4, 0, 1, 1, const Color(0xFFDA291C));
        circle(.4, .5, .18, const Color(0xFFFFE900));
        break;
      case 'br':
        fill(const Color(0xFF009C3B));
        {
          final path = Path()
            ..moveTo(w * .5, h * .14)
            ..lineTo(w * .88, h * .5)
            ..lineTo(w * .5, h * .86)
            ..lineTo(w * .12, h * .5)
            ..close();
          canvas.drawPath(path, Paint()..color = const Color(0xFFFFDF00));
        }
        circle(.5, .5, .17, const Color(0xFF002776));
        break;
      case 'ru':
        hBands(const [
          Color(0xFFFFFFFF),
          Color(0xFF0039A6),
          Color(0xFFD52B1E),
        ]);
        break;
      case 'tr':
        fill(const Color(0xFFE30A17));
        crescent(
          .4,
          .5,
          .24,
          const Color(0xFFFFFFFF),
          const Color(0xFFE30A17),
        );
        star(.62, .5, .14, const Color(0xFFFFFFFF));
        break;
      case 'pl':
        hBands(const [Color(0xFFFFFFFF), Color(0xFFDC143C)]);
        break;
      case 'nl':
        hBands(const [
          Color(0xFFAE1C28),
          Color(0xFFFFFFFF),
          Color(0xFF21468B),
        ]);
        break;
      case 'gb':
        fill(const Color(0xFF012169));
        box(.42, 0, .58, 1, const Color(0xFFFFFFFF));
        box(0, .38, 1, .62, const Color(0xFFFFFFFF));
        box(.46, 0, .54, 1, const Color(0xFFC8102E));
        box(0, .44, 1, .56, const Color(0xFFC8102E));
        break;
      case 'us':
        hBands(List<Color>.generate(
          7,
          (index) => index.isEven
              ? const Color(0xFFB22234)
              : const Color(0xFFFFFFFF),
        ));
        box(0, 0, .45, .5, const Color(0xFF3C3B6E));
        break;
      case 'ph':
        hBands(const [Color(0xFF0038A8), Color(0xFFCE1126)]);
        {
          final path = Path()
            ..moveTo(0, 0)
            ..lineTo(w * .38, h * .5)
            ..lineTo(0, h)
            ..close();
          canvas.drawPath(path, Paint()..color = const Color(0xFFFFFFFF));
        }
        break;
      case 'ua':
        hBands(const [Color(0xFF0057B7), Color(0xFFFFD700)]);
        break;
      case 'se':
        fill(const Color(0xFF006AA7));
        box(.3, 0, .42, 1, const Color(0xFFFECC00));
        box(0, .42, 1, .58, const Color(0xFFFECC00));
        break;
      default:
        fill(const Color(0xFF9E9E9E));
        circle(.5, .5, .22, const Color(0xFFFFFFFF));
        break;
    }

    // A faint inner border keeps a white flag readable on a white card.
    canvas.drawRect(
      rect.deflate(.25),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8
        ..color = Colors.black.withValues(alpha: .18),
    );
  }

  @override
  bool shouldRepaint(covariant _FlagPainter oldDelegate) =>
      oldDelegate.flag != flag;
}
