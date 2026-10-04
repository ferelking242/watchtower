import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:watchtower/models/settings.dart';
import 'package:watchtower/services/settings_store.dart';
import 'package:watchtower/utils/constant.dart';
import 'package:watchtower/utils/mock_isar.dart';

/// Régression du crash APK :
/// `RangeError (length): Invalid value: Not in inclusive range 0..58: 62`
///
/// Mécanisme réel (confirmé dans isar_community 3.3.2,
/// `IsarReaderImpl.readObjectList`) : la désérialisation du record `Settings`
/// lit des préfixes de taille uint24 et construit
/// `Uint8List.sublistView(_buffer, startOffset, endOffset)` ; quand un
/// préfixe (62) dépasse les octets disponibles (59), Dart lève
/// `RangeError.range(62, 0, 58, 'length')` — exactement le message du
/// rapport. L'exception sort de `isar.settings.getSync()` AVANT tout code
/// applicatif ; le seul correctif robuste est de survivre à la lecture et de
/// RÉPARER le record (cf. `services/settings_store.dart`).
///
/// Ces tests passent par le même chemin de code que l'app :
/// `readSettingsSafely(isar: isar)` avec un Isar mocké.
void main() {
  // ── Logique pure (injection read/repair) ────────────────────────────────

  group('readSettingsSafelyWith', () {
    test('lecture saine → objet renvoyé tel quel, pas de réparation', () {
      final healthy = Settings()..id = kSettingsId;
      var repairs = 0;
      final result = readSettingsSafelyWith(
        read: () => healthy,
        repair: () => repairs++,
      );
      expect(identical(result, healthy), isTrue);
      expect(repairs, 0);
    });

    test('lecture null (record absent) → défauts, pas de réparation', () {
      var repairs = 0;
      final result = readSettingsSafelyWith(
        read: () => null,
        repair: () => repairs++,
      );
      expect(result, isA<Settings>());
      expect(repairs, 0);
    });

    test('RangeError (le crash historique) → réparation + relecture', () {
      final healed = Settings()..id = kSettingsId;
      var reads = 0;
      var repairs = 0;
      Object? reported;
      final result = readSettingsSafelyWith(
        read: () {
          reads++;
          if (reads == 1) {
            // Même signature que la production :
            // RangeError (length): Invalid value: Not in inclusive range 0..58: 62
            throw RangeError.range(62, 0, 58, 'length');
          }
          return healed;
        },
        repair: () => repairs++,
        onCorrupt: (e) => reported = e,
      );
      expect(identical(result, healed), isTrue);
      expect(repairs, 1);
      expect(reported, isA<RangeError>());
    });

    test('FormatException (octets UTF-8 malformés) → réparation', () {
      var repairs = 0;
      readSettingsSafelyWith(
        read: () => throw const FormatException('unexpected end of input'),
        repair: () => repairs++,
      );
      expect(repairs, 1);
    });

    test('réparation elle-même en échec → défauts, pas de crash', () {
      final result = readSettingsSafelyWith(
        read: () => throw RangeError.range(62, 0, 58, 'length'),
        repair: () => throw StateError('disk full'),
      );
      expect(result, isA<Settings>());
    });

    test('IsarError (erreur potentiellement transitoire) → défauts SANS écraser le record', () {
      var repairs = 0;
      final result = readSettingsSafelyWith(
        read: () => throw _TransientIsarError(),
        repair: () => repairs++,
      );
      expect(result, isA<Settings>());
      expect(repairs, 0);
    });

    test('repairOnCorrupt=false → défauts sans toucher au record', () {
      var repairs = 0;
      final result = readSettingsSafelyWith(
        read: () => throw RangeError.range(62, 0, 58, 'length'),
        repair: () => repairs++,
        repairOnCorrupt: false,
      );
      expect(result, isA<Settings>());
      expect(repairs, 0);
    });

    test('erreur non liée à la corruption → relancée (pas de masquage)', () {
      expect(
        () => readSettingsSafelyWith(
          read: () => throw UnsupportedError('bug applicatif'),
          repair: () {},
        ),
        throwsUnsupportedError,
      );
    });
  });

  // ── Chemin réel : Isar mocké (même code que l'app) ──────────────────────

  group('readSettingsSafely (MockIsar)', () {
    test('record sain → renvoyé', () {
      final isar = MockIsar();
      final seeded = Settings()..id = kSettingsId;
      isar.seed<Settings>(kSettingsId, seeded);
      final result = readSettingsSafely(isar: isar);
      expect(identical(result, seeded), isTrue);
    });

    test('record corrompu → réparé (réécrit) puis lisible', () {
      final isar = _CorruptOnceIsar();
      // Chemin EXACT de l'app : readSettingsSafely(isar:) avec sa réparation
      // intégrée (deleteSync + putSync d'un record par défaut).
      final result = readSettingsSafely(isar: isar);
      expect(result, isA<Settings>());
      // getSync #1 : échec → réparation → getSync #2 : record réparé lu.
      expect(isar.settingsCollection.getSyncCalls, 2);
      expect(isar.settings.getSync(kSettingsId), isA<Settings>());
    });

    test('healSettingsRecord ne lève jamais, même en corruption persistante', () {
      final isar = _AlwaysCorruptIsar();
      expect(() => healSettingsRecord(isar: isar), returnsNormally);
    });
  });
}

/// Isar mocké dont la collection `Settings` lève le crash de production à la
/// première lecture (record corrompu), puis se comporte normalement.
class _CorruptOnceIsar extends MockIsar {
  late final _CorruptOnceSettingsCollection settingsCollection =
      _CorruptOnceSettingsCollection(this);

  @override
  IsarCollection<T> collection<T>() {
    if (T == Settings) return settingsCollection as IsarCollection<T>;
    return super.collection<T>();
  }
}

class _CorruptOnceSettingsCollection extends MockIsarCollection<Settings> {
  _CorruptOnceSettingsCollection(MockIsar isar) : super(isar);

  int getSyncCalls = 0;

  @override
  Settings? getSync(int id) {
    getSyncCalls++;
    if (getSyncCalls == 1) {
      throw RangeError.range(62, 0, 58, 'length');
    }
    return super.getSync(id);
  }
}

/// Isar mocké où le record reste corrompu (la réparation ne suffit pas) :
/// `healSettingsRecord` doit absorber l'erreur et laisser l'app démarrer.
class _AlwaysCorruptIsar extends MockIsar {
  late final _AlwaysCorruptSettingsCollection settingsCollection =
      _AlwaysCorruptSettingsCollection(this);

  @override
  IsarCollection<T> collection<T>() {
    if (T == Settings) return settingsCollection as IsarCollection<T>;
    return super.collection<T>();
  }
}

class _AlwaysCorruptSettingsCollection extends MockIsarCollection<Settings> {
  _AlwaysCorruptSettingsCollection(MockIsar isar) : super(isar);

  @override
  Settings? getSync(int id) {
    throw RangeError.range(62, 0, 58, 'length');
  }
}

/// IsarError factice (erreur potentiellement transitoire) — évite
/// d'invoquer le constructeur @protected hors de la bibliothèque isar.
class _TransientIsarError extends IsarError {
  _TransientIsarError() : super('Cannot perform IO while a transaction is open');
}
