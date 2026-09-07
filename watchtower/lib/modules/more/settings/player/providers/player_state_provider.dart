import 'dart:ui';

import 'package:watchtower/main.dart';
import 'package:watchtower/models/settings.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:watchtower/utils/constant.dart';
part 'player_state_provider.g.dart';

@riverpod
class DefaultSubtitleLangState extends _$DefaultSubtitleLangState {
  @override
  Locale build() {
    return Locale(
      _getLocale()!.languageCode ?? "en",
      _getLocale()!.countryCode ?? "",
    );
  }

  L10nLocale? _getLocale() {
    return (isar.settings.getSync(kSettingsId) ?? Settings()).defaultSubtitleLang ??
        L10nLocale(languageCode: "en", countryCode: "");
  }

  void setLocale(Locale locale) async {
    final settings = (isar.settings.getSync(kSettingsId) ?? Settings());
    isar.writeTxnSync(() {
      isar.settings.putSync(
        settings
          ..defaultSubtitleLang = L10nLocale(
            languageCode: locale.languageCode,
            countryCode: locale.countryCode,
          )
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      );
    });
    state = locale;
  }
}

@riverpod
class MarkEpisodeAsSeenTypeState extends _$MarkEpisodeAsSeenTypeState {
  @override
  int build() {
    return (isar.settings.getSync(kSettingsId) ?? Settings()).markEpisodeAsSeenType ?? 75;
  }

  void set(int value) {
    final settings = isar.settings.getSync(kSettingsId);
    state = value;
    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings!
          ..markEpisodeAsSeenType = value
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

@riverpod
class DefaultSkipIntroLengthState extends _$DefaultSkipIntroLengthState {
  @override
  int build() {
    return (isar.settings.getSync(kSettingsId) ?? Settings()).defaultSkipIntroLength ?? 85;
  }

  void set(int value) {
    final settings = isar.settings.getSync(kSettingsId);
    state = value;
    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings!
          ..defaultSkipIntroLength = value
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

@riverpod
class DefaultDoubleTapToSkipLengthState
    extends _$DefaultDoubleTapToSkipLengthState {
  @override
  int build() {
    return (isar.settings.getSync(kSettingsId) ?? Settings()).defaultDoubleTapToSkipLength ?? 10;
  }

  void set(int value) {
    final settings = isar.settings.getSync(kSettingsId);
    state = value;
    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings!
          ..defaultDoubleTapToSkipLength = value
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

@riverpod
class DefaultPlayBackSpeedState extends _$DefaultPlayBackSpeedState {
  @override
  double build() {
    return (isar.settings.getSync(kSettingsId) ?? Settings()).defaultPlayBackSpeed ?? 1.0;
  }

  void set(double value) {
    final settings = isar.settings.getSync(kSettingsId);
    state = value;
    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings!
          ..defaultPlayBackSpeed = value
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

@riverpod
class FullScreenPlayerState extends _$FullScreenPlayerState {
  @override
  bool build() {
    return (isar.settings.getSync(kSettingsId) ?? Settings()).fullScreenPlayer ?? false;
  }

  void set(bool value) {
    final settings = isar.settings.getSync(kSettingsId);
    state = value;
    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings!
          ..fullScreenPlayer = value
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

@riverpod
class EnableAniSkipState extends _$EnableAniSkipState {
  @override
  bool build() {
    return (isar.settings.getSync(kSettingsId) ?? Settings()).enableAniSkip ?? false;
  }

  void set(bool value) {
    final settings = isar.settings.getSync(kSettingsId);
    state = value;
    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings!
          ..enableAniSkip = value
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

@riverpod
class EnableAutoSkipState extends _$EnableAutoSkipState {
  @override
  bool build() {
    return (isar.settings.getSync(kSettingsId) ?? Settings()).enableAutoSkip ?? false;
  }

  void set(bool value) {
    final settings = isar.settings.getSync(kSettingsId);
    state = value;
    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings!
          ..enableAutoSkip = value
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

@riverpod
class AniSkipTimeoutLengthState extends _$AniSkipTimeoutLengthState {
  @override
  int build() {
    return (isar.settings.getSync(kSettingsId) ?? Settings()).aniSkipTimeoutLength ?? 5;
  }

  void set(int value) {
    final settings = isar.settings.getSync(kSettingsId);
    state = value;
    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings!
          ..aniSkipTimeoutLength = value
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

@riverpod
class UseLibassState extends _$UseLibassState {
  @override
  bool build() {
    return (isar.settings.getSync(kSettingsId) ?? Settings()).useLibass ?? true;
  }

  void set(bool value) {
    final settings = isar.settings.getSync(kSettingsId);
    state = value;
    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings!
          ..useLibass = value
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

@riverpod
class UseMpvConfigState extends _$UseMpvConfigState {
  @override
  bool build() {
    return (isar.settings.getSync(kSettingsId) ?? Settings()).useMpvConfig ?? false;
  }

  void set(bool value) {
    final settings = isar.settings.getSync(kSettingsId);
    state = value;
    isar.writeTxnSync(
      () => isar.settings.putSync(settings!..useMpvConfig = value),
    );
  }
}

@riverpod
class ForceLandscapePlayerState extends _$ForceLandscapePlayerState {
  @override
  bool build() {
    return (isar.settings.getSync(kSettingsId) ?? Settings()).forceLandscapePlayer ?? false;
  }

  void set(bool value) {
    final settings = isar.settings.getSync(kSettingsId);
    state = value;
    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings!
          ..forceLandscapePlayer = value
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}
