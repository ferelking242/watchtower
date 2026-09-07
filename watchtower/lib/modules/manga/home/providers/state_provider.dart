import 'package:watchtower/main.dart';
import 'package:watchtower/models/settings.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:watchtower/utils/constant.dart';
part 'state_provider.g.dart';

@riverpod
class MangaHomeDisplayTypeState extends _$MangaHomeDisplayTypeState {
  @override
  DisplayType build() {
    final settings = (isar.settings.getSync(kSettingsId) ?? Settings());
    return settings.mangaHomeDisplayType;
  }

  void setMangaHomeDisplayType(DisplayType displayType) {
    final settings = (isar.settings.getSync(kSettingsId) ?? Settings());

    state = displayType;

    isar.writeTxnSync(() {
      isar.settings.putSync(
        settings
          ..mangaHomeDisplayType = displayType
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      );
    });
  }
}
