import 'package:isar_community/isar.dart';
part 'local_file_cache.g.dart';

/// Entrée de cache par fichier — permet de ne jamais rescanner un fichier
/// dont la taille et la date de modification n'ont pas changé.
///
/// Stratégie :
///   1. Lire [filePath], [fileSize], [modifiedAt] depuis le système de fichiers.
///   2. Si une entrée existe avec les mêmes valeurs → fichier inchangé, sauter.
///   3. Sinon → analyser, écrire [LocalIndexedItem], mettre à jour ce cache.
@collection
@Name("LocalFileCache")
class LocalFileCache {
  Id id = Isar.autoIncrement;

  /// Chemin absolu du fichier.
  @Index(unique: true, caseSensitive: false)
  late String filePath;

  /// Taille en octets (signature rapide).
  late int fileSize;

  /// Date de modification du fichier en ms depuis epoch.
  late int modifiedAt;

  /// ID du [LocalIndexedItem] associé (null si analyse échouée).
  int? indexedItemId;

  /// Hash CRC32 rapide — calculé uniquement pour les fichiers < 1 Mo et
  /// en option, pour détecter des modifications sans changement de taille.
  String? quickHash;

  /// Horodatage de la dernière mise à jour du cache.
  late int cachedAt;

  /// Nombre de fois que ce fichier a été analysé (pour débogage).
  int scanCount = 0;

  LocalFileCache();

  /// Retourne `true` si la signature fichier correspond à ce cache,
  /// c'est-à-dire que le fichier n'a pas changé depuis le dernier scan.
  bool isUnchanged(int currentSize, int currentModifiedAt) {
    return fileSize == currentSize && modifiedAt == currentModifiedAt;
  }
}
