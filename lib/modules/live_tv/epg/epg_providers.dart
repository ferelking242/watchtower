import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:watchtower/modules/live_tv/epg/epg_matcher.dart';
import 'package:watchtower/modules/live_tv/epg/epg_models.dart';
import 'package:watchtower/modules/live_tv/epg/epg_parser.dart';
import 'package:watchtower/modules/live_tv/epg/epg_store.dart';
import 'package:watchtower/modules/live_tv/models/live_provider.dart';

/// A guide URL the user can pick in Settings.
class EpgSource {
  const EpgSource({required this.id, required this.label, required this.url});

  final String id;
  final String label;
  final String url;
}

/// Guides offered out of the box.
///
/// All are gzip XMLTV, which the parser unwraps itself, so the download is a
/// fifth of the XML size. epgshare01 publishes per-country rips; the French one
/// carries 574 channels and about 70 000 programmes.
const epgSources = <EpgSource>[
  EpgSource(
    id: 'fr',
    label: 'France (epgshare01)',
    url: 'https://epgshare01.online/epgshare01/epg_ripper_FR1.xml.gz',
  ),
  EpgSource(
    id: 'uk',
    label: 'Royaume-Uni (epgshare01)',
    url: 'https://epgshare01.online/epgshare01/epg_ripper_UK1.xml.gz',
  ),
  EpgSource(
    id: 'us',
    label: 'États-Unis (epgshare01)',
    url: 'https://epgshare01.online/epgshare01/epg_ripper_US1.xml.gz',
  ),
  EpgSource(
    id: 'be',
    label: 'Belgique (epgshare01)',
    url: 'https://epgshare01.online/epgshare01/epg_ripper_BE1.xml.gz',
  ),
];

/// State of the guide: what is loaded, and what the last attempt did.
class EpgState {
  const EpgState({
    this.guide,
    this.loading = false,
    this.progress = 0,
    this.error,
    this.sourceUrl,
  });

  final EpgGuide? guide;
  final bool loading;

  /// Programmes parsed so far, for a determinate progress bar.
  final int progress;

  final String? error;
  final String? sourceUrl;

  bool get hasGuide => guide != null;

  EpgState copyWith({
    EpgGuide? guide,
    bool? loading,
    int? progress,
    String? error,
    String? sourceUrl,
    bool clearError = false,
  }) => EpgState(
    guide: guide ?? this.guide,
    loading: loading ?? this.loading,
    progress: progress ?? this.progress,
    error: clearError ? null : (error ?? this.error),
    sourceUrl: sourceUrl ?? this.sourceUrl,
  );
}

/// Downloads, parses and caches the guide.
class EpgNotifier extends Notifier<EpgState> {
  late final EpgStore _store = EpgStore();
  http.Client? _client;

  @override
  EpgState build() {
    // A cached guide is shown immediately; a stale one is refreshed lazily so
    // the guide screen is never empty while the network works.
    final cached = _store.read();
    final stale = cached ?? _store.readStale();
    return EpgState(guide: stale, sourceUrl: _store.readUrl());
  }

  /// Downloads [source] and replaces the cached guide.
  Future<void> load(EpgSource source) async {
    if (state.loading) return;
    state = state.copyWith(
      loading: true,
      progress: 0,
      clearError: true,
      sourceUrl: source.url,
    );
    _client?.close();
    final client = _client = http.Client();
    try {
      final response = await client
          .get(Uri.parse(source.url))
          .timeout(const Duration(seconds: 90));
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }
      final guide =
          await EpgParser(
            onProgress: (count) {
              if (state.loading) state = state.copyWith(progress: count);
            },
          ).parseBytes(
            Uint8List.fromList(response.bodyBytes),
            source: source.label,
          );
      if (guide.programmeCount == 0) {
        throw Exception('Guide vide');
      }
      await _store.write(guide, url: source.url);
      state = EpgState(guide: guide, sourceUrl: source.url);
    } catch (error) {
      state = state.copyWith(loading: false, error: '$error');
    } finally {
      if (identical(_client, client)) {
        client.close();
        _client = null;
      }
    }
  }

  /// Re-downloads whatever was loaded last.
  Future<void> refresh() async {
    final url = state.sourceUrl ?? _store.readUrl();
    if (url == null) return;
    final known = epgSources.where((source) => source.url == url).firstOrNull;
    await load(
      known ??
          EpgSource(
            id: 'custom',
            label: _store.read()?.source ?? url,
            url: url,
          ),
    );
  }

  Future<void> clear() async {
    await _store.clear();
    state = const EpgState();
  }
}

final epgProvider = NotifierProvider<EpgNotifier, EpgState>(EpgNotifier.new);

/// Matcher for the loaded guide, rebuilt only when the guide changes.
final epgMatcherProvider = Provider<EpgMatcher?>((ref) {
  final guide = ref.watch(epgProvider.select((state) => state.guide));
  return guide == null ? null : EpgMatcher(guide);
});

/// Channels of the current guide matched to a playlist channel.
///
/// Returns a map keyed by `LiveChannel.id` so a channel row can look up its
/// schedule in constant time, and a guide channel shared by two playlist
/// entries is not matched twice.
final epgChannelIndexProvider =
    Provider.family<Map<String, String>, List<LiveChannel>>((ref, channels) {
      final matcher = ref.watch(epgMatcherProvider);
      if (matcher == null) return const {};
      final index = <String, String>{};
      for (final channel in channels) {
        final guideId = matcher.guideIdFor(channel);
        if (guideId != null) index[channel.id] = guideId;
      }
      return index;
    });
