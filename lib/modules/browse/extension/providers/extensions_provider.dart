import 'package:isar_community/isar.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/settings.dart';
import 'package:watchtower/models/source.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'extensions_provider.g.dart';

@riverpod
Stream<List<Source>> getExtensionsStream(Ref ref, ItemType itemType) async* {
  yield* isar.sources
      .filter()
      .idIsNotNull()
      .and()
      .group(
        (q) => q.repoIsNull().or().repo(
          (q) => q.hiddenIsNull().or().hiddenEqualTo(false),
        ),
      )
      .isActiveEqualTo(true)
      .itemTypeEqualTo(itemType)
      .watch(fireImmediately: true)
      // On the web mock, Isar filter chains are no-ops — apply them in Dart
      // so only the correct item type / active / visible sources appear.
      // On real Isar this map is a safe no-op (the DB already filtered).
      .map((sources) => sources
          .where((s) =>
              s.id != null &&
              (s.isActive ?? false) &&
              s.itemType == itemType &&
              s.isObsolete != true &&
              (s.repo == null || s.repo?.hidden != true))
          .toList());
}
