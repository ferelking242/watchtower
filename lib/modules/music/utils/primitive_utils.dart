import 'dart:math';
import 'package:uuid/uuid.dart';

abstract class PrimitiveUtils {
  static bool containsTextInBracket(String matcher, String text) {
    final allMatches = RegExp(r"(?<=\().+?(?=\))").allMatches(matcher);
    if (allMatches.isEmpty) return false;
    return allMatches
        .map((e) => e.group(0))
        .every((match) => match?.contains(text) ?? false);
  }

  static final Random _random = Random();
  static T getRandomElement<T>(List<T> list) {
    return list[_random.nextInt(list.length)];
  }

  static const uuid = Uuid();

  static String toReadableNumber(double num) {
    if (num > 999 && num < 99999) {
      return "${(num / 1000).toStringAsFixed(0)}K";
    } else if (num > 99999 && num < 999999) {
      return "${(num / 1000).toStringAsFixed(0)}K";
    } else if (num > 999999 && num < 999999999) {
      return "${(num / 1000000).toStringAsFixed(0)}M";
    } else if (num > 999999999) {
      return "${(num / 1000000000).toStringAsFixed(0)}B";
    } else {
      return num.toStringAsFixed(0);
    }
  }

  static Future<T> raceMultiple<T>(
    Future<T> Function() inner, {
    Duration timeout = const Duration(milliseconds: 2500),
    int retryCount = 4,
  }) async {
    return Future.any(
      List.generate(retryCount, (i) {
        if (i == 0) return inner();
        return Future.delayed(
          Duration(milliseconds: timeout.inMilliseconds * i),
          inner,
        );
      }),
    );
  }

  static String toSafeFileName(String str) {
    return str.replaceAll(RegExp(r'[/\?%*:|"<>]'), ' ');
  }

  /// Lower-cases and strips every non-alphanumeric character so plugin names
  /// can be compared across the catalogue and the installed plugin list, where
  /// the same plugin is spelled differently ("MusicBrainz" vs
  /// "Musicbrainz and Listenbrainz", "FLAC Music" vs "Flac Downloader Audio").
  static String compactName(String str) =>
      str.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  /// Whether two plugin names refer to the same plugin. Catalogue entries use
  /// a short display name ("MusicBrainz") while the plugin manifest may carry
  /// the full one ("Musicbrainz and Listenbrainz"), so equality of the compact
  /// forms or containment in either direction both count. Empty names never
  /// match: a missing name must not collapse every plugin into one.
  static bool namesLikelySame(String a, String b) {
    final ca = compactName(a);
    final cb = compactName(b);
    if (ca.isEmpty || cb.isEmpty) return false;
    return ca == cb || ca.contains(cb) || cb.contains(ca);
  }
}
