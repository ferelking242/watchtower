import 'dart:convert';
import 'dart:io' if (dart.library.js_interop) 'io_stub.dart';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';

class WindowGeometry {
  static const _fileName = 'window_geometry.json';

  static Future<File> get _file async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$_fileName');
  }

  static Future<void> restore() async {
    if (kIsWeb) return;
    try {
      final file = await _file;
      if (!await file.exists()) return;
      final json = jsonDecode(await file.readAsString());
      final width = (json['width'] as num?)?.toDouble();
      final height = (json['height'] as num?)?.toDouble();
      final x = (json['x'] as num?)?.toDouble();
      final y = (json['y'] as num?)?.toDouble();
      final isMaximized = json['isMaximized'] as bool? ?? false;

      if (width != null && height != null && width > 100 && height > 100) {
        await windowManager.setSize(Size(width, height));
      }
      if (x != null && y != null) {
        await windowManager.setPosition(Offset(x, y));
      }
      if (isMaximized) {
        await windowManager.maximize();
      }
    } catch (_) {}
  }

  static Future<void> save() async {
    if (kIsWeb) return;
    try {
      final isMaximized = await windowManager.isMaximized();
      final size = await windowManager.getSize();
      final position = await windowManager.getPosition();
      final json = jsonEncode({
        'width': size.width,
        'height': size.height,
        'x': position.dx,
        'y': position.dy,
        'isMaximized': isMaximized,
      });
      final file = await _file;
      await file.writeAsString(json);
    } catch (_) {}
  }
}
