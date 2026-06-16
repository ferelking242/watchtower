import 'package:watchtower/main.dart';
import 'package:watchtower/models/settings.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:watchtower/utils/constant.dart';
part 'color_filter_provider.g.dart';

@riverpod
class CustomColorFilterState extends _$CustomColorFilterState {
  @override
  CustomColorFilter? build() {
    if (!ref.watch(enableCustomColorFilterStateProvider)) return null;
    return (isar.settings.getSync(kSettingsId) ?? Settings()).customColorFilter;
  }

  void set(int a, int r, int g, int b, bool end) {
    final settings = isar.settings.getSync(kSettingsId);
    var value = CustomColorFilter()
      ..a = a
      ..r = r
      ..g = g
      ..b = b;
    if (end) {
      isar.writeTxnSync(
        () => isar.settings.putSync(
          settings!
            ..customColorFilter = value
            ..updatedAt = DateTime.now().millisecondsSinceEpoch,
        ),
      );
    }
    state = value;
  }
}

@riverpod
class EnableCustomColorFilterState extends _$EnableCustomColorFilterState {
  @override
  bool build() {
    return (isar.settings.getSync(kSettingsId) ?? Settings()).enableCustomColorFilter ?? false;
  }

  void set(bool value) {
    final settings = isar.settings.getSync(kSettingsId);

    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings!
          ..enableCustomColorFilter = value
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      ),
    );
    state = value;
  }
}

@riverpod
class ColorFilterBlendModeState extends _$ColorFilterBlendModeState {
  @override
  ColorFilterBlendMode build() {
    return (isar.settings.getSync(kSettingsId) ?? Settings()).colorFilterBlendMode;
  }

  void set(ColorFilterBlendMode value) {
    final settings = isar.settings.getSync(kSettingsId);

    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings!
          ..colorFilterBlendMode = value
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      ),
    );
    state = value;
  }
}
