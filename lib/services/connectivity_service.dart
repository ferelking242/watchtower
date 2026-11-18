import 'dart:async';
import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:watchtower/utils/log/logger.dart';

/// Marker error for a request the app refused to send because it is offline.
///
/// Its `toString` reads as an ordinary network failure so the shared
/// `isOfflineContentError` helper recognises it and the UI shows the "no
/// connection" surface instead of a bug-looking trace.
class OfflineRequestError implements Exception {
  const OfflineRequestError();

  @override
  String toString() =>
      'SocketException: Failed host lookup (no Internet connection)';
}

/// App-wide answer to "is there Internet right now?".
///
/// One listener for the whole app, so screens, downloads and background
/// workers never each poll the network on their own:
///
///  * the OS connectivity stream is the primary signal — it is push-based and
///    costs nothing, and a `none` result is trusted immediately;
///  * a result that reports *some* link (Wi-Fi, mobile, VPN) is only a hint: a
///    captive portal or a dead router still has a link, so a short DNS probe
///    confirms real reachability before the app goes back online;
///  * while offline a low-frequency probe (30 s) retries, but only while the
///    app is in the foreground, so a backgrounded app never wakes the radio.
///
/// [isOnline] starts optimistic (`true`) so the very first frame is never
/// blocked; [start] runs an immediate check that corrects it.
class ConnectivityService with WidgetsBindingObserver {
  ConnectivityService._();

  static final ConnectivityService instance = ConnectivityService._();

  /// Current reachability. Listen to it with a `ValueListenableBuilder`.
  final ValueNotifier<bool> isOnline = ValueNotifier<bool>(true);

  /// Emits only on a real change of [isOnline], so callers can pause or resume
  /// work exactly once per transition.
  final StreamController<bool> _changes =
      StreamController<bool>.broadcast(sync: true);

  Stream<bool> get onChanged => _changes.stream;

  bool get isOffline => !isOnline.value;

  /// Hosts probed to confirm reachability. Several independent resolvers so a
  /// single blocked domain (or a region that blocks one of them) does not read
  /// as "offline".
  static const _probeHosts = <String>[
    'one.one.one.one',
    'dns.google',
    'cloudflare.com',
  ];
  static const _probeTimeout = Duration(seconds: 4);

  /// Retry cadence while offline. Only runs in the foreground.
  static const _offlineRetryInterval = Duration(seconds: 30);

  Connectivity? _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _retryTimer;
  bool _started = false;
  bool _probing = false;
  bool _hasLink = true;

  /// Starts listening. Safe to call more than once.
  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);

    _connectivity = Connectivity();
    _subscription = _connectivity!.onConnectivityChanged.listen(
      _handleResults,
      onError: (Object error, StackTrace stack) {
        AppLogger.log(
          'connectivity stream error: $error',
          logLevel: LogLevel.warning,
          tag: LogTag.network,
        );
      },
    );

    // The stream only fires on change, so read the current state once.
    unawaited(refresh());
  }

  /// Re-reads connectivity and, if needed, probes for real reachability.
  Future<void> refresh() async {
    List<ConnectivityResult> results;
    try {
      results = await (_connectivity ??= Connectivity()).checkConnectivity();
    } catch (error) {
      AppLogger.log(
        'connectivity check failed: $error',
        logLevel: LogLevel.warning,
        tag: LogTag.network,
      );
      // A failed check is not proof of being offline; leave the last value.
      return;
    }
    await _handleResults(results);
  }

  Future<void> _handleResults(List<ConnectivityResult> results) async {
    final hasLink = results.any((r) => r != ConnectivityResult.none);
    _hasLink = hasLink;
    if (!hasLink) {
      // No link at all: offline with no network round-trip needed.
      _setOnline(false);
      return;
    }
    if (kIsWeb) {
      // The browser has no dart:io DNS; the connectivity signal is all we get.
      _setOnline(true);
      return;
    }
    await _probe();
  }

  /// Confirms reachability with a cheap DNS lookup. Guarded so overlapping
  /// probes (a burst of connectivity events) collapse into one.
  Future<void> _probe() async {
    if (_probing) return;
    _probing = true;
    try {
      final reachable = await _anyHostReachable();
      _setOnline(reachable);
    } finally {
      _probing = false;
    }
  }

  Future<bool> _anyHostReachable() async {
    final probes = _probeHosts.map(_canResolve);
    try {
      return await Future.any(probes).timeout(
        _probeTimeout,
        onTimeout: () => false,
      );
    } catch (_) {
      return false;
    }
  }

  Future<bool> _canResolve(String host) async {
    try {
      final addresses = await InternetAddress.lookup(host);
      return addresses.isNotEmpty && addresses.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  void _setOnline(bool value) {
    if (isOnline.value == value) {
      _syncRetryTimer();
      return;
    }
    isOnline.value = value;
    _changes.add(value);
    AppLogger.log(
      value ? 'connectivity restored' : 'connectivity lost',
      logLevel: LogLevel.info,
      tag: LogTag.network,
    );
    _syncRetryTimer();
  }

  void _syncRetryTimer() {
    if (isOnline.value || !_hasLink) {
      // Online: nothing to retry. No link: the OS stream will wake us when a
      // network appears, so there is no point polling either.
      _retryTimer?.cancel();
      _retryTimer = null;
      return;
    }
    _retryTimer ??= Timer.periodic(_offlineRetryInterval, (_) {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        unawaited(refresh());
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(refresh());
  }

  @visibleForTesting
  void dispose() {
    _subscription?.cancel();
    _retryTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _started = false;
  }
}
