import 'package:watchtower/eval/lib.dart';
import 'package:watchtower/models/source.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'get_source_baseurl.g.dart';

@riverpod
String sourceBaseUrl(Ref ref, {required Source source}) {
  // Shared, cached runtime — see [ExtensionServiceRegistry.readSync].
  return ExtensionServiceRegistry.readSync(source, (s) => s.sourceBaseUrl);
}
