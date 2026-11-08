import 'package:watchtower/main.dart';
import 'package:watchtower/models/settings.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:watchtower/utils/constant.dart';
part 'logs_state.g.dart';

@riverpod
bool logsState(Ref ref) {
  // Matches the Settings model default (enableLogs = false). Keeping the two
  // in sync means the À propos switch, the logger's master gate and the
  // floating overlay all agree even before the first Settings record exists.
  return isar.settings.getSync(kSettingsId)?.enableLogs ?? false;
}
