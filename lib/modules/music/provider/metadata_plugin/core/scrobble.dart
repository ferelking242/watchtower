import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:watchtower/modules/music/models/metadata/metadata.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/core/auth.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/metadata_plugin_provider.dart';
import 'package:watchtower/modules/music/services/logger/logger.dart';
import 'package:watchtower/services/connectivity_service.dart';

/// Bridges playback events to the active metadata plugin's `scrobble` endpoint.
///
/// Only plugins that declare the [PluginAbilities.scrobbling] ability (e.g.
/// MusicBrainz/ListenBrainz) receive scrobbles; when none is configured this
/// provider is `null` and callers become no-ops. Scrobbling submits to the
/// user's ListenBrainz account, so a signed-out session never sends anything.
class MetadataPluginScrobbleNotifier
    extends Notifier<StreamController<SpotubeTrackObject>?> {
  @override
  build() {
    final metadataPlugin = ref.watch(metadataPluginProvider);
    final pluginConfig = ref
        .watch(metadataPluginsProvider)
        .asData
        ?.value
        .defaultMetadataPluginConfig;

    final authenticated =
        ref.watch(metadataPluginAuthenticatedProvider).asData?.value == true;

    final plugin = metadataPlugin.asData?.value;
    if (plugin == null ||
        pluginConfig == null ||
        !authenticated ||
        !pluginConfig.abilities.contains(PluginAbilities.scrobbling)) {
      return null;
    }

    final controller = StreamController<SpotubeTrackObject>.broadcast();

    final subscription = controller.stream.listen((event) async {
      // Offline: a scrobble can only fail, so skip the request instead of
      // hammering a dead network and logging a raw socket trace each time.
      if (ConnectivityService.instance.isOffline) return;
      try {
        await plugin.core.scrobble({
          "id": event.id,
          "title": event.name,
          "artists": event.artists
              .map((artist) => {
                    "id": artist.id,
                    "name": artist.name,
                  })
              .toList(),
          "album": {
            "id": event.album.id,
            "name": event.album.name,
          },
          "timestamp": DateTime.now().millisecondsSinceEpoch ~/ 1000,
          "duration_ms": event.durationMs,
          "isrc": event is SpotubeFullTrackObject ? event.isrc : null,
        });
      } catch (e, stack) {
        AppLogger.reportError(e, stack);
      }
    });

    ref.onDispose(() {
      subscription.cancel();
      controller.close();
    });

    return controller;
  }

  void scrobble(SpotubeTrackObject track) {
    state?.add(track);
  }
}

final metadataPluginScrobbleProvider = NotifierProvider<
    MetadataPluginScrobbleNotifier, StreamController<SpotubeTrackObject>?>(
  MetadataPluginScrobbleNotifier.new,
);
