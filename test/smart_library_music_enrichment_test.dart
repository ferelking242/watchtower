import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/local_indexer/metadata/local_metadata_resolver.dart';
import 'package:watchtower/local_indexer/models/local_indexed_item.dart';
import 'package:watchtower/local_indexer/normalizer/name_normalizer.dart';

/// A music track never carries an episode, a quality token or a language, so
/// [NameNormalizer] caps its confidence at 0.45 — exactly the general lookup
/// floor. Anything scoring below that (a bare "Track.mp3" lands at 0.225) used
/// to be skipped before MusicBrainz was ever asked, which left albums without
/// covers, artists or years. The floor is now per-kind.
void main() {
  group('Smart Library music enrichment floor', () {
    test('a bare track name stays under the general video floor', () {
      final result = NameNormalizer.normalize('/Music/Album/Track.mp3');
      expect(result.kind, LocalMediaKind.music);
      expect(result.confidence, lessThan(0.45));
    });

    test('music clears its own floor even when it misses the video floor', () {
      final result = NameNormalizer.normalize('/Music/Album/Track.mp3');
      expect(
        result.confidence,
        greaterThanOrEqualTo(
          LocalMetadataResolver.minimumConfidenceFor(LocalMediaKind.music),
        ),
      );
    });

    test('music uses a lower floor than movies and series', () {
      final music = LocalMetadataResolver.minimumConfidenceFor(
        LocalMediaKind.music,
      );
      for (final kind in [
        LocalMediaKind.movie,
        LocalMediaKind.series,
        LocalMediaKind.anime,
        LocalMediaKind.manga,
      ]) {
        expect(
          LocalMetadataResolver.minimumConfidenceFor(kind),
          greaterThan(music),
          reason: '$kind must keep the general floor',
        );
      }
    });

    test('platform tags beat the filename', () {
      // MediaStore already parsed ARTIST/ALBUM/TITLE from the file. A messily
      // named file must still display its real metadata, and no MusicBrainz
      // round trip is needed to get there.
      final result = NameNormalizer.normalize(
        '/Music/Unknown/01 - track_03_mix_final.mp3',
        tagTitle: 'Bohemian Rhapsody',
        tagArtist: 'Queen',
        tagAlbum: 'A Night at the Opera',
      );
      expect(result.kind, LocalMediaKind.music);
      expect(result.title, 'Bohemian Rhapsody');
      expect(result.artist, 'Queen');
      expect(result.album, 'A Night at the Opera');
    });

    test('an untagged file still falls back to the filename', () {
      final result = NameNormalizer.normalize(
        '/Music/Unknown/Queen - Bohemian Rhapsody.mp3',
      );
      expect(result.kind, LocalMediaKind.music);
      expect(result.title, 'Bohemian Rhapsody');
      expect(result.artist, 'Queen');
    });

    test('a titled track clears the music floor', () {
      final result = NameNormalizer.normalize(
        '/Music/Daft Punk/Random Access Memories/01 - Get Lucky.flac',
      );
      expect(result.kind, LocalMediaKind.music);
      expect(
        result.confidence,
        greaterThanOrEqualTo(
          LocalMetadataResolver.minimumConfidenceFor(LocalMediaKind.music),
        ),
      );
    });
  });
}
