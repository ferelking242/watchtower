import 'package:watchtower/eval/lib.dart';
import 'package:watchtower/models/source.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'supports_latest.g.dart';

@riverpod
bool supportsLatest(Ref ref, {required Source source}) {
  final service = getExtensionService(source);
  try {
    return service.supportsLatest;
  } finally {
    service.dispose();
  }
}
