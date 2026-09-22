import 'package:isar_community/isar.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/settings.dart';
import 'package:watchtower/models/source.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'extensions_provider.g.dart';

@riverpod
Stream<List<Source>> getExtensionsStream(Ref ref, ItemType itemType) async* {
  // isar_community can reject filters on nullable bool properties, including
  // bools inside embedded objects. Watch the collection without a filter and
  // apply the equivalent predicate in Dart.
  yield* isar.sources.where().watch(fireImmediately: true).map(
        (sources) => sources
            .where((s) =>
                s.id != null &&
                (s.isActive ?? false) &&
                s.itemType == itemType &&
                s.isObsolete != true &&
                (s.repo == null || s.repo?.hidden != true))
            .toList(),
      );
}
