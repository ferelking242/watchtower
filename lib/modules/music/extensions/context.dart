import 'package:flutter/material.dart';
import 'package:watchtower/modules/music/l10n/l10n.dart';

extension AppLocale on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}
