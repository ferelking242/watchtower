import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/eval/model/m_manga.dart';
import 'package:watchtower/modules/watch/home/extension_collection_route.dart';

void main() {
  test('opens a collection using its extension list id', () {
    final item = MManga.fromJson({
      'name': 'Amateur',
      'link': 'https://example.com/search?q=amateur',
      'collectionId': 'category_amateur',
    });

    expect(
      ExtensionCollectionRoute.fromItem(item)?.listId,
      'category_amateur',
    );
  });

  test('does not treat regular videos as collections', () {
    final item = MManga(
      name: 'A video',
      link: 'https://example.com/video/123',
    );

    expect(ExtensionCollectionRoute.fromItem(item), isNull);
  });

  test('keeps URL-only collection payloads navigable', () {
    final item = MManga(
      name: 'English',
      link: 'https://example.com/language/english',
    );

    expect(ExtensionCollectionRoute.fromItem(item)?.listId, 'language_english');
  });
}