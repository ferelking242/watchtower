import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:watchtower/modules/music/collections/formatters.dart';

class SummaryCard extends StatelessWidget {
  final String title;
  final String unit;
  final String description;
  final VoidCallback? onTap;
  final Color color;

  SummaryCard({
    super.key,
    required double title,
    required this.unit,
    required this.description,
    required this.color,
    this.onTap,
  }) : title = compactNumberFormatter.format(title);

  const SummaryCard.unformatted({
    super.key,
    required this.title,
    required this.unit,
    required this.description,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final cardColor = brightness == Brightness.dark
        ? color.withValues(alpha: 0.15)
        : color.withValues(alpha: 0.08);
    final textColor = brightness == Brightness.dark ? color.withValues(alpha: 0.9) : color;

    final descriptionNewLines = description.split("").where((s) => s == "\n");

    return Card(
      color: cardColor,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 15),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AutoSizeText.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: title,
                      style: theme.textTheme.headlineMedium?.copyWith(color: textColor),
                    ),
                    TextSpan(
                      text: " $unit",
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                maxLines: 1,
              ),
              const SizedBox(height: 5),
              AutoSizeText(
                description,
                maxLines: description.contains("\n")
                    ? descriptionNewLines.length + 1
                    : 1,
                minFontSize: 9,
                style: theme.textTheme.bodySmall?.copyWith(color: textColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
