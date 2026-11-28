import 'package:watchtower/main.dart';
import 'package:watchtower/models/settings.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:watchtower/modules/more/settings/reader/providers/reader_prefs_provider.dart';
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
    return (isar.settings.getSync(kSettingsId) ?? Settings())
        .animatePageTransitions!;
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
    return (isar.settings.getSync(kSettingsId) ?? Settings())
        .doubleTapAnimationSpeed!;
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
    return (isar.settings.getSync(kSettingsId) ?? Settings()).cropBorders ??
        false;
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
    return (isar.settings.getSync(kSettingsId) ?? Settings())
            .pagePreloadAmount ??
        6;
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
    return (isar.settings.getSync(kSettingsId) ?? Settings()).usePageTapZones ??
        true;
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
    return (isar.settings.getSync(kSettingsId) ?? Settings())
            .fullScreenReader ??
        true;
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
  /// Clean four-slot dock: the Hub umbrella (every library collapses into it),
  /// then the cross-type library, Explorer and the menu.
  final items = [
    '/AnimeLibrary',
    '/MoviesLibrary',
    '/SeriesLibrary',
    '/MangaLibrary',
    '/NovelLibrary',
    '/MusicLibrary',
    '/GameLibrary',
    '/Library',
    '/browse',
  ];

  /// Order with the now-removed Accueil page first. Kept so untouched installs
  /// drop that page instead of keeping it in the dock.
  static const _homeFirstDefault = [
    '/WatchtowerHome',
    '/MoviesLibrary',
    '/SeriesLibrary',
    '/AnimeLibrary',
    '/MangaLibrary',
    '/NovelLibrary',
    '/MusicLibrary',
    '/GameLibrary',
    '/Library',
    '/history',
    '/updates',
    '/marketplace',
    '/browse',
    '/trackerLibrary',
    '/settings',
    '/discover',
  ];

  /// Order shipped before the hub was put first. Kept so an untouched install
  /// follows the new default instead of keeping its old order.
  static const _previousDefault = [
    '/AnimeLibrary',
    '/MoviesLibrary',
    '/SeriesLibrary',
    '/Library',
    '/MangaLibrary',
    '/NovelLibrary',
    '/MusicLibrary',
    '/GameLibrary',
    '/history',
    '/updates',
    '/marketplace',
    '/browse',
    '/trackerLibrary',
    '/settings',
    '/discover',
  ];

  /// Order briefly shipped with Movies first (before the hub was added back).
  static const _moviesFirstDefault = [
    '/MoviesLibrary',
    '/SeriesLibrary',
    '/AnimeLibrary',
    '/MangaLibrary',
    '/NovelLibrary',
    '/MusicLibrary',
    '/GameLibrary',
    '/Library',
    '/history',
    '/updates',
    '/marketplace',
    '/browse',
    '/trackerLibrary',
    '/settings',
    '/discover',
  ];

  /// Previous shipped order. Installations that never reordered their dock are
  /// moved to [items]; a custom order is left untouched.
  static const _legacyDefault = [
    '/MoviesLibrary',
    '/discover',
    '/Library',
    '/AnimeLibrary',
    '/SeriesLibrary',
    '/MangaLibrary',
    '/NovelLibrary',
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
    final stored =
        (isar.settings.getSync(kSettingsId) ?? Settings()).navigationOrder
            ?.toList() ??
        [];
    final order =
        stored.isEmpty ||
            _sameOrder(stored, _legacyDefault) ||
            _sameOrder(stored, _previousDefault) ||
            _sameOrder(stored, _moviesFirstDefault) ||
            _sameOrder(stored, _homeFirstDefault)
        ? List<String>.from(items)
        : stored;
    return _checkMissingItems(order);
  }

  bool _sameOrder(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
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
        const ['/trackerLibrary', '/updates', '/history'];
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
    return (isar.settings.getSync(kSettingsId) ?? Settings())
            .mergeLibraryNavMobile ??
        true;
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
    return (isar.settings.getSync(kSettingsId) ?? Settings()).novelFontSize ??
        14;
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
    return (isar.settings.getSync(kSettingsId) ?? Settings())
            .novelReaderTheme ??
        '#292832';
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
    return (isar.settings.getSync(kSettingsId) ?? Settings())
            .novelReaderTextColor ??
        '#CCCCCC';
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
    return (isar.settings.getSync(kSettingsId) ?? Settings())
            .novelReaderPadding ??
        16;
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
    return (isar.settings.getSync(kSettingsId) ?? Settings())
            .novelReaderLineHeight ??
        1.5;
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
    return (isar.settings.getSync(kSettingsId) ?? Settings())
            .novelShowScrollPercentage ??
        true;
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
    return (isar.settings.getSync(kSettingsId) ?? Settings())
            .novelRemoveExtraParagraphSpacing ??
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
    return (isar.settings.getSync(kSettingsId) ?? Settings())
            .novelTapToScroll ??
        false;
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
    return (isar.settings.getSync(kSettingsId) ?? Settings()).showPagesNumber ??
        true;
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
    return (isar.settings.getSync(kSettingsId) ?? Settings())
            .keepScreenOnReader ??
        true;
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
    return (isar.settings.getSync(kSettingsId) ?? Settings())
            .webtoonSidePadding ??
        0;
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
    return (isar.settings.getSync(kSettingsId) ?? Settings()).showPageGaps ??
        true;
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
    return (isar.settings.getSync(kSettingsId) ?? Settings()).invertColors ??
        false;
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
    return (isar.settings.getSync(kSettingsId) ?? Settings()).grayscale ??
        false;
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
    return (isar.settings.getSync(kSettingsId) ?? Settings())
            .readerBrightness ??
        0.0;
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
    return (isar.settings.getSync(kSettingsId) ?? Settings()).readerContrast ??
        1.0;
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
    return (isar.settings.getSync(kSettingsId) ?? Settings())
            .readerSaturation ??
        1.0;
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
    return (isar.settings.getSync(kSettingsId) ?? Settings())
            .readerNavigationLayout ??
        0;
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
    return (isar.settings.getSync(kSettingsId) ?? Settings()).ttsSpeechRate ??
        0.5;
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
  // Persisted in the `reader_prefs` Hive box rather than in `Settings`: the
  // Isar schema is frozen (see IsarOpenGuard — adding a property changes the
  // fingerprint and quarantines every existing library), so a setting stored
  // there would never be written back.
  @override
  bool build() => readerPrefsBool(kVolumeButtonNavigationKey, false);

  void set(bool value) {
    state = value;
    readerPrefsPut(kVolumeButtonNavigationKey, value);
  }
}

@riverpod
class InvertVolumeButtonNavigationState
    extends _$InvertVolumeButtonNavigationState {
  @override
  bool build() => readerPrefsBool(kInvertVolumeButtonNavigationKey, false);

  void set(bool value) {
    state = value;
    readerPrefsPut(kInvertVolumeButtonNavigationKey, value);
  }
}
