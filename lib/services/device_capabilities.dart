import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

/// Detects real device hardware (RAM, storage) at startup and applies
/// adaptive parameters so low-RAM phones are protected from OOM kills
/// while powerful phones are not penalised with tiny caches.
///
/// Call [DeviceCapabilities.initialize] once, right after
/// [WidgetsFlutterBinding.ensureInitialized], before any other init.
class DeviceCapabilities {
  DeviceCapabilities._();

  static int _physicalMemoryMB = 0;
  static bool _initialized = false;

  // ── Public API ─────────────────────────────────────────────────────────

  static int get physicalMemoryMB => _physicalMemoryMB;

  /// low  = < 3 GB  (e.g. iPhone 7/8, SE, budget Android)
  /// mid  = 3–5 GB  (iPhone 11/12 mini, mid-range Android)
  /// high = > 5 GB  (iPhone 14+, flagship Android)
  static String get ramTier {
    if (_physicalMemoryMB <= 0) return 'mid';
    if (_physicalMemoryMB < 3000) return 'low';
    if (_physicalMemoryMB < 5500) return 'mid';
    return 'high';
  }

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        final mb = await _fetchPhysicalMemoryMB();
        if (mb != null && mb > 0) _physicalMemoryMB = mb;
      }
    } catch (_) {}
    _applyAdaptiveImageCache();
  }

  /// Call this from a [WidgetsBindingObserver.didHaveMemoryPressure] override
  /// (Flutter invokes it on iOS didReceiveMemoryWarning and Android onLowMemory).
  static void onLowMemory() {
    final cache = PaintingBinding.instance.imageCache;
    cache.clear();
    cache.clearLiveImages();
  }

  // ── Internal ───────────────────────────────────────────────────────────

  static Future<int?> _fetchPhysicalMemoryMB() async {
    try {
      if (Platform.isIOS) {
        // Routed through the existing binary_utils channel in AppDelegate.swift
        return await const MethodChannel('com.watchtower.app.binary_utils')
            .invokeMethod<int>('getPhysicalMemoryMB');
      }
      if (Platform.isAndroid) {
        return await const MethodChannel('com.watchtower.app.device_capabilities')
            .invokeMethod<int>('getPhysicalMemoryMB');
      }
    } catch (_) {}
    return null;
  }

  static void _applyAdaptiveImageCache() {
    final cache = PaintingBinding.instance.imageCache;
    switch (ramTier) {
      case 'low':
        // iPhone 7 / SE class: keep memory footprint minimal.
        cache.maximumSizeBytes = 20 * 1024 * 1024;   // 20 MB
        cache.maximumSize = 80;
        break;
      case 'mid':
        cache.maximumSizeBytes = 50 * 1024 * 1024;   // 50 MB
        cache.maximumSize = 150;
        break;
      case 'high':
        // Flagship phones: give a generous cache for smooth browsing.
        cache.maximumSizeBytes = 120 * 1024 * 1024;  // 120 MB
        cache.maximumSize = 300;
        break;
    }
  }
}
