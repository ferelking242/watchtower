import 'package:watchtower/main.dart';
import 'package:watchtower/models/settings.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:watchtower/utils/constant.dart';
part 'reader_state_provider.g.dart';

@riverpod
class DefaultReadingModeState extends _$DefaultReadingModeState {
  @override
  ReaderMode build() {
    return (isar.settings.getSync(kSettingsId) ?? Settings()).defaultReaderMode;
  }

  void set(ReaderMode value) {
    final settings = isar.settings.getSync(kSettingsId);
    state = value;
    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings!
          ..defaultReaderMode = value
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

@riverpod
class AnimatePageTransitionsState extends _$AnimatePageTransitionsState {
  @override
  bool build() {
    return (isar.settings.getSync(kSettingsId) ?? Settings()).animatePageTransitions!;
  }

  void set(bool value) {
    final settings = isar.settings.getSync(kSettingsId);
    state = value;
    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings!
          ..animatePageTransitions = value
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

@riverpod
class DoubleTapAnimationSpeedState extends _$DoubleTapAnimationSpeedState {
  @override
  int build() {
    return (isar.settings.getSync(kSettingsId) ?? Settings()).doubleTapAnimationSpeed!;
  }

  void set(int value) {
    final settings = isar.settings.getSync(kSettingsId);
    state = value;
    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings!
          ..doubleTapAnimationSpeed = value
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

@riverpod
class CropBordersState extends _$CropBordersState {
  @override
  bool build() {
    return (isar.settings.getSync(kSettingsId) ?? Settings()).cropBorders ?? false;
  }

  void set(bool value) {
    final settings = isar.settings.getSync(kSettingsId);
    state = value;
    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings!
          ..cropBorders = value
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

@riverpod
class ScaleTypeState extends _$ScaleTypeState {
  @override
  ScaleType build() {
    return (isar.settings.getSync(kSettingsId) ?? Settings()).scaleType;
  }

  void set(ScaleType value) {
    final settings = isar.settings.getSync(kSettingsId);
    state = value;
    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings!
          ..scaleType = value
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

@riverpod
class PagePreloadAmountState extends _$PagePreloadAmountState {
  @override
  int build() {
    return (isar.settings.getSync(kSettingsId) ?? Settings()).pagePreloadAmount ?? 6;
  }

  void set(int value) {
    final settings = isar.settings.getSync(kSettingsId);
    state = value;
    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings!
          ..pagePreloadAmount = value
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

@riverpod
class BackgroundColorState extends _$BackgroundColorState {
  @override
  BackgroundColor build() {
    return (isar.settings.getSync(kSettingsId) ?? Settings()).backgroundColor;
  }

  void set(BackgroundColor value) {
    final settings = isar.settings.getSync(kSettingsId);
    state = value;
    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings!
          ..backgroundColor = value
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

@riverpod
class UsePageTapZonesState extends _$UsePageTapZonesState {
  @override
  bool build() {
    return (isar.settings.getSync(kSettingsId) ?? Settings()).usePageTapZones ?? true;
  }

  void set(bool value) {
    final settings = isar.settings.getSync(kSettingsId);
    state = value;
    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings!
          ..usePageTapZones = value
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

@riverpod
class FullScreenReaderState extends _$FullScreenReaderState {
  @override
  bool build() {
    return (isar.settings.getSync(kSettingsId) ?? Settings()).fullScreenReader ?? true;
  }

  void set(bool value) {
    final settings = isar.settings.getSync(kSettingsId);
    state = value;
    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings!
          ..fullScreenReader = value
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

@riverpod
class NavigationOrderState extends _$NavigationOrderState {
  // Hub (Anime/Manga/Novel) comes before Library in the dock, per product
  // request — keep this order so the collapsed "_enableLibSwitch" (Hub) item
  // is placed ahead of "/Library" once merge-into-dock logic runs.
  final items = [
    '/discover',
    '/AnimeLibrary',
    '/MangaLibrary',
    '/NovelLibrary',
    '/Library',
    '/MusicLibrary',
    '/GameLibrary',
    '/marketplace',
    '/browse',
    '/history',
    '/updates',
    '/trackerLibrary',
    '/settings',
  ];

  @override
  List<String> build() {
    return _checkMissingItems(
      (isar.settings.getSync(kSettingsId) ?? Settings()).navigationOrder?.toList() ?? [],
    );
  }

  List<String> _checkMissingItems(List<String> navigationOrder) {
    navigationOrder.addAll(
      items.where((e) => !navigationOrder.contains(e)).toList(),
    );
    return navigationOrder;
  }

  void set(List<String> values) {
    final settings = isar.settings.getSync(kSettingsId);
    state = values;
    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings!
          ..navigationOrder = values
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

@riverpod
class HideItemsState extends _$HideItemsState {
  @override
  List<String> build() {
    return (isar.settings.getSync(kSettingsId) ?? Settings()).hideItems ??
        const [
          '/trackerLibrary',
          '/updates',
          '/history',
        ];
  }

  void set(List<String> values) {
    final settings = isar.settings.getSync(kSettingsId);
    state = values;
    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings!
          ..hideItems = values
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

@riverpod
class MergeLibraryNavMobileState extends _$MergeLibraryNavMobileState {
  @override
  bool build() {
    return (isar.settings.getSync(kSettingsId) ?? Settings()).mergeLibraryNavMobile ?? true;
  }

  void set(bool value) {
    final settings = isar.settings.getSync(kSettingsId);
    state = value;
    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings!
          ..mergeLibraryNavMobile = value
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

@riverpod
class NovelFontSizeState extends _$NovelFontSizeState {
  @override
  int build() {
    return (isar.settings.getSync(kSettingsId) ?? Settings()).novelFontSize ?? 14;
  }

  void set(int value) {
    final settings = isar.settings.getSync(kSettingsId);
    state = value;
    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings!
          ..novelFontSize = value
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

@riverpod
class NovelTextAlignState extends _$NovelTextAlignState {
  @override
  NovelTextAlign build() {
    return (isar.settings.getSync(kSettingsId) ?? Settings()).novelTextAlign;
  }

  void set(NovelTextAlign value) {
    final settings = isar.settings.getSync(kSettingsId);
    state = value;
    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings!
          ..novelTextAlign = value
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

@riverpod
class NovelReaderThemeState extends _$NovelReaderThemeState {
  @override
  String build() {
    return (isar.settings.getSync(kSettingsId) ?? Settings()).novelReaderTheme ?? '#292832';
  }

  void set(String value) {
    final settings = isar.settings.getSync(kSettingsId);
    state = value;
    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings!
          ..novelReaderTheme = value
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

@riverpod
class NovelReaderTextColorState extends _$NovelReaderTextColorState {
  @override
  String build() {
    return (isar.settings.getSync(kSettingsId) ?? Settings()).novelReaderTextColor ?? '#CCCCCC';
  }

  void set(String value) {
    final settings = isar.settings.getSync(kSettingsId);
    state = value;
    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings!
          ..novelReaderTextColor = value
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

@riverpod
class NovelReaderPaddingState extends _$NovelReaderPaddingState {
  @override
  int build() {
    return (isar.settings.getSync(kSettingsId) ?? Settings()).novelReaderPadding ?? 16;
  }

  void set(int value) {
    final settings = isar.settings.getSync(kSettingsId);
    state = value;
    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings!
          ..novelReaderPadding = value
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

@riverpod
class NovelReaderLineHeightState extends _$NovelReaderLineHeightState {
  @override
  double build() {
    return (isar.settings.getSync(kSettingsId) ?? Settings()).novelReaderLineHeight ?? 1.5;
  }

  void set(double value) {
    final settings = isar.settings.getSync(kSettingsId);
    state = value;
    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings!
          ..novelReaderLineHeight = value
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

@riverpod
class NovelShowScrollPercentageState extends _$NovelShowScrollPercentageState {
  @override
  bool build() {
    return (isar.settings.getSync(kSettingsId) ?? Settings()).novelShowScrollPercentage ?? true;
  }

  void set(bool value) {
    final settings = isar.settings.getSync(kSettingsId);
    state = value;
    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings!
          ..novelShowScrollPercentage = value
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

@riverpod
class NovelRemoveExtraParagraphSpacingState
    extends _$NovelRemoveExtraParagraphSpacingState {
  @override
  bool build() {
    return (isar.settings.getSync(kSettingsId) ?? Settings()).novelRemoveExtraParagraphSpacing ??
        false;
  }

  void set(bool value) {
    final settings = isar.settings.getSync(kSettingsId);
    state = value;
    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings!
          ..novelRemoveExtraParagraphSpacing = value
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

@riverpod
class NovelTapToScrollState extends _$NovelTapToScrollState {
  @override
  bool build() {
    return (isar.settings.getSync(kSettingsId) ?? Settings()).novelTapToScroll ?? false;
  }

  void set(bool value) {
    final settings = isar.settings.getSync(kSettingsId);
    state = value;
    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings!
          ..novelTapToScroll = value
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

@riverpod
class ShowPagesNumberState extends _$ShowPagesNumberState {
  @override
  build() {
    return (isar.settings.getSync(kSettingsId) ?? Settings()).showPagesNumber ?? true;
  }

  void set(bool value) {
    final settings = isar.settings.getSync(kSettingsId);

    state = value;
    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings!
          ..showPagesNumber = value
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

@riverpod
class KeepScreenOnReaderState extends _$KeepScreenOnReaderState {
  @override
  bool build() {
    return (isar.settings.getSync(kSettingsId) ?? Settings()).keepScreenOnReader ?? true;
  }

  void set(bool value) {
    final settings = isar.settings.getSync(kSettingsId);
    state = value;
    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings!
          ..keepScreenOnReader = value
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

@riverpod
class WebtoonSidePaddingState extends _$WebtoonSidePaddingState {
  @override
  int build() {
    return (isar.settings.getSync(kSettingsId) ?? Settings()).webtoonSidePadding ?? 0;
  }

  void set(int value) {
    final settings = isar.settings.getSync(kSettingsId);
    state = value;
    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings!
          ..webtoonSidePadding = value
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

@riverpod
class ShowPageGapsState extends _$ShowPageGapsState {
  @override
  bool build() {
    return (isar.settings.getSync(kSettingsId) ?? Settings()).showPageGaps ?? true;
  }

  void set(bool value) {
    final settings = isar.settings.getSync(kSettingsId);
    state = value;
    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings!
          ..showPageGaps = value
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

@riverpod
class InvertColorsState extends _$InvertColorsState {
  @override
  bool build() {
    return (isar.settings.getSync(kSettingsId) ?? Settings()).invertColors ?? false;
  }

  void set(bool value) {
    final settings = isar.settings.getSync(kSettingsId);
    state = value;
    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings!
          ..invertColors = value
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

@riverpod
class GrayscaleState extends _$GrayscaleState {
  @override
  bool build() {
    return (isar.settings.getSync(kSettingsId) ?? Settings()).grayscale ?? false;
  }

  void set(bool value) {
    final settings = isar.settings.getSync(kSettingsId);
    state = value;
    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings!
          ..grayscale = value
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

@riverpod
class ReaderBrightnessState extends _$ReaderBrightnessState {
  @override
  double build() {
    return (isar.settings.getSync(kSettingsId) ?? Settings()).readerBrightness ?? 0.0;
  }

  void set(double value) {
    final settings = isar.settings.getSync(kSettingsId);
    state = value;
    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings!
          ..readerBrightness = value
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

@riverpod
class ReaderContrastState extends _$ReaderContrastState {
  @override
  double build() {
    return (isar.settings.getSync(kSettingsId) ?? Settings()).readerContrast ?? 1.0;
  }

  void set(double value) {
    final settings = isar.settings.getSync(kSettingsId);
    state = value;
    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings!
          ..readerContrast = value
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

@riverpod
class ReaderSaturationState extends _$ReaderSaturationState {
  @override
  double build() {
    return (isar.settings.getSync(kSettingsId) ?? Settings()).readerSaturation ?? 1.0;
  }

  void set(double value) {
    final settings = isar.settings.getSync(kSettingsId);
    state = value;
    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings!
          ..readerSaturation = value
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

@riverpod
class ReaderNavigationLayoutState extends _$ReaderNavigationLayoutState {
  @override
  int build() {
    return (isar.settings.getSync(kSettingsId) ?? Settings()).readerNavigationLayout ?? 0;
  }

  void set(int value) {
    final settings = isar.settings.getSync(kSettingsId);
    state = value;
    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings!
          ..readerNavigationLayout = value
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

@riverpod
class TtsSpeechRateState extends _$TtsSpeechRateState {
  @override
  double build() {
    return (isar.settings.getSync(kSettingsId) ?? Settings()).ttsSpeechRate ?? 0.5;
  }

  void set(double value) {
    final settings = isar.settings.getSync(kSettingsId);
    state = value;
    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings!
          ..ttsSpeechRate = value
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

@riverpod
class TtsPitchState extends _$TtsPitchState {
  @override
  double build() {
    return (isar.settings.getSync(kSettingsId) ?? Settings()).ttsPitch ?? 1.0;
  }

  void set(double value) {
    final settings = isar.settings.getSync(kSettingsId);
    state = value;
    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings!
          ..ttsPitch = value
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

@riverpod
class TtsLanguageState extends _$TtsLanguageState {
  @override
  String? build() {
    return (isar.settings.getSync(kSettingsId) ?? Settings()).ttsLanguage;
  }

  void set(String? value) {
    final settings = isar.settings.getSync(kSettingsId);
    state = value;
    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings!
          ..ttsLanguage = value
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

@riverpod
class TtsVoiceState extends _$TtsVoiceState {
  @override
  String? build() {
    return (isar.settings.getSync(kSettingsId) ?? Settings()).ttsVoice;
  }

  void set(String? value) {
    final settings = isar.settings.getSync(kSettingsId);
    state = value;
    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings!
          ..ttsVoice = value
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

@riverpod
class VolumeButtonNavigationState extends _$VolumeButtonNavigationState {
  @override
  bool build() {
    return (isar.settings.getSync(kSettingsId) ?? Settings()).volumeButtonNavigation ?? false;
  }

  void set(bool value) {
    final settings = isar.settings.getSync(kSettingsId);
    state = value;
    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings!
          ..volumeButtonNavigation = value
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

@riverpod
class InvertVolumeButtonNavigationState extends _$InvertVolumeButtonNavigationState {
  @override
  bool build() {
    return (isar.settings.getSync(kSettingsId) ?? Settings()).invertVolumeButtonNavigation ?? false;
  }

  void set(bool value) {
    final settings = isar.settings.getSync(kSettingsId);
    state = value;
    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings!
          ..invertVolumeButtonNavigation = value
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}
