library permission_handler;

enum PermissionStatus {
  denied,
  granted,
  restricted,
  limited,
  permanentlyDenied,
  provisional,
}

extension PermissionStatusCheck on PermissionStatus {
  bool get isGranted => this == PermissionStatus.granted;
  bool get isDenied => this == PermissionStatus.denied;
  bool get isPermanentlyDenied => this == PermissionStatus.permanentlyDenied;
  bool get isRestricted => this == PermissionStatus.restricted;
  bool get isLimited => this == PermissionStatus.limited;
  bool get isProvisional => this == PermissionStatus.provisional;
}

class Permission {
  final String _name;
  const Permission._(this._name);

  static const Permission notification = Permission._('notification');
  static const Permission storage = Permission._('storage');
  static const Permission manageExternalStorage = Permission._('manageExternalStorage');
  static const Permission requestInstallPackages = Permission._('requestInstallPackages');
  static const Permission microphone = Permission._('microphone');
  static const Permission camera = Permission._('camera');
  static const Permission location = Permission._('location');
  static const Permission phone = Permission._('phone');
  static const Permission contacts = Permission._('contacts');
  static const Permission calendar = Permission._('calendar');
  static const Permission photos = Permission._('photos');
  static const Permission mediaLibrary = Permission._('mediaLibrary');
  static const Permission bluetooth = Permission._('bluetooth');
  static const Permission bluetoothScan = Permission._('bluetoothScan');
  static const Permission bluetoothConnect = Permission._('bluetoothConnect');
  static const Permission scheduleExactAlarm = Permission._('scheduleExactAlarm');
  static const Permission accessMediaLocation = Permission._('accessMediaLocation');
  static const Permission activityRecognition = Permission._('activityRecognition');
  static const Permission audio = Permission._('audio');
  static const Permission calendarFullAccess = Permission._('calendarFullAccess');
  static const Permission calendarWriteOnly = Permission._('calendarWriteOnly');
  static const Permission ignoreBatteryOptimizations = Permission._('ignoreBatteryOptimizations');
  static const Permission locationAlways = Permission._('locationAlways');
  static const Permission locationWhenInUse = Permission._('locationWhenInUse');
  static const Permission manageExternalStorageWithoutCache = Permission._('manageExternalStorageWithoutCache');
  static const Permission nearbyWifiDevices = Permission._('nearbyWifiDevices');
  static const Permission systemAlertWindow = Permission._('systemAlertWindow');
  static const Permission videos = Permission._('videos');

  // These return PermissionStatus (not Future) so the caller can use
  // `await permission.request().isGranted` — since awaiting a non-Future
  // just yields the value, this also works with `(await permission.request()).isGranted`.
  PermissionStatus get status => PermissionStatus.granted;
  bool get isGranted => true;
  bool get isDenied => false;
  bool get isPermanentlyDenied => false;
  PermissionStatus request() => PermissionStatus.granted;
}

Future<Map<Permission, PermissionStatus>> requestList(
    List<Permission> permissions) async =>
    {for (final p in permissions) p: PermissionStatus.granted};

Future<void> openAppSettings() async {}
