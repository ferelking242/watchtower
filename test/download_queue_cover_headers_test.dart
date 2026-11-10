import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/modules/widgets/custom_extended_image_provider.dart';
import 'package:watchtower/utils/cached_network.dart';

void main() {
  // The download-queue cards render their covers through `cachedNetworkImage`
  // with the extension's own headers. A hotlink-protected CDN (MissAV's cover
  // host, `fourhoi.com`, answers 403 without a `Referer`) needs those headers,
  // and the parent/child rows used to reach this widget with a null header map,
  // so every cover fell back to the placeholder. This pins the forwarding.
  testWidgets('cachedNetworkImage forwards extension headers to the provider', (
    tester,
  ) async {
    const headers = {
      'Referer': 'https://missav.ws/en/dldss-570',
      'User-Agent': 'WT-test',
    };

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 40,
            height: 56,
            child: cachedNetworkImage(
              imageUrl: 'https://fourhoi.com/dldss-570/cover-t.jpg',
              width: 40,
              height: 56,
              fit: BoxFit.cover,
              headers: headers,
              sourceId: 1900000218,
              errorWidget: const SizedBox.shrink(),
              loadingWidget: const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );

    final image = tester.widget<ExtendedImage>(find.byType(ExtendedImage));
    final provider = image.image as CustomExtendedNetworkImageProvider;
    expect(provider.headers, headers);
    expect(provider.sourceId, 1900000218);

    // Let the (mocked) network attempt and its retries finish so no timer is
    // left pending when the test tears down.
    await tester.pumpAndSettle();
  });
}
