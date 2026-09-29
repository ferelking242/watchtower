import 'package:flutter/material.dart';
import 'package:watchtower/main.dart';
import 'dart:ui';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:watchtower/l10n/generated/app_localizations.dart';
part 'l10n_providers.g.dart';

@riverpod
class L10nLocaleState extends _$L10nLocaleState {
  @override
  Locale build() {
    final systemLocales = PlatformDispatcher.instance.locales;
    final supported = AppLocalizations.supportedLocales;
    for (final systemLocale in systemLocales) {
      final exact = supported.where(
        (locale) =>
            locale.languageCode == systemLocale.languageCode &&
            locale.countryCode == systemLocale.countryCode,
      );
      if (exact.isNotEmpty) return exact.first;
      final language = supported.where(
        (locale) => locale.languageCode == systemLocale.languageCode,
      );
      if (language.isNotEmpty) return language.first;
    }
    return supported.first;
  }
}

AppLocalizations? l10nLocalizations(BuildContext context) =>
    AppLocalizations.of(context);
Locale currentLocale(BuildContext context) {
  return Localizations.localeOf(context);
}

extension L10nExtension on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}
