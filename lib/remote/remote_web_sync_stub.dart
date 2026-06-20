
import 'package:watchtower/utils/mock_isar.dart';

Future<void> syncRemoteDataToMockIsar(MockIsar mockIsar) async {}

Future<List<Map<String, dynamic>>?> fetchRemotePopular(
    String baseUrl, int sourceId, int page) async => null;

Future<List<Map<String, dynamic>>?> fetchRemoteSearch(
    String baseUrl, int sourceId, String query, int page) async => null;

String remoteProxyUrl(String baseUrl, String imageUrl, {String? referer}) =>
    imageUrl;
