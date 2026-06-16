import 'package:google_fonts/google_fonts.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/settings.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:watchtower/utils/constant.dart';
part 'app_font_family.g.dart';

@riverpod
class AppFontFamily extends _$AppFontFamily {
  @override
  String? build() {
    final fontFamily = (isar.settings.getSync(kSettingsId) ?? Settings()).appFontFamily;
    if (fontFamily == null) return null;

    return GoogleFonts.asMap().entries
        .toList()
        .firstWhere((element) => element.value().fontFamily! == fontFamily)
        .value()
        .fontFamily;
  }

  void set(String? fontFamily) {
    final settings = isar.settings.getSync(kSettingsId);
    state = fontFamily;
    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings!
          ..appFontFamily = fontFamily
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}
