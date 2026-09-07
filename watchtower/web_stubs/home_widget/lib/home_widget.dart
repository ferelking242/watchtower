class HomeWidget {
    static Future<void> setAppGroupId(String id) async {}
    static Future<void> registerBackgroundCallback(Function cb) async {}
    static Future<bool?> saveWidgetData<T>(String key, T? value) async => true;
    static Future<bool?> updateWidget({String? name, String? iOSName, String? androidName, String? qualifiedAndroidName}) async => true;
    static Future<List<Uri?>?> getInstalledWidgets() async => [];
    static Future<dynamic> getWidgetData<T>(String key, {T? defaultValue}) async => defaultValue;
  }
  