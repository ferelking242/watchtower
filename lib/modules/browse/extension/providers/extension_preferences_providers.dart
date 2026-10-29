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

/// Values handed to an extension worker.
///
/// Workers never open Isar (the root isolate owns the only handle), so a
/// `SharedPreferences.get()` call used to always return null there: a source
/// setting such as the site language silently never applied. The root isolate
/// exports the stored values with the request and the worker reads this map.
Map<String, dynamic>? _preferenceSnapshot;

void installPreferenceSnapshot(Object? raw) {
  if (raw is Map) {
    _preferenceSnapshot = raw.map(
      (key, value) => MapEntry(key.toString(), value),
    );
  } else {
    _preferenceSnapshot = null;
  }
}

/// Snapshot of the stored preferences of one source, ready to be sent to a
/// worker isolate.
Map<String, dynamic> exportPreferenceSnapshot(int? sourceId) {
  final db = _db;
  if (db == null || sourceId == null) return const {};
  final result = <String, dynamic>{};
  final stored = db.sourcePreferences
      .filter()
      .sourceIdEqualTo(sourceId)
      .findAllSync();
  for (final preference in stored) {
    final key = preference.key;
    if (key == null) continue;
    result[key] = _resolvedValue(preference);
  }
  return result;
}

dynamic _resolvedValue(SourcePreference preference) {
  final list = preference.listPreference;
  if (list != null) {
    final values = list.entryValues ?? const <String>[];
    if (values.isEmpty) return null;
    final raw = list.valueIndex ?? 0;
    final index = raw < 0
        ? 0
        : (raw >= values.length ? values.length - 1 : raw);
    return values[index];
  }
  final checkBox = preference.checkBoxPreference;
  if (checkBox != null) return checkBox.value;
  final switchPreference = preference.switchPreferenceCompat;
  if (switchPreference != null) return switchPreference.value;
  final editText = preference.editTextPreference;
  if (editText != null) return editText.value;
  return preference.multiSelectListPreference?.values;
}

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
  // Worker isolate: no Isar, so answer from the snapshot sent by the root
  // isolate. Without it every `SharedPreferences.get()` returned null and a
  // user-chosen setting (site language, image server, …) was ignored.
  if (_db == null) {
    final snapshot = _preferenceSnapshot;
    return snapshot == null ? null : snapshot[key];
  }
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

  // ── Isolate path: no DB → return an empty preference safely ──────────────
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
      // Return an empty preference instead of throwing — a missing key is
      // normal when a JS extension is first installed and has not set any
      // preferences yet.  Throwing here crashed every extension cold-start.
      orElse: () => SourcePreference()..key = key,
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
