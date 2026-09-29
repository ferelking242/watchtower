import 'package:watchtower/main.dart';
import 'package:watchtower/models/settings.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:watchtower/utils/constant.dart';
part 'downloaded_only_state_provider.g.dart';

@riverpod
class DownloadedOnlyState extends _$DownloadedOnlyState {
  @override
  bool build() {
    return (isar.settings.getSync(kSettingsId) ?? Settings()).downloadedOnlyMode ?? false;
  }

  void setDownloadedOnly(bool value) {
    final settings = (isar.settings.getSync(kSettingsId) ?? Settings());
    state = value;
    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings
          ..downloadedOnlyMode = state
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}
