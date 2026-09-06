library permission_handler;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// ─── MethodChannel (same as PermissionHandlerPlugin on Android) ───────────────
const _kChannel = MethodChannel('flutter.baseflow.com/permissions/methods');

// ─── Permission integer codes — must match permission_handler_android v12 ─────
// Source: permission_handler/lib/permission_handler.dart Permission.byValue(n)
const _kCalendar              = 0;
const _kCamera                = 1;
const _kContacts              = 2;
const _kLocation              = 3;
const _kLocationAlways        = 4;
const _kLocationWhenInUse     = 5;
const _kMediaLibrary          = 6;
const _kMicrophone            = 7;
const _kPhone                 = 8;
const _kPhotos                = 9;
const _kStorage               = 14;
const _kIgnoreBattery         = 15;
const _kNotification          = 16;
const _kAccessMediaLocation   = 17;
const _kActivityRecognition   = 18;
const _kBluetooth             = 20;
const _kManageExternalStorage = 21;
const _kSystemAlertWindow     = 22;
const _kInstallPackages       = 23;
const _kBluetoothScan         = 26;
const _kBluetoothAdvertise    = 27;
const _kBluetoothConnect      = 28;
const _kNearbyWifi            = 29;
const _kVideos                = 30;
const _kAudio                 = 31;
const _kScheduleExactAlarm    = 32;

// ─── PermissionStatus ─────────────────────────────────────────────────────────
enum PermissionStatus {
  denied,            // 0
  granted,           // 1
  restricted,        // 2
  limited,           // 3
  permanentlyDenied, // 4
  provisional,       // 5
}

extension PermissionStatusCheck on PermissionStatus {
  bool get isGranted           => this == PermissionStatus.granted;
  bool get isDenied            => this == PermissionStatus.denied;
  bool get isPermanentlyDenied => this == PermissionStatus.permanentlyDenied;
  bool get isRestricted        => this == PermissionStatus.restricted;
  bool get isLimited           => this == PermissionStatus.limited;
  bool get isProvisional       => this == PermissionStatus.provisional;
}

// ─── Future<PermissionStatus> convenience extensions ─────────────────────────
extension FuturePermissionStatusGetters on Future<PermissionStatus> {
  Future<bool> get isGranted           => then((s) => s.isGranted);
  Future<bool> get isDenied            => then((s) => s.isDenied);
  Future<bool> get isPermanentlyDenied => then((s) => s.isPermanentlyDenied);
}

// ─── Internal code → PermissionStatus ────────────────────────────────────────
PermissionStatus _fromCode(int? code) {
  switch (code) {
    case 1:  return PermissionStatus.granted;
    case 2:  return PermissionStatus.restricted;
    case 3:  return PermissionStatus.limited;
    case 4:  return PermissionStatus.permanentlyDenied;
    case 5:  return PermissionStatus.provisional;
    default: return PermissionStatus.denied;
  }
}

// ─── Permission ───────────────────────────────────────────────────────────────
class Permission {
  final int _code;
  const Permission._(this._code);

  static const Permission calendar                      = Permission._(_kCalendar);
  static const Permission camera                        = Permission._(_kCamera);
  static const Permission contacts                      = Permission._(_kContacts);
  static const Permission location                      = Permission._(_kLocation);
  static const Permission locationAlways                = Permission._(_kLocationAlways);
  static const Permission locationWhenInUse             = Permission._(_kLocationWhenInUse);
  static const Permission mediaLibrary                  = Permission._(_kMediaLibrary);
  static const Permission microphone                    = Permission._(_kMicrophone);
  static const Permission phone                         = Permission._(_kPhone);
  static const Permission photos                        = Permission._(_kPhotos);
  static const Permission storage                       = Permission._(_kStorage);
  static const Permission ignoreBatteryOptimizations    = Permission._(_kIgnoreBattery);
  static const Permission notification                  = Permission._(_kNotification);
  static const Permission accessMediaLocation           = Permission._(_kAccessMediaLocation);
  static const Permission activityRecognition           = Permission._(_kActivityRecognition);
  static const Permission bluetooth                     = Permission._(_kBluetooth);
  static const Permission manageExternalStorage         = Permission._(_kManageExternalStorage);
  static const Permission manageExternalStorageWithoutCache = Permission._(_kManageExternalStorage);
  static const Permission systemAlertWindow             = Permission._(_kSystemAlertWindow);
  static const Permission requestInstallPackages        = Permission._(_kInstallPackages);
  static const Permission bluetoothScan                 = Permission._(_kBluetoothScan);
  static const Permission bluetoothAdvertise            = Permission._(_kBluetoothAdvertise);
  static const Permission bluetoothConnect              = Permission._(_kBluetoothConnect);
  static const Permission nearbyWifiDevices             = Permission._(_kNearbyWifi);
  static const Permission videos                        = Permission._(_kVideos);
  static const Permission audio                         = Permission._(_kAudio);
  static const Permission scheduleExactAlarm            = Permission._(_kScheduleExactAlarm);
  static const Permission calendarFullAccess            = Permission._(_kCalendar);
  static const Permission calendarWriteOnly             = Permission._(_kCalendar);

  // ── status / isGranted / isDenied ──────────────────────────────────────────
  //
  // On web  : always granted — browser has no concept of these OS permissions.
  // On native: real check via PermissionHandlerPlugin MethodChannel.
  Future<PermissionStatus> get status async {
    if (kIsWeb) return PermissionStatus.granted;
    return _checkStatus();
  }

  Future<bool> get isGranted           async => (await status).isGranted;
  Future<bool> get isDenied            async => (await status).isDenied;
  Future<bool> get isPermanentlyDenied async => (await status).isPermanentlyDenied;

  // ── request ────────────────────────────────────────────────────────────────
  //
  // On web  : instant granted.
  // On native: real OS dialog (or Settings intent for special permissions like
  //            MANAGE_EXTERNAL_STORAGE).  Returns the resulting status.
  Future<PermissionStatus> request() async {
    if (kIsWeb) return PermissionStatus.granted;
    return _request();
  }

  // ── Internal: MethodChannel helpers ────────────────────────────────────────

  Future<PermissionStatus> _checkStatus() async {
    try {
      // The permission_handler_android v12 MethodChannel expects a bare int
      // as the argument — NOT a map like {'permission': code}.
      final int? result = await _kChannel.invokeMethod<int>(
        'checkPermissionStatus',
        _code,
      );
      return _fromCode(result);
    } catch (e) {
      debugPrint('[permission_handler] checkPermissionStatus($_code) error: $e');
      return PermissionStatus.denied;
    }
  }

  Future<PermissionStatus> _request() async {
    try {
      // The permission_handler_android v12 MethodChannel expects a bare
      // List<int> as the argument — NOT a map like {'permissions': [code]}.
      final Map<dynamic, dynamic>? result =
          await _kChannel.invokeMethod<Map<dynamic, dynamic>>(
        'requestPermissions',
        <int>[_code],
      );
      return _fromCode(result?[_code] as int?);
    } catch (e) {
      debugPrint('[permission_handler] requestPermissions($_code) error: $e');
      return PermissionStatus.denied;
    }
  }
}

// ─── requestList helper ───────────────────────────────────────────────────────
Future<Map<Permission, PermissionStatus>> requestList(
    List<Permission> permissions) async {
  if (kIsWeb) {
    return {for (final p in permissions) p: PermissionStatus.granted};
  }
  try {
    final codes = permissions.map((p) => p._code).toList();
    // Bare List<int> — NOT a map like {'permissions': codes}.
    final Map<dynamic, dynamic>? result =
        await _kChannel.invokeMethod<Map<dynamic, dynamic>>(
      'requestPermissions',
      codes,
    );
    return {
      for (final p in permissions)
        p: _fromCode(result?[p._code] as int?),
    };
  } catch (e) {
    debugPrint('[permission_handler] requestList error: $e');
    return {for (final p in permissions) p: PermissionStatus.denied};
  }
}

// ─── openAppSettings ─────────────────────────────────────────────────────────
Future<void> openAppSettings() async {
  if (kIsWeb) return;
  try {
    await _kChannel.invokeMethod<bool>('openAppSettings');
  } catch (e) {
    debugPrint('[permission_handler] openAppSettings error: $e');
  }
}
