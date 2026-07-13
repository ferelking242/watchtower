import 'package:flutter/material.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';

/// Minimal "ALL >" see-all button — replaces the old "Voir tout" / "See all"
/// text buttons across hub carousels/section headers.
///
/// Language-agnostic: uses a short, always-uppercase "ALL" label (no i18n
/// string needed) followed by a Broken chevron icon, so it stays compact and
/// legible regardless of the app locale.
class SeeAllButton extends StatelessWidget {
  final VoidCallback onTap;
  final Color? color;

  const SeeAllButton({super.key, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = color ?? cs.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'ALL',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                color: c,
              ),
            ),
            const SizedBox(width: 2),
            Icon(Broken.arrow_right_3, size: 14, color: c),
          ],
        ),
      ),
    );
  }
}
