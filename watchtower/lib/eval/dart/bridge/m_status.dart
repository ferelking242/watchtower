import 'package:d4rt/d4rt.dart';
import 'package:watchtower/models/manga.dart';

class MStatusBridge {
  final statusDefinition = BridgedEnumDefinition<Status>(
    name: 'MStatus',
    values: Status.values,
  );
  void registerBridgedEnum(D4rt interpreter) {
    interpreter.registerBridgedEnum(
      statusDefinition,
      'package:watchtower/bridge_lib.dart',
    );
  }
}
