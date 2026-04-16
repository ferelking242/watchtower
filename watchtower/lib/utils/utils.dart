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
    var sourcesFilter = isar.sources.filter().idIsNotNull();
    if (installedOnly) {
      sourcesFilter = sourcesFilter.isActiveEqualTo(true).isAddedEqualTo(true);
    }
    final sourcesList = sourcesFilter.findAllSync();
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
