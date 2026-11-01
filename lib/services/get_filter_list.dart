import 'package:watchtower/eval/lib.dart';
import 'package:watchtower/models/source.dart';

List<dynamic> getFilterList({required Source source, String? context}) {
  final service = getExtensionService(source);
  try {
    return service.getFilterList(context).filters;
  } finally {
    service.dispose();
  }
}
