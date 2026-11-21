@Tags(['live'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/modules/live_tv/data/live_provider_fetcher.dart';
import 'package:watchtower/modules/live_tv/data/live_builtin_catalog.dart';
import 'package:watchtower/modules/live_tv/sources/m3u_parser.dart';

/// End-to-end check against the real iptv-org playlists IPTV Pro ships with.
///
/// Tagged `live` and skipped by default: the unit suite must not depend on
/// GitHub Pages being reachable. Run explicitly with
/// `flutter test test/live_tv_live_fetch_test.dart --tags live`.
///
/// This exists because the parser's own tests use fixtures, and a fixture can
/// agree with a bug. Only the real 11k-entry playlist proves the shipped
/// provider actually yields playable channels.
void main() {
  test('every builtin playlist parses into channels', () async {
    final fetcher = LiveProviderFetcher();
    addTearDown(fetcher.dispose);

    for (final entry in LiveBuiltinCatalog.entries) {
      final channels = await fetcher.fetch(entry.toProvider(isBuiltin: true));
      expect(
        channels,
        isNotEmpty,
        reason: '${entry.name} returned no channel',
      );
      expect(
        channels.every((c) => c.urls.isNotEmpty),
        isTrue,
        reason: '${entry.name} produced a channel without url',
      );
      // ignore: avoid_print
      print('${entry.name}: ${channels.length} channels');
    }
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('the shipped IPTV Pro playlist yields thousands of channels', () async {
    final fetcher = LiveProviderFetcher();
    addTearDown(fetcher.dispose);

    final provider = LiveBuiltinCatalog.entries
        .firstWhere((e) => e.id == LiveBuiltinCatalog.iptvProId)
        .toProvider(isBuiltin: true);
    final channels = await fetcher.fetch(provider);

    expect(channels.length, greaterThan(5000));
    expect(channels.any((c) => c.group != null), isTrue);
    expect(channels.any((c) => c.logoUrl != null), isTrue);
    expect(
      channels.map((c) => c.id).toSet().length,
      channels.length,
      reason: 'channel ids must be unique',
    );
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('the real playlist is parsed without losing entries', () async {
    final file = File('/tmp/real.m3u');
    if (!file.existsSync()) {
      // Downloaded out of band for the manual check; absent on CI.
      return;
    }
    final content = await file.readAsString();
    final extinfCount = RegExp(r'^#EXTINF', multiLine: true)
        .allMatches(content)
        .length;
    final channels = M3uParser.parse(content, providerId: 'iptv-pro');

    // Dedupe by tvg-id can merge entries, so channels <= extinf, but the drop
    // must stay marginal: a parser bug shows up as a mass loss here.
    expect(channels.length, greaterThan(extinfCount * 0.9));
    expect(channels.every((c) => c.name.isNotEmpty), isTrue);
    expect(channels.every((c) => c.primaryUrl.startsWith('http')), isTrue);
    // ignore: avoid_print
    print('parsed ${channels.length} of $extinfCount entries');
  }, timeout: const Timeout(Duration(minutes: 2)));
}
