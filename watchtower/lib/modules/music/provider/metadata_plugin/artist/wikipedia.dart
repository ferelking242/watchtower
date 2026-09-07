import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:watchtower/modules/music/models/metadata/metadata.dart';
import 'package:watchtower/modules/music/services/wikipedia/wikipedia.dart';
import 'package:wikipedia_api/wikipedia_api.dart';

final artistWikipediaSummaryProvider =
    FutureProvider.autoDispose.family<Summary?, SpotubeFullArtistObject>(
  (ref, artist) async {
    final query = artist.name.replaceAll(" ", "_");
    final res = await wikipedia.pageContent.pageSummaryTitleGet(query);

    if (res?.type != "standard") {
      return await wikipedia.pageContent
          .pageSummaryTitleGet("${query}_(singer)");
    }
    return res;
  },
);
