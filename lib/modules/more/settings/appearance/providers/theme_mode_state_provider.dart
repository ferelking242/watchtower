import 'package:flutter/widgets.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/settings.dart';
import 'package:watchtower/modules/more/settings/appearance/providers/flex_scheme_color_state_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:watchtower/utils/constant.dart';
part 'theme_mode_state_provider.g.dart';

@riverpod
class ThemeModeState extends _$ThemeModeState {
  @override
  bool build() {
    return (isar.settings.getSync(kSettingsId) ?? Settings()).themeIsDark ?? true;
  }

  void setTheme(Brightness brightness) {
    if (brightness == Brightness.light) {
      ref.read(themeModeStateProvider.notifier).setLightTheme();
    } else {
      ref.read(themeModeStateProvider.notifier).setDarkTheme();
    }
  }

  void setLightTheme() {
    final settings = isar.settings.getSync(kSettingsId) ?? Settings();
    state = false;
    final schemeIndex = settings.flexSchemeColorIndex ?? 5;
    ref
        .read(flexSchemeColorStateProvider.notifier)
        .setTheme(
          ThemeAA.schemes[schemeIndex].light,
          schemeIndex,
        );
    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings
          ..themeIsDark = state
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  void setDarkTheme() {
    final settings = isar.settings.getSync(kSettingsId) ?? Settings();
    state = true;
    final schemeIndex = settings.flexSchemeColorIndex ?? 5;
    ref
        .read(flexSchemeColorStateProvider.notifier)
        .setTheme(
          ThemeAA.schemes[schemeIndex].dark,
          schemeIndex,
        );
    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings
          ..themeIsDark = state
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

@riverpod
class FollowSystemThemeState extends _$FollowSystemThemeState {
  @override
  bool build() {
    return (isar.settings.getSync(kSettingsId) ?? Settings()).followSystemTheme ?? false;
  }

  void set(bool value) {
    final settings = isar.settings.getSync(kSettingsId) ?? Settings();
    state = value;
    if (value) {
      if (WidgetsBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.light) {
        ref.read(themeModeStateProvider.notifier).setLightTheme();
      } else {
        ref.read(themeModeStateProvider.notifier).setDarkTheme();
      }
    }
    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings
          ..followSystemTheme = value
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}
