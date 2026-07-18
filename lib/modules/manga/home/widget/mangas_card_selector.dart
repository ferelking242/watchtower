import 'package:flutter/material.dart';
import 'package:watchtower/utils/extensions/build_context_extensions.dart';

/// Pill selector — style Aidoku / iOS :
///   • Actif   : couleur primaire (tint), texte blanc
///   • Inactif : secondarySystemFill (surfaceContainerHighest), texte primaire
///   • Forme   : RoundedRectangle cornerRadius 100 (stadium)
///   • Padding : horizontal 13, vertical 8  (identique à Aidoku ListingsHeaderView)
///   • Police  : footnote w500 (~12 sp)
///   • Pas de bordure
class MangasCardSelector extends StatelessWidget {
  final String text;
  final IconData? icon;    // optionnel — affiché en petit avant le texte
  final String? emojiStr;  // emoji / texte court — optionnel
  final bool selected;
  final VoidCallback onPressed;

  const MangasCardSelector({
    super.key,
    required this.text,
    this.icon,
    this.emojiStr,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final bgColor = selected
        ? cs.primary
        : cs.surfaceContainerHighest.withValues(alpha: 0.85);

    final textColor = selected ? Colors.white : cs.onSurface;

    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(100), // stadium — identique à Aidoku
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon!, size: 12, color: textColor),
              const SizedBox(width: 4),
            ] else if (emojiStr != null) ...[
              Text(emojiStr!, style: const TextStyle(fontSize: 11, height: 1.0)),
              const SizedBox(width: 4),
            ],
            Text(
              text,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500, // .footnote.weight(.medium) Aidoku
                color: textColor,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
