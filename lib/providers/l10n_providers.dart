import 'package:flutter/material.dart';
import 'dart:ui';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:watchtower/l10n/generated/app_localizations.dart';
import 'package:watchtower/modules/more/settings/appearance/providers/display_prefs_provider.dart';
part 'l10n_providers.g.dart';

@riverpod
class L10nLocaleState extends _$L10nLocaleState {
  @override
  Locale build() {
    // A language chosen in Affichage overrides the system locale.
    final override = ref.watch(appLanguageOverrideProvider);
    if (override != null) {
      // The override is a raw string persisted by an older build. A code that
      // this build has no translation table for would make
      // `AppLocalizations.delegate.load` throw during the first build, which
      // takes down every screen at once. Only an override we can render is
      // honoured; anything else falls back to the system locale below.
      final resolved = _matchSupported(override);
      if (resolved != null) return resolved;
    }

    for (final systemLocale in PlatformDispatcher.instance.locales) {
      final resolved = _matchSupported(systemLocale);
      if (resolved != null) return resolved;
    }
    return _englishLocale;
  }

  static Locale? _matchSupported(Locale wanted) {
    final supported = AppLocalizations.supportedLocales;
    for (final locale in supported) {
      if (locale.languageCode == wanted.languageCode &&
          locale.countryCode == wanted.countryCode) {
        return locale;
      }
    }
    for (final locale in supported) {
      if (locale.languageCode == wanted.languageCode) return locale;
    }
    return null;
  }
}

const Locale _englishLocale = Locale('en');

/// The English table, used when the resolved locale has no translation.
///
/// `MaterialApp` is given the union of the app's and the music module's
/// locale lists, so the resolver can settle on a language only one of the two
/// modules translates (Korean, Dutch, Polish, Vietnamese, …). The other
/// module's delegate then returns null for that locale, and the `!` that
/// every call site uses would throw on the first frame of every screen.
final AppLocalizations _fallbackLocalizations =
    lookupAppLocalizations(_englishLocale);

AppLocalizations? l10nLocalizations(BuildContext context) =>
    AppLocalizations.of(context) ?? _fallbackLocalizations;
Locale currentLocale(BuildContext context) {
  return Localizations.localeOf(context);
}

extension L10nExtension on BuildContext {
  AppLocalizations get l10n => l10nLocalizations(this)!;
}
