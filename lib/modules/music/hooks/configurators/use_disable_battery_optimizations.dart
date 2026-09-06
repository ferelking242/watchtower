import 'package:disable_battery_optimization/disable_battery_optimization.dart';

import 'package:watchtower/modules/music/hooks/utils/use_async_effect.dart';
import 'package:watchtower/modules/music/services/kv_store/kv_store.dart';
import 'package:watchtower/modules/music/utils/platform.dart';

void useDisableBatteryOptimizations() {
  useAsyncEffect(() async {
    if (!kIsAndroid || KVStoreService.askedForBatteryOptimization) return;

    await DisableBatteryOptimization.showDisableBatteryOptimizationSettings();

    await DisableBatteryOptimization
        .showDisableManufacturerBatteryOptimizationSettings(
      "Your device has additional battery optimization",
      "Follow the steps and disable the optimizations to allow smooth functioning of this app",
    );

    await KVStoreService.setAskedForBatteryOptimization(true);
  }, null, []);
}
