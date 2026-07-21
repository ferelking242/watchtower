import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:watchtower/modules/music/provider/user_preferences/user_preferences_provider.dart';

class SpotubeColor extends Color {
  final String name;

  const SpotubeColor(super.color, {required this.name});

  const SpotubeColor.from(super.value, {required this.name});

  factory SpotubeColor.fromString(String string) {
    final slices = string.split(":");
    return SpotubeColor(int.parse(slices.last), name: slices.first);
  }

  @override
  String toString() {
    return "$name:${toARGB32()}";
  }
}

final Set<SpotubeColor> colorsMap = {
  SpotubeColor(Colors.blueGrey.value, name: "slate"),
  SpotubeColor(Colors.grey.value, name: "gray"),
  SpotubeColor(Colors.grey.value, name: "zinc"),
  SpotubeColor(Colors.grey.value, name: "neutral"),
  SpotubeColor(Colors.brown.value, name: "stone"),
  SpotubeColor(Colors.red.value, name: "red"),
  SpotubeColor(Colors.orange.value, name: "orange"),
  SpotubeColor(Colors.yellow.value, name: "yellow"),
  SpotubeColor(Colors.green.value, name: "green"),
  SpotubeColor(Colors.blue.value, name: "blue"),
  SpotubeColor(Colors.purple.value, name: "violet"),
  SpotubeColor(Colors.pink.value, name: "rose"),
};

final Map<String, ColorScheme> colorSchemeMap = {
  "slate": ColorScheme.fromSeed(seedColor: Colors.blueGrey),
  "gray": ColorScheme.fromSeed(seedColor: Colors.grey),
  "zinc": ColorScheme.fromSeed(seedColor: Colors.grey),
  "neutral": ColorScheme.fromSeed(seedColor: Colors.grey),
  "stone": ColorScheme.fromSeed(seedColor: Colors.brown),
  "red": ColorScheme.fromSeed(seedColor: Colors.red),
  "orange": ColorScheme.fromSeed(seedColor: Colors.orange),
  "yellow": ColorScheme.fromSeed(seedColor: Colors.yellow),
  "green": ColorScheme.fromSeed(seedColor: Colors.green),
  "blue": ColorScheme.fromSeed(seedColor: Colors.blue),
  "violet": ColorScheme.fromSeed(seedColor: Colors.purple),
  "rose": ColorScheme.fromSeed(seedColor: Colors.pink),
};

class ColorSchemePickerDialog extends HookConsumerWidget {
  const ColorSchemePickerDialog({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final preferences = ref.watch(userPreferencesProvider);
    final preferencesNotifier = ref.watch(userPreferencesProvider.notifier);

    final scheme = preferences.accentColorScheme;
    final active = useState<String?>(
      colorsMap.firstWhereOrNull(
        (element) => scheme.name == element.name,
      )?.name,
    );

    return AlertDialog(
      title: Text(context.l10n.pick_color_scheme),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.save),
        ),
      ],
      content: SizedBox(
        height: 200,
        width: 400,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: colorsMap.map(
            (color) {
              return _ColorChip(
                name: color.name,
                color: color,
                isActive: color.name == active.value,
                onPressed: () {
                  active.value = color.name;
                  preferencesNotifier.setAccentColorScheme(
                    colorsMap.firstWhere((e) => e.name == color.name),
                  );
                },
              );
            },
          ).toList(),
        ),
      ),
    );
  }
}

class _ColorChip extends StatelessWidget {
  final String name;
  final Color color;
  final bool isActive;
  final VoidCallback onPressed;

  const _ColorChip({
    required this.name,
    required this.color,
    required this.isActive,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return isActive
        ? FilledButton.icon(
            onPressed: onPressed,
            icon: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            label: Text(name),
          )
        : OutlinedButton.icon(
            onPressed: onPressed,
            icon: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            label: Text(name),
          );
  }
}
