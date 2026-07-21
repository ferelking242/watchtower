import 'package:watchtower/main.dart';
import 'package:watchtower/models/settings.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:watchtower/utils/constant.dart';

part 'player_audio_state_provider.g.dart';

@riverpod
class AudioPreferredLangState extends _$AudioPreferredLangState {
  @override
  String build() {
    return (isar.settings.getSync(kSettingsId) ?? Settings()).audioPreferredLanguages ?? "";
  }

  void set(String value) {
    final settings = isar.settings.getSync(kSettingsId);
    state = value;
    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings!
          ..audioPreferredLanguages = value
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

@riverpod
class EnableAudioPitchCorrectionState
    extends _$EnableAudioPitchCorrectionState {
  @override
  bool build() {
    return (isar.settings.getSync(kSettingsId) ?? Settings()).enableAudioPitchCorrection ?? true;
  }

  void set(bool value) {
    final settings = isar.settings.getSync(kSettingsId);
    state = value;
    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings!
          ..enableAudioPitchCorrection = value
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

@riverpod
class AudioChannelState extends _$AudioChannelState {
  @override
  AudioChannel build() {
    return (isar.settings.getSync(kSettingsId) ?? Settings()).audioChannels;
  }

  void set(AudioChannel value) {
    final settings = isar.settings.getSync(kSettingsId);
    state = value;
    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings!
          ..audioChannels = value
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

@riverpod
class VolumeBoostCapState extends _$VolumeBoostCapState {
  @override
  int build() {
    return (isar.settings.getSync(kSettingsId) ?? Settings()).volumeBoostCap ?? 30;
  }

  void set(int value) {
    final settings = isar.settings.getSync(kSettingsId);
    state = value;
    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings!
          ..volumeBoostCap = value
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}
