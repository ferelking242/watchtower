import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/l10n/generated/app_localizations.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/modules/media/widgets/download_unit.dart';

/// The assertions below are written against the French strings, so resolve the
/// `fr` bundle directly (these helpers take an `AppLocalizations`).
final AppLocalizations _l10n = lookupAppLocalizations(const Locale('fr'));

void main() {
  group('downloadUnitFor', () {
    test('maps each source type to its own unit', () {
      expect(downloadUnitFor(ItemType.manga), DownloadUnit.manga);
      expect(downloadUnitFor(ItemType.anime), DownloadUnit.video);
      expect(downloadUnitFor(ItemType.novel), DownloadUnit.novel);
      expect(downloadUnitFor(ItemType.music), DownloadUnit.music);
      expect(downloadUnitFor(ItemType.game), DownloadUnit.game);
    });

    test('treats an unknown or plugin source as video', () {
      expect(downloadUnitFor(null), DownloadUnit.video);
      expect(downloadUnitFor(ItemType.plugin), DownloadUnit.video);
    });
  });

  group('catalogEntryUnitLabel', () {
    test('names the catalogue entry type, singular and plural', () {
      expect(catalogEntryUnitLabel(_l10n, ItemType.manga, 1), 'manga');
      expect(catalogEntryUnitLabel(_l10n, ItemType.manga, 5), 'mangas');
      expect(catalogEntryUnitLabel(_l10n, ItemType.anime, 3), 'vidéos');
      expect(catalogEntryUnitLabel(_l10n, ItemType.novel, 2), 'romans');
      expect(catalogEntryUnitLabel(_l10n, ItemType.music, 2), 'albums');
    });
  });

  group('queuedUnitLabel', () {
    test('names the queued item type, singular and plural', () {
      expect(queuedUnitLabel(_l10n, ItemType.manga, 1), 'chapitre');
      expect(queuedUnitLabel(_l10n, ItemType.manga, 120), 'chapitres');
      expect(queuedUnitLabel(_l10n, ItemType.anime, 12), 'épisodes');
      expect(queuedUnitLabel(_l10n, ItemType.music, 9), 'pistes');
    });

    test('a manga chapter is never called a video', () {
      // The bug this helper fixes: the catalogue entry count and the queued
      // item count must not collapse onto the same word.
      final entry = catalogEntryUnitLabel(_l10n, ItemType.manga, 5);
      final queued = queuedUnitLabel(_l10n, ItemType.manga, 5);
      expect(entry, isNot(equals(queued)));
      expect(queued, isNot(contains('vidéo')));
    });
  });
}
