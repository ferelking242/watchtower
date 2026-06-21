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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: selected
                ? context.primaryColor
                : Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(100),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: selected
                  ? Colors.white
                  : Theme.of(context).textTheme.bodyMedium!.color,
            ),
          ),
        ),
      );
    }
  }
  