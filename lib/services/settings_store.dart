import 'package:isar_community/isar.dart';
import 'package:watchtower/models/settings.dart';
import 'package:watchtower/utils/constant.dart';
import 'package:watchtower/utils/log/logger.dart';

/// Lecture sûre et auto-réparante de l'enregistrement `Settings`.
///
/// ── Pourquoi ce fichier existe ────────────────────────────────────────────
/// `isar.settings.getSync(kSettingsId)` désérialise TOUTES les propriétés du
/// record en une fois, y compris le cache de pages embarqué
/// (`Settings.chapterPageUrlsList`). Ce désérialiseur (isar_community 3.3.2,
/// `IsarReaderImpl.readDynamicList` / `readObjectList`) lit des préfixes de
/// taille uint24 stockés dans le record et crée
/// `Uint8List.sublistView(_buffer, startOffset, endOffset)` : si les tailles
/// déclarées dépassent les octets réellement présents (écriture interrompue,
/// process tué en plein `writeTxnSync`, dérive de schéma), Dart lève
///
///   RangeError (length): Invalid value: Not in inclusive range 0..58: 62
///
/// L'exception sort de `getSync` AVANT que le moindre code Dart applicatif ne
/// touche aux listes `urls`/`headers` — c'est pourquoi les gardes
/// post-désérialisation (`decodeCachedPageUrls`) ne pouvaient pas suffire.
///
/// Tant que le record corrompu n'est pas réécrit, TOUTES les lectures de
/// settings de l'app lèvent la même exception. Cette bibliothèque fournit
/// l'unique point de lecture qui (1) survit à l'erreur, (2) répare le record
/// en le réécrivant avec les valeurs par défaut, (3) journalise la réparation
/// (aucune corruption masquée silencieusement).

/// Signature d'une lecture bas niveau de l'enregistrement `Settings`.
typedef SettingsReader = Settings? Function();

/// Signature de la réparation (suppression + réécriture du record).
typedef SettingsRepairer = void Function();

/// Callback de diagnostic : appelé quand un record illisible est détecté.
typedef SettingsCorruptionReporter = void Function(Object error);

/// Lit l'enregistrement `Settings` sans jamais laisser une corruption
/// remonter, et répare le record illisible.
///
/// Réparation destructive (réécriture avec les défauts) réservée aux
/// signatures de corruption de DONNÉES :
/// - `RangeError` : le crash historique (préfixes de taille > octets
///   disponibles lors de `Uint8List.sublistView`) ;
/// - `FormatException` : octets UTF-8 malformés dans le record ;
/// - `TypeError` / `ArgumentError` : dérive de schéma / bornes incohérentes.
///
/// Les erreurs potentiellement transitoires (`IsarError`, `StateError`,
/// ex. lecture concurrente d'une transaction) retombent sur les défauts SANS
/// réécrire le record, pour ne jamais détruire des réglages valides.
/// Toute autre exception est relancée.
///
/// [read] et [repair] sont injectables pour les tests ; en production,
/// utiliser [readSettingsSafely].
Settings readSettingsSafelyWith({
  required SettingsReader read,
  required SettingsRepairer repair,
  SettingsCorruptionReporter? onCorrupt,
  bool repairOnCorrupt = true,
}) {
  try {
    return read() ?? Settings();
  } on RangeError catch (e) {
    return _handleCorruption(e, null, read, repair, onCorrupt, repairOnCorrupt);
  } on FormatException catch (e) {
    return _handleCorruption(e, null, read, repair, onCorrupt, repairOnCorrupt);
  } on TypeError catch (e) {
    return _handleCorruption(e, null, read, repair, onCorrupt, repairOnCorrupt);
  } on ArgumentError catch (e) {
    return _handleCorruption(e, null, read, repair, onCorrupt, repairOnCorrupt);
  } on IsarError catch (e) {
    return _handleCorruption(
      e,
      null,
      read,
      repair,
      onCorrupt,
      false, // erreur potentiellement transitoire → pas d'écrasement du record
    );
  } on StateError catch (e) {
    return _handleCorruption(
      e,
      null,
      read,
      repair,
      onCorrupt,
      false, // erreur potentiellement transitoire → pas d'écrasement du record
    );
  }
}

Settings _handleCorruption(
  Object error,
  StackTrace? stackTrace,
  SettingsReader read,
  SettingsRepairer repair,
  SettingsCorruptionReporter? onCorrupt,
  bool repairOnCorrupt,
) {
  onCorrupt?.call(error);
  AppLogger.log(
    'Enregistrement Settings illisible (désérialisation Isar corrompue) — '
    'réparation ${repairOnCorrupt ? 'avec réécriture des défauts' : 'désactivée'}',
    logLevel: LogLevel.error,
    error: error,
    stackTrace: stackTrace,
  );
  if (!repairOnCorrupt) return Settings();
  try {
    repair();
    // Relit le record réparé pour renvoyer l'instance réellement persistée.
    return read() ?? Settings();
  } catch (e, st) {
    // La réparation elle-même a échoué : on ne plante pas l'app pour ça.
    AppLogger.log(
      'Échec de la réparation de l\'enregistrement Settings — valeurs par '
      'défaut renvoyées pour cette lecture',
      logLevel: LogLevel.error,
      error: e,
      stackTrace: st,
    );
    return Settings();
  }
}

/// Variante production : lit/répare le record `Settings` d'une instance Isar.
Settings readSettingsSafely({required Isar isar, bool repairOnCorrupt = true}) {
  return readSettingsSafelyWith(
    read: () => isar.settings.getSync(kSettingsId),
    repair: () {
      isar.writeTxnSync(() {
        isar.settings.deleteSync(kSettingsId);
        isar.settings.putSync(Settings()..id = kSettingsId);
      });
    },
    repairOnCorrupt: repairOnCorrupt,
  );
}

/// Auto-réparation au démarrage : force une lecture + réparation du record
/// `Settings` AVANT que le moindre écran / scheduler ne le lise.
///
/// Ne lève jamais : toute erreur (y compris pendant la réparation) est
/// journalisée et ignorée pour ne pas retarder le lancement de l'app.
void healSettingsRecord({required Isar isar}) {
  try {
    readSettingsSafely(isar: isar);
  } catch (e, st) {
    AppLogger.log(
      'healSettingsRecord: erreur inattendue pendant la vérification du '
      'record Settings (ignorée, l\'app continue)',
      logLevel: LogLevel.error,
      error: e,
      stackTrace: st,
    );
  }
}
