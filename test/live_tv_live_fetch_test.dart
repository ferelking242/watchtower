@Tags(['live'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/modules/live_tv/data/live_extension_catalog.dart';
import 'package:watchtower/modules/live_tv/data/live_provider_fetcher.dart';
import 'package:watchtower/modules/live_tv/models/live_provider.dart';
import 'package:watchtower/modules/live_tv/sources/m3u_parser.dart';

/// End-to-end check against the real published Live TV catalogue.
///
/// Tagged `live` and skipped by default: the unit suite must not depend on
/// GitHub being reachable. Run explicitly with
/// `flutter test test/live_tv_live_fetch_test.dart --tags live`.
///
/// This exists because the parser's own tests use fixtures, and a fixture can
/// agree with a bug. Only the real index proves the published providers
/// actually resolve to channels.
void main() {
  test('the published Live TV index parses', () async {
    final entries = await LiveExtensionCatalog.fetch();

    expect(entries, isNotEmpty, reason: 'index/live.json is empty or missing');
    expect(
      entries.map((e) => e.id).toSet().length,
      entries.length,
      reason: 'provider ids must be unique',
    );
    // ignore: avoid_print
    for (final entry in entries) {
      print('${entry.name} (${entry.kind.name}) v${entry.version}');
    }
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('every published provider resolves to channels', () async {
    final fetcher = LiveProviderFetcher();
    addTearDown(fetcher.dispose);

    final entries = await LiveExtensionCatalog.fetch();
    for (final entry in entries) {
      if (entry.kind == LiveProviderKind.xtream) continue; // needs credentials
      final channels = await fetcher.fetch(entry.toProvider());
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
  }, timeout: const Timeout(Duration(minutes: 5)));

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
