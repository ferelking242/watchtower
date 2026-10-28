import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:watchtower/l10n/generated/app_localizations.dart';
import 'package:watchtower/modules/more/settings/appearance/providers/display_prefs_provider.dart';
import 'package:watchtower/modules/more/settings/widgets/settings_subpage_scaffold.dart';

/// Language picker, opened from Affichage › Langue de l'application.
/// Choosing a language overrides the system locale for the whole app.
class AppLanguageScreen extends ConsumerWidget {
  const AppLanguageScreen({super.key});

  static const labels = <String, String>{
    'en': 'English',
    'fr': 'Français',
    'de': 'Deutsch',
    'es': 'Español',
    'it': 'Italiano',
    'pt': 'Português',
    'ru': 'Русский',
    'ar': 'العربية',
    'tr': 'Türkçe',
    'vi': 'Tiếng Việt',
    'zh': '中文',
    'ja': '日本語',
    'ko': '한국어',
    'hi': 'हिन्दी',
    'id': 'Bahasa Indonesia',
    'th': 'ไทย',
    'uk': 'Українська',
    'pl': 'Polski',
    'nl': 'Nederlands',
    'as': 'অসমীয়া',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(appLanguageOverrideProvider);
    final supported = AppLocalizations.supportedLocales;

    // De-duplicate by language code and keep a stable, readable order.
    final seen = <String>{};
    final entries = <(Locale, String)>[];
    for (final locale in supported) {
      if (!seen.add(locale.languageCode)) continue;
      entries.add((
        Locale(locale.languageCode),
        labels[locale.languageCode] ?? locale.languageCode.toUpperCase(),
      ));
    }
    entries.sort((a, b) => a.$2.toLowerCase().compareTo(b.$2.toLowerCase()));

    return SettingsSubpageScaffold(
      title: "Langue de l'application",
      slivers: [
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final isSystem = index == 0;
              final entry = isSystem ? null : entries[index - 1];
              final locale = entry?.$1;
              final label = isSystem ? 'Système (par défaut)' : entry!.$2;
              final isSelected = isSystem
                  ? selected == null
                  : selected?.languageCode == locale!.languageCode;

              return RadioGroup<Locale?>(
                groupValue: selected,
                onChanged: (v) =>
                    ref.read(appLanguageOverrideProvider.notifier).set(v),
                child: RadioListTile<Locale?>(
                  value: locale,
                  title: Text(label),
                  selected: isSelected,
                ),
              );
            },
            childCount: entries.length + 1,
          ),
        ),
      ],
    );
  }
}
