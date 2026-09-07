import 'package:watchtower/main.dart';
import 'package:watchtower/models/settings.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:watchtower/utils/constant.dart';
part 'logs_state.g.dart';

@riverpod
bool logsState(Ref ref) {
  return isar.settings.getSync(kSettingsId)?.enableLogs ?? true;
}
