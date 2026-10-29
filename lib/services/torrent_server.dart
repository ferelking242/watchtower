import 'dart:convert';
import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'dart:isolate';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:http_interceptor/http_interceptor.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/settings.dart';
import 'package:watchtower/models/video.dart';
import 'package:watchtower/providers/storage_provider.dart';
import 'package:watchtower/services/http/m_client.dart';
import 'package:watchtower/utils/extensions/string_extensions.dart';
import 'package:watchtower/ffi/torrent_server_ffi.dart' as libmtorrentserver_ffi;
import 'package:watchtower/utils/constant.dart';

class MTorrentServer {
  // Magnet → playable HTTP requires libtorrent to:
  //   1) handshake with the DHT,
  //   2) fetch the .torrent metadata from a peer,
  //   3) build the master playlist.
  // For sparsely-seeded magnets that easily takes 30–90s. The default
  // RHTTP/InterceptedClient timeout (≈30s) is too aggressive and was
  // causing `RhttpTimeoutException: Request timed out. URL:
  // http://127.0.0.1:.../torrent/play?magnet=...` for any magnet that
  // wasn't already cached. Bump to 3 min for the torrent server only.
  final http = MClient.init(
    reqcopyWith: const {"timeout": 180, "connectTimeout": 30},
  );
  Future<bool> removeTorrent(String? inforHash) async {
    if (inforHash == null || inforHash.isEmpty) return false;
    try {
      final res = await http.delete(
        Uri.parse("$_baseUrl/torrent/remove?infohash=$inforHash"),
      );
      if (res.statusCode == 200) {
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> check() async {
    if (_baseUrl == "http://127.0.0.1:0") return false;
    try {
      final res = await http.get(Uri.parse("$_baseUrl/"));
      if (res.statusCode == 200) {
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<String> getInfohash(String url, bool isFilePath) async {
    try {
      final torrentByte = isFilePath
          ? File(url).readAsBytesSync()
          : (await http.get(Uri.parse(url))).bodyBytes;
      var request = MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/torrent/add'),
      );

      request.files.add(
        MultipartFile.fromBytes('file', torrentByte, filename: 'file.torrent'),
      );
      final response = await http.send(request);
      return await response.stream.bytesToString();
    } catch (e) {
      rethrow;
    }
  }

  Future<(List<Video>, String?)> getTorrentPlaylist(
    String? url,
    String? archivePath,
  ) async {
    try {
      final isFilePath = archivePath?.isNotEmpty ?? false;
      // A user-configured TorrServer is expected to run outside the app, so the
      // bundled libmtorrentserver is only started when no custom URL is set.
      final hasCustomServer = _customTorrServerUrl() != null;
      final isRunning = await check();
      if (!isRunning && !hasCustomServer) {
        final path = (await StorageProvider().getBtDirectory())!.path;
        final config = jsonEncode({"path": path, "address": "127.0.0.1:0"});
        int port = 0;
        if (Platform.isAndroid || Platform.isIOS) {
          const channel = MethodChannel(
            'com.watchtower.app.libmtorrentserver',
          );
          port = await channel.invokeMethod('start', {"config": config});
        } else {
          port = await Isolate.run(() async {
            return libmtorrentserver_ffi.start(config);
          });
        }
        _setBtServerPort(port);
      }
      url = isFilePath ? archivePath! : url!;
      bool isMagnet = url.startsWith("magnet:?");
      String finalUrl = "";
      String? infohash;
      if (!isMagnet) {
        infohash = await getInfohash(url, isFilePath);
        finalUrl = "$_baseUrl/torrent/play?infohash=$infohash";
      } else {
        finalUrl = "$_baseUrl/torrent/play?magnet=$url";
      }

      final masterPlaylist = (await http.get(Uri.parse(finalUrl))).body;
      final videoList = <Video>[];
      const separator = "#EXTINF:";
      for (var e in masterPlaylist.substringAfter(separator).split(separator)) {
        final fileName = e.substringAfter("-1,").substringBefore("\n");
        if (fileName.isMediaVideo()) {
          var videoUrl = e.substringAfter("\n").substringBefore("\n");
          videoList.add(Video(videoUrl, fileName, videoUrl));
        }
      }

      return (videoList, infohash);
    } catch (e) {
      rethrow;
    }
  }
}

String get _baseUrl {
  // A user-configured TorrServer (Paramètres → Lecteur vidéo → Torrent) takes
  // precedence over the bundled libmtorrentserver instance.
  final custom = _customTorrServerUrl();
  if (custom != null) return custom;
  final settings = isar.settings.getSync(kSettingsId);
  final port = settings!.btServerPort ?? 0;
  final address = settings.btServerAddress ?? "127.0.0.1";
  return "http://$address:$port";
}

/// Reads the TorrServer URL stored by the settings screen, if any.
String? _customTorrServerUrl() {
  try {
    if (!Hive.isBoxOpen('player_prefs')) return null;
    final raw = Hive.box('player_prefs').get('torrserver_url');
    return normaliseTorrServerUrl(raw is String ? raw : null);
  } catch (_) {
    return null;
  }
}

/// Normalises a user-entered TorrServer address into a usable base URL.
///
/// Accepts `host`, `host:port`, `http://host:port` and `https://host`; returns
/// null for blank input so callers can fall back to the bundled server. The
/// default port is 8090, the one TorrServer listens on out of the box.
String? normaliseTorrServerUrl(String? raw) {
  final trimmed = raw?.trim() ?? '';
  if (trimmed.isEmpty) return null;
  final withScheme = trimmed.contains('://') ? trimmed : 'http://$trimmed';
  final uri = Uri.tryParse(withScheme);
  if (uri == null || uri.host.isEmpty) return null;
  final port = uri.hasPort ? uri.port : 8090;
  return '${uri.scheme}://${uri.host}:$port';
}

void _setBtServerPort(int newPort) {
  isar.writeTxnSync(
    () => isar.settings.putSync(
      (isar.settings.getSync(kSettingsId) ?? Settings())
        ..btServerPort = newPort
        ..updatedAt = DateTime.now().millisecondsSinceEpoch,
    ),
  );
}
