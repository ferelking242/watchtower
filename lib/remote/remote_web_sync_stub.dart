// remote_web_sync_stub.dart
// Stub for native platforms (dart.library.io) — all functions are no-ops.
// The real implementations live in remote_web_sync.dart (web only).

import 'package:watchtower/utils/mock_isar.dart';

Future<void> syncRemoteDataToMockIsar(MockIsar mockIsar) async {}

Future<List<Map<String, dynamic>>?> fetchRemotePopular(
    String baseUrl, int sourceId, int page) async => null;

Future<List<Map<String, dynamic>>?> fetchRemoteLatest(
    String baseUrl, int sourceId, int page) async => null;

Future<List<Map<String, dynamic>>?> fetchRemoteSearch(
    String baseUrl, int sourceId, String query, int page) async => null;

Future<Map<String, dynamic>?> fetchRemoteDetail(
    String baseUrl, int sourceId, String itemUrl) async => null;

Future<List<Map<String, dynamic>>?> fetchRemoteVideos(
    String baseUrl, int sourceId, String episodeUrl) async => null;

Future<List<Map<String, dynamic>>?> fetchRemotePages(
    String baseUrl, int sourceId, String chapterUrl) async => null;

String remoteProxyUrl(String baseUrl, String imageUrl, {String? referer}) =>
    imageUrl;
