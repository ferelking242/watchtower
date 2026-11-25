import 'package:flutter/material.dart';
import 'package:watchtower/modules/music/l10n/l10n.dart';

/// Falls back to English when the app-wide locale is one the music module has
/// no table for (Assamese, for instance): `MaterialApp` resolves against the
/// union of both modules' locales, so the music delegate can legitimately
/// return null and every music screen would throw on its first build.
final AppLocalizations _musicFallbackLocalizations =
    lookupAppLocalizations(const Locale('en'));

extension AppLocale on BuildContext {
  AppLocalizations get l10n =>
      AppLocalizations.of(this) ?? _musicFallbackLocalizations;
}
