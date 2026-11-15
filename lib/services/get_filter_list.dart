import 'package:watchtower/eval/lib.dart';
import 'package:watchtower/models/source.dart';

List<dynamic> getFilterList({required Source source, String? context}) {
  // Shared, cached runtime — see [ExtensionServiceRegistry.readSync]. The old
  // code built and disposed a private QuickJS runtime on every call, which is
  // what caused the native heap corruption / SIGBUS.
  return ExtensionServiceRegistry.readSync(
    source,
    (service) => service.getFilterList(context).filters,
  );
}
