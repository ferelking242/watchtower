import 'package:watchtower/main.dart';
import 'package:watchtower/models/settings.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:watchtower/utils/constant.dart';
part 'pure_black_dark_mode_state_provider.g.dart';

@riverpod
class PureBlackDarkModeState extends _$PureBlackDarkModeState {
  @override
  bool build() {
    return (isar.settings.getSync(kSettingsId) ?? Settings()).pureBlackDarkMode!;
  }

  void set(bool value) {
    final settings = isar.settings.getSync(kSettingsId);
    state = value;
    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings!
          ..pureBlackDarkMode = value
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}
