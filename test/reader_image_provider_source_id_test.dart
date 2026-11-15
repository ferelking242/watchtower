import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/models/page.dart';
import 'package:watchtower/modules/manga/reader/u_chap_data_preload.dart';
import 'package:watchtower/utils/extensions/others.dart';

/// The reader must fetch a page image through the *owning extension's* browser
/// session. That session holds the `cf_clearance` cookie and the exact
/// User-Agent the WebView used, and the cookie is bound to that UA. Dropping
/// `sourceId` makes the native client send neither, and the CDN answers 403.
void main() {
  UChapDataPreload page(String url) => UChapDataPreload(
    null,
    null,
    PageUrl(url),
    false,
    null,
    0,
    null,
    0,
  );

  test('the reader page provider carries the extension sourceId', () {
    final provider = page(
      'https://cdn.example.com/ch1/001.webp',
    ).buildNetworkImageProvider(sourceId: 42);

    expect(provider.sourceId, 42);
  });

  test('the same page under different extensions is a different provider', () {
    final data = page('https://cdn.example.com/ch1/001.webp');

    // Two extensions can serve the same CDN URL from different cleared
    // sessions. The providers must not compare equal, or Flutter's image cache
    // would hand one extension the other's (403-bound) entry.
    final first = data.buildNetworkImageProvider(sourceId: 7);
    final same = data.buildNetworkImageProvider(sourceId: 7);
    final other = data.buildNetworkImageProvider(sourceId: 8);

    expect(first, same);
    expect(first, isNot(other));
  });
}
