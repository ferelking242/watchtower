import 'package:watchtower/eval/lib.dart';
import 'package:watchtower/models/source.dart';

List<Map<String, dynamic>> getCustomLists({required Source source}) {
  final service = getExtensionService(source, "");
  try {
    return service.getCustomLists();
  } catch (_) {
    return [];
  } finally {
    service.dispose();
  }
}
