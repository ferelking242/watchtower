import 'package:watchtower/main.dart';
import 'package:watchtower/models/settings.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:watchtower/utils/constant.dart';
part 'date_format_state_provider.g.dart';

@riverpod
class DateFormatState extends _$DateFormatState {
  @override
  String build() {
    return (isar.settings.getSync(kSettingsId) ?? Settings()).dateFormat!;
  }

  void set(String dateFormat) {
    final settings = isar.settings.getSync(kSettingsId);
    state = dateFormat;
    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings!
          ..dateFormat = state
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

@riverpod
class RelativeTimesTampsState extends _$RelativeTimesTampsState {
  @override
  int build() {
    return (isar.settings.getSync(kSettingsId) ?? Settings()).relativeTimesTamps!;
  }

  void set(int type) {
    final settings = isar.settings.getSync(kSettingsId);
    state = type;
    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings!
          ..relativeTimesTamps = state
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}
