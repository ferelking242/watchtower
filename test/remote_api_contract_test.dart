// ignore: depend_on_referenced_packages
import 'package:watchtower_client/watchtower_client.dart' as sdk;
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/shelf.dart';
import 'package:watchtower/main.dart' as app;
import 'package:watchtower/models/manga.dart' show ItemType;
import 'package:watchtower/models/source.dart';
import 'package:watchtower/remote/remote_api_handler.dart';
import 'package:watchtower/utils/mock_isar.dart';

/// Contract between the server's `/api/sources` payload and the official Dart
/// SDK. Watchtower stores ids as Isar ints and `itemType` as an enum name,
/// while the SDK used to expect `String` and `int`: every client died with
/// "type 'int' is not a subtype of type 'String' in type cast".
void main() {
  late MockIsar mock;

  setUp(() {
    mock = MockIsar();
    app.isar = mock;
    mock.seed<Source>(
      7,
      Source()
        ..id = 7
        ..name = 'RedGifs'
        ..lang = 'en'
        ..baseUrl = 'https://redgifs.com'
        ..iconUrl = 'https://redgifs.com/icon.png'
        ..itemType = ItemType.anime
        ..isActive = true
        ..isAdded = true
        ..isNsfw = false,
    );
  });

  test('getSources returns the Isar-shaped payload the SDK must accept',
      () async {
    final handler = RemoteApiHandler(ProviderContainer());
    final response = await handler.getSources(
      Request('GET', Uri.parse('http://localhost/api/sources')),
    );

    expect(response.statusCode, 200);
    final payload = jsonDecode(await response.readAsString()) as Map;
    final raw = (payload['sources'] as List).single as Map<String, dynamic>;

    // What the server actually emits.
    expect(raw['id'], 7);
    expect(raw['itemType'], 'anime');
    expect(payload['hiddenNsfw'], 0);

    // And the SDK must read it without throwing.
    final source = sdk.Source.fromJson(raw);
    expect(source.id, '7');
    expect(source.name, 'RedGifs');
    expect(source.itemType, sdk.ItemType.video);
    expect(source.isNsfw, isFalse);
  });
}
