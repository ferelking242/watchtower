// remote_web_sync_stub.dart
// Stub for native platforms (dart.library.io).
// All functions are no-ops — the real implementations are in remote_web_sync.dart (web only).
// Required to avoid "undefined function" compile errors on native builds.

import 'package:watchtower/utils/mock_isar.dart';

Future<void> syncRemoteDataToMockIsar(MockIsar mockIsar) async {}

String remoteProxyUrl(String baseUrl, String imageUrl, {String? referer}) => imageUrl;
