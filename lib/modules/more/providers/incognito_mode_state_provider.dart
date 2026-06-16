import 'package:watchtower/main.dart';
import 'package:watchtower/models/settings.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:watchtower/utils/constant.dart';
part 'incognito_mode_state_provider.g.dart';

@riverpod
class IncognitoModeState extends _$IncognitoModeState {
  @override
  bool build() {
    return (isar.settings.getSync(kSettingsId) ?? Settings()).incognitoMode ?? false;
  }

  void setIncognitoMode(bool value) {
    final settings = (isar.settings.getSync(kSettingsId) ?? Settings());
    state = value;
    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings
          ..incognitoMode = state
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}
