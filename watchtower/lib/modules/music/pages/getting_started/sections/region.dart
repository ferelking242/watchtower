import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:watchtower/modules/music/collections/language_codes.dart';
import 'package:watchtower/modules/music/collections/markets.dart';
import 'package:watchtower/modules/music/collections/spotube_icons.dart';
import 'package:watchtower/modules/music/modules/getting_started/blur_card.dart';
import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:watchtower/modules/music/l10n/l10n.dart';
import 'package:watchtower/modules/music/provider/user_preferences/user_preferences_provider.dart';

class GettingStartedPageLanguageRegionSection extends HookConsumerWidget {
  final void Function() onNext;
  const GettingStartedPageLanguageRegionSection(
      {super.key, required this.onNext});

  @override
  Widget build(BuildContext context, ref) {
    final preferences = ref.watch(userPreferencesProvider);
    final preferencesNotifier = ref.read(userPreferencesProvider.notifier);

    // Pre-fill Spotube's locale with Watchtower's active locale on first setup,
    // so the language picker shows the same language as the host app by default.
    final appLocale = Localizations.localeOf(context);
    useEffect(() {
      final current = preferences.locale;
      if (current == null || current.languageCode == 'system') {
        final match = L10n.all
            .where(
              (l) => l.languageCode == appLocale.languageCode,
            )
            .firstOrNull;
        if (match != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            preferencesNotifier.setLocale(match);
          });
        }
      }
      return null;
    }, const []);

    return SafeArea(
      child: Center(
        child: BlurCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(
                    SpotubeIcons.language,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(context.l10n.language_region),
                ],
              ),
              const SizedBox(height: 30),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(context.l10n.choose_your_region),
                  Text(context.l10n.choose_your_region_description),
                  const SizedBox(height: 16),
                  Text(context.l10n.market_place_region),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: DropdownButtonFormField<dynamic>(
                      value: preferences.market,
                      isExpanded: true,
                      decoration: InputDecoration(
                        hintText: context.l10n.market_place_region,
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      onChanged: (value) {
                        if (value == null) return;
                        preferencesNotifier.setRecommendationMarket(value);
                      },
                      items: marketsMap.map((entry) {
                        return DropdownMenuItem<dynamic>(
                          value: entry.$1,
                          child: Text(
                            entry.$2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 36),
                  Text(context.l10n.choose_your_language),
                  const SizedBox(height: 16),
                  Text(context.l10n.language),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: DropdownButtonFormField<Locale>(
                      value: preferences.locale,
                      isExpanded: true,
                      decoration: InputDecoration(
                        hintText: context.l10n.system_default,
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      onChanged: (locale) {
                        if (locale == null) return;
                        preferencesNotifier.setLocale(locale);
                      },
                      items: [
                        DropdownMenuItem<Locale>(
                          value: const Locale("system", "system"),
                          child: Text(context.l10n.system_default),
                        ),
                        ...L10n.all.map((locale) {
                          return DropdownMenuItem<Locale>(
                            value: locale,
                            child: Text(
                              LanguageLocals.getDisplayLanguage(
                                locale.languageCode,
                                locale.countryCode,
                              ).toString(),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 48),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  icon: const Icon(SpotubeIcons.angleRight),
                  onPressed: onNext,
                  label: Text(context.l10n.next),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
