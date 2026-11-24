import 'package:flutter/material.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';

/// One settings block, drawn the way every Watchtower settings page draws it:
/// a small uppercase accent-coloured header with its icon, then plain rows on
/// the page background.
///
/// The music module used to wrap each block in a `Card`, which read as a second
/// design system nested inside Watchtower's own settings. Rows now sit directly
/// on the background so Music Hub settings are indistinguishable from
/// Watchtower → Réglages.
class SectionCardWithHeading extends StatelessWidget {
  final String heading;
  final List<Widget> children;
  final IconData icon;

  const SectionCardWithHeading({
    super.key,
    required this.heading,
    required this.children,
    this.icon = Broken.setting_2,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
          child: Row(
            children: [
              Icon(icon, size: 14, color: cs.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  heading.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.9,
                    color: cs.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        ...children,
      ],
    );
  }
}
