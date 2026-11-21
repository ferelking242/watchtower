import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/modules/live_tv/data/live_builtin_catalog.dart';
import 'package:watchtower/modules/live_tv/data/live_provider_fetcher.dart';
import 'package:watchtower/modules/live_tv/data/live_provider_store.dart';
import 'package:watchtower/modules/live_tv/models/live_provider.dart';

/// Installed providers plus the actions that change them.
///
/// State lives here rather than in the screen so the provider list, the
/// channel browser and the settings entry all observe the same list.
class LiveProvidersNotifier extends Notifier<List<LiveProvider>> {
  late final LiveProviderStore _store = LiveProviderStore();

  @override
  List<LiveProvider> build() => _store.read();

  Future<void> add(LiveProvider provider) async {
    await _store.save(provider);
    state = _store.read();
  }

  Future<void> remove(String id) async {
    await _store.remove(id);
    state = _store.read();
  }

  Future<void> setEnabled(String id, bool enabled) async {
    await _store.setEnabled(id, enabled);
    state = _store.read();
  }

  /// Pulls the shipped catalogue and applies newer versions.
  ///
  /// Returns the providers that actually changed, so the caller can tell the
  /// user "updated IPTV Pro" instead of claiming a check ran when nothing did.
  Future<List<LiveProvider>> checkForUpdates() async {
    final updated = await _store.applyUpdates(LiveBuiltinCatalog.catalogue);
    if (updated.isNotEmpty) state = _store.read();
    return updated;
  }

}

final liveProvidersProvider =
    NotifierProvider<LiveProvidersNotifier, List<LiveProvider>>(
      LiveProvidersNotifier.new,
    );

/// What the last fetch of each provider learned: channel count and timestamp.
///
/// Deliberately separate from [liveProvidersProvider]: `liveChannelsProvider`
/// watches the provider list, so writing fetch stats into it would invalidate
/// the very future that produced them and re-fetch forever. Nothing watches
/// this map from a fetch path, so recording here is inert.
class LiveFetchStatsNotifier extends Notifier<Map<String, LiveFetchStat>> {
  late final LiveProviderStore _store = LiveProviderStore();

  @override
  Map<String, LiveFetchStat> build() => _store.readFetchStats();

  Future<void> record(String providerId, int channelCount) async {
    await _store.recordFetch(providerId, channelCount);
    state = _store.readFetchStats();
  }
}

final liveFetchStatsProvider =
    NotifierProvider<LiveFetchStatsNotifier, Map<String, LiveFetchStat>>(
      LiveFetchStatsNotifier.new,
    );

/// Only the providers the user left enabled.
final enabledLiveProvidersProvider = Provider<List<LiveProvider>>((ref) {
  return ref
      .watch(liveProvidersProvider)
      .where((provider) => provider.isEnabled)
      .toList();
});

/// Channels of one provider.
///
/// Keyed by provider id and kept alive for the session: a playlist can be tens
/// of thousands of entries, and re-downloading it on every tab switch would be
/// the single most expensive thing Live TV does.
final liveChannelsProvider =
    FutureProvider.family<List<LiveChannel>, String>((ref, providerId) async {
      final provider = ref
          .watch(liveProvidersProvider)
          .where((candidate) => candidate.id == providerId)
          .firstOrNull;
      if (provider == null) {
        throw const LiveProviderException('Fournisseur introuvable.');
      }
      final fetcher = LiveProviderFetcher();
      try {
        final channels = await fetcher.fetch(provider);
        // Stats live outside liveProvidersProvider: that list is what this
        // future watches, so writing to it here would re-trigger the fetch.
        unawaited(
          ref
              .read(liveFetchStatsProvider.notifier)
              .record(provider.id, channels.length),
        );
        return channels;
      } finally {
        fetcher.dispose();
      }
    });

/// Channels from every enabled provider, flattened.
final allLiveChannelsProvider = FutureProvider<List<LiveChannel>>((ref) async {
  final providers = ref.watch(enabledLiveProvidersProvider);
  final results = <LiveChannel>[];
  for (final provider in providers) {
    try {
      results.addAll(await ref.watch(liveChannelsProvider(provider.id).future));
    } catch (_) {
      // One dead provider must not empty the whole list.
      continue;
    }
  }
  return results;
});

/// Channel groups of one provider, for the filter chips.
final liveGroupsProvider = FutureProvider.family<List<String>, String>((
  ref,
  providerId,
) async {
  final channels = await ref.watch(liveChannelsProvider(providerId).future);
  final groups = <String>{};
  for (final channel in channels) {
    final group = channel.group;
    if (group != null && group.isNotEmpty) groups.add(group);
  }
  final sorted = groups.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return sorted;
});
