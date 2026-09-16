import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:retry/retry.dart';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

const kTextHeaderStyle = TextStyle(
  fontFamily: 'FigtreeSB',
  fontSize: 22,
);

const kBoldItemTitleStyle = TextStyle(
  fontFamily: 'FigtreeSB',
  fontSize: 19,
);

const kTextSmallHeaderStyle = TextStyle(
  fontFamily: 'FigtreeSB',
  fontSize: 17,
  overflow: TextOverflow.ellipsis,
);

const kTextSmallBodyStyle = TextStyle(
  fontFamily: 'Figtree',
  fontSize: 17,
  overflow: TextOverflow.ellipsis,
);

const kTextVerySmallBodyStyle = TextStyle(
  fontFamily: 'Figtree',
  fontSize: 13,
  overflow: TextOverflow.ellipsis,
);

const kTextSmallAboutBodyStyle = TextStyle(
  fontFamily: 'Figtree',
  fontSize: 14,
  overflow: TextOverflow.ellipsis,
);

const kTableLeftStyle =
    TextStyle(overflow: TextOverflow.ellipsis, fontWeight: FontWeight.bold);

const String currentAppVersion = '4.0.0';

final client = HttpClient();
// Catalog requests must fail back to the screen instead of retrying forever.
// The old 100000-attempt policy kept the hero shimmer alive for hours when
// TMDB or the configured proxy was unreachable.
const retryOptions = RetryOptions(
  maxAttempts: 2,
  maxDelay: Duration(seconds: 1),
  delayFactor: Duration(milliseconds: 300),
);
const timeOut = Duration(seconds: 12);

const retryOptionsStream = RetryOptions(
    maxDelay: Duration(milliseconds: 300),
    delayFactor: Duration(seconds: 0),
    maxAttempts: 1);
const timeOutStream = Duration(seconds: 30);

final List<String> appNames = [
  'flixquest-v2.4.0.apk',
  'flixquest-v2.4.1.apk',
  'flixquest-v2.4.2.apk',
  'flixquest-v2.4.3.apk',
  'flixquest-v2.4.4.apk',
  'flixquest-v2.5.0.apk',
  'flixquest-v2.5.0-2.apk',
  'flixquest-v2.5.0-3.apk',
  'flixquest-v2.5.0-4.apk',
  'flixquest-v2.5.0-5.apk',
  'flixquest-v2.5.0-6.apk',
  'flixquest-v2.6.0.apk',
  'flixquest-v2.7.0.apk',
  'flixquest-v2.7.1.apk',
  'flixquest-v2.7.2.apk',
  'flixquest-v2.7.2-b2.apk',
  'flixquest-v3.0.0.apk'
];

/// Shared, bounded image cache. Creating one manager per widget bypasses
/// reuse and leaves multiple cache instances competing for TV memory/storage.
final CacheManager _sharedImageCache = CacheManager(
  Config(
    'flixquest-images',
    stalePeriod: const Duration(days: 15),
    maxNrOfCacheObjects: 180,
  ),
);

CacheManager cacheProp() => _sharedImageCache;

enum MediaType { movie, tvShow }

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

late SharedPreferences sharedPrefsSingleton;

/// Returns persisted preferences when the host has finished initializing the
/// platform plugin. Embedded FlixQuest screens use defaults until then.
SharedPreferences? get sharedPrefsSingletonOrNull {
  try {
    return sharedPrefsSingleton;
  } catch (_) {
    return null;
  }
}

/// easy localization run command
// flutter pub run easy_localization:generate -S packages/flixquest/assets/translations -f keys -O lib/translations -o locale_keys.g.dart
