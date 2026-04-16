import 'package:watchtower/eval/lib.dart';
import 'package:watchtower/models/source.dart';

List<dynamic> getFilterList({required Source source}) {
  final service = getExtensionService(source, "");
  try {
    return service.getFilterList().filters;
  } finally {
    service.dispose();
  }
}
