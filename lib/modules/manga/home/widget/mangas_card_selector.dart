import 'package:flutter/material.dart';
  import 'package:watchtower/utils/extensions/build_context_extensions.dart';

  class MangasCardSelector extends StatelessWidget {
    final String text;
    final IconData icon;
    final bool selected;
    final VoidCallback onPressed;
    const MangasCardSelector({
      super.key,
      required this.text,
      required this.icon,
      required this.selected,
      required this.onPressed,
    });

    @override
    Widget build(BuildContext context) {
      return GestureDetector(
        onTap: onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? context.primaryColor
                : Colors.transparent,
            borderRadius: BorderRadius.circular(100),
            border: selected
                ? null
                : Border.all(
                    color: Theme.of(context).dividerColor.withValues(alpha: 0.4),
                    width: 1,
                  ),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: selected
                  ? Colors.white
                  : Theme.of(context).textTheme.bodyMedium!.color,
            ),
          ),
        ),
      );
    }
  }
