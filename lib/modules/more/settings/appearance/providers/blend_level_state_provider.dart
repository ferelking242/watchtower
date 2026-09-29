import 'package:watchtower/main.dart';
import 'package:watchtower/models/settings.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:watchtower/utils/constant.dart';
part 'blend_level_state_provider.g.dart';

@riverpod
class BlendLevelState extends _$BlendLevelState {
  @override
  double build() {
    return (isar.settings.getSync(kSettingsId) ?? Settings()).flexColorSchemeBlendLevel!;
  }

  void setBlendLevel(double blendLevelValue, {bool end = false}) {
    final settings = isar.settings.getSync(kSettingsId);
    state = blendLevelValue;
    if (end) {
      isar.writeTxnSync(
        () => isar.settings.putSync(
          settings!
            ..flexColorSchemeBlendLevel = state
            ..updatedAt = DateTime.now().millisecondsSinceEpoch,
        ),
      );
    }
  }
}
