import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:watchtower/modules/music/collections/riverpod_compat.dart';
import 'package:watchtower/modules/music/models/metadata/metadata.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/audio_source/quality_presets.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/metadata_plugin_provider.dart';
import 'package:watchtower/modules/music/services/sourced_track/sourced_track.dart';

class SourcedTrackNotifier
    extends FamilyAsyncNotifier<SourcedTrack, SpotubeFullTrackObject> {
  @override
  FutureOr<SourcedTrack> build() {
    final query = arg;

    // Use ref.listen instead of ref.watch so that startup initialisation of
    // audioSourcePluginProvider / audioSourcePresetsProvider does NOT trigger
    // extra rebuilds while the first fetch is still in-flight.  Only once the
    // state has a value (first fetch complete) do we invalidate and re-fetch
    // with the new settings.  This eliminates the triple YouTube URL fetch
    // that was visible at startup in the logs.
    ref.listen(audioSourcePluginProvider, (_, __) {
      if (state.valueOrNull != null) ref.invalidateSelf();
    });
    ref.listen(audioSourcePresetsProvider, (_, __) {
      if (state.valueOrNull != null) ref.invalidateSelf();
    });

    return SourcedTrack.fetchFromTrack(query: query, ref: ref);
  }

  Future<SourcedTrack> refreshStreamingUrl() async {
    return await update((prev) async {
      return await prev.refreshStream();
    });
  }

  Future<SourcedTrack> copyWithSibling() async {
    return await update((prev) async {
      return prev.copyWithSibling();
    });
  }

  Future<SourcedTrack> swapWithSibling(
    SpotubeAudioSourceMatchObject sibling,
  ) async {
    return await update((prev) async {
      return await prev.swapWithSibling(sibling) ?? prev;
    });
  }

  Future<SourcedTrack> swapWithNextSibling() async {
    return await update((prev) async {
      return await prev.swapWithSibling(prev.siblings.first) as SourcedTrack;
    });
  }
}

final sourcedTrackProvider = AsyncNotifierProvider.family<SourcedTrackNotifier,
    SourcedTrack, SpotubeFullTrackObject>(
  (a) => SourcedTrackNotifier()..initFamily(a),
);
