import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Use platform-native settings navigation so reverse transitions and system
/// back gestures remain available on supported platforms.
Route<T> settingsSubpageRoute<T>(Widget page) {
  if (!kIsWeb && (Platform.isIOS || Platform.isMacOS)) {
    return CupertinoPageRoute<T>(builder: (_) => page);
  }
  return MaterialPageRoute<T>(builder: (_) => page);
}
