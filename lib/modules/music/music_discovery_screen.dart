/// Conditional export: native platforms (mobile/desktop) get the real
/// Spotube UI; web gets a lightweight stub that avoids native FFI packages.
export 'music_discovery_screen_stub.dart'
    if (dart.library.io) 'music_discovery_screen_impl.dart';
