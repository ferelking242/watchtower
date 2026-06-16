import 'package:watchtower/main.dart';
import 'package:watchtower/models/settings.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:watchtower/utils/constant.dart';
part 'state_provider.g.dart';

@riverpod
class SubtitleSettingsState extends _$SubtitleSettingsState {
  @override
  PlayerSubtitleSettings build() {
    final subSets = (isar.settings.getSync(kSettingsId) ?? Settings()).playerSubtitleSettings;
    if (subSets == null || subSets.backgroundColorA == null) {
      set(PlayerSubtitleSettings(), true);
      return PlayerSubtitleSettings();
    }
    return subSets;
  }

  void set(PlayerSubtitleSettings value, bool end) {
    final settings = isar.settings.getSync(kSettingsId);
    state = value;
    if (end) {
      isar.writeTxnSync(
        () => isar.settings.putSync(
          settings!
            ..playerSubtitleSettings = value
            ..updatedAt = DateTime.now().millisecondsSinceEpoch,
        ),
      );
    }
  }

  void resetColor() {
    final settings = isar.settings.getSync(kSettingsId);
    state = PlayerSubtitleSettings(
      fontSize: state.fontSize,
      useBold: state.useBold,
      useItalic: state.useItalic,
    );
    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings!
          ..playerSubtitleSettings = PlayerSubtitleSettings(
            fontSize: state.fontSize,
            useBold: state.useBold,
            useItalic: state.useItalic,
          )
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}
