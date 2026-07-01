import 'package:flutter/material.dart';
import 'package:watchtower/utils/extensions/build_context_extensions.dart';

class MangasCardSelector extends StatelessWidget {
  final String text;
  final IconData? icon;      // Material icon — optionnel
  final String? emojiStr;    // emoji / texte court — optionnel
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
    final textColor = selected
        ? Colors.white
        : Theme.of(context).textTheme.bodyMedium!.color;

    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? context.primaryColor
              : context.primaryColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? context.primaryColor
                : context.primaryColor.withValues(alpha: 0.22),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon!, size: 13, color: textColor),
              const SizedBox(width: 5),
            ] else if (emojiStr != null) ...[
              Text(emojiStr!,
                  style: const TextStyle(fontSize: 11, height: 1.0)),
              const SizedBox(width: 4),
            ],
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
