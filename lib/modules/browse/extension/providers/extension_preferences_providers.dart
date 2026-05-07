import 'dart:convert';

import 'package:isar_community/isar.dart';
import 'package:watchtower/eval/model/source_preference.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/services/get_source_preference.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Safe Isar accessor
// ─────────────────────────────────────────────────────────────────────────────
//
// The global `isar` from main.dart is a `late` variable that is only assigned
// in the *main* isolate.  Extension services run inside a background isolate
// (GetIsolateService) where `late isar` has never been assigned → accessing it
// directly throws LateInitializationError and crashes every extension.
//
// Using Isar.getInstance() is safe from any isolate: it returns the already-open
// instance when available, or null if the DB has not been opened in this isolate.
// When null (background isolate), all write operations become no-ops and read
// operations return their default values so the extension can still run.

Isar? get _db => Isar.getInstance('watchtowerDb');

// ─────────────────────────────────────────────────────────────────────────────
// Write helpers
// ─────────────────────────────────────────────────────────────────────────────

void setPreferenceSetting(SourcePreference sourcePreference, Source source) {
  final db = _db;
  if (db == null) return; // no-op in isolate
  final sourcePref = db.sourcePreferences
      .filter()
      .sourceIdEqualTo(source.id)
      .keyEqualTo(sourcePreference.key)
      .findFirstSync();
  db.writeTxnSync(() {
    if (source.sourceCodeLanguage == SourceCodeLanguage.mihon &&
        source.preferenceList != null) {
      final prefs = (jsonDecode(source.preferenceList!) as List)
          .map((e) => SourcePreference.fromJson(e))
          .toList();
      final idx = prefs.indexWhere((e) => e.key == sourcePreference.key);
      if (idx != -1) {
        prefs[idx] = sourcePreference..id = null;
        db.sources.putSync(
          source
            ..preferenceList = jsonEncode(
              prefs.map((e) => e.toJson()).toList(),
            ),
        );
      }
    }
    if (sourcePref != null) {
      db.sourcePreferences.putSync(sourcePreference);
    } else {
      db.sourcePreferences.putSync(sourcePreference..sourceId = source.id);
    }
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Read helpers
// ─────────────────────────────────────────────────────────────────────────────

dynamic getPreferenceValue(int sourceId, String key) {
  final sourcePreference = getSourcePreferenceEntry(key, sourceId);

  if (sourcePreference.listPreference != null) {
    final pref = sourcePreference.listPreference!;
    return pref.entryValues![pref.valueIndex!];
  } else if (sourcePreference.checkBoxPreference != null) {
    return sourcePreference.checkBoxPreference!.value;
  } else if (sourcePreference.switchPreferenceCompat != null) {
    return sourcePreference.switchPreferenceCompat!.value;
  } else if (sourcePreference.editTextPreference != null) {
    return sourcePreference.editTextPreference!.value;
  }
  return sourcePreference.multiSelectListPreference?.values;
}

SourcePreference getSourcePreferenceEntry(String key, int sourceId) {
  final db = _db;

  // ── Isolate path: no DB → try to resolve from source.preferenceList only ──
  if (db == null) {
    // We cannot look up the source from Isar here; return an empty preference
    // so JS preferences.get() returns null rather than crashing with a
    // LateInitializationError.
    return SourcePreference()..key = key;
  }

  // ── Main-isolate path: normal DB lookup ───────────────────────────────────
  SourcePreference? sourcePreference = db.sourcePreferences
      .filter()
      .sourceIdEqualTo(sourceId)
      .keyEqualTo(key)
      .findFirstSync();

  if (sourcePreference == null) {
    final source = db.sources.getSync(sourceId);
    if (source == null) {
      return SourcePreference()..key = key;
    }
    sourcePreference = getSourcePreference(source: source).firstWhere(
      (element) => element.key == key,
      orElse: () => throw "Error when getting source preference",
    );
    setPreferenceSetting(sourcePreference, source);
  }

  return sourcePreference;
}

String getSourcePreferenceStringValue(
  int sourceId,
  String key,
  String defaultValue,
) {
  final db = _db;
  if (db == null) return defaultValue; // isolate: return default safely

  SourcePreferenceStringValue? sourcePreferenceStringValue = db
      .sourcePreferenceStringValues
      .filter()
      .sourceIdEqualTo(sourceId)
      .keyEqualTo(key)
      .findFirstSync();

  if (sourcePreferenceStringValue == null) {
    setSourcePreferenceStringValue(sourceId, key, defaultValue);
    return defaultValue;
  }

  return sourcePreferenceStringValue.value ?? "";
}

void setSourcePreferenceStringValue(int sourceId, String key, String value) {
  final db = _db;
  if (db == null) return; // no-op in isolate

  final sourcePref = db.sourcePreferenceStringValues
      .filter()
      .sourceIdEqualTo(sourceId)
      .keyEqualTo(key)
      .findFirstSync();

  db.writeTxnSync(() {
    if (sourcePref != null) {
      db.sourcePreferenceStringValues.putSync(sourcePref..value = value);
    } else {
      db.sourcePreferenceStringValues.putSync(
        SourcePreferenceStringValue()
          ..key = key
          ..sourceId = sourceId
          ..value = value,
      );
    }
  });
}
