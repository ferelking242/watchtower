/// Platform-aware volume-button navigation helper.
///
/// Conditional import keeps volume_controller off the web compilation path,
/// where its showSystemUI property does not exist.
export 'vol_nav_helper_web.dart'
    if (dart.library.io) 'vol_nav_helper_native.dart';
