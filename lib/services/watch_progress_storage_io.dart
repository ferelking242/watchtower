import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:watchtower/modules/watch/detail/watch_progress_key.dart';
import 'package:watchtower/services/saved_watch_progress.dart';

Future<Map<String, SavedWatchProgress>> loadSavedWatchPositions(
  Iterable<String> titles,
) async {
  try {
    final directory = await getApplicationSupportDirectory();
    final entries = await Future.wait(
      titles.toSet().map((title) async {
        try {
          final file = File(
            '${directory.path}/wt_progress_${stableWatchProgressKey(title)}.json',
          );
          if (!await file.exists()) return null;
          final data = json.decode(await file.readAsString()) as Map;
          final milliseconds = (data['ms'] as num?)?.toInt() ?? 0;
          if (milliseconds <= 5000) return null;
          final savedAtMilliseconds = (data['savedAt'] as num?)?.toInt();
          return MapEntry(
            title,
            SavedWatchProgress(
              position: Duration(milliseconds: milliseconds),
              savedAt: savedAtMilliseconds == null
                  ? null
                  : DateTime.fromMillisecondsSinceEpoch(
                      savedAtMilliseconds,
                    ),
            ),
          );
        } catch (_) {
          return null;
        }
      }),
    );
    return Map.fromEntries(
      entries.whereType<MapEntry<String, SavedWatchProgress>>(),
    );
  } catch (_) {
    return {};
  }
}