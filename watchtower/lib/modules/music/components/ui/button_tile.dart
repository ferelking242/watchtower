import 'package:flutter/material.dart';

class ButtonTile extends StatelessWidget {
  final Widget? title;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final bool enabled;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final bool selected;
  final EdgeInsets? padding;

  const ButtonTile({
    super.key,
    this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.enabled = true,
    this.onPressed,
    this.onLongPress,
    this.selected = false,
    this.padding,
    // ignore unused style param for compat
    dynamic style,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: enabled ? onPressed : null,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: selected
            ? BoxDecoration(
                color: colorScheme.primary.withAlpha(25),
                border: Border.all(color: colorScheme.primary, width: 1.0),
                borderRadius: BorderRadius.circular(8),
              )
            : null,
        width: double.infinity,
        child: Row(
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (title != null)
                    DefaultTextStyle.merge(
                      style: selected ? TextStyle(color: colorScheme.primary) : null,
                      child: title!,
                    ),
                  if (subtitle != null)
                    DefaultTextStyle.merge(
                      style: selected
                          ? TextStyle(color: colorScheme.primary, fontSize: 11)
                          : const TextStyle(fontSize: 11),
                      child: subtitle!,
                    ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
