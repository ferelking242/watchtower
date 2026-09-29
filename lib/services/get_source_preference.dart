import 'package:watchtower/eval/lib.dart';
import 'package:watchtower/eval/model/source_preference.dart';
import 'package:watchtower/models/source.dart';

List<SourcePreference> getSourcePreference({required Source source}) {
  final service = getExtensionService(source, "");
  try {
    return service.getSourcePreferences();
  } finally {
    service.dispose();
  }
}
