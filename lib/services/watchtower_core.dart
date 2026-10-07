import 'package:isar_community/isar.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/services/settings_store.dart';

/// Shared startup primitives used by BOTH the graphical application and the
/// headless CLI. Keeping them here (instead of duplicating the logic in the
/// CLI) guarantees the CLI sees exactly the same database state as the app.

/// Registers the built-in `local` pseudo-sources for every supported item
/// type. Idempotent: existing rows are only repaired, never duplicated.
void ensureLocalSources({Isar? database}) {
  final db = database ?? isar;
  const itemTypes = [ItemType.manga, ItemType.anime, ItemType.novel];
  db.writeTxnSync(() {
    for (final type in itemTypes) {
      final existing = db.sources
          .filter()
          .nameEqualTo('local')
          .and()
          .langEqualTo('')
          .and()
          .itemTypeEqualTo(type)
          .findFirstSync();
      if (existing == null) {
        db.sources.putSync(
          Source()
            ..name = 'local'
            ..lang = ''
            ..isAdded = true
            ..isActive = true
            ..isPinned = false
            ..lastUsed = false
            ..itemType = type,
        );
      } else if (!(existing.isAdded ?? false) ||
          !(existing.isActive ?? false)) {
        db.sources.putSync(
          existing
            ..isAdded = true
            ..isActive = true,
        );
      }
    }
  });
}

/// Opens the Watchtower Isar database, heals a corrupt `Settings` record and
/// registers the local sources — the exact sequence the app runs at launch.
///
/// [path] overrides the default database directory (used by the CLI's
/// `--data-dir`); when null the platform default is used.
Future<Isar> openWatchtowerDatabase(dynamic storage, {String? path}) async {
  final database = await storage.initDB(path, inspector: false);
  isar = database;
  healSettingsRecord(isar: database);
  ensureLocalSources(database: database);
  return database;
}
