import 'dart:convert';
  import 'dart:io';
  import 'package:flutter/foundation.dart';
  import 'package:flutter/services.dart';
  import 'package:http/http.dart' as http;
  import 'package:watchtower/main.dart';
  import 'package:watchtower/models/manga.dart';
  import 'package:watchtower/models/settings.dart';
  import 'package:watchtower/models/source.dart';
  import 'package:watchtower/services/fetch_sources_list.dart';
  import 'package:watchtower/utils/log/logger.dart';

  /// Silently detects Mihon/Aniyomi extensions already installed on the device
  /// and auto-installs them in Watchtower — no user action required.
  ///
  /// Deduplication is handled by source ID: if a source is already [isAdded]
  /// in the Isar DB, it is skipped entirely.
  class MihonAutoSync {
    static const _channel = MethodChannel('com.watchtower.app.package_scanner');

    static Future<void> run() async {
      if (kIsWeb || !Platform.isAndroid) return;
      try {
        // 1. Ask Android for installed Mihon/Aniyomi extension packages.
        final raw = await _channel.invokeMethod<List>('getInstalledMihonExtensions');
        if (raw == null || raw.isEmpty) return;

        final installedPkgs = <String>{};
        for (final item in raw) {
          if (item is Map) {
            final pkg = item['pkg'] as String?;
            if (pkg != null) installedPkgs.add(pkg);
          }
        }
        if (installedPkgs.isEmpty) return;

        AppLogger.log(
          'MihonAutoSync: ${installedPkgs.length} Mihon/Aniyomi extension(s) detected on device',
          tag: LogTag.extension_,
        );

        // 2. Read proxy server from settings (set by MExtensionServerPlatform).
        final settings = isar.settings.getSync(227)!;
        String proxyServer = settings.androidProxyServer ?? 'http://127.0.0.1:8080';
        if (!proxyServer.startsWith('http')) proxyServer = 'http://$proxyServer';

        // 3. Scan all configured repos (manga + anime).
        final allRepos = <Repo>[
          ...?settings.mangaExtensionsRepo,
          ...?settings.animeExtensionsRepo,
        ];

        int autoInstalled = 0;

        for (final repo in allRepos) {
          final url = repo.jsonUrl;
          if (url == null || url.isEmpty) continue;

          try {
            final response = await http
                .get(Uri.parse(url))
                .timeout(const Duration(seconds: 20));
            if (response.statusCode != 200) continue;

            final dynamic decoded = jsonDecode(response.body);
            if (decoded is! List) continue;

            for (final entry in decoded) {
              final pkg = entry['pkg'] as String?;
              if (pkg == null || !installedPkgs.contains(pkg)) continue;

              final sources = entry['sources'] as List?;
              if (sources == null) continue;

              final isAnime = pkg.startsWith('eu.kanade.tachiyomi.animeextension');
              final itemType = isAnime ? ItemType.anime : ItemType.manga;

              for (final src in sources) {
                final sourceId = 'mihon-${src['id']}'.hashCode;

                // Skip if already installed in Watchtower.
                final existing = await isar.sources.get(sourceId);
                if (existing != null && existing.isAdded == true) continue;

                AppLogger.log(
                  'MihonAutoSync: auto-installing "${src['name']}" (pkg=$pkg)',
                  tag: LogTag.extension_,
                );
                try {
                  await fetchSourcesList(
                    id: sourceId,
                    refresh: false,
                    androidProxyServer: proxyServer,
                    autoUpdateExtensions: false,
                    itemType: itemType,
                    repo: repo,
                  );
                  autoInstalled++;
                } catch (err) {
                  AppLogger.log(
                    'MihonAutoSync: install failed for "${src['name']}": $err',
                    logLevel: LogLevel.warning,
                    tag: LogTag.extension_,
                  );
                }
              }
            }
          } catch (err) {
            AppLogger.log(
              'MihonAutoSync: error fetching repo index $url: $err',
              logLevel: LogLevel.warning,
              tag: LogTag.extension_,
            );
          }
        }

        AppLogger.log(
          autoInstalled > 0
              ? 'MihonAutoSync: done — $autoInstalled extension(s) auto-installed'
              : 'MihonAutoSync: done — all detected extensions already present',
          tag: LogTag.extension_,
        );
      } catch (err) {
        AppLogger.log(
          'MihonAutoSync error: $err',
          logLevel: LogLevel.warning,
          tag: LogTag.extension_,
        );
      }
    }
  }
  