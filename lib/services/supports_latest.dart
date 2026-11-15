import 'package:watchtower/eval/lib.dart';
import 'package:watchtower/models/source.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'supports_latest.g.dart';

@riverpod
bool supportsLatest(Ref ref, {required Source source}) {
  // Read on the shared, cached runtime (see [ExtensionServiceRegistry.readSync]).
  // Building and disposing a private QuickJS runtime per call is what caused the
  // native heap corruption / SIGBUS at launch.
  return ExtensionServiceRegistry.readSync(source, (s) => s.supportsLatest);
}
