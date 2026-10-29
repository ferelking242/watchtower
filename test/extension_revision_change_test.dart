import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/services/fetch_sources_list.dart';

/// Regression cover for the 2026-10-26 Harimanga bug.
///
/// The catalogue re-pinned Harimanga to a new commit while still announcing
/// `0.4.12`, so the version-only comparison saw nothing to install and every
/// cover kept the placeholder. [extensionRevisionChanged] must treat a changed
/// `@<rev>` as an update, and only then.
void main() {
  const base =
      'https://cdn.jsdelivr.net/gh/ferelking242/watchtower-extensions';
  String url(String rev) => '$base@$rev/src/manga/en/harimanga.js';

  group('extensionRevisionChanged', () {
    test('detects a re-pin without a version bump', () {
      expect(
        extensionRevisionChanged(url('0ce3ade'), url('b8743eeb')),
        isTrue,
      );
    });

    test('ignores an identical pin', () {
      expect(extensionRevisionChanged(url('b8743eeb'), url('b8743eeb')), isFalse);
    });

    test('ignores a host swap that keeps the revision', () {
      expect(
        extensionRevisionChanged(
          url('b8743eeb'),
          'https://raw.githubusercontent.com/ferelking242/'
              'watchtower-extensions@b8743eeb/src/manga/en/harimanga.js',
        ),
        isFalse,
      );
    });

    test('ignores URLs without a revision segment', () {
      expect(
        extensionRevisionChanged(
          'https://example.com/harimanga.js',
          'https://example.com/harimanga.js?v=2',
        ),
        isFalse,
      );
      expect(
        extensionRevisionChanged(null, url('b8743eeb')),
        isFalse,
      );
      expect(
        extensionRevisionChanged('', url('b8743eeb')),
        isFalse,
      );
    });
  });

  group('hasPendingExtensionUpdate', () {
    test('is true for a pending code revision with no version change', () {
      final source = Source()
        ..version = '0.4.12'
        ..versionLast = '0.4.12'
        ..pendingSourceRevision = 'b8743eeb';
      expect(hasPendingExtensionUpdate(source), isTrue);
      expect(extensionUpdateLabel(source), 'code mis à jour');
    });

    test('is false once the revision was installed', () {
      final source = Source()
        ..version = '0.4.13'
        ..versionLast = '0.4.13';
      expect(hasPendingExtensionUpdate(source), isFalse);
    });
  });
}
