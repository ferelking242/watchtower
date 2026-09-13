import 'package:isar_community/isar.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/source.dart';

Source? getSource(
  String lang,
  String name,
  int? sourceId, {
  bool installedOnly = false,
}) {
  try {
    // The Isar community runtime does not support every filter operation on
    // the implicit id property on every platform. Load the small source
    // collection and apply these simple predicates in Dart instead.
    final sourcesList = isar.sources
        .where()
        .findAllSync()
        .where(
          (source) =>
              !installedOnly ||
              ((source.isActive ?? false) && (source.isAdded ?? false)),
        )
        .toList();
    return sourcesList.firstWhere(
      (element) => sourceId != null
          ? element.id == sourceId && element.sourceCode != null
          : element.name!.toLowerCase() == name.toLowerCase() &&
                element.lang == lang &&
                element.sourceCode != null,
      orElse: () => throw ("Error when getting source"),
    );
  } catch (_) {
    return null;
  }
}
