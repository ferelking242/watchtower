// lib/services/layout_downloader.dart
// Downloads the ui-layout JSON file for an extension from GitHub
// and hands it to LayoutRegistry to persist and cache.
// Called during extension install and version update.

import 'package:http/http.dart' as http;
import 'package:watchtower/models/source.dart';
import 'package:watchtower/services/layout_registry.dart';
import 'package:watchtower/utils/log/logger.dart';

class LayoutDownloader {
  LayoutDownloader._();
  static final LayoutDownloader instance = LayoutDownloader._();

  static const String _rawBase =
      'https://raw.githubusercontent.com/ferelking242/watchtower-extensions/main/';

  /// Download and cache the layout for [source].
  /// Returns true on success, false if no layout declared or download failed.
  Future<bool> download(Source source) async {
    final layoutPath = source.uiLayout;
    if (layoutPath == null || layoutPath.isEmpty) return false;

    final url = '$_rawBase$layoutPath';
    AppLogger.log('[LayoutDownloader] GET $url', tag: LogTag.extension_);

    try {
      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        AppLogger.log(
          '[LayoutDownloader] HTTP ${response.statusCode} — $url',
          logLevel: LogLevel.warning,
          tag: LogTag.extension_,
        );
        return false;
      }

      await LayoutRegistry.instance.save(source, response.body);
      return true;
    } catch (e) {
      AppLogger.log(
        '[LayoutDownloader] Failed for ${source.name}: $e',
        logLevel: LogLevel.error,
        tag: LogTag.extension_,
      );
      return false;
    }
  }

  /// Remove cached layout for [source] (called on extension uninstall).
  Future<void> remove(Source source) =>
      LayoutRegistry.instance.remove(source);
}
