import 'dart:io';

import 'package:watchtower/services/device_capabilities.dart';

/// Number of QuickJS extension workers to spawn.
///
/// Each worker is a full Dart isolate with its own QuickJS runtime, its own
/// Rust library handle and its own copy of the intl date data. The CPU count
/// alone therefore over-provisions small devices: four workers on a 3–4 GB
/// phone kept the process at the edge of memory pressure for the whole
/// session. The pool is bounded by the RAM tier as well as by the core count.
int getRecommendedExtensionWorkerCount() {
  final processors = Platform.numberOfProcessors;
  final byCpu = processors <= 1 ? 1 : (processors - 1).clamp(1, 4).toInt();
  // An unreadable RAM figure (desktop, CLI) must not cap the pool: fall back
  // to the core count exactly as before.
  if (DeviceCapabilities.physicalMemoryMB <= 0) return byCpu;
  final byRam = switch (DeviceCapabilities.ramTier) {
    'low' => 2,
    'mid' => 2,
    _ => 4,
  };
  return byCpu < byRam ? byCpu : byRam;
}

/// Number of chapters that may download at the same time.
///
/// Every download worker is a full isolate with its own HTTP client and Rust
/// handle, and each chapter already opens its own page-level connections
/// (`MangaConnections` / `AnimeConnections`, 3 by default). Sizing this from
/// the core count (2x cores, 8-32) produced sixteen workers on a flagship and
/// sixteen concurrent chapter downloads; the 2026-11 device logs then show
/// load 28 on eight cores, kswapd pinning another, and 2-17 s UI stalls. A
/// phone link cannot carry that many streams anyway - the same bytes move
/// faster on three.
int recommendedDownloadPoolSize() {
  if (DeviceCapabilities.physicalMemoryMB <= 0) {
    return Platform.numberOfProcessors <= 4 ? 2 : 3;
  }
  return switch (DeviceCapabilities.ramTier) {
    'low' => 2,
    'mid' => 3,
    _ => 4,
  };
}
