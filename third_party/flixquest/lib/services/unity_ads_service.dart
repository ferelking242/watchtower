import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';

/// Centralized service to manage Unity Ads SDK lifecycle.
class UnityAdsService {
  UnityAdsService._();

  static final UnityAdsService instance = UnityAdsService._();

  static const String defaultAndroidGameId = '5445375';
  static const String defaultBannerPlacementId = 'Banner_Android';
  static const String defaultInterstitialPlacementId = 'Interstitial_Android';
  static const String defaultRewardedPlacementId = 'Rewarded_Android';

  bool _isInitialized = false;
  bool _isInitializing = false;
  String? _initializedGameId;
  String? _lastError;

  bool get isInitialized => _isInitialized;
  bool get isInitializing => _isInitializing;
  String? get lastError => _lastError;

  /// Returns the fallback Game ID for Android from .env or defaults.
  static String get fallbackAndroidGameId =>
      dotenv.env['UNITY_GAME_ID_ANDROID']?.trim().isNotEmpty == true
          ? dotenv.env['UNITY_GAME_ID_ANDROID']!.trim()
          : defaultAndroidGameId;

  /// Returns the fallback banner placement ID from .env or defaults.
  static String get fallbackBannerPlacementId =>
      dotenv.env['UNITY_BANNER_PLACEMENT_ID']?.trim().isNotEmpty == true
          ? dotenv.env['UNITY_BANNER_PLACEMENT_ID']!.trim()
          : defaultBannerPlacementId;

  /// Initializes Unity Ads SDK.
  ///
  /// Safe to call multiple times; redundant calls with the same [gameId] and
  /// [testMode] are skipped.
  Future<bool> initialize({
    required String gameId,
    bool testMode = false,
  }) async {
    final effectiveGameId = gameId.trim().isNotEmpty
        ? gameId.trim()
        : fallbackAndroidGameId;

    if (effectiveGameId.isEmpty) {
      _lastError = 'Game ID is empty';
      debugPrint('UnityAdsService: Game ID is empty, skipping initialization');
      return false;
    }

    if (_isInitialized && _initializedGameId == effectiveGameId) {
      return true;
    }

    if (_isInitializing) {
      return false;
    }

    _isInitializing = true;
    final completer = Completer<bool>();

    try {
      debugPrint('UnityAdsService: Initializing with Game ID: $effectiveGameId, testMode: $testMode');
      await UnityAds.init(
        gameId: effectiveGameId,
        testMode: testMode,
        onComplete: () {
          _isInitialized = true;
          _isInitializing = false;
          _initializedGameId = effectiveGameId;
          _lastError = null;
          debugPrint('UnityAdsService: Initialization successful');
          if (!completer.isCompleted) completer.complete(true);
        },
        onFailed: (error, message) {
          _isInitialized = false;
          _isInitializing = false;
          _lastError = '$error: $message';
          debugPrint('UnityAdsService: Initialization failed: $error - $message');
          if (!completer.isCompleted) completer.complete(false);
        },
      );
    } catch (e, stack) {
      _isInitialized = false;
      _isInitializing = false;
      _lastError = e.toString();
      debugPrint('UnityAdsService: Exception during initialization: $e\n$stack');
      if (!completer.isCompleted) completer.complete(false);
    }

    return completer.future;
  }
}
