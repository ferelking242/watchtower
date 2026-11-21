import 'package:watchtower/modules/live_tv/models/live_provider.dart';

/// Providers shipped with the app.
///
/// These are declarations, not code: adding one here is enough for it to appear
/// in Live TV, be updatable, and be disabled — no reader changes. That is the
/// whole point of the provider system: Watch and Manga ship extensions the same
/// way, and Live TV was the one surface without it.
///
/// IPTV Pro is the flagship provider. It indexes the free, publicly published
/// iptv-org playlists, so it needs no account and no key, and its version is
/// bumped whenever the upstream selection changes.
class LiveBuiltinCatalog {
  static const _iptvOrg =
      'https://iptv-org.github.io/iptv/index.m3u';

  static const iptvProId = 'iptv-pro';

  static List<LiveProviderCatalogEntry> get entries => const [
    LiveProviderCatalogEntry(
      id: iptvProId,
      name: 'IPTV Pro',
      kind: LiveProviderKind.m3u,
      source: _iptvOrg,
      version: '1.2.0',
      author: 'Watchtower',
      description:
          'Chaînes du monde entier, agrégées depuis les listes publiques '
          'iptv-org. Aucun compte requis.',
      iconUrl: null,
    ),
    LiveProviderCatalogEntry(
      id: 'iptv-france',
      name: 'IPTV France',
      kind: LiveProviderKind.m3u,
      source: 'https://iptv-org.github.io/iptv/countries/fr.m3u',
      version: '1.1.0',
      author: 'Watchtower',
      description: 'Chaînes françaises uniquement, liste iptv-org.',
    ),
    LiveProviderCatalogEntry(
      id: 'iptv-news',
      name: 'IPTV News',
      kind: LiveProviderKind.m3u,
      source: 'https://iptv-org.github.io/iptv/categories/news.m3u',
      version: '1.0.0',
      author: 'Watchtower',
      description: 'Chaînes d’information en continu, liste iptv-org.',
    ),
  ];

  /// The providers a fresh install starts with.
  ///
  /// Only IPTV Pro is enabled by default: enabling every builtin would make the
  /// first launch fetch several playlists at once for no benefit, and the user
  /// can turn the others on in one tap.
  static List<LiveProvider> get defaultInstalled => [
    for (final entry in entries)
      entry.toProvider(isBuiltin: true).copyWith(
        isEnabled: entry.id == iptvProId,
      ),
  ];

  /// The catalogue the update check compares installed versions against.
  static List<LiveProviderCatalogEntry> get catalogue => entries;
}
