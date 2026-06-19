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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? context.primaryColor
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: selected
                  ? Colors.white
                  : Theme.of(context).textTheme.bodyLarge!.color,
            ),
          ),
        ),
      );
    }
  }
  