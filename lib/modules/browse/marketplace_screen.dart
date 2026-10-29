import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:isar_community/isar.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/eval/model/source_preference.dart';
import 'package:watchtower/models/catalog_entry.dart';
import 'package:watchtower/modules/browse/marketplace_palette.dart';
import 'package:watchtower/models/catalog_shelf.dart';
import 'package:watchtower/models/catalog_taxonomy.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/settings.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/modules/browse/catalog_category_page.dart';
import 'package:watchtower/modules/browse/catalog_widgets.dart';
import 'package:watchtower/modules/more/settings/browse/providers/browse_state_provider.dart';
import 'package:watchtower/l10n/generated/app_localizations.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/services/catalog_shelf_builder.dart';
import 'package:watchtower/services/fetch_sources_list.dart';
import 'package:watchtower/services/extension_catalog_notifications.dart';
import 'package:watchtower/services/layout_registry.dart';
import 'package:watchtower/services/update_notification_service.dart';
import 'package:go_router/go_router.dart';
import 'package:watchtower/modules/browse/plugins_section.dart';
import 'package:watchtower/modules/more/settings/browse/extension_repositories_screen.dart';
import 'package:watchtower/modules/music/models/metadata/metadata.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/metadata_plugin_provider.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/core/repositories.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/utils/log/logger.dart';
import 'package:watchtower/widgets/shimmer_skeleton.dart';

// ─── Constants ─────────────────────────────────────────────────────────────────

// raw.githubusercontent.com — _fetch already appends ?_=timestamp so every
// refresh is a cache-miss and always reflects the latest push immediately.
// No CDN purge needed.
const _kWtBase =
    'https://raw.githubusercontent.com/ferelking242/watchtower-extensions/main';

/// Catalogue indices the Marketplace fetches.
///
/// The repository publishes one index per content type; this list is the single
/// source of truth for both the loader and the jsDelivr purge. It previously
/// lived as two hand-maintained copies, and `subtitles.json` was missing from
/// both, which is why the subtitle sources never appeared in the Marketplace.
const List<String> kMarketplaceIndexPaths = [
  'index/manga.json',
  'index/watch.json',
  'index/novel.json',
  'index/music.json',
  'index/game.json',
  'index/subtitles.json',
];

const _kFeaturedNames = {
  'MangaDex',
  'Webtoons',
  'Comick',
  'MangaPlus',
  'NovelUpdates',
  'AsuraScans',
  'ReaperScans',
  'Bato.to',
  'Viz',
  'CrunchyRoll',
};

// ─── Compat filter ─────────────────────────────────────────────────────────────

enum _CompatF { all, js }

// Rewrites icon URLs so brand icons keep their REAL colors:
//  • cdn.simpleicons.org is a free community CDN that rate-limits
//    aggressively and only serves SVG — the marketplace SVG path applies a
//    monochrome tint that makes Spotify/YouTube/Deezer look like generic
//    blue placeholders.
//  • We map known music brands to PNG sources with the brand color baked in
//    (icons8 color set / Google favicons), so they render through the
//    untinted Image.network path instead.
const _kMktBrandIcons = <String, String>{
  'spotify': 'https://img.icons8.com/color/128/spotify.png',
  'youtubemusic': 'https://img.icons8.com/color/128/youtube-music.png',
  'applemusic': 'https://img.icons8.com/color/128/apple-music.png',
  'deezer': 'https://img.icons8.com/color/128/deezer.png',
  'musicbrainz':
      'https://www.google.com/s2/favicons?domain=musicbrainz.org&sz=128',
  'flac': 'https://img.icons8.com/color/128/audio-wave.png',
};

String? _mktIconUrl(String? raw) {
  if (raw == null || raw.isEmpty) return raw;
  final m = RegExp(
    r'^https?://cdn\.simpleicons\.org/([a-z0-9-]+)$',
  ).firstMatch(raw);
  if (m != null) {
    return _kMktBrandIcons[m.group(1)] ?? raw;
  }
  return raw;
}

/// Formats a byte count for a card. Unit suffixes are localised ("Ko"/"Mo" in
/// French); the value itself is never localised so it stays a plain number.
String _formatMktSize(AppLocalizations l10n, int? bytes) {
  if (bytes == null || bytes <= 0) return '';
  if (bytes < 1024 * 1024) {
    return l10n.marketplace_size_kb((bytes / 1024).toStringAsFixed(0));
  }
  return l10n.marketplace_size_mb((bytes / (1024 * 1024)).toStringAsFixed(1));
}

int? _parseMktSize(dynamic raw) {
  if (raw is num) return raw.toInt();
  if (raw is! String) return null;
  final match = RegExp(
    r'^\s*([\d.,]+)\s*(kb|kib|mb|mib|gb|gib)?\s*$',
    caseSensitive: false,
  ).firstMatch(raw);
  if (match == null) return null;
  final value = double.tryParse(match.group(1)!.replaceAll(',', '.'));
  if (value == null) return null;
  final unit = match.group(2)?.toLowerCase() ?? 'b';
  final multiplier = switch (unit) {
    'kb' || 'kib' => 1024,
    'mb' || 'mib' => 1024 * 1024,
    'gb' || 'gib' => 1024 * 1024 * 1024,
    _ => 1,
  };
  return (value * multiplier).round();
}

// ─── Data model ────────────────────────────────────────────────────────────────

class _ExtEntry implements CatalogEntryView {
  @override
  final int id;
  @override
  final String name;
  final String? iconUrl;
  final String lang;
  final String version;
  final ItemType contentType;
  final SourceCodeLanguage compat;
  @override
  final bool isNsfw;
  final String repoUrl;
  final List<_ExtVersionEntry> versions;
  final List<String> subCategories;
  final String? uiLayout;
  final String? uiLayoutVersion;
  final List<String> contentSubtype;
  final bool requiresAccount;
  final bool hasDRM;
  final bool isAggregator;
  final String paywall;
  final bool supportsComments;
  final String upstream;
  @override
  final String description;

  /// Localised summaries published by the index, keyed by locale code
  /// (`en`, `fr`, `pt_BR`…). Empty for indexes that only carry a single
  /// [description]. See [localizedDescription].
  final Map<String, String> descriptions;

  final int? sizeBytes;
  final double rating;
  final int reviewCount;

  /// Marketplace tags published by the index, already filtered to the tags this
  /// build understands. Empty for indexes that predate the tag system, in which
  /// case [effectiveTags] derives the shelves from the catalogue and language.
  /// Website the extension serves content from, when the index publishes one.
  @override
  final String? siteUrl;

  @override
  final List<String> tags;

  /// Declared language codes (`lang` plus any `langs` list), lower-cased.
  @override
  final List<String> languages;

  /// Date the entry first appeared in the catalogue, when the index has one.
  @override
  final DateTime? addedAt;

  /// Catalogue index the entry was published under.
  ///
  /// Kept as the raw integer because [CatalogTaxonomy] indexes its vocabulary
  /// by `itemType`, and [contentType] cannot round-trip `7` (subtitles).
  @override
  final int itemType;

  /// Lower-cased blob used for substring search (name, language, type,
  /// sub-categories and description). Built once to avoid re-lowercasing the
  /// whole catalogue on every keystroke.
  late final String searchText = [
    name,
    lang,
    description,
    ...descriptions.values,
    ...subCategories,
  ].join(' ').toLowerCase();

  /// Description to show for [entry] in the current [l10n] locale.
  ///
  /// A localised summary published by the index wins; the single `description`
  /// field is the fallback for indexes that predate the localised map.
  String localizedDescription(String localeName) {
    if (descriptions.isEmpty) return '';
    final normalized = localeName.toLowerCase().replaceAll('-', '_');
    final exact = descriptions[normalized];
    if (exact != null && exact.isNotEmpty) return exact;
    final language = normalized.split('_').first;
    final byLanguage = descriptions[language];
    if (byLanguage != null && byLanguage.isNotEmpty) return byLanguage;
    return '';
  }

  _ExtEntry({
    required this.id,
    required this.name,
    this.iconUrl,
    required this.lang,
    required this.version,
    required this.contentType,
    required this.compat,
    this.isNsfw = false,
    required this.repoUrl,
    this.versions = const [],
    this.subCategories = const [],
    this.uiLayout,
    this.uiLayoutVersion,
    this.contentSubtype = const [],
    this.requiresAccount = false,
    this.hasDRM = false,
    this.isAggregator = false,
    this.paywall = 'free',
    this.supportsComments = false,
    this.upstream = '',
    this.description = '',
    this.descriptions = const {},
    this.sizeBytes,
    this.rating = 0,
    this.reviewCount = 0,
    this.tags = const [],
    this.languages = const [],
    this.addedAt,
    this.siteUrl,
    int? itemType,
  }) : itemType = itemType ?? contentType.index;
}

bool _isMusicPluginEntry(_ExtEntry entry) {
  if (entry.contentType != ItemType.music) return false;
  return [entry.upstream, entry.repoUrl]
      .where((url) => url.isNotEmpty)
      .any(
        (url) =>
            Uri.tryParse(url)?.path.toLowerCase().endsWith('.smplug') ?? false,
      );
}

// ─── Top-level parse helpers ───────────────────────────────────────────────────

/// Parses one catalogue index body into the maps [_mapsToEntries] consumes.
///
/// Public (rather than private) so the de-duplication rule below can be
/// exercised directly in tests; the Marketplace screen is its only caller.
@visibleForTesting
List<Map<String, dynamic>> parseMarketplaceIndex(Map<String, String> args) {
  final String body = args['body']!;
  final String url = args['url']!;
  dynamic decoded;
  try {
    decoded = jsonDecode(body);
  } catch (_) {
    return [];
  }
  if (decoded is! List) return [];

  final results = <Map<String, dynamic>>[];
  for (final raw in decoded) {
    if (raw is! Map) continue;
    final e = raw;
    try {
      final rawId = e['id'];
      if (rawId is! num || e['name'] is! String) continue;
      final rawItemType = e['itemType'];
      final rawCompat = e['sourceCodeLanguage'];
      final itemTypeIdx = (rawItemType is num ? rawItemType.toInt() : 0).clamp(
        0,
        4,
      );
      // The raw itemType drives the taxonomy; it is not clamped because the
      // catalogue publishes values outside the app's ItemType enum (subtitles).
      final rawItemTypeValue = rawItemType is num
          ? rawItemType.toInt()
          : itemTypeIdx;
      final compatIdx = rawCompat is num ? rawCompat.toInt() : 1;
      if (compatIdx < 0 || compatIdx > 1) continue;
      final rawSubCategories = e['subCategories'];
      final rawTags = e['tags'];
      final rawLangs = e['langs'];
      final primaryLang = (e['lang'] is String ? e['lang'] as String : 'all')
          .toLowerCase();
      results.add({
        'id': rawId.toInt(),
        'name': e['name'],
        'iconUrl': _mktIconUrl(
          e['iconUrl'] is String ? e['iconUrl'] as String : null,
        ),
        'lang': primaryLang,
        'languages': <String>[
          primaryLang,
          if (rawLangs is List) ...rawLangs.whereType<String>(),
        ].map((code) => code.toLowerCase()).toList(),
        'itemType': rawItemTypeValue,
        'tags': rawTags is List
            ? rawTags.whereType<String>().toList()
            : <String>[],
        'siteUrl': e['baseUrl'] is String && (e['baseUrl'] as String).isNotEmpty
            ? e['baseUrl'] as String
            : null,
        'addedAt': e['addedAt'] is String ? e['addedAt'] as String : null,
        'version': e['version'] is String ? e['version'] : '?',
        'contentType': itemTypeIdx,
        'compat': compatIdx,
        'isNsfw': e['isNsfw'] is bool ? e['isNsfw'] as bool : false,
        'repoUrl': url,
        'subCategories': rawSubCategories is List
            ? rawSubCategories.whereType<String>().toList()
            : <String>[],
        'contentSubtype': e['contentSubtype'] is List
            ? (e['contentSubtype'] as List).whereType<String>().toList()
            : <String>[],
        'uiLayout': e['uiLayout'] is String ? e['uiLayout'] : null,
        'uiLayoutVersion': e['uiLayoutVersion'] is String
            ? e['uiLayoutVersion']
            : null,
        // Localised summaries published by the index, keyed by locale code
        // (`en`, `fr`, `pt_BR`…). Optional: an index that only carries a single
        // `description`/`notes` keeps working through the fallback below.
        'descriptions': e['descriptions'] is Map
            ? <String, String>{
                for (final entry in (e['descriptions'] as Map).entries)
                  if (entry.key is String && entry.value is String)
                    (entry.key as String).toLowerCase().replaceAll('-', '_'):
                        (entry.value as String).trim(),
              }
            : null,
        'requiresAccount': e['requiresAccount'] is bool
            ? e['requiresAccount'] as bool
            : false,
        'hasDRM': e['hasDRM'] is bool ? e['hasDRM'] as bool : false,
        'isAggregator': e['isAggregator'] is bool
            ? e['isAggregator'] as bool
            : false,
        'paywall': e['paywall'] is String ? e['paywall'] : 'free',
        'supportsComments': e['supportsComments'] is bool
            ? e['supportsComments'] as bool
            : false,
        'upstream': e['upstream'] is String ? e['upstream'] : '',
        // The index `notes` field is exactly the text the extension's own
        // settings page shows, so the card reuses it verbatim instead of
        // inventing a summary. A catalogue that publishes a non-empty
        // `description` wins.
        'description': switch (e['description']) {
          final String value when value.trim().isNotEmpty => value.trim(),
          _ => e['notes'] is String ? (e['notes'] as String).trim() : '',
        },
        'sizeBytes': _parseMktSize(
          e['sizeBytes'] ?? e['size'] ?? e['downloadSize'],
        ),
        'rating': e['rating'] is num ? (e['rating'] as num).toDouble() : null,
        'reviewCount': e['reviewCount'] is num
            ? (e['reviewCount'] as num).toInt()
            : null,
      });
    } catch (_) {
      // One malformed catalogue entry must not blank every Marketplace tab.
      continue;
    }
  }
  // Two extensions may legitimately share a display name — `SpankBang` ships a
  // `spankbang.js` and a newer `spankbang_new.js`, `AnimeSongLyrics` has an old
  // and a rewritten source, and so on. Keying the de-duplication on the name
  // hid one of each pair from the whole Marketplace, so the key is the id the
  // catalogue guarantees to be unique. Entries without a usable id were
  // already skipped above, so this never merges two distinct sources.
  final seen = <int>{};
  return results.where((r) => seen.add(r['id'] as int)).toList();
}

List<_ExtEntry> _mapsToEntries(List<Map<String, dynamic>> maps) => maps.map((
  m,
) {
  final rawItemType = m['contentType'] is num
      ? (m['contentType'] as num).toInt()
      : -1;
  final rawCompat = m['compat'] is num ? (m['compat'] as num).toInt() : -1;
  final itemType = rawItemType >= 0 && rawItemType < ItemType.values.length
      ? ItemType.values[rawItemType]
      : ItemType.manga;
  final compat = rawCompat >= 0 && rawCompat < 2
      ? SourceCodeLanguage.values[rawCompat]
      : SourceCodeLanguage.javascript;
  return _ExtEntry(
    id: m['id'] as int,
    name: m['name'] as String,
    iconUrl: m['iconUrl'] as String?,
    lang: m['lang'] as String,
    version: m['version'] as String,
    contentType: itemType,
    compat: compat,
    isNsfw: m['isNsfw'] as bool? ?? false,
    repoUrl: m['repoUrl'] as String,
    subCategories: (m['subCategories'] as List<dynamic>?)?.cast<String>() ?? [],
    contentSubtype:
        (m['contentSubtype'] as List<dynamic>?)?.cast<String>() ?? [],
    uiLayout: m['uiLayout'] as String?,
    uiLayoutVersion: m['uiLayoutVersion'] as String?,
    requiresAccount: m['requiresAccount'] as bool? ?? false,
    hasDRM: m['hasDRM'] as bool? ?? false,
    isAggregator: m['isAggregator'] as bool? ?? false,
    paywall: m['paywall'] as String? ?? 'free',
    supportsComments: m['supportsComments'] as bool? ?? false,
    upstream: m['upstream'] as String? ?? '',
    description: m['description'] as String? ?? '',
    descriptions:
        (m['descriptions'] as Map<String, dynamic>?)?.cast<String, String>() ??
        const {},
    sizeBytes: _parseMktSize(m['sizeBytes']),
    rating: (m['rating'] as num?)?.toDouble() ?? 0,
    reviewCount: (m['reviewCount'] as num?)?.toInt() ?? 0,
    // Unknown tags are dropped rather than kept: an older build must shelve an
    // entry it half-understands by the tags it does know, not ignore the entry.
    tags: CatalogTaxonomy.filterKnown(
      (m['tags'] as List<dynamic>?)?.whereType<String>() ?? const <String>[],
    ),
    languages:
        (m['languages'] as List<dynamic>?)?.whereType<String>().toList() ??
        <String>[],
    addedAt: _parseMktDate(m['addedAt']),
    siteUrl: m['siteUrl'] as String?,
    itemType: (m['itemType'] as num?)?.toInt() ?? itemType.index,
  );
}).toList();

/// Parses an index `addedAt` (`YYYY-MM-DD`), returning null for anything else.
///
/// A malformed or absent date must not fail the entry: the only thing it drives
/// is the "recently added" shelf, and the entry stays fully usable without it.
DateTime? _parseMktDate(dynamic raw) {
  if (raw is! String || raw.isEmpty) return null;
  return DateTime.tryParse(raw);
}

// ─── Outils natifs (ancienne « page plugin », désormais dans le Marketplace) ──

// ─── Screen ────────────────────────────────────────────────────────────────────

enum MarketplaceSection { extensions, plugins, search }

class MarketplaceScreen extends ConsumerStatefulWidget {
  final MarketplaceSection initialSection;

  const MarketplaceScreen({
    super.key,
    this.initialSection = MarketplaceSection.extensions,
  });

  @override
  ConsumerState<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

// Tab indices
const _kTabHome = 0;
const _kTabManga = 1;
const _kTabAnime = 2;
const _kTabNovel = 3;
const _kTabGames = 4;
const _kTabMusic = 5;
const _kTabBinary = 6;
const _kTabTools = 7;

class _MarketplaceScreenState extends ConsumerState<MarketplaceScreen>
    with TickerProviderStateMixin {
  // ── Data ─────────────────────────────────────────────────────────────────────
  List<_ExtEntry> _all = [];
  Set<int> _installed = {};
  final Map<int, bool> _busy = {};
  Map<int, String> _installedVersions = {};
  Map<int, Source> _installedSources = {};
  bool _loading = true;
  bool _refreshing = false;
  String? _error;

  // ── Tabs ─────────────────────────────────────────────────────────────────────
  late TabController _tabCtrl;

  // ── Search overlay ───────────────────────────────────────────────────────────
  bool _searchOpen = false;
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();

  // ── Per-tab compat filter (legacy chips) ─────────────────────────────────────
  final Map<int, _CompatF> _compatF = {
    _kTabHome: _CompatF.all,
    _kTabManga: _CompatF.all,
    _kTabAnime: _CompatF.all,
    _kTabNovel: _CompatF.all,
    _kTabGames: _CompatF.all,
    _kTabMusic: _CompatF.all,
    _kTabBinary: _CompatF.all,
  };

  // ── Play Store enhanced filter state ─────────────────────────────────────────
  final Map<int, String?> _repoFilter = {};
  final Map<int, String?> _langFilter = {};
  final Map<int, SourceCodeLanguage?> _progLangFilter = {};
  String _sortBy = 'alpha';
  bool _installedOnly = false;
  bool _withUpdatesOnly = false;
  bool _showNsfw = true;

  // ── Cache (survives navigation) ──────────────────────────────────────────
  static List<_ExtEntry>? _cachedAll;
  static DateTime? _cacheTime;
  String? _globalLangFilter;
  String? _globalRepoFilter;
  SourceCodeLanguage? _globalProgLangFilter;

  OverlayEntry? _accountOverlay;

  // ── Banner ───────────────────────────────────────────────────────────────────
  final _bannerCtrl = PageController(viewportFraction: 0.88);
  Timer? _bannerTimer;
  void initState() {
    super.initState();
    _tabCtrl = TabController(
      length: 8,
      vsync: this,
      initialIndex: widget.initialSection == MarketplaceSection.plugins ? 7 : 0,
    );
    _searchOpen = widget.initialSection == MarketplaceSection.search;
    if (_searchOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchFocus.requestFocus();
      });
    }
    if (_cachedAll != null &&
        _cacheTime != null &&
        DateTime.now().difference(_cacheTime!) < const Duration(seconds: 30)) {
      _all = _cachedAll!;
      _loading = false;
    } else {
      _loadAll();
    }
    _refreshInstalled();
  }

  @override
  void dispose() {
    _accountOverlay?.remove();
    _accountOverlay = null;
    _tabCtrl.dispose();
    _bannerTimer?.cancel();
    _bannerCtrl.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // ── Data load ─────────────────────────────────────────────────────────────────

  static String _normCompact(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  /// Finds the installed music plugin matching a marketplace entry.
  /// Matching by exact slug fails for entries like "MusicBrainz" vs the
  /// plugin "Musicbrainz and Listenbrainz" (slug `musicbrainz-and-listenbrainz`)
  /// or "FLAC Music" vs a plugin named "FLAC", so we also compare compact
  /// names and the repository URLs stored on both sides.
  PluginConfiguration? _musicPluginFor(_ExtEntry entry) {
    if (!_isMusicPluginEntry(entry)) return null;
    final plugins =
        ref.read(metadataPluginsProvider).value?.plugins ?? const [];
    if (plugins.isEmpty) return null;
    final entryName = _normCompact(entry.name);
    final urls =
        <String>{entry.repoUrl, if (entry.upstream.isNotEmpty) entry.upstream}
            .where((u) => u.isNotEmpty)
            .map((u) => u.replaceAll(RegExp(r'/+$'), ''))
            .toSet();
    for (final p in plugins) {
      final repo = p.repository?.replaceAll(RegExp(r'/+$'), '');
      if (repo != null && repo.isNotEmpty && urls.contains(repo)) return p;
      final pn = _normCompact(p.name);
      if (pn == entryName) return p;
    }
    return null;
  }

  Future<void> _refreshInstalled() async {
    try {
      final allSrcs = await isar.sources.buildQuery<Source>().findAll();
      final sources = allSrcs.where((s) => s.isAdded == true).toList();
      for (final source in sources) {
        source.hydrateExtendedMetadata();
      }
      // Music plugins (metadata/audio-source) live in the music module's
      // drift DB, not in the Isar `sources` table — mark the marketplace
      // entries matching an installed plugin as installed too.
      final musicPlugins = <int, PluginConfiguration>{};
      for (final entry in _all.where(_isMusicPluginEntry)) {
        final plugin = _musicPluginFor(entry);
        if (plugin != null) musicPlugins[entry.id] = plugin;
      }
      if (mounted) {
        setState(() {
          _installed = {
            ...sources.map((s) => s.id).whereType<int>(),
            ...musicPlugins.keys,
          };
          _installedVersions = {
            for (final s in sources)
              if (s.id != null && s.version != null) s.id!: s.version!,
            ...musicPlugins.map((id, plugin) => MapEntry(id, plugin.version)),
          };
          _installedSources = {
            for (final s in sources)
              if (s.id != null) s.id!: s,
          };
        });
      }
    } catch (_) {}
  }

  // ── Toast notification ─────────────────────────────────────────────────
  void _showToast(
    BuildContext ctx,
    String message, {
    bool isError = false,
    IconData? icon,
  }) {
    final overlay = Overlay.of(ctx);
    late OverlayEntry oe;
    oe = OverlayEntry(
      builder: (_) => _WTToast(
        message: message,
        isError: isError,
        icon: icon,
        onDismiss: () {
          try {
            oe.remove();
          } catch (_) {}
        },
      ),
    );
    overlay.insert(oe);
    Future.delayed(const Duration(milliseconds: 2800), () {
      try {
        oe.remove();
      } catch (_) {}
    });
  }

  Future<List<_ExtEntry>> _fetch(String url) async {
    final bust = '?_=${DateTime.now().millisecondsSinceEpoch}';
    final bustUrl = url.contains('?') ? url : url + bust;
    final r = await http
        .get(Uri.parse(bustUrl))
        .timeout(const Duration(seconds: 12));
    if (r.statusCode != 200) {
      throw Exception('HTTP ${r.statusCode} for $url');
    }
    if (r.bodyBytes.isEmpty) {
      throw Exception('Empty response for $url');
    }
    final decodedBody = utf8.decode(r.bodyBytes, allowMalformed: true);
    final maps = r.bodyBytes.length > 80000
        ? await compute(parseMarketplaceIndex, {
            'body': decodedBody,
            'url': url,
          })
        : parseMarketplaceIndex({'body': decodedBody, 'url': url});
    return _mapsToEntries(maps);
  }

  Future<void> _loadAll({bool bypassCache = false}) async {
    if (_all.isEmpty) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else {
      setState(() {
        _refreshing = true;
      });
    }
    if (bypassCache) {
      _cachedAll = null;
      _cacheTime = null;
      try {
        await _purgeJsDelivr().timeout(const Duration(seconds: 6));
      } catch (_) {
        // CDN purging is an optimisation; a slow purge must not block loading.
      }
    }
    try {
      var failures = 0;
      final catalogUrls = [
        for (final path in kMarketplaceIndexPaths) '$_kWtBase/$path',
      ];
      final catalogLoaded = List<bool>.filled(catalogUrls.length, false);
      Future<List<_ExtEntry>> safe(
        int index,
        Future<List<_ExtEntry>> request,
      ) async {
        try {
          final entries = await request;
          catalogLoaded[index] = true;
          return entries;
        } catch (_) {
          failures++;
          return <_ExtEntry>[];
        }
      }

      final results =
          await Future.wait<List<_ExtEntry>>(
            List<Future<List<_ExtEntry>>>.generate(
              catalogUrls.length,
              (index) => safe(index, _fetch(catalogUrls[index])),
            ),
          ).timeout(
            const Duration(seconds: 20),
            onTimeout: () {
              failures = catalogUrls.length;
              return List<List<_ExtEntry>>.generate(
                catalogUrls.length,
                (_) => <_ExtEntry>[],
              );
            },
          );

      if (failures < catalogUrls.length) {
        final published = <ExtensionPublicationNotice>[];
        for (var index = 0; index < catalogUrls.length; index++) {
          if (!catalogLoaded[index]) continue;
          try {
            published.addAll(
              await ExtensionCatalogNotifications.observeCatalog(
                catalogUrl: catalogUrls[index],
                entries: results[index].map(
                  (entry) => ExtensionPublicationNotice(
                    id: entry.id,
                    name: entry.name,
                    itemType: entry.contentType,
                    version: entry.version,
                    lang: entry.lang,
                    iconUrl: entry.iconUrl,
                  ),
                ),
              ),
            );
          } catch (error, stackTrace) {
            AppLogger.log(
              'Could not record new marketplace extensions',
              logLevel: LogLevel.warning,
              tag: LogTag.repo,
              error: error,
              stackTrace: stackTrace,
            );
          }
        }
        if (published.isNotEmpty) {
          unawaited(
            WatchtowerNotificationService.instance.showNewExtensions(published),
          );
        }
      }

      if (mounted)
        setState(() {
          _all = results.expand((l) => l).toList();
          _cachedAll = _all;
          _cacheTime = DateTime.now();
          _loading = false;
          _refreshing = false;
          _error = _all.isEmpty
              ? context.l10n.marketplace_error_load_failed(failures)
              : null;
        });
      // Entries are loaded now — recompute the installed set (music
      // plugins included) so cards show their real state on first paint.
      _refreshInstalled();
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString();
          _loading = false;
          _refreshing = false;
        });
    }
  }

  // ── jsDelivr purge — appelé automatiquement à chaque refresh forcé ──────────

  Future<void> _purgeJsDelivr() async {
    const purgeBase =
        'https://purge.jsdelivr.net/gh/ferelking242/watchtower-extensions@main';
    const indexes = kMarketplaceIndexPaths;
    await Future.wait(
      indexes.map(
        (p) => http
            .get(Uri.parse('$purgeBase/$p'))
            .timeout(const Duration(seconds: 8))
            .catchError((_) => http.Response('', 200)),
      ),
    );
  }

  // ── Install ───────────────────────────────────────────────────────────────────

  Future<bool> _install(_ExtEntry entry) async {
    if (_busy[entry.id] == true) return false;
    setState(() => _busy[entry.id] = true);
    try {
      // Only .smplug entries are metadata/audio plugins. Music sources such
      // as the YouTube Music JavaScript extension still install through Isar.
      if (_isMusicPluginEntry(entry)) {
        final repoUrl = entry.upstream.isNotEmpty
            ? entry.upstream
            : entry.repoUrl;
        final pluginsNotifier = ref.read(metadataPluginsProvider.notifier);
        final existingPlugin = _musicPluginFor(entry);
        final pluginConfig = await pluginsNotifier.downloadAndCachePlugin(
          repoUrl,
        );
        if (existingPlugin == null) {
          await pluginsNotifier.addPlugin(pluginConfig);
        } else {
          await pluginsNotifier.replacePlugin(existingPlugin, pluginConfig);
        }
        // addPlugin writes Drift synchronously, but the Riverpod watch stream
        // can publish the new state on the next event-loop turn. Refreshing
        // immediately can therefore report a successful install as missing.

        // New plugins become defaults only when installed, not when replacing
        // an existing plugin that the user may not have selected as default.
        if (existingPlugin == null &&
            pluginConfig.abilities.contains(PluginAbilities.metadata)) {
          try {
            await pluginsNotifier.setDefaultMetadataPlugin(pluginConfig);
          } catch (_) {}
        }
        if (existingPlugin == null &&
            pluginConfig.abilities.contains(PluginAbilities.audioSource)) {
          try {
            await pluginsNotifier.setDefaultAudioSourcePlugin(pluginConfig);
          } catch (_) {}
        }
        ref.invalidate(metadataPluginsProvider);

        var installed = false;
        for (int attempt = 0; attempt < 10; attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          await _refreshInstalled();
          if (_installed.contains(entry.id)) {
            installed = true;
            break;
          }
        }
        if (!installed) {
          throw StateError(
            context.l10n.marketplace_error_plugin_not_registered(entry.name),
          );
        }
        await ExtensionCatalogNotifications.dismissById(
          id: entry.id,
          itemType: entry.contentType,
        );
        await ExtensionCatalogNotifications.dismissPendingUpdate(
          id: entry.id,
          itemType: entry.contentType,
        );
        if (mounted) {
          _showToast(
            context,
            context.l10n.marketplace_installed_toast(entry.name),
            icon: Broken.tick_circle,
          );
        }
        return true;
      }

      final repo = Repo(
        jsonUrl: entry.repoUrl,
        name: _compatLabel(entry.compat),
        website: '',
      );
      await fetchSourcesList(
        id: entry.id,
        repo: repo,
        refresh: true,
        autoUpdateExtensions: true,
        itemType: entry.contentType,
      );
      await _verifyInstalled(entry);
      await ExtensionCatalogNotifications.dismissById(
        id: entry.id,
        itemType: entry.contentType,
      );
      await ExtensionCatalogNotifications.dismissPendingUpdate(
        id: entry.id,
        itemType: entry.contentType,
      );
      await _refreshInstalled();
      if (mounted) {
        _showToast(
          context,
          context.l10n.marketplace_installed_toast(entry.name),
          icon: Broken.tick_circle,
        );
      }
      return true;
    } catch (e) {
      if (mounted) {
        _showToast(
          context,
          context.l10n.marketplace_error_generic('$e'),
          isError: true,
          icon: Broken.danger,
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _busy.remove(entry.id));
    }
  }

  // ── Silent core: no toasts, no setState ─────────────────────────────────
  Future<void> _installOneCore(_ExtEntry entry) async {
    if (_isMusicPluginEntry(entry)) {
      final repoUrl = entry.upstream.isNotEmpty
          ? entry.upstream
          : entry.repoUrl;
      final pluginsNotifier = ref.read(metadataPluginsProvider.notifier);
      final pluginConfig = await pluginsNotifier.downloadAndCachePlugin(
        repoUrl,
      );
      final existingPlugin = _musicPluginFor(entry);
      if (existingPlugin == null) {
        await pluginsNotifier.addPlugin(pluginConfig);
      } else {
        await pluginsNotifier.replacePlugin(existingPlugin, pluginConfig);
      }
      await ExtensionCatalogNotifications.dismissById(
        id: entry.id,
        itemType: entry.contentType,
      );
      await ExtensionCatalogNotifications.dismissPendingUpdate(
        id: entry.id,
        itemType: entry.contentType,
      );
      return;
    }
    final repo = Repo(
      jsonUrl: entry.repoUrl,
      name: _compatLabel(entry.compat),
      website: '',
    );
    await fetchSourcesList(
      id: entry.id,
      repo: repo,
      refresh: true,
      autoUpdateExtensions: true,
      itemType: entry.contentType,
    );
    await _verifyInstalled(entry);
    await ExtensionCatalogNotifications.dismissById(
      id: entry.id,
      itemType: entry.contentType,
    );
    await ExtensionCatalogNotifications.dismissPendingUpdate(
      id: entry.id,
      itemType: entry.contentType,
    );
  }

  Future<void> _verifyInstalled(_ExtEntry entry) async {
    final source = await isar.sources.get(entry.id);
    source?.hydrateExtendedMetadata();
    if (source == null ||
        source.isAdded != true ||
        (source.sourceCode ?? '').trim().isEmpty) {
      throw StateError(
        context.l10n.marketplace_error_not_installed(entry.name),
      );
    }
    if (entry.uiLayout?.isNotEmpty == true) {
      if (source.uiLayout != entry.uiLayout ||
          source.uiLayoutVersion != entry.uiLayoutVersion) {
        throw StateError(
          context.l10n.marketplace_error_layout_not_saved(entry.name),
        );
      }
      await LayoutRegistry.instance.load(source);
      if (!LayoutRegistry.instance.has(source)) {
        throw StateError(
          context.l10n.marketplace_error_layout_unreadable(entry.name),
        );
      }
    }
    if (entry.subCategories.isNotEmpty &&
        !_sameStrings(source.subCategories, entry.subCategories)) {
      throw StateError(
        context.l10n.marketplace_error_categories_not_saved(entry.name),
      );
    }
    if (entry.contentSubtype.isNotEmpty &&
        !_sameStrings(source.contentSubtype, entry.contentSubtype)) {
      throw StateError(
        context.l10n.marketplace_error_content_types_not_saved(entry.name),
      );
    }
  }

  bool _sameStrings(List<String>? actual, List<String> expected) =>
      actual != null &&
      actual.length == expected.length &&
      actual.toSet().containsAll(expected);

  // ── Bulk install: parallel batches of 4, no toasts, single refresh ──────
  Future<void> _installBulk({
    required List<_ExtEntry> entries,
    required void Function(int done, int total, int failed) onProgress,
  }) async {
    if (entries.isEmpty) return;
    var done = 0;
    var failed = 0;
    const batchSize = 4;
    for (int i = 0; i < entries.length; i += batchSize) {
      if (!mounted) break;
      final batch = entries.skip(i).take(batchSize).toList();
      await Future.wait(
        batch.map((entry) async {
          try {
            await _installOneCore(entry);
          } catch (_) {
            failed++;
          }
          done++;
          onProgress(done, entries.length, failed);
        }),
      );
    }
    await _refreshInstalled();
  }

  // ── Uninstall ─────────────────────────────────────────────────────────────────

  Future<void> _uninstall(_ExtEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(context.l10n.marketplace_uninstall_title(entry.name)),
        content: Text(context.l10n.marketplace_uninstall_body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.l10n.uninstall),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy[entry.id] = true);
    try {
      if (_isMusicPluginEntry(entry)) {
        final plugin = _musicPluginFor(entry);
        if (plugin == null) {
          throw StateError(context.l10n.marketplace_error_audio_plugin_missing);
        }
        await ref.read(metadataPluginsProvider.notifier).removePlugin(plugin);
        ref.invalidate(metadataPluginsProvider);
      } else {
        final source = await isar.sources.get(entry.id);
        if (source == null) {
          throw StateError(context.l10n.marketplace_error_extension_missing);
        }
        final prefsIds = await isar.sourcePreferences
            .filter()
            .sourceIdEqualTo(source.id!)
            .findAll()
            .then((items) => items.map((item) => item.id!).toList());
        final prefsStringIds = await isar.sourcePreferenceStringValues
            .filter()
            .sourceIdEqualTo(source.id!)
            .findAll()
            .then((items) => items.map((item) => item.id).toList());
        await isar.writeTxn(() async {
          await isar.sources.put(
            source
              ..isAdded = false
              ..sourceCode = ''
              ..isPinned = false
              ..updatedAt = DateTime.now().millisecondsSinceEpoch,
          );
          await isar.sourcePreferences.deleteAll(prefsIds);
          await isar.sourcePreferenceStringValues.deleteAll(prefsStringIds);
        });
        await LayoutRegistry.instance.remove(source);
      }
      await ExtensionCatalogNotifications.dismissPendingUpdate(
        id: entry.id,
        itemType: entry.contentType,
      );
      await _refreshInstalled();
      if (mounted) {
        _showToast(
          context,
          context.l10n.marketplace_uninstalled_toast(entry.name),
          icon: Broken.trash,
        );
      }
    } catch (e) {
      if (mounted) {
        _showToast(
          context,
          context.l10n.marketplace_error_uninstall('$e'),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _busy.remove(entry.id));
    }
  }

  // ── Marketplace settings ──────────────────────────────────────────────────────

  void _showMarketplaceSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _MarketplaceSettingsSheet(state: this),
    );
  }
  // ── Filter helpers ────────────────────────────────────────────────────────────

  // ── Raw tab entries (no enhanced filters) ────────────────────────────────────
  List<_ExtEntry> _forTabRaw(int tab) {
    switch (tab) {
      case _kTabManga:
        return _all.where((e) => e.contentType == ItemType.manga).toList();
      case _kTabAnime:
        return _all.where((e) => e.contentType == ItemType.anime).toList();
      case _kTabNovel:
        return _all.where((e) => e.contentType == ItemType.novel).toList();
      case _kTabGames:
        return _all.where((e) => e.contentType == ItemType.game).toList();
      case _kTabMusic:
        return _all.where((e) => e.contentType == ItemType.music).toList();
      case _kTabBinary:
        return [];
      case _kTabTools:
        return [];
      default:
        return _all;
    }
  }

  // Maps visual tab-controller index → logical tab constant
  int _visualToTabConst(int visual) {
    const m = [
      _kTabHome, // 0
      _kTabAnime, // 1 Watch
      _kTabManga, // 2 Manga
      _kTabNovel, // 3 Novel
      _kTabGames, // 4 Game
      _kTabMusic, // 5 Music
      _kTabTools, // 6 Outils natifs
      _kTabBinary, // 7 Binaires
    ];
    return visual < m.length ? m[visual] : _kTabHome;
  }

  // Maps logical tab constant → visual tab-controller index
  int _tabConstToVisual(int tabConst) {
    const m = {
      _kTabHome: 0,
      _kTabAnime: 1,
      _kTabManga: 2,
      _kTabNovel: 3,
      _kTabGames: 4,
      _kTabMusic: 5,
      _kTabTools: 6,
      _kTabBinary: 7,
    };
    return m[tabConst] ?? 0;
  }

  List<_ExtEntry> get _searchResults {
    if (_searchQuery.isEmpty) return [];
    final q = _searchQuery.toLowerCase();
    return _all
        .where(
          (e) =>
              e.name.toLowerCase().contains(q) ||
              e.lang.toLowerCase().contains(q),
        )
        .take(80)
        .toList();
  }

  List<_ExtEntry> get _featured =>
      _all.where((e) => _kFeaturedNames.contains(e.name)).toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  // ── Static helpers ────────────────────────────────────────────────────────────

  static String _compatLabel(SourceCodeLanguage c) => switch (c) {
    SourceCodeLanguage.javascript => 'JS',
    SourceCodeLanguage.dart => 'Dart',
    SourceCodeLanguage.unsupported => 'Unsupported',
  };

  static Color _compatColor(SourceCodeLanguage c, ColorScheme cs) =>
      switch (c) {
        SourceCodeLanguage.javascript => const Color(0xFFF5A623),
        SourceCodeLanguage.dart => const Color(0xFF00B4D8),
        SourceCodeLanguage.unsupported => const Color(0xFF757575),
      };

  /// `_kItemTypeSubtitle` is the subtitle catalogue's raw index. It has no
  /// `ItemType` member, so these helpers take the raw index instead.
  static const int _kItemTypeSubtitle = 7;

  static IconData _typeIcon(int itemType) {
    if (itemType == _kItemTypeSubtitle) return Icons.subtitles_rounded;
    return switch (ItemType.values[itemType.clamp(
      0,
      ItemType.values.length - 1,
    )]) {
      ItemType.anime => Broken.video,
      ItemType.manga => Broken.bookmark,
      ItemType.novel => Broken.book_1,
      ItemType.music => Broken.musicnote,
      _ => Broken.game,
    };
  }

  static Color _typeColor(int itemType) {
    if (itemType == _kItemTypeSubtitle) return const Color(0xFF43A047);
    return switch (ItemType.values[itemType.clamp(
      0,
      ItemType.values.length - 1,
    )]) {
      ItemType.anime => const Color(0xFF9C27B0),
      ItemType.manga => const Color(0xFFE91E63),
      ItemType.novel => const Color(0xFF009688),
      ItemType.music => const Color(0xFF0288D1),
      _ => const Color(0xFF607D8B),
    };
  }

  static String _langCode(String lang) {
    final l = lang.toLowerCase();
    if (l == 'all' || l == 'multi') return 'MULTI';
    if (l.contains('-'))
      return l.split('-').map((p) => p.toUpperCase()).join('-');
    return l.length > 3 ? l.substring(0, 3).toUpperCase() : l.toUpperCase();
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    _showNsfw = ref.watch(showNSFWStateProvider);

    // Keep the installed markers in sync when the music plugin DB changes
    // (install/uninstall from the Music section while the marketplace is open).
    ref.listen<AsyncValue<MetadataPluginState>>(metadataPluginsProvider, (
      prev,
      next,
    ) {
      final a = prev?.value?.plugins.length;
      final b = next.value?.plugins.length;
      if (a != b) _refreshInstalled();
    });

    if (widget.initialSection != MarketplaceSection.plugins) {
      return Scaffold(
        backgroundColor: MarketplacePalette.of(context).background,
        body: SafeArea(
          bottom: false,
          child: _PlayStoreMarketplaceView(
            entries: _all,
            installed: _installed,
            installedVersions: _installedVersions,
            installedSources: _installedSources,
            busy: _busy,
            loading: _loading,
            error: _error,
            initialSearch: widget.initialSection == MarketplaceSection.search,
            showNsfw: _showNsfw,
            onEnableNsfw: () =>
                ref.read(showNSFWStateProvider.notifier).set(true),
            onOpenSettings: _showMarketplaceSettings,
            onInstall: _install,
            onSettings: _openSettings,
            onRefresh: () => _loadAll(bypassCache: true),
          ),
        ),
      );
    }

    // Only the plugins section reaches this point: every other section is
    // rendered by the Play Store catalogue above. The plugin surface is a
    // single column, so it does not need the old tab controller.
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          if (_searchOpen)
            _buildSearchOverlay(cs, theme)
          else if (_error != null && _all.isEmpty)
            _buildError(cs)
          else
            Column(
              children: [
                _buildLogoRow(cs, theme),
                _buildPersistentSearch(cs, theme),
                const Expanded(child: _BinaryTab()),
              ],
            ),
          if (_refreshing)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                minHeight: 2,
                color: cs.primary,
                backgroundColor: Colors.transparent,
              ),
            ),
        ],
      ),
    );
  }

  // ── Top bar ───────────────────────────────────────────────────────────────────

  Widget _buildLogoRow(ColorScheme cs, ThemeData theme) {
    return Container(
      color: theme.scaffoldBackgroundColor,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/app_icons/icon.png',
                    width: 42,
                    height: 42,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Watchtower',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      'Extension Marketplace',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Adulte',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Transform.scale(
                    scale: 0.78,
                    child: Switch(
                      value: _showNsfw,
                      onChanged: (v) =>
                          ref.read(showNSFWStateProvider.notifier).state = v,
                      activeThumbColor: Colors.red.shade400,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Tab bar row (pinned — inside NestedScrollView body) ───────────────────────

  // ── Persistent search bar — theme-aware, taller, more spacious ──────────────
  Widget _buildPersistentSearch(ColorScheme cs, ThemeData theme) {
    return Container(
      color: theme.scaffoldBackgroundColor,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 2),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _searchQuery.isNotEmpty
                  ? cs.primary.withValues(alpha: 0.55)
                  : cs.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            children: [
              const SizedBox(width: 14),
              Icon(
                Broken.search_normal_1,
                size: 18,
                color: cs.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  onTap: () => setState(() => _searchOpen = true),
                  style: TextStyle(fontSize: 14, color: cs.onSurface),
                  decoration: InputDecoration(
                    hintText: context.l10n.marketplace_search_extension_hint,
                    hintStyle: TextStyle(
                      fontSize: 14,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              if (_searchQuery.isNotEmpty)
                IconButton(
                  icon: Icon(
                    Broken.close_circle,
                    size: 16,
                    color: cs.onSurfaceVariant,
                  ),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _searchQuery = '');
                  },
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              if (widget.initialSection != MarketplaceSection.plugins)
                _MarketplaceFilterButton(
                  active:
                      _globalLangFilter != null ||
                      _globalRepoFilter != null ||
                      _globalProgLangFilter != null,
                  onTap: _showMarketplaceFilterOverlay,
                ),
              const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }

  void _showMarketplaceFilterOverlay() {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    Icon(Broken.filter, color: cs.primary, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      context.l10n.marketplace_filter_extensions,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Broken.close_circle,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              _buildFilterRows(cs, theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterRows(ColorScheme cs, ThemeData theme) {
    final repoSet = <String>{};
    for (final e in _all) {
      final m = RegExp(r'github\.com/([^/]+/[^/]+)').firstMatch(e.repoUrl);
      if (m != null) repoSet.add(m.group(1)!);
    }
    final repos = repoSet.toList()..sort();
    final tabItems = _forTabRaw(_visualToTabConst(_tabCtrl.index));
    final humanLangs = tabItems.map((e) => e.lang).toSet().toList()..sort();
    final activeCount =
        (_globalRepoFilter != null ? 1 : 0) +
        (_globalProgLangFilter != null ? 1 : 0) +
        (_globalLangFilter != null ? 1 : 0);

    // ── Theme-aware filter decorations ──────────────────────────────────────
    BoxDecoration deco(bool active) => BoxDecoration(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
        color: active ? cs.primary : cs.outlineVariant.withValues(alpha: 0.5),
        width: active ? 1.5 : 1,
      ),
    );

    return Container(
      color: theme.scaffoldBackgroundColor,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                // ── Repo filter ─────────────────────────────────────────────
                Expanded(
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: deco(_globalRepoFilter != null),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: _globalRepoFilter,
                        isExpanded: true,
                        isDense: true,
                        icon: Icon(
                          Icons.expand_more_rounded,
                          size: 14,
                          color: cs.onSurfaceVariant,
                        ),
                        style: TextStyle(
                          fontSize: 12,
                          color: _globalRepoFilter != null
                              ? cs.primary
                              : cs.onSurfaceVariant,
                        ),
                        dropdownColor: cs.surfaceContainerLow,
                        items: [
                          DropdownMenuItem<String?>(
                            value: null,
                            child: Text(
                              context.l10n.marketplace_repository,
                              style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                          ...repos.map((r) {
                            final label = r.contains('ferelking242')
                                ? '⭐ Official'
                                : r.split('/').lastOrNull ?? r;
                            return DropdownMenuItem<String?>(
                              value: r,
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: cs.onSurface,
                                ),
                              ),
                            );
                          }),
                        ],
                        onChanged: (v) => setState(() => _globalRepoFilter = v),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // ── Prog-lang filter ─────────────────────────────────────────
                SizedBox(
                  width: 96,
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: deco(_globalProgLangFilter != null),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<SourceCodeLanguage?>(
                        value: _globalProgLangFilter,
                        isExpanded: true,
                        isDense: true,
                        icon: Icon(
                          Icons.expand_more_rounded,
                          size: 12,
                          color: cs.onSurfaceVariant,
                        ),
                        dropdownColor: cs.surfaceContainerLow,
                        selectedItemBuilder: (_) => [
                          Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.code_rounded,
                                  size: 12,
                                  color: cs.onSurfaceVariant,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Lang',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const _ProgLangBadge(
                                  color: Color(0xFFF7DF1E),
                                  textColor: Color(0xFF000000),
                                  label: 'JS',
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'JS',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: cs.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const _ProgLangBadge(
                                  color: Color(0xFF0175C2),
                                  textColor: Colors.white,
                                  label: 'D',
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Dart',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: cs.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        items: [
                          DropdownMenuItem<SourceCodeLanguage?>(
                            value: null,
                            child: Text(
                              'Tous',
                              style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                          DropdownMenuItem<SourceCodeLanguage?>(
                            value: SourceCodeLanguage.javascript,
                            child: Row(
                              children: [
                                const _ProgLangBadge(
                                  color: Color(0xFFF7DF1E),
                                  textColor: Color(0xFF000000),
                                  label: 'JS',
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'JavaScript',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: cs.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          DropdownMenuItem<SourceCodeLanguage?>(
                            value: SourceCodeLanguage.dart,
                            child: Row(
                              children: [
                                const _ProgLangBadge(
                                  color: Color(0xFF0175C2),
                                  textColor: Colors.white,
                                  label: 'D',
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Dart',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: cs.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        onChanged: (v) =>
                            setState(() => _globalProgLangFilter = v),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                // ── Language filter ──────────────────────────────────────────
                Expanded(
                  child: GestureDetector(
                    onTap: () => _showLangGridPicker(humanLangs),
                    child: Container(
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: deco(_globalLangFilter != null),
                      child: Row(
                        children: [
                          Icon(
                            Icons.language_outlined,
                            size: 14,
                            color: cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _globalLangFilter != null
                                  ? '${_MarketplaceScreenState._langFlag(_globalLangFilter!)} ${_MarketplaceScreenState._langDisplayName(_globalLangFilter!)}'
                                  : context.l10n.language,
                              style: TextStyle(
                                fontSize: 12,
                                color: _globalLangFilter != null
                                    ? cs.primary
                                    : cs.onSurfaceVariant,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(
                            Icons.expand_more_rounded,
                            size: 14,
                            color: cs.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // ── Settings / active filters badge ──────────────────────────
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    GestureDetector(
                      onTap: _showMarketplaceSettings,
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: activeCount > 0
                              ? cs.primaryContainer
                              : cs.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: activeCount > 0
                                ? cs.primary
                                : cs.outlineVariant.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Icon(
                          Icons.tune_rounded,
                          size: 18,
                          color: activeCount > 0
                              ? cs.onPrimaryContainer
                              : cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (activeCount > 0)
                      Positioned(
                        top: -5,
                        right: -5,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: cs.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '$activeCount',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: cs.onPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _langFlag(String lang) {
    const flags = <String, String>{
      'en': '\u{1F1EC}\u{1F1E7}',
      'fr': '\u{1F1EB}\u{1F1F7}',
      'ja': '\u{1F1EF}\u{1F1F5}',
      'zh': '\u{1F1E8}\u{1F1F3}',
      'ko': '\u{1F1F0}\u{1F1F7}',
      'es': '\u{1F1EA}\u{1F1F8}',
      'pt': '\u{1F1E7}\u{1F1F7}',
      'de': '\u{1F1E9}\u{1F1EA}',
      'it': '\u{1F1EE}\u{1F1F9}',
      'ru': '\u{1F1F7}\u{1F1FA}',
      'ar': '\u{1F1F8}\u{1F1E6}',
      'tr': '\u{1F1F9}\u{1F1F7}',
      'pl': '\u{1F1F5}\u{1F1F1}',
      'nl': '\u{1F1F3}\u{1F1F1}',
      'id': '\u{1F1EE}\u{1F1E9}',
      'th': '\u{1F1F9}\u{1F1ED}',
      'vi': '\u{1F1FB}\u{1F1F3}',
      'uk': '\u{1F1FA}\u{1F1E6}',
      'cs': '\u{1F1E8}\u{1F1FF}',
      'ro': '\u{1F1F7}\u{1F1F4}',
      'sv': '\u{1F1F8}\u{1F1EA}',
      'he': '\u{1F1EE}\u{1F1F1}',
      'hi': '\u{1F1EE}\u{1F1F3}',
      'hu': '\u{1F1ED}\u{1F1FA}',
    };
    return flags[lang.toLowerCase()] ?? '\u{1F5FA}';
  }

  static String _langDisplayName(String lang) {
    const names = <String, String>{
      'en': 'English',
      'fr': 'Fran\u00e7ais',
      'ja': '\u65e5\u672c\u8a9e',
      'zh': '\u4e2d\u6587',
      'ko': '\ud55c\uad6d\uc5b4',
      'es': 'Espa\u00f1ol',
      'pt': 'Portugu\u00eas',
      'de': 'Deutsch',
      'it': 'Italiano',
      'ru': '\u0420\u0443\u0441\u0441\u043a\u0438\u0439',
      'ar': '\u0639\u0631\u0628\u064a',
      'tr': 'T\u00fcrk\u00e7e',
      'pl': 'Polski',
      'nl': 'Nederlands',
      'id': 'Bahasa Indonesia',
      'th': '\u0e20\u0e32\u0e29\u0e32\u0e44\u0e17\u0e22',
      'vi': 'Ti\u1ebfng Vi\u1ec7t',
      'uk': '\u0423\u043a\u0440\u0430\u0457\u043d\u0441\u044c\u043a\u0430',
      'cs': '\u010ce\u0161tina',
      'ro': 'Rom\u00e2n\u0103',
      'sv': 'Svenska',
      'he': '\u05e2\u05d1\u05e8\u05d9\u05ea',
      'hi': '\u0939\u093f\u0902\u0926\u0940',
      'hu': 'Magyar',
    };
    return names[lang.toLowerCase()] ?? lang.toUpperCase();
  }

  void _showLangGridPicker(List<String> langs) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LangGridPickerSheet(
        langs: langs,
        selected: _globalLangFilter,
        onPick: (v) {
          setState(() => _globalLangFilter = v);
          Navigator.pop(context);
        },
      ),
    );
  }

  // ── Loading / Error ────────────────────────────────────────────────────────────

  Widget _buildError(ColorScheme cs) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.wifi_off_rounded,
          size: 52,
          color: cs.error.withValues(alpha: 0.6),
        ),
        const SizedBox(height: 12),
        Text(
          context.l10n.marketplace_load_error,
          style: TextStyle(fontWeight: FontWeight.w700, color: cs.onSurface),
        ),
        const SizedBox(height: 6),
        FilledButton.tonal(
          onPressed: () => _loadAll(bypassCache: true),
          child: Text(context.l10n.retry),
        ),
      ],
    ),
  );

  // ── Section title ──────────────────────────────────────────────────────────────

  void _closeSearch() {
    if (widget.initialSection == MarketplaceSection.search) {
      context.go('/marketplace');
      return;
    }
    setState(() {
      _searchOpen = false;
      _searchQuery = '';
      _searchCtrl.clear();
    });
  }

  Widget _buildSearchOverlay(ColorScheme cs, ThemeData theme) {
    return Container(
      color: theme.scaffoldBackgroundColor,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Search bar pill (Play Store style) ──────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_rounded, color: cs.onSurface),
                    onPressed: _closeSearch,
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 16),
                          Icon(
                            Icons.search_rounded,
                            size: 20,
                            color: cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _searchCtrl,
                              focusNode: _searchFocus,
                              autofocus: true,
                              onChanged: (v) =>
                                  setState(() => _searchQuery = v),
                              style: TextStyle(
                                fontSize: 15,
                                color: cs.onSurface,
                              ),
                              decoration: InputDecoration(
                                hintText:
                                    context.l10n.marketplace_search_apps_hint,
                                hintStyle: TextStyle(
                                  fontSize: 15,
                                  color: cs.onSurfaceVariant.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                          if (_searchQuery.isNotEmpty)
                            IconButton(
                              icon: Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: cs.onSurfaceVariant,
                              ),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _searchQuery = '');
                              },
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.mic_rounded,
                            size: 22,
                            color: cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 12),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Body ────────────────────────────────────────────────────────
            Expanded(
              child: _searchQuery.isEmpty
                  ? _buildSearchBrowse(cs)
                  : _searchResults.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '(・_・;)',
                            style: TextStyle(
                              fontSize: 46,
                              color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            context.l10n.marketplace_empty_search_title,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            context.l10n.marketplace_empty_search_hint,
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _searchResults.length,
                      itemBuilder: (ctx, i) => _PlayStoreCard(
                        entry: _searchResults[i],
                        installed: _installed.contains(_searchResults[i].id),
                        hasUpdate: _hasUpdate(
                          _searchResults[i].id,
                          _searchResults[i].version,
                        ),
                        busy: _busy[_searchResults[i].id] == true,
                        onInstall: () => _install(_searchResults[i]),
                        onSettings: _installed.contains(_searchResults[i].id)
                            ? () => _openSettings(_searchResults[i].id)
                            : null,
                        onUninstall: _installed.contains(_searchResults[i].id)
                            ? () => _uninstall(_searchResults[i])
                            : null,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBrowse(ColorScheme cs) {
    // Content type categories grid (Play Store style)
    final l10n = context.l10n;
    final categories = [
      (
        _kTabAnime,
        Icons.live_tv_rounded,
        l10n.catalog_tab_watch,
        const Color(0xFF9C27B0),
      ),
      (
        _kTabManga,
        Icons.auto_stories_rounded,
        l10n.catalog_tab_manga,
        const Color(0xFFE91E63),
      ),
      (
        _kTabNovel,
        Icons.menu_book_rounded,
        l10n.catalog_tab_novels,
        const Color(0xFF009688),
      ),
      (
        _kTabMusic,
        Icons.music_note_rounded,
        l10n.catalog_tab_music,
        const Color(0xFF0288D1),
      ),
      (
        _kTabGames,
        Icons.sports_esports_rounded,
        l10n.catalog_tab_games,
        const Color(0xFF607D8B),
      ),
    ];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Text(
              context.l10n.marketplace_browse_extensions,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: cs.onSurface,
              ),
            ),
          ),
          // 2-column grid of categories
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: [
                for (int i = 0; i < categories.length; i += 2)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: _SearchCategoryTile(
                            icon: categories[i].$2,
                            label: categories[i].$3,
                            color: categories[i].$4,
                            onTap: () {
                              _closeSearch();
                              _tabCtrl.animateTo(
                                _tabConstToVisual(categories[i].$1),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (i + 1 < categories.length)
                          Expanded(
                            child: _SearchCategoryTile(
                              icon: categories[i + 1].$2,
                              label: categories[i + 1].$3,
                              color: categories[i + 1].$4,
                              onTap: () {
                                _closeSearch();
                                _tabCtrl.animateTo(
                                  _tabConstToVisual(categories[i + 1].$1),
                                );
                              },
                            ),
                          )
                        else
                          const Expanded(child: SizedBox()),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Recommandations (featured horizontal)
          if (_featured.isNotEmpty) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(
                children: [
                  Text(
                    'Recommandations',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 136,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
                itemCount: _featured.length.clamp(0, 12),
                itemBuilder: (ctx, i) => _MiniCard(
                  entry: _featured[i],
                  installed: _installed.contains(_featured[i].id),
                  hasUpdate: _hasUpdate(
                    _featured[i].id,
                    _featured[i].version,
                    _featured[i].uiLayoutVersion,
                  ),
                  busy: _busy[_featured[i].id] == true,
                  onInstall: () => _install(_featured[i]),
                  onSettings: _installed.contains(_featured[i].id)
                      ? () => _openSettings(_featured[i].id)
                      : null,
                ),
              ),
            ),
          ],

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ── Update detection ──────────────────────────────────────────────────────────

  bool _hasUpdate(
    int id,
    String availableVersion, [
    String? availableLayoutVersion,
  ]) {
    final installed = _installedVersions[id];
    if (installed == null) return false;
    try {
      if (compareVersions(installed, availableVersion) < 0) return true;
      final source = _installedSources[id];
      return availableLayoutVersion != null &&
          source?.uiLayoutVersion != availableLayoutVersion;
    } catch (_) {
      return false;
    }
  }

  void _openSettings(int id) {
    // First: try Isar sources (JS/Dart/APK extensions)
    final source = _installedSources[id];
    if (source != null) {
      context.push('/extension_detail', extra: source);
      return;
    }
    // Music extensions live in the drift DB, not Isar sources.
    final entry = _all.where((e) => e.id == id).firstOrNull;
    if (entry == null || !_isMusicPluginEntry(entry)) return;
    final plugin = _musicPluginFor(entry);
    if (plugin == null) return;
    _showMusicPluginConfigSheet(plugin);
  }

  void _showMusicPluginConfigSheet(PluginConfiguration config) {
    final cs = Theme.of(context).colorScheme;
    final notifier = ref.read(metadataPluginsProvider.notifier);
    final pluginsData = ref.read(metadataPluginsProvider).value;
    if (pluginsData == null) return;
    final isDefaultMetadata =
        pluginsData.defaultMetadataPluginConfig?.slug == config.slug;
    final isDefaultAudioSource =
        pluginsData.defaultAudioSourcePluginConfig?.slug == config.slug;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                config.name,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                config.author,
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              if (config.abilities.contains(PluginAbilities.metadata))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    isDefaultMetadata
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: isDefaultMetadata ? cs.primary : cs.onSurfaceVariant,
                  ),
                  title: Text(
                    context.l10n.marketplace_default_metadata_provider,
                  ),
                  subtitle: Text(
                    isDefaultMetadata
                        ? context.l10n.marketplace_currently_default
                        : context.l10n.marketplace_set_default_provider,
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                  onTap: isDefaultMetadata
                      ? null
                      : () async {
                          await notifier.setDefaultMetadataPlugin(config);
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            setState(() {});
                          }
                        },
                ),
              if (config.abilities.contains(PluginAbilities.audioSource))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    isDefaultAudioSource
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: isDefaultAudioSource
                        ? cs.primary
                        : cs.onSurfaceVariant,
                  ),
                  title: Text(context.l10n.marketplace_default_audio_source),
                  subtitle: Text(
                    isDefaultAudioSource
                        ? context.l10n.marketplace_currently_default
                        : context.l10n.marketplace_set_default_audio_source,
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                  onTap: isDefaultAudioSource
                      ? null
                      : () async {
                          await notifier.setDefaultAudioSourcePlugin(config);
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            setState(() {});
                          }
                        },
                ),
              const Divider(height: 24),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.delete_outline, color: cs.error),
                title: Text(
                  context.l10n.uninstall,
                  style: TextStyle(color: cs.error),
                ),
                onTap: () async {
                  await notifier.removePlugin(config);
                  await _refreshInstalled();
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Compat filter strip ────────────────────────────────────────────────────────

  static String _repoShortLabel(String url) {
    if (url.contains('ferelking') || url.contains('watchtower-extensions')) {
      if (url.contains('/manga/')) return 'WT Manga';
      if (url.contains('/watch/')) return 'WT Watch';
      if (url.contains('/novel/')) return 'WT Novel';
      if (url.contains('/music/')) return 'WT Music';
      if (url.contains('/game/')) return 'WT Jeux';
      return 'Watchtower';
    }
    final parts = url.split('/');
    return parts.length >= 5 ? parts[4] : 'Repo';
  }

  int _activeFilterCount(int tab) {
    int n = 0;
    if (_repoFilter[tab] != null) n++;
    if (_langFilter[tab] != null) n++;
    if (_progLangFilter[tab] != null) n++;
    if (_installedOnly) n++;
    if (_withUpdatesOnly) n++;
    if (_sortBy != 'alpha') n++;
    return n;
  }

  void _clearFilters(int tab) {
    setState(() {
      _repoFilter.remove(tab);
      _langFilter.remove(tab);
      _progLangFilter.remove(tab);
      _compatF[tab] = _CompatF.all;
      _installedOnly = false;
      _withUpdatesOnly = false;
      _sortBy = 'alpha';
    });
  }
}

class _PlayStoreCard extends StatelessWidget {
  final _ExtEntry entry;
  final bool installed;
  final bool hasUpdate;
  final bool busy;
  final VoidCallback onInstall;
  final VoidCallback? onSettings;
  final VoidCallback? onUninstall;
  const _PlayStoreCard({
    required this.entry,
    required this.installed,
    this.hasUpdate = false,
    required this.busy,
    required this.onInstall,
    this.onSettings,
    this.onUninstall,
  });

  String _slugify(String name) => name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');

  String _description(BuildContext context, ItemType t, String lang) {
    final l10n = context.l10n;
    final typeName = switch (t) {
      ItemType.anime => l10n.marketplace_kind_anime,
      ItemType.manga => l10n.marketplace_kind_manga,
      ItemType.novel => l10n.marketplace_kind_novel,
      ItemType.music => l10n.marketplace_kind_music,
      _ => l10n.marketplace_kind_default,
    };
    final langCode = _MarketplaceScreenState._langCode(lang);
    return l10n.marketplace_source_blurb(langCode, typeName);
  }

  String get _codeUrl {
    final url = entry.repoUrl;
    if (url.contains('ferelking242') || url.contains('watchtower-extensions'))
      return 'https://github.com/ferelking242/watchtower-extensions';
    return url;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final compatLabel = _MarketplaceScreenState._compatLabel(entry.compat);
    final langCode = _MarketplaceScreenState._langCode(entry.lang);
    final slug = _slugify(entry.name);
    final localizedDesc = entry.localizedDescription(l10n.localeName);
    final desc = localizedDesc.isNotEmpty
        ? localizedDesc
        : entry.description.isNotEmpty
        ? entry.description
        : _description(context, entry.contentType, entry.lang);

    return GestureDetector(
      onLongPress: (installed && onUninstall != null) ? onUninstall : null,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: installed
              ? cs.primaryContainer.withValues(alpha: 0.08)
              : cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: installed
                ? cs.primary.withValues(alpha: 0.30)
                : cs.outlineVariant.withValues(alpha: 0.25),
            width: installed ? 1.2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: installed
                  ? cs.primary.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row ──────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ExtIcon(
                  iconUrl: entry.iconUrl,
                  itemType: entry.itemType,
                  size: 48,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              entry.name,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: cs.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (installed) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: cs.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Broken.tick_circle,
                                    size: 12,
                                    color: cs.primary,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    'Install\u00e9',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: cs.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        slug,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.65),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // ── Action button ────────────────────────────────────
                _CardAction(
                  installed: installed,
                  hasUpdate: hasUpdate,
                  busy: busy,
                  onInstall: onInstall,
                  onSettings: onSettings,
                  onCode: () async {
                    final url = Uri.parse(_codeUrl);
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  },
                  onUninstall: onUninstall,
                  cs: cs,
                ),
              ],
            ),
            const SizedBox(height: 10),
            // ── Description ──────────────────────────────────────────
            Text(
              desc,
              style: TextStyle(
                fontSize: 13,
                color: cs.onSurfaceVariant,
                height: 1.45,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.star_outline_rounded,
                  size: 14,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.72),
                ),
                const SizedBox(width: 4),
                Text(
                  'v${entry.version}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                _MetaDot(color: cs.onSurfaceVariant),
                Text(
                  _formatMktSize(context.l10n, entry.sizeBytes),
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                ),
                _MetaDot(color: cs.onSurfaceVariant),
                Text(
                  langCode,
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // ── Tags ─────────────────────────────────────────────────
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _TagChip(label: langCode, cs: cs),
                _TagChip(label: compatLabel, cs: cs),
                if (entry.isNsfw)
                  _TagChip(
                    label: context.l10n.marketplace_tag_adult,
                    cs: cs,
                    color: Colors.red.shade400,
                  ),
                if (hasUpdate)
                  _TagChip(
                    label: '↑ v${entry.version}',
                    cs: cs,
                    color: Colors.orange.shade400,
                  ),
                ...entry.subCategories
                    .take(2)
                    .map((c) => _TagChip(label: c, cs: cs, color: cs.primary)),
                if (entry.requiresAccount)
                  _TagChip(
                    label: '🔐 Compte requis',
                    cs: cs,
                    color: Colors.blue.shade400,
                  ),
                if (entry.hasDRM)
                  _TagChip(
                    label: '🔒 DRM',
                    cs: cs,
                    color: Colors.orange.shade600,
                  ),
                if (entry.paywall != 'free' && entry.paywall.isNotEmpty)
                  _TagChip(
                    label: entry.paywall,
                    cs: cs,
                    color: Colors.amber.shade600,
                  ),
                if (entry.isAggregator)
                  _TagChip(
                    label: context.l10n.marketplace_aggregator,
                    cs: cs,
                    color: cs.secondary,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaDot extends StatelessWidget {
  final Color color;
  const _MetaDot({required this.color});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 7),
    child: Text('•', style: TextStyle(fontSize: 11, color: color)),
  );
}

class _TagChip extends StatelessWidget {
  final String label;
  final ColorScheme cs;
  final Color? color;
  final bool filled;
  const _TagChip({
    required this.label,
    required this.cs,
    this.color,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = color ?? cs.onSurfaceVariant;
    if (filled) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: fg.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: fg,
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fg.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: fg),
      ),
    );
  }
}

class _CardAction extends StatelessWidget {
  final bool installed;
  final bool hasUpdate;
  final bool busy;
  final VoidCallback onInstall;
  final VoidCallback? onSettings;
  final VoidCallback? onUninstall;
  final VoidCallback? onCode;
  final ColorScheme cs;
  const _CardAction({
    required this.installed,
    required this.hasUpdate,
    required this.busy,
    required this.onInstall,
    required this.onSettings,
    this.onUninstall,
    required this.onCode,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    if (busy) {
      return Container(
        width: 36,
        height: 36,
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(10),
        ),
        child: CircularProgressIndicator(strokeWidth: 2.2, color: cs.primary),
      );
    }
    if (!installed) {
      return GestureDetector(
        onTap: onInstall,
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: cs.primary.withValues(alpha: 0.20),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            Broken.document_download,
            size: 20,
            color: cs.onPrimaryContainer,
          ),
        ),
      );
    }
    if (hasUpdate) {
      return GestureDetector(
        onTap: onInstall,
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.orange.shade700.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Broken.refresh_2,
            size: 20,
            color: Colors.orange.shade600,
          ),
        ),
      );
    }
    // Installed, no update → settings only
    return GestureDetector(
      onTap: onSettings,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(Broken.setting_2, size: 18, color: cs.onSurfaceVariant),
      ),
    );
  }
}

// ─── Music Plugin Card (music marketplace) ───────────────────────────────────

class _MusicPluginCard extends ConsumerStatefulWidget {
  final MetadataPluginRepository pluginRepo;
  const _MusicPluginCard({required this.pluginRepo});

  @override
  ConsumerState<_MusicPluginCard> createState() => _MusicPluginCardState();
}

class _MusicPluginCardState extends ConsumerState<_MusicPluginCard> {
  bool _installing = false;

  MetadataPluginRepository get _repo => widget.pluginRepo;

  String get _displayName {
    final name = _repo.name;
    if (name.startsWith('spotube-plugin-')) {
      return name
          .replaceFirst('spotube-plugin-', '')
          .replaceAll('-', ' ')
          .trim()
          .split(' ')
          .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
          .join(' ');
    }
    return name.replaceAll('-', ' ').trim();
  }

  bool get _isOfficial => _repo.owner == 'ferelking242';

  String _topicLabel(String topic) => switch (topic) {
    'spotube-metadata-plugin' => 'Metadata',
    'spotube-audio-source-plugin' => 'Source Audio',
    _ => topic,
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final plugins = ref.watch(metadataPluginsProvider);
    final pluginsNotifier = ref.watch(metadataPluginsProvider.notifier);

    final isInstalled =
        plugins.asData?.value.plugins.any(
          (p) => p.repository == _repo.repoUrl,
        ) ??
        false;
    final installedConfig = isInstalled
        ? plugins.asData?.value.plugins
              .where((p) => p.repository == _repo.repoUrl)
              .firstOrNull
        : null;
    final needsLogin =
        installedConfig?.abilities.contains(PluginAbilities.authentication) ??
        false;

    final topics = _repo.topics
        .where(
          (t) =>
              t == 'spotube-metadata-plugin' ||
              t == 'spotube-audio-source-plugin',
        )
        .map(_topicLabel)
        .toList();

    return GestureDetector(
      onLongPress: isInstalled
          ? () async {
              final plugin = plugins.asData?.value.plugins
                  .where((p) => p.repository == _repo.repoUrl)
                  .firstOrNull;
              if (plugin != null) {
                await pluginsNotifier.removePlugin(plugin);
              }
            }
          : null,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isInstalled
              ? cs.primaryContainer.withValues(alpha: 0.08)
              : cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isInstalled
                ? cs.primary.withValues(alpha: 0.30)
                : cs.outlineVariant.withValues(alpha: 0.25),
            width: isInstalled ? 1.2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isInstalled
                  ? cs.primary.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row ──────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Plugin icon — the real logo published by the catalogue, with
                // the same initials fallback the catalogue cards use.
                CatalogIcon(
                  name: _displayName,
                  iconUrl: _repo.iconUrl,
                  size: 48,
                  tint: const Color(0xFF0288D1),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _displayName,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_repo.owner} · Plugin Musique',
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.65),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // ── Action button ────────────────────────────────────────
                if (_installing)
                  Container(
                    width: 36,
                    height: 36,
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: cs.primary,
                    ),
                  )
                else if (!isInstalled)
                  GestureDetector(
                    onTap: () async {
                      setState(() => _installing = true);
                      try {
                        final pluginConfig = await pluginsNotifier
                            .downloadAndCachePlugin(_repo.repoUrl);
                        if (!context.mounted) return;
                        if (_isOfficial) {
                          await pluginsNotifier.addPlugin(pluginConfig);
                        } else {
                          final allowed = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text(
                                context.l10n.plugins_third_party_confirm_title,
                              ),
                              content: Text(
                                context.l10n.plugins_third_party_confirm_body(
                                  _repo.owner,
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: Text(context.l10n.cancel),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: Text(context.l10n.install),
                                ),
                              ],
                            ),
                          );
                          if (allowed == true && context.mounted) {
                            await pluginsNotifier.addPlugin(pluginConfig);
                          }
                        }
                        // Auto-set as default provider when first installed
                        for (int _attempt = 0; _attempt < 5; _attempt++) {
                          await Future<void>.delayed(
                            const Duration(milliseconds: 50),
                          );
                          final _cp = ref.read(metadataPluginsProvider).value;
                          if (_cp != null) {
                            if (pluginConfig.abilities.contains(
                              PluginAbilities.metadata,
                            )) {
                              try {
                                await pluginsNotifier.setDefaultMetadataPlugin(
                                  pluginConfig,
                                );
                              } catch (_) {}
                            }
                            if (pluginConfig.abilities.contains(
                              PluginAbilities.audioSource,
                            )) {
                              try {
                                await pluginsNotifier
                                    .setDefaultAudioSourcePlugin(pluginConfig);
                              } catch (_) {}
                            }
                            break;
                          }
                        }
                      } catch (_) {
                        // ignore install errors silently
                      } finally {
                        if (mounted) setState(() => _installing = false);
                      }
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Broken.document_download,
                        size: 20,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  )
                else
                  GestureDetector(
                    onTap: () => _showPluginConfigSheet(
                      context,
                      ref,
                      plugins,
                      installedConfig!,
                    ),
                    child: Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: cs.primaryContainer.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Broken.setting_2,
                        size: 18,
                        color: cs.primary,
                      ),
                    ),
                  ),
              ],
            ),
            // ── Description ─────────────────────────────────────────────
            if (_repo.description.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                _repo.description,
                style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurfaceVariant,
                  height: 1.45,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 10),
            // ── Tags ────────────────────────────────────────────────────
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (_isOfficial)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Officiel',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Colors.blue.shade400.withValues(alpha: 0.45),
                      ),
                    ),
                    child: Text(
                      'Tiers',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.blue.shade400,
                      ),
                    ),
                  ),
                ...topics.map((t) => _TagChip(label: t, cs: cs)),
              ],
            ),
            // ── Login button (plugins avec authentication) ───────────────
            if (needsLogin) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.login_rounded, size: 16),
                  label: const Text(
                    'Se connecter',
                    style: TextStyle(fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => showModalBottomSheet(
                    context: context,
                    builder: (ctx) => SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.lock_open_rounded,
                              size: 40,
                              color: Theme.of(ctx).colorScheme.primary,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Connexion — $_displayName',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              context.l10n.plugins_auth_required_body,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(
                                  ctx,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 20),
                            FilledButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: Text(context.l10n.marketplace_got_it),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showPluginConfigSheet(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<MetadataPluginState> plugins,
    PluginConfiguration config,
  ) {
    final cs = Theme.of(context).colorScheme;
    final notifier = ref.read(metadataPluginsProvider.notifier);
    final isDefaultMetadata =
        plugins.asData?.value.defaultMetadataPluginConfig?.slug == config.slug;
    final isDefaultAudioSource =
        plugins.asData?.value.defaultAudioSourcePluginConfig?.slug ==
        config.slug;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                config.name,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                config.author,
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              // Set as default metadata provider
              if (config.abilities.contains(PluginAbilities.metadata))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    isDefaultMetadata
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: isDefaultMetadata ? cs.primary : cs.onSurfaceVariant,
                  ),
                  title: Text(
                    context.l10n.marketplace_default_metadata_provider,
                  ),
                  subtitle: Text(
                    isDefaultMetadata
                        ? context.l10n.marketplace_currently_default
                        : context.l10n.marketplace_set_default_provider,
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                  onTap: isDefaultMetadata
                      ? null
                      : () async {
                          await notifier.setDefaultMetadataPlugin(config);
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                ),
              // Set as default audio source
              if (config.abilities.contains(PluginAbilities.audioSource))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    isDefaultAudioSource
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: isDefaultAudioSource
                        ? cs.primary
                        : cs.onSurfaceVariant,
                  ),
                  title: Text(context.l10n.marketplace_default_audio_source),
                  subtitle: Text(
                    isDefaultAudioSource
                        ? context.l10n.marketplace_currently_default
                        : context.l10n.marketplace_set_default_audio_source,
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                  onTap: isDefaultAudioSource
                      ? null
                      : () async {
                          await notifier.setDefaultAudioSourcePlugin(config);
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                ),
              const Divider(height: 24),
              // Uninstall
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.delete_outline, color: cs.error),
                title: Text(
                  context.l10n.uninstall,
                  style: TextStyle(color: cs.error),
                ),
                onTap: () async {
                  await notifier.removePlugin(config);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Music Plugins Section (injecté dans le tab Music) ──────────────────────

class _MusicPluginsSection extends ConsumerWidget {
  const _MusicPluginsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = MarketplacePalette.of(context);
    final snapshot = ref.watch(metadataPluginRepositoriesProvider);
    final repos = snapshot.asData?.value.items ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Same header rhythm as the catalogue shelves, so the music plugins
        // read as one more shelf instead of a differently-styled list.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: palette.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.library_music_rounded,
                  size: 16,
                  color: palette.accent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.l10n.plugins_music_title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: palette.text,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              if (snapshot.isLoading && repos.isEmpty)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ),
        if (repos.isEmpty && !snapshot.isLoading)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              context.l10n.plugins_section_empty,
              style: TextStyle(fontSize: 13, color: palette.muted),
            ),
          )
        else
          ...repos.map((repo) => _MusicPluginCard(pluginRepo: repo)),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ─── Banner card (featured) ────────────────────────────────────────────────────

class _BannerCard extends StatelessWidget {
  final _ExtEntry entry;
  final bool installed;
  final bool hasUpdate;
  final bool busy;
  final VoidCallback onInstall;
  final VoidCallback? onSettings;
  const _BannerCard({
    required this.entry,
    required this.installed,
    this.hasUpdate = false,
    required this.busy,
    required this.onInstall,
    this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final typeColor = _MarketplaceScreenState._typeColor(entry.itemType);
    final compatColor = _MarketplaceScreenState._compatColor(entry.compat, cs);
    final hasIcon = entry.iconUrl != null && entry.iconUrl!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: typeColor.withValues(alpha: 0.30),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background: blurred icon image or gradient fallback
            if (hasIcon)
              ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
                child: Image.network(
                  entry.iconUrl!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (_, _, _) => Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [typeColor, compatColor],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      typeColor.withValues(alpha: 0.85),
                      compatColor.withValues(alpha: 0.65),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            // Dark gradient overlay for text readability
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.62),
                    typeColor.withValues(alpha: 0.55),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _ExtIcon(
                    iconUrl: entry.iconUrl,
                    itemType: entry.itemType,
                    size: 60,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Text(
                          entry.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            shadows: [
                              Shadow(blurRadius: 4, color: Colors.black45),
                            ],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                _MarketplaceScreenState._compatLabel(
                                  entry.compat,
                                ),
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                _MarketplaceScreenState._langCode(entry.lang),
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(
                          width: double.infinity,
                          height: 32,
                          child: installed
                              ? Row(
                                  children: [
                                    // Gear icon
                                    if (onSettings != null)
                                      GestureDetector(
                                        onTap: onSettings,
                                        child: Container(
                                          width: 34,
                                          height: 32,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(
                                              alpha: 0.22,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: const Icon(
                                            Broken.setting_2,
                                            size: 15,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    if (onSettings != null)
                                      const SizedBox(width: 6),
                                    Expanded(
                                      child: hasUpdate
                                          ? GestureDetector(
                                              onTap: busy ? null : onInstall,
                                              child: Container(
                                                height: 32,
                                                alignment: Alignment.center,
                                                decoration: BoxDecoration(
                                                  color: Colors.orange.shade700
                                                      .withValues(alpha: 0.85),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: busy
                                                    ? const SizedBox(
                                                        width: 13,
                                                        height: 13,
                                                        child:
                                                            CircularProgressIndicator(
                                                              strokeWidth: 2,
                                                              color:
                                                                  Colors.white,
                                                            ),
                                                      )
                                                    : Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .center,
                                                        children: [
                                                          Icon(
                                                            Icons
                                                                .system_update_alt_rounded,
                                                            size: 13,
                                                            color: Colors.white,
                                                          ),
                                                          SizedBox(width: 5),
                                                          Text(
                                                            context
                                                                .l10n
                                                                .marketplace_update_available_short,
                                                            style: TextStyle(
                                                              fontSize: 11,
                                                              color:
                                                                  Colors.white,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                              ),
                                            )
                                          : Container(
                                              alignment: Alignment.center,
                                              decoration: BoxDecoration(
                                                color: Colors.white.withValues(
                                                  alpha: 0.22,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Broken.check,
                                                    size: 14,
                                                    color: Colors.white,
                                                  ),
                                                  SizedBox(width: 5),
                                                  Text(
                                                    context.l10n.installed,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                    ),
                                  ],
                                )
                              : FilledButton(
                                  onPressed: busy ? null : onInstall,
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    backgroundColor: Colors.white.withValues(
                                      alpha: 0.25,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: busy
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Text(
                                          context.l10n.install,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniCard extends StatelessWidget {
  final _ExtEntry entry;
  final bool installed;
  final bool hasUpdate;
  final bool busy;
  final VoidCallback onInstall;
  final VoidCallback? onSettings;
  final VoidCallback? onHistory;
  const _MiniCard({
    required this.entry,
    required this.installed,
    this.hasUpdate = false,
    required this.busy,
    required this.onInstall,
    this.onSettings,
    this.onHistory,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: 138,
      margin: const EdgeInsets.only(right: 10, bottom: 2),
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
      decoration: BoxDecoration(
        color: installed
            ? cs.primaryContainer.withValues(alpha: 0.08)
            : cs.surfaceContainerLow.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: installed
              ? cs.primary.withValues(alpha: 0.35)
              : cs.outlineVariant.withValues(alpha: 0.20),
        ),
        boxShadow: [
          BoxShadow(
            color: installed
                ? cs.primary.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _ExtIcon(iconUrl: entry.iconUrl, itemType: entry.itemType, size: 54),
          const SizedBox(height: 8),
          Text(
            entry.name,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'v${entry.version}',
            style: TextStyle(
              fontSize: 10,
              color: cs.onSurfaceVariant.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // Settings button
              if (installed && onSettings != null)
                GestureDetector(
                  onTap: onSettings,
                  child: Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Broken.setting_2,
                      size: 15,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              // Install / Update / Installed button
              Expanded(
                child: SizedBox(
                  height: 30,
                  child: installed
                      ? hasUpdate
                            ? FilledButton(
                                onPressed: busy ? null : onInstall,
                                style: FilledButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  backgroundColor: Colors.orange.shade700,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                ),
                                child: busy
                                    ? const SizedBox(
                                        width: 10,
                                        height: 10,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 1.5,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(
                                        context.l10n.update,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                              )
                            : OutlinedButton(
                                onPressed: onSettings,
                                style: OutlinedButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  side: BorderSide(
                                    color: cs.primary.withValues(alpha: 0.4),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                ),
                                child: Icon(
                                  Broken.check,
                                  size: 14,
                                  color: cs.primary,
                                ),
                              )
                      : FilledButton(
                          onPressed: busy ? null : onInstall,
                          style: FilledButton.styleFrom(
                            padding: EdgeInsets.zero,
                            backgroundColor: cs.primaryContainer,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9),
                            ),
                          ),
                          child: busy
                              ? SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    color: cs.onPrimaryContainer,
                                  ),
                                )
                              : Icon(
                                  Broken.document_download,
                                  size: 15,
                                  color: cs.onPrimaryContainer,
                                ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Stats bar ─────────────────────────────────────────────────────────────────

// ─── Extension icon ─────────────────────────────────────────────────────────────

class _ExtIcon extends StatelessWidget {
  final String? iconUrl;
  final int itemType;
  final double size;
  const _ExtIcon({this.iconUrl, required this.itemType, required this.size});

  bool get _isSvg {
    final url = iconUrl ?? '';
    return url.endsWith('.svg') ||
        url.contains('simpleicons.org') ||
        url.contains('/svg/') ||
        url.contains('jsdelivr.net') && url.contains('/icons/');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = _MarketplaceScreenState._typeColor(itemType);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: iconUrl != null && iconUrl!.isNotEmpty
            ? _isSvg
                  ? SvgPicture.network(
                      iconUrl!,
                      width: size,
                      height: size,
                      fit: BoxFit.contain,
                      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                      placeholderBuilder: (_) => _SkeletonShimmer(
                        width: size,
                        height: size,
                        radius: 12,
                      ),
                    )
                  : Image.network(
                      iconUrl!,
                      width: size,
                      height: size,
                      fit: BoxFit.cover,
                      loadingBuilder: (_, child, progress) => progress == null
                          ? child
                          : _SkeletonShimmer(
                              width: size,
                              height: size,
                              radius: 12,
                            ),
                      errorBuilder: (_, _, _) => _fallback(cs, color),
                    )
            : _fallback(cs, color),
      ),
    );
  }

  Widget _fallback(ColorScheme cs, Color color) => Center(
    child: Icon(
      _MarketplaceScreenState._typeIcon(itemType),
      size: size * 0.48,
      color: color,
    ),
  );
}

// ─── Skeleton shimmer ────────────────────────────────────────────────────────

class _SkeletonShimmer extends StatefulWidget {
  final double width, height, radius;
  const _SkeletonShimmer({
    required this.width,
    required this.height,
    this.radius = 8,
  });
  @override
  State<_SkeletonShimmer> createState() => _SkeletonShimmerState();
}

class _SkeletonShimmerState extends State<_SkeletonShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (_, _) => Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.radius),
        gradient: LinearGradient(
          begin: Alignment(-1 + 2 * _anim.value, 0),
          end: Alignment(1 + 2 * _anim.value, 0),
          colors: [
            Theme.of(context).colorScheme.surfaceContainerHigh,
            Theme.of(context).colorScheme.surfaceContainerHighest,
            Theme.of(context).colorScheme.surfaceContainerHigh,
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
    ),
  );
}

// ─── Icon chip ─────────────────────────────────────────────────────────────────

class _IconChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _IconChip({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: active ? cs.primary : cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? cs.primary : cs.outline.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: active ? cs.onPrimary : cs.onSurfaceVariant,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: active ? cs.onPrimary : cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Repo Carousel ─────────────────────────────────────────────────────────────

class _MarketplaceSettingsSheet extends ConsumerWidget {
  final _MarketplaceScreenState state;
  const _MarketplaceSettingsSheet({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final showNsfw = ref.watch(showNSFWStateProvider);
    final autoUpdate = ref.watch(autoUpdateExtensionsStateProvider);
    final checkUpdates = ref.watch(checkForExtensionsUpdateStateProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.85,
      expand: false,
      builder: (_, sc) => Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 10, bottom: 14),
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                context.l10n.settings,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
            ),
            Divider(
              height: 1,
              indent: 20,
              endIndent: 20,
              color: cs.outlineVariant.withValues(alpha: 0.5),
            ),
            Expanded(
              child: ListView(
                controller: sc,
                padding: const EdgeInsets.only(top: 8, bottom: 32),
                children: [
                  // ── Section : Comportement ─────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
                    child: Text(
                      context.l10n.marketplace_settings_section_behavior,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: cs.primary,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  _LightSettingsTile(
                    icon: Icons.update_rounded,
                    title: context.l10n.check_for_extension_updates,
                    subtitle: context.l10n.marketplace_check_updates_subtitle,
                    value: checkUpdates,
                    onChanged: (v) => ref
                        .read(checkForExtensionsUpdateStateProvider.notifier)
                        .set(v),
                  ),
                  _LightSettingsTile(
                    icon: Broken.refresh_2,
                    title: context.l10n.auto_extensions_updates,
                    subtitle: context.l10n.marketplace_auto_update_subtitle,
                    value: autoUpdate,
                    onChanged: (v) => ref
                        .read(autoUpdateExtensionsStateProvider.notifier)
                        .set(v),
                  ),
                  _LightSettingsTile(
                    icon: Icons.explicit_rounded,
                    title: context.l10n.marketplace_adult_content_title,
                    subtitle: context.l10n.marketplace_adult_content_subtitle,
                    value: showNsfw,
                    onChanged: (v) =>
                        ref.read(showNSFWStateProvider.notifier).set(v),
                  ),
                  Divider(
                    height: 1,
                    indent: 20,
                    endIndent: 20,
                    color: cs.outlineVariant.withValues(alpha: 0.4),
                  ),
                  // ── Section : Dépôts ───────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                    child: Text(
                      context.l10n.marketplace_settings_section_repositories,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: cs.primary,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  _LightActionTile(
                    icon: Icons.folder_special_rounded,
                    title: context.l10n.marketplace_manage_repositories,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ExtensionRepositoriesScreen(),
                        ),
                      );
                    },
                  ),
                  Divider(
                    height: 1,
                    indent: 20,
                    endIndent: 20,
                    color: cs.outlineVariant.withValues(alpha: 0.4),
                  ),
                  // ── Section : Cache ────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                    child: Text(
                      context.l10n.marketplace_settings_section_cache,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: cs.primary,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  _LightActionTile(
                    icon: Broken.refresh_2,
                    title: context.l10n.marketplace_reload_catalogue,
                    onTap: () {
                      Navigator.pop(context);
                      state._loadAll(bypassCache: true);
                    },
                  ),
                  _LightActionTile(
                    icon: Icons.cloud_sync_rounded,
                    title: context.l10n.marketplace_force_reload,
                    onTap: () {
                      Navigator.pop(context);
                      state._loadAll(bypassCache: true);
                    },
                  ),
                  Divider(
                    height: 1,
                    indent: 20,
                    endIndent: 20,
                    color: cs.outlineVariant.withValues(alpha: 0.4),
                  ),
                  // ── Section : Actions ──────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                    child: Text(
                      context.l10n.marketplace_settings_section_actions,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: cs.primary,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: FilledButton.icon(
                      icon: const Icon(
                        Icons.download_for_offline_rounded,
                        size: 18,
                      ),
                      label: Text(context.l10n.marketplace_bulk_install),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        if (context.mounted) {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => _BulkInstallSheet(state: state),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Light tiles for redesigned settings sheet ────────────────────────────────

class _LightSettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _LightSettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SwitchListTile.adaptive(
      secondary: Icon(icon, size: 20, color: cs.onSurfaceVariant),
      title: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: cs.onSurfaceVariant.withValues(alpha: 0.7),
        ),
      ),
      value: value,
      onChanged: onChanged,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
      dense: true,
    );
  }
}

class _LightActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  const _LightActionTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        child: Row(
          children: [
            Icon(icon, size: 20, color: cs.onSurfaceVariant),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(Broken.arrow_right, size: 18, color: cs.outlineVariant),
          ],
        ),
      ),
    );
  }
}

// ─── Account dropdown overlay ─────────────────────────────────────────────────

class _SearchCategoryTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _SearchCategoryTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
            ),
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              child: Icon(icon, size: 26, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Filter chip button (Play Store style) ─────────────────────────────────────

class _MarketplaceFilterButton extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;

  const _MarketplaceFilterButton({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: context.l10n.filter,
      onPressed: onTap,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      icon: Icon(
        Broken.filter,
        size: 19,
        color: active ? cs.primary : cs.onSurfaceVariant,
      ),
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  final String label;
  final bool active;
  final IconData icon;
  final VoidCallback onTap;
  const _FilterChipButton({
    required this.label,
    required this.active,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
        decoration: BoxDecoration(
          color: active ? cs.primaryContainer : cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? cs.primary : cs.outline.withValues(alpha: 0.25),
            width: active ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: active ? cs.primary : cs.onSurfaceVariant,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: active ? cs.primary : cs.onSurface,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down_rounded,
              size: 16,
              color: active ? cs.primary : cs.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Simple picker bottom sheet ────────────────────────────────────────────────

class _SimplePickerSheet extends StatelessWidget {
  final String title;
  final String allLabel;
  final List<(String, String)> items; // (value, display)
  final String? selected;
  final void Function(String? value) onPick;
  const _SimplePickerSheet({
    required this.title,
    required this.allLabel,
    required this.items,
    required this.selected,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, ctrl) => Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: cs.outline.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(Icons.filter_list_rounded, size: 18, color: cs.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Divider(height: 1, color: cs.outline.withValues(alpha: 0.15)),
          Expanded(
            child: ListView(
              controller: ctrl,
              children: [
                // "All" option
                _PickerTile(
                  label: allLabel,
                  selected: selected == null,
                  onTap: () => onPick(null),
                  cs: cs,
                ),
                ...items.map(
                  (item) => _PickerTile(
                    label: item.$2,
                    selected: selected == item.$1,
                    onTap: () => onPick(item.$1),
                    cs: cs,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final ColorScheme cs;
  const _PickerTile({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? cs.primary : cs.onSurface,
        ),
        overflow: TextOverflow.ellipsis,
      ),
      trailing: selected
          ? Icon(Broken.check, size: 18, color: cs.primary)
          : null,
      tileColor: selected ? cs.primaryContainer.withValues(alpha: 0.3) : null,
    );
  }
}
// ─── Language grid picker sheet ────────────────────────────────────────────────

class _LangGridPickerSheet extends StatefulWidget {
  final List<String> langs;
  final String? selected;
  final ValueChanged<String?> onPick;
  const _LangGridPickerSheet({
    required this.langs,
    this.selected,
    required this.onPick,
  });
  @override
  State<_LangGridPickerSheet> createState() => _LangGridPickerSheetState();
}

class _LangGridPickerSheetState extends State<_LangGridPickerSheet> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final all = ['all', ...widget.langs];
    final filtered = all.where((l) {
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return l.toLowerCase().contains(q) ||
          _MarketplaceScreenState._langDisplayName(l).toLowerCase().contains(q);
    }).toList();

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.78,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: cs.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.language_rounded, size: 18, color: cs.primary),
                const SizedBox(width: 8),
                Text(
                  context.l10n.language,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
                const Spacer(),
                if (widget.selected != null)
                  TextButton(
                    onPressed: () => widget.onPick(null),
                    style: TextButton.styleFrom(
                      foregroundColor: cs.error,
                      padding: EdgeInsets.zero,
                    ),
                    child: const Text(
                      'Effacer',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  Icon(
                    Icons.search_rounded,
                    size: 16,
                    color: cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _search,
                      onChanged: (v) => setState(() => _query = v),
                      style: TextStyle(fontSize: 13, color: cs.onSurface),
                      decoration: InputDecoration(
                        hintText: context.l10n.marketplace_search_language_hint,
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 2.4,
              ),
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final l = filtered[i];
                final isAll = l == 'all';
                final sel = isAll
                    ? widget.selected == null
                    : widget.selected == l;
                return GestureDetector(
                  onTap: () => widget.onPick(isAll ? null : l),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    decoration: BoxDecoration(
                      color: sel
                          ? cs.primaryContainer
                          : cs.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: sel
                            ? cs.primary
                            : cs.outlineVariant.withValues(alpha: 0.4),
                        width: sel ? 1.5 : 1,
                      ),
                    ),
                    child: Center(
                      child: isAll
                          ? Text(
                              'Toutes',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: sel
                                    ? cs.onPrimaryContainer
                                    : cs.onSurfaceVariant,
                              ),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _MarketplaceScreenState._langFlag(l),
                                  style: const TextStyle(fontSize: 18),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  _MarketplaceScreenState._langDisplayName(l),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: sel
                                        ? cs.onPrimaryContainer
                                        : cs.onSurfaceVariant,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Prog lang badge ─────────────────────────────────────────────────────────

class _ProgLangBadge extends StatelessWidget {
  final Color color, textColor;
  final String label;
  const _ProgLangBadge({
    required this.color,
    required this.textColor,
    required this.label,
  });
  @override
  Widget build(BuildContext context) => Container(
    width: 18,
    height: 18,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(4),
    ),
    child: Center(
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w900,
          color: textColor,
        ),
      ),
    ),
  );
}

class _AdvancedFilterSheet extends StatefulWidget {
  final _MarketplaceScreenState state;
  final int tab;
  final VoidCallback onChanged;
  const _AdvancedFilterSheet({
    required this.state,
    required this.tab,
    required this.onChanged,
  });

  @override
  State<_AdvancedFilterSheet> createState() => _AdvancedFilterSheetState();
}

class _AdvancedFilterSheetState extends State<_AdvancedFilterSheet> {
  late String _sortBy;
  late bool _installedOnly;
  late bool _withUpdatesOnly;

  @override
  void initState() {
    super.initState();
    _sortBy = widget.state._sortBy;
    _installedOnly = widget.state._installedOnly;
    _withUpdatesOnly = widget.state._withUpdatesOnly;
  }

  void _apply() {
    widget.state._sortBy = _sortBy;
    widget.state._installedOnly = _installedOnly;
    widget.state._withUpdatesOnly = _withUpdatesOnly;
    widget.onChanged();
  }

  void _resetAll() {
    setState(() {
      _sortBy = 'alpha';
      _installedOnly = false;
      _withUpdatesOnly = false;
    });
    widget.state._clearFilters(widget.tab);
    Navigator.pop(context);
  }

  Widget _section(String title, Widget child) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Builder(
        builder: (ctx) => Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Theme.of(ctx).colorScheme.onSurfaceVariant,
            letterSpacing: 0.8,
          ),
        ),
      ),
      const SizedBox(height: 10),
      child,
    ],
  );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final nActive = widget.state._activeFilterCount(widget.tab);

    return DraggableScrollableSheet(
      initialChildSize: 0.68,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, ctrl) => Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.tune_rounded,
                      size: 16,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    context.l10n.marketplace_advanced_filters,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface,
                    ),
                  ),
                  const Spacer(),
                  if (nActive > 0)
                    TextButton(
                      onPressed: _resetAll,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        backgroundColor: cs.errorContainer.withValues(
                          alpha: 0.4,
                        ),
                        foregroundColor: cs.error,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        context.l10n.marketplace_clear_all_filters,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.5)),
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                children: [
                  // Sort section
                  _section(
                    'TRIER PAR',
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _SortChip(
                          label: context.l10n.marketplace_sort_alpha,
                          icon: Icons.sort_by_alpha_rounded,
                          active: _sortBy == 'alpha',
                          onTap: () {
                            setState(() => _sortBy = 'alpha');
                            _apply();
                          },
                        ),
                        _SortChip(
                          label: context.l10n.marketplace_sort_installed,
                          icon: Icons.download_done_rounded,
                          active: _sortBy == 'installed',
                          onTap: () {
                            setState(() => _sortBy = 'installed');
                            _apply();
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Show section
                  _section(
                    context.l10n.marketplace_section_show,
                    Column(
                      children: [
                        _FilterToggleTile(
                          icon: Icons.download_done_rounded,
                          label: context.l10n.marketplace_installed_only,
                          sub: context.l10n.marketplace_installed_only_sub,
                          value: _installedOnly,
                          onChanged: (v) {
                            setState(() {
                              _installedOnly = v;
                              if (v) _withUpdatesOnly = false;
                            });
                            _apply();
                          },
                          cs: cs,
                        ),
                        const SizedBox(height: 6),
                        _FilterToggleTile(
                          icon: Broken.refresh_2,
                          label: context.l10n.marketplace_updates_available,
                          sub: context.l10n.marketplace_updates_available_sub,
                          value: _withUpdatesOnly,
                          onChanged: (v) {
                            setState(() {
                              _withUpdatesOnly = v;
                              if (v) _installedOnly = false;
                            });
                            _apply();
                          },
                          cs: cs,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Active filters
                  if (nActive > 0) ...[
                    _section(
                      context.l10n.marketplace_section_active_filters,
                      _ActiveFiltersSummary(
                        state: widget.state,
                        tab: widget.tab,
                        cs: cs,
                        onClear: () {
                          setState(() {});
                          widget.onChanged();
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Apply button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: const Color(0xFF4F46E5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Appliquer',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Sort chip ────────────────────────────────────────────────────────────────

class _SortChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  const _SortChip({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: active ? cs.primaryContainer : cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: active
                ? cs.primary
                : cs.outlineVariant.withValues(alpha: 0.5),
            width: active ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: active ? cs.onPrimaryContainer : cs.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: active ? cs.onPrimaryContainer : cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Filter toggle tile ───────────────────────────────────────────────────────

class _FilterToggleTile extends StatelessWidget {
  final IconData icon;
  final String label, sub;
  final bool value;
  final ValueChanged<bool> onChanged;
  final ColorScheme cs;
  const _FilterToggleTile({
    required this.icon,
    required this.label,
    required this.sub,
    required this.value,
    required this.onChanged,
    required this.cs,
  });
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => onChanged(!value),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: value
            ? cs.primaryContainer.withValues(alpha: 0.5)
            : cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: value
              ? cs.primary.withValues(alpha: 0.5)
              : cs.outlineVariant.withValues(alpha: 0.4),
          width: value ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: value ? cs.primaryContainer : cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              icon,
              size: 16,
              color: value ? cs.onPrimaryContainer : cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: value ? cs.onPrimaryContainer : cs.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sub,
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          _FToggle(value: value, cs: cs),
        ],
      ),
    ),
  );
}

class _FToggle extends StatelessWidget {
  final bool value;
  final ColorScheme cs;
  const _FToggle({required this.value, required this.cs});
  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 200),
    width: 40,
    height: 24,
    decoration: BoxDecoration(
      color: value ? cs.primary : cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
    ),
    child: AnimatedAlign(
      duration: const Duration(milliseconds: 200),
      alignment: value ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: 18,
        height: 18,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: value
              ? cs.onPrimary
              : cs.onSurfaceVariant.withValues(alpha: 0.7),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 4,
            ),
          ],
        ),
      ),
    ),
  );
}

class _ActiveFiltersSummary extends StatelessWidget {
  final _MarketplaceScreenState state;
  final int tab;
  final ColorScheme cs;
  final VoidCallback onClear;
  const _ActiveFiltersSummary({
    required this.state,
    required this.tab,
    required this.cs,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final chips = <(String, VoidCallback)>[];
    final repo = state._repoFilter[tab];
    if (repo != null)
      chips.add((
        _MarketplaceScreenState._repoShortLabel(repo),
        () {
          state._repoFilter.remove(tab);
          onClear();
        },
      ));
    final lang = state._langFilter[tab];
    if (lang != null)
      chips.add((
        _MarketplaceScreenState._langCode(lang),
        () {
          state._langFilter.remove(tab);
          onClear();
        },
      ));
    final prog = state._progLangFilter[tab];
    if (prog != null)
      chips.add((
        _MarketplaceScreenState._compatLabel(prog),
        () {
          state._progLangFilter.remove(tab);
          onClear();
        },
      ));
    if (state._installedOnly)
      chips.add((
        context.l10n.marketplace_sort_installed,
        () {
          state._installedOnly = false;
          onClear();
        },
      ));
    if (state._withUpdatesOnly)
      chips.add((
        context.l10n.marketplace_with_updates_short,
        () {
          state._withUpdatesOnly = false;
          onClear();
        },
      ));
    if (state._sortBy != 'alpha')
      chips.add((
        'Tri: ${state._sortBy}',
        () {
          state._sortBy = 'alpha';
          onClear();
        },
      ));

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: chips
          .map(
            (c) => GestureDetector(
              onTap: c.$2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: cs.errorContainer.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      c.$1,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: cs.onErrorContainer,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.close_rounded,
                      size: 13,
                      color: cs.onErrorContainer,
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

// ─── Marketplace skeleton loading ──────────────────────────────────────────────

class _ExtVersionEntry {
  final String version;
  final String? date;
  final String? changelog;
  final List<String> tags;
  const _ExtVersionEntry({
    required this.version,
    this.date,
    this.changelog,
    this.tags = const [],
  });
}

// ─── Version history bottom sheet ──────────────────────────────────────────────

// ─── Glass toast notification ─────────────────────────────────────────────────

// ─── Bulk Install Sheet ──────────────────────────────────────────────────────

class _BulkInstallSheet extends StatefulWidget {
  final _MarketplaceScreenState state;
  const _BulkInstallSheet({required this.state});

  @override
  State<_BulkInstallSheet> createState() => _BulkInstallSheetState();
}

class _BulkInstallSheetState extends State<_BulkInstallSheet> {
  final Set<String> _selLangs = {};
  final Set<ItemType> _selTypes = {};
  bool _running = false;
  int _done = 0;
  int _failed = 0;
  int _total = 0;

  static const _typeItems = [
    (ItemType.anime, Icons.live_tv_rounded, 'Watch'),
    (ItemType.manga, Icons.auto_stories_rounded, 'Manga'),
    (ItemType.novel, Icons.menu_book_rounded, 'Novel'),
    (ItemType.music, Icons.music_note_rounded, 'Music'),
    (ItemType.game, Icons.sports_esports_rounded, 'Games'),
  ];

  List<(String, int)> get _availLangs {
    final counts = <String, int>{};
    for (final e in widget.state._all) {
      if (!widget.state._installed.contains(e.id)) {
        counts[e.lang] = (counts[e.lang] ?? 0) + 1;
      }
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.map((e) => (e.key, e.value)).toList();
  }

  List<_ExtEntry> get _toInstall {
    var list = widget.state._all
        .where((e) => !widget.state._installed.contains(e.id))
        .toList();
    if (_selLangs.isNotEmpty)
      list = list.where((e) => _selLangs.contains(e.lang)).toList();
    if (_selTypes.isNotEmpty)
      list = list.where((e) => _selTypes.contains(e.contentType)).toList();
    return list;
  }

  Future<void> _start() async {
    final entries = List<_ExtEntry>.from(_toInstall);
    if (entries.isEmpty) return;
    setState(() {
      _running = true;
      _done = 0;
      _failed = 0;
      _total = entries.length;
    });
    await widget.state._installBulk(
      entries: entries,
      onProgress: (done, total, failed) {
        if (mounted)
          setState(() {
            _done = done;
            _total = total;
            _failed = failed;
          });
      },
    );
    if (mounted) setState(() => _running = false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final toInstall = _toInstall;
    final langs = _availLangs;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      maxChildSize: 0.92,
      builder: (_, ctrl) => Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(
                children: [
                  Icon(
                    Icons.download_for_offline_rounded,
                    size: 20,
                    color: cs.primary,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Installer en masse',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface,
                    ),
                  ),
                  const Spacer(),
                  if (!_running)
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        color: cs.onSurfaceVariant,
                        size: 20,
                      ),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
            ),
            Divider(height: 16, color: cs.outline.withValues(alpha: 0.15)),
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
                children: [
                  Text(
                    context.l10n.categories,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _typeItems.map<Widget>((
                      (ItemType, IconData, String) item,
                    ) {
                      final (type, icon, label) = item;
                      final sel = _selTypes.contains(type);
                      return GestureDetector(
                        onTap: _running
                            ? null
                            : () => setState(() {
                                sel
                                    ? _selTypes.remove(type)
                                    : _selTypes.add(type);
                              }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 140),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: sel
                                ? cs.primaryContainer
                                : cs.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: sel ? cs.primary : cs.outlineVariant,
                              width: sel ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                icon,
                                size: 13,
                                color: sel ? cs.primary : cs.onSurfaceVariant,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                label,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: sel ? cs.primary : cs.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Text(
                        context.l10n.language,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _selLangs.isEmpty
                            ? context.l10n.marketplace_all_option
                            : '(${context.l10n.marketplace_selected_count(_selLangs.length)})',
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: langs.take(40).map<Widget>(((String, int) item) {
                      final (lang, count) = item;
                      final sel = _selLangs.contains(lang);
                      final code = _MarketplaceScreenState._langCode(lang);
                      final flag = _MarketplaceScreenState._langFlag(lang);
                      return GestureDetector(
                        onTap: _running
                            ? null
                            : () => setState(() {
                                sel
                                    ? _selLangs.remove(lang)
                                    : _selLangs.add(lang);
                              }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 140),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: sel
                                ? cs.primaryContainer
                                : cs.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: sel ? cs.primary : cs.outlineVariant,
                              width: sel ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(flag, style: const TextStyle(fontSize: 14)),
                              const SizedBox(width: 5),
                              Text(
                                '$code ($count)',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: sel ? cs.primary : cs.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer.withValues(alpha: 0.30),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: cs.primary.withValues(alpha: 0.20),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 16,
                          color: cs.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            context.l10n.marketplace_bulk_install_count(
                              toInstall.length,
                            ),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: cs.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_running) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _total > 0 ? _done / _total : null,
                        minHeight: 6,
                        backgroundColor: cs.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        context.l10n.marketplace_progress('$_done', '$_total') +
                            (_failed == 0
                                ? ''
                                : ' · ${context.l10n.marketplace_failed_count(_failed)}'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: _running
                        ? OutlinedButton.icon(
                            icon: const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            label: Text(
                              context.l10n.marketplace_installing_progress(
                                '$_done',
                                '$_total',
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: null,
                          )
                        : FilledButton.icon(
                            icon: const Icon(
                              Icons.download_for_offline_rounded,
                              size: 18,
                            ),
                            label: Text(
                              toInstall.isEmpty
                                  ? context.l10n.marketplace_nothing_to_install
                                  : 'Installer ${toInstall.length} extension${toInstall.length > 1 ? "s" : ""}',
                            ),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: toInstall.isEmpty ? null : _start,
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WTToast extends StatefulWidget {
  final String message;
  final bool isError;
  final IconData? icon;
  final VoidCallback onDismiss;
  const _WTToast({
    required this.message,
    required this.onDismiss,
    this.isError = false,
    this.icon,
  });
  @override
  State<_WTToast> createState() => _WTToastState();
}

class _WTToastState extends State<_WTToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
    Future.delayed(const Duration(milliseconds: 2200), () async {
      if (!mounted) return;
      await _ctrl.reverse();
      widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.isError
        ? Colors.red.shade500
        : Colors.deepPurple.shade400;
    return Positioned(
      bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      left: 32,
      right: 32,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: SafeArea(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Builder(
                  builder: (ctx) {
                    final cs = Theme.of(ctx).colorScheme;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHigh.withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.35),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            widget.icon ??
                                (widget.isError
                                    ? Broken.danger
                                    : Icons.info_rounded),
                            size: 18,
                            color: accent,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              widget.message,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Plugin tab sliver ─────────────────────────────────────────────────────────
// Shows plugins from the Watchtower extensions registry in the Marketplace Plugin tab.

// ─── Engine card (binary engines: Aria2) ──────────────────────────────────────
// Shown at the top of the Plugin tab in the marketplace.

// ─── Binary tab ────────────────────────────────────────────────────────────────
// Marketplace plugins and downloadable runtime engines.

class _BinaryTab extends StatelessWidget {
  const _BinaryTab();

  @override
  Widget build(BuildContext context) {
    return const CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: SizedBox(height: 4)),
        SliverToBoxAdapter(child: PluginsSection()),
        // The music plugins are part of the same catalogue surface: they were
        // previously reachable only from the music settings page, so their real
        // logos never showed up in the Marketplace.
        SliverToBoxAdapter(child: _MusicPluginsSection()),
        SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }
}

// ─── Play Store catalogue ─────────────────────────────────────────────────────
//
// This is deliberately a single, focused catalogue surface. The old
// marketplace contained several competing card systems; this one follows the
// mobile Play Store rhythm: compact header, swipeable category tabs, featured
// shelves, full-width app rows and a persistent bottom navigation bar.

class _PlayStoreMarketplaceView extends StatefulWidget {
  final List<_ExtEntry> entries;
  final Set<int> installed;
  final Map<int, String> installedVersions;
  final Map<int, Source> installedSources;
  final Map<int, bool> busy;
  final bool loading;
  final String? error;
  final bool initialSearch;
  final bool showNsfw;
  final VoidCallback onEnableNsfw;
  final VoidCallback onOpenSettings;
  final Future<void> Function(_ExtEntry entry) onInstall;
  final ValueChanged<int> onSettings;
  final Future<void> Function() onRefresh;

  const _PlayStoreMarketplaceView({
    required this.entries,
    required this.installed,
    required this.installedVersions,
    required this.installedSources,
    required this.busy,
    required this.loading,
    required this.error,
    required this.initialSearch,
    required this.showNsfw,
    required this.onEnableNsfw,
    required this.onOpenSettings,
    required this.onInstall,
    required this.onSettings,
    required this.onRefresh,
  });

  @override
  State<_PlayStoreMarketplaceView> createState() =>
      _PlayStoreMarketplaceViewState();
}

class _PlayStoreMarketplaceViewState extends State<_PlayStoreMarketplaceView> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  int _tab = 0;
  bool _searching = false;
  bool _searchFocused = false;
  bool _accountOpen = false;
  final List<String> _recentSearches = [];

  bool _hasUpdate(_ExtEntry entry) {
    final installed = widget.installedVersions[entry.id];
    if (installed == null) return false;
    try {
      if (compareVersions(installed, entry.version) < 0) return true;
    } catch (_) {
      return false;
    }
    final layoutVersion = entry.uiLayoutVersion;
    return layoutVersion != null &&
        layoutVersion.isNotEmpty &&
        widget.installedSources[entry.id]?.uiLayoutVersion != layoutVersion;
  }

  /// Colours for the current theme. Replaces the hard-coded dark constants the
  /// Marketplace used to paint itself with, so the light theme is actually
  /// light instead of a black page with white text.
  MarketplacePalette get _palette => MarketplacePalette.of(context);
  Color get _green => _palette.accent;
  Color get _surface => _palette.surface;
  Color get _surfaceHigh => _palette.surfaceHigh;
  Color get _muted => _palette.muted;

  static const _recentSearchKey = 'marketplace_recent_searches';
  static const _maxRecentSearches = 8;

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(_handleSearchFocus);
    _loadRecentSearches();
    if (widget.initialSearch) {
      _searching = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchFocus.requestFocus();
      });
    }
  }

  Future<void> _loadRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_recentSearchKey);
      if (saved == null || saved.isEmpty || !mounted) return;
      setState(() {
        _recentSearches
          ..clear()
          ..addAll(saved.take(_maxRecentSearches));
      });
    } catch (_) {
      // Search history is a convenience; never block the marketplace on it.
    }
  }

  Future<void> _persistRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_recentSearchKey, _recentSearches);
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchFocus.removeListener(_handleSearchFocus);
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _handleSearchFocus() {
    if (!mounted || _searchFocused == _searchFocus.hasFocus) return;
    setState(() => _searchFocused = _searchFocus.hasFocus);
  }

  List<_ExtEntry> get _visible {
    final query = _searchController.text.trim().toLowerCase();
    var list = widget.entries.where((entry) {
      if (!widget.showNsfw && entry.isNsfw) return false;
      if (query.isEmpty) return true;
      return entry.searchText.contains(query);
    }).toList();

    switch (_tab) {
      case 1:
      case 2:
      case 3:
      case 4:
      case 5:
        list = list.where(_tabMatches).toList();
        break;
    }
    list.sort((a, b) {
      final aNeedsUpdate = _hasUpdate(a);
      final bNeedsUpdate = _hasUpdate(b);
      if (aNeedsUpdate != bNeedsUpdate) return aNeedsUpdate ? -1 : 1;
      final rating = _playRating(b).compareTo(_playRating(a));
      if (rating != 0) return rating;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return list;
  }

  /// True when the current tab would only surface adult entries and the user
  /// has not opted in yet. The gate offers the one-tap opt-in instead of an
  /// empty list.
  bool get _needsNsfwGate {
    if (widget.showNsfw || _visible.isNotEmpty) return false;
    final query = _searchController.text.trim().toLowerCase();
    return widget.entries.any(
      (entry) =>
          entry.isNsfw &&
          _tabMatches(entry) &&
          (query.isEmpty || entry.searchText.contains(query)),
    );
  }

  bool _tabMatches(_ExtEntry entry) {
    // Routed on the raw `itemType`, not [ItemType]: subtitle providers publish
    // itemType 7, which the enum cannot represent and which would otherwise
    // fall through to the wrong tab. Legacy entries default their itemType to
    // `contentType.index`, so the mapping below is unchanged for them.
    switch (_tab) {
      case 1:
        return entry.itemType == 1 || entry.itemType == 7;
      case 2:
        return entry.itemType == 0;
      case 3:
        return entry.itemType == 3;
      case 4:
        return entry.itemType == 4;
      case 5:
        return entry.itemType == 2;
    }
    return true;
  }

  List<_ExtEntry> get _availableUpdates {
    final updates =
        widget.entries
            .where(
              (entry) =>
                  widget.installed.contains(entry.id) &&
                  _hasUpdate(entry) &&
                  (widget.showNsfw || !entry.isNsfw),
            )
            .toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
    return updates;
  }

  static const _tabIcons = [
    Broken.category,
    Broken.video,
    Broken.bookmark,
    Broken.musicnote,
    Broken.game,
    Broken.book_1,
  ];

  /// Tab captions, in the same order as [_tabIcons].
  static List<String> _tabLabelsFor(AppLocalizations l10n) => [
    l10n.catalog_tab_for_you,
    l10n.catalog_tab_watch,
    l10n.catalog_tab_manga,
    l10n.catalog_tab_music,
    l10n.catalog_tab_games,
    l10n.catalog_tab_novels,
  ];

  void _selectTab(int tab) {
    setState(() {
      _tab = tab;
      _searching = false;
    });
  }

  // ── Catalogue shelves ──────────────────────────────────────────────────────
  //
  // Shelves are declared once in [CatalogShelves] and resolved from the tags the
  // index publishes. Nothing here inspects an extension's name: a source is
  // shelved as manhwa because its catalogue says so, not because "manhwa"
  // happens to appear in its title.

  CatalogShelfBuilder<_ExtEntry>? _shelfCache;
  List<_ExtEntry>? _shelfCacheSource;

  /// Shelf resolver for the current catalogue.
  ///
  /// Cached against the catalogue list's identity, so the per-entry tag lists
  /// are computed once per catalogue load rather than once per rebuild. The
  /// parent passes a new list only when the catalogue itself changes.
  CatalogShelfBuilder<_ExtEntry> get _shelfBuilder {
    if (!identical(_shelfCacheSource, widget.entries)) {
      _shelfCacheSource = widget.entries;
      _shelfCache = CatalogShelfBuilder(widget.entries);
    }
    return _shelfCache!;
  }

  List<CatalogShelfContent<_ExtEntry>> _shelvesFor(
    List<CatalogShelfSpec> specs,
  ) => _shelfBuilder.shelves(specs, showNsfw: widget.showNsfw);

  /// The shelves a catalogue tab is built from.
  ///
  /// The adult shelves are appended only once the user has opted in, which
  /// replaces the hard-coded "Midnight World" / "Midnight Library" rows the
  /// discovery page used to append by hand.
  List<CatalogShelfSpec> _specsForTab(int tab) {
    final base = switch (tab) {
      1 => CatalogShelves.watch,
      2 => CatalogShelves.read,
      3 => CatalogShelves.music,
      4 => CatalogShelves.game,
      5 => CatalogShelves.novel,
      _ => const <CatalogShelfSpec>[],
    };
    if (!widget.showNsfw) return base;
    return [
      ...base,
      ...CatalogShelves.adult.where(
        (spec) => switch (tab) {
          1 => spec.medium == CatalogMedium.watch,
          2 || 5 => spec.medium == CatalogMedium.read,
          _ => false,
        },
      ),
    ];
  }

  /// One card, wired to the install state the screen already tracks.
  Widget _buildCatalogCard(_ExtEntry entry) {
    final l10n = context.l10n;
    final installed = widget.installed.contains(entry.id);
    return CatalogCard(
      entry: entry,
      tags: _shelfBuilder.tagsOf(entry),
      iconUrl: _mktIconUrl(entry.iconUrl),
      status: !installed
          ? CatalogCardStatus.available
          : _hasUpdate(entry)
          ? CatalogCardStatus.update
          : CatalogCardStatus.installed,
      isNew: _shelfBuilder.isNew(entry),
      busy: widget.busy[entry.id] == true,
      description: _playDescription(l10n, entry),
      onOpenSite: entry.siteUrl == null
          ? null
          : () => launchUrl(
              Uri.parse(entry.siteUrl!),
              mode: LaunchMode.externalApplication,
            ),
      onTap: () => _showDetails(entry),
      onInstall: () => widget.onInstall(entry),
      onSettings: installed ? () => widget.onSettings(entry.id) : null,
    );
  }

  /// Header plus 2 × 2 swipe grid for each shelf, as slivers.
  List<Widget> _buildShelfSlivers(
    List<CatalogShelfContent<_ExtEntry>> shelves,
  ) {
    final slivers = <Widget>[];
    for (final shelf in shelves) {
      slivers
        ..add(
          SliverToBoxAdapter(
            child: CatalogShelfHeader(
              spec: shelf.spec,
              count: shelf.entries.length,
              onSeeAll: () => _openShelfPage(shelf.spec, shelf.entries),
            ),
          ),
        )
        ..add(
          SliverToBoxAdapter(
            child: CatalogShelfGrid(
              entries: shelf.entries,
              cardBuilder: (context, entry) =>
                  _buildCatalogCard(entry as _ExtEntry),
            ),
          ),
        );
    }
    return slivers;
  }

  /// Opens the full grid for a shelf.
  ///
  /// The resolved entries are handed over as-is, so the page lists exactly what
  /// the shelf listed instead of filtering the catalogue a second time.
  void _openShelfPage(CatalogShelfSpec spec, List<_ExtEntry> entries) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CatalogCategoryPage(
          spec: spec,
          entries: entries,
          cardBuilder: (context, entry) =>
              _buildCatalogCard(entry as _ExtEntry),
        ),
      ),
    );
  }

  /// Hero entries: the catalogue's explicitly featured sources.
  ///
  /// Ordered with the same comparator as the "featured" shelf, so the banner
  /// and the shelf beneath it never disagree about which source leads.
  List<_ExtEntry> get _featured {
    final builder = _shelfBuilder;
    final featured = widget.entries
        .where((entry) => widget.showNsfw || !entry.isNsfw)
        .where((entry) => builder.tagsOf(entry).contains('featured'))
        .toList();
    if (featured.isEmpty) return const [];
    featured.sort(
      (a, b) => CatalogShelves.featured.compare(
        a,
        b,
        builder.tagsOf(a),
        builder.tagsOf(b),
      ),
    );
    return featured.take(6).toList();
  }

  List<String> get _catalogueLanguages =>
      widget.entries
          .where((entry) => widget.showNsfw || !entry.isNsfw)
          .map((entry) => entry.lang.toLowerCase())
          .where((language) => language.isNotEmpty)
          .toSet()
          .toList()
        ..sort();

  /// Name suggestions for the current query, best matches first.
  ///
  /// Returns nothing while the field is empty so the discovery view can show
  /// history and popular categories instead of an arbitrary name dump.
  List<_ExtEntry> get _suggestionEntries {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return const [];
    final scored = <({_ExtEntry entry, int score})>[];
    for (final entry in widget.entries) {
      if (!widget.showNsfw && entry.isNsfw) continue;
      final name = entry.name.toLowerCase();
      final int score;
      if (name == query) {
        score = 0;
      } else if (name.startsWith(query)) {
        score = 1;
      } else if (name.contains(query)) {
        score = 2;
      } else if (entry.searchText.contains(query)) {
        score = 3;
      } else {
        continue;
      }
      scored.add((entry: entry, score: score));
    }
    scored.sort((a, b) {
      final byScore = a.score.compareTo(b.score);
      if (byScore != 0) return byScore;
      return a.entry.name.toLowerCase().compareTo(b.entry.name.toLowerCase());
    });
    return scored.take(6).map((item) => item.entry).toList();
  }

  List<String> get _popularSearches {
    final l10n = context.l10n;
    final types = <ItemType, String>{
      ItemType.anime: l10n.catalog_tab_watch,
      ItemType.manga: l10n.catalog_tab_manga,
      ItemType.novel: l10n.catalog_tab_novels,
      ItemType.music: l10n.catalog_tab_music,
      ItemType.game: l10n.catalog_tab_games,
    };
    return types.entries
        .where(
          (entry) => widget.entries.any(
            (item) =>
                item.contentType == entry.key &&
                (widget.showNsfw || !item.isNsfw),
          ),
        )
        .map((entry) => entry.value)
        .toList();
  }

  void _setSearch(String value) {
    setState(() {});
  }

  void _recordSearch([String? term]) {
    final value = (term ?? _searchController.text).trim();
    if (value.isEmpty) return;
    setState(() {
      _recentSearches.removeWhere(
        (item) => item.toLowerCase() == value.toLowerCase(),
      );
      _recentSearches.insert(0, value);
      if (_recentSearches.length > _maxRecentSearches) {
        _recentSearches.removeRange(_maxRecentSearches, _recentSearches.length);
      }
    });
    _persistRecentSearches();
  }

  void _clearRecentSearches() {
    setState(_recentSearches.clear);
    _persistRecentSearches();
  }

  void _closeSearch() {
    _searchController.clear();
    _searchFocus.unfocus();
    setState(() => _searching = false);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return Center(
      child: SizedBox(
        width: width,
        child: Column(
          children: [
            Expanded(
              child: _accountOpen ? _buildAccount() : _buildMain(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMain(BuildContext context) {
    final l10n = context.l10n;
    return RefreshIndicator(
      color: _green,
      backgroundColor: _surfaceHigh,
      onRefresh: widget.onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(child: _buildHeader()),
          if (!_searching) _buildTabs(),
          if (widget.error != null && widget.entries.isEmpty)
            SliverFillRemaining(hasScrollBody: false, child: _buildError())
          else if (widget.loading && widget.entries.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: _LoadingRows(),
            )
          else if (!_searching && _needsNsfwGate) ...[
            SliverToBoxAdapter(child: _buildHero()),
            SliverToBoxAdapter(child: _buildNsfwGate()),
          ] else if (!_searching && _visible.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildEmptyCatalog(),
            )
          else if (!_searching && _tab == 0)
            ..._buildForYou()
          else if (!_searching) ...[
            SliverToBoxAdapter(child: _buildHero()),
            ..._buildShelfSlivers(_shelvesFor(_specsForTab(_tab))),
            SliverToBoxAdapter(
              child: _buildSectionTitle(
                l10n.marketplace_all_extensions(
                  _tabLabelsFor(context.l10n)[_tab],
                ),
              ),
            ),
            _buildRows(_visible),
          ] else ...[
            SliverToBoxAdapter(child: _buildSearchBar()),
            if (_searchController.text.isEmpty)
              SliverToBoxAdapter(child: _buildSearchDiscovery())
            else if (_visible.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildEmptyCatalog(),
              )
            else ...[
              ..._buildSearchSuggestions(),
              SliverToBoxAdapter(
                child: _buildSectionTitle(l10n.marketplace_search_results),
              ),
              _buildRows(_visible),
            ],
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 28)),
        ],
      ),
    );
  }

  Widget _buildEmptyCatalog() {
    final searchHasQuery =
        _searching && _searchController.text.trim().isNotEmpty;
    final l10n = context.l10n;
    final title = searchHasQuery
        ? l10n.marketplace_empty_search_title
        : l10n.marketplace_empty_catalog_title;
    final subtitle = searchHasQuery
        ? l10n.marketplace_empty_search_hint
        : l10n.marketplace_empty_catalog_hint;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              label: l10n.marketplace_empty_semantics,
              child: Lottie.asset(
                'assets/animations/empty_box_partho.json',
                width: 190,
                height: 190,
                fit: BoxFit.contain,
                repeat: true,
              ),
            ),
            SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: MarketplacePalette.of(context).text,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 14),
            TextButton.icon(
              onPressed: widget.onRefresh,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(l10n.refresh),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final palette = MarketplacePalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 14, 8),
      child: Row(
        children: [
          const _EyeLogo(size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Watchtower',
              style: TextStyle(
                color: palette.text,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.6,
              ),
            ),
          ),
          _HeaderIcon(
            icon: Broken.notification,
            onTap: () => _showNotifications(context),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: context.l10n.marketplace_settings_tooltip,
            child: GestureDetector(
              onTap: widget.onOpenSettings,
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Icon(
                  Icons.view_in_ar_rounded,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  size: 21,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: _surfaceHigh,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: _searchFocused || _searchController.text.isNotEmpty
                      ? _green.withValues(alpha: 0.8)
                      : _palette.border,
                  width: _searchFocused ? 1.4 : 1,
                ),
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocus,
                onTap: () {
                  if (!_searching) setState(() => _searching = true);
                },
                onChanged: _setSearch,
                onSubmitted: (_) => _recordSearch(),
                style: TextStyle(
                  color: MarketplacePalette.of(context).text,
                  fontSize: 14,
                ),
                textAlignVertical: TextAlignVertical.center,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  prefixIcon: Icon(Icons.search_rounded, color: _muted),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  suffixIcon: _searching && _searchController.text.isNotEmpty
                      ? IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                          icon: Icon(Icons.close_rounded, color: _muted),
                        )
                      : Icon(Icons.mic_none_rounded, color: _muted),
                  suffixIconConstraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 48,
                  ),
                  hintText: context.l10n.marketplace_search_hint,
                  hintStyle: TextStyle(color: _muted, fontSize: 14),
                ),
              ),
            ),
          ),
          if (_searching) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: _closeSearch,
              child: Text(context.l10n.cancel, style: TextStyle(color: _green)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _MarketplaceTabHeaderDelegate(
        labels: _tabLabelsFor(context.l10n),
        icons: _tabIcons,
        selected: _tab,
        onSelected: _selectTab,
      ),
    );
  }

  Widget _buildHero() {
    return _buildHeroFor(_featuredForTab(_tab), _heroLabel(_tab));
  }

  /// Caption of the hero banner, so a tab-specific selection is not labelled as
  /// a catalogue-wide recommendation.
  String _heroLabel(int tab) {
    final l10n = context.l10n;
    return switch (tab) {
      1 => l10n.catalog_shelf_for_you_watch,
      2 || 5 => l10n.catalog_shelf_for_you_read,
      3 => l10n.catalog_shelf_music,
      4 => l10n.catalog_shelf_games,
      _ => l10n.catalog_shelf_recommended,
    };
  }

  /// Hero entries for the active tab.
  ///
  /// The banner used to ignore the selected tab and always show the same
  /// catalogue-wide featured sources, so switching to Manga still advertised
  /// watch extensions. Each tab now leads with its own selection: the featured
  /// entries of that tab when the index declares any, otherwise the tab's
  /// entries in the same deterministic order as its shelves.
  List<_ExtEntry> _featuredForTab(int tab) {
    if (tab == 0) return _featured;
    final builder = _shelfBuilder;
    final scoped = _visible.where(_tabMatches).toList();
    if (scoped.isEmpty) return const [];
    final featured = scoped
        .where((entry) => builder.tagsOf(entry).contains('featured'))
        .toList();
    final source = featured.isNotEmpty ? featured : scoped;
    source.sort(
      (a, b) => CatalogShelves.featured.compare(
        a,
        b,
        builder.tagsOf(a),
        builder.tagsOf(b),
      ),
    );
    return source;
  }

  Widget _buildHeroFor(List<_ExtEntry> sourceEntries, String label) {
    final l10n = context.l10n;
    final entries = sourceEntries.take(6).toList();
    if (entries.isEmpty) return const SizedBox(height: 8);
    return SizedBox(
      height: 176,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
        scrollDirection: Axis.horizontal,
        itemCount: entries.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, index) {
          final entry = entries[index];
          final hero = MarketplacePalette.of(context);
          final colors = index.isEven
              ? [hero.heroStart, hero.heroEnd]
              : [hero.heroAlt.$1, hero.heroAlt.$2];
          return SizedBox(
            width: (MediaQuery.sizeOf(context).width - 32)
                .clamp(280.0, 540.0)
                .toDouble(),
            child: GestureDetector(
              onTap: () => _showDetails(entry),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: colors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: 18,
                      top: 18,
                      child: _PlayStoreIcon(entry: entry, size: 82),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 116, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            label,
                            style: TextStyle(
                              color: hero.heroLabel,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            entry.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: hero.heroTitle,
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _playDescription(l10n, entry),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: hero.heroSubtitle,
                              fontSize: 12,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// The "Pour vous" discovery page.
  ///
  /// Composed of the declared [CatalogShelves.forYou] groups, plus two blocks
  /// that are not tag-driven: pending updates, and the language explorer.
  /// A group with too few entries is skipped by the builder, so the page never
  /// renders an empty shelf.
  List<Widget> _buildForYou() {
    final l10n = context.l10n;
    final updates = _availableUpdates;
    final widgets = <Widget>[
      if (updates.isNotEmpty) ...[
        SliverToBoxAdapter(child: _buildSectionTitle(l10n.updates)),
        _buildRows(updates),
      ],
      SliverToBoxAdapter(child: _buildHero()),
      ..._buildShelfSlivers(
        _shelvesFor([
          ...CatalogShelves.forYou,
          if (widget.showNsfw) ...CatalogShelves.adult,
        ]),
      ),
    ];

    widgets
      ..add(
        SliverToBoxAdapter(
          child: _buildSectionTitle(l10n.marketplace_explore_by_language),
        ),
      )
      ..add(SliverToBoxAdapter(child: _buildLanguageExplorer()))
      ..add(
        SliverToBoxAdapter(
          child: _buildSectionTitle(l10n.marketplace_whole_catalogue),
        ),
      )
      ..add(_buildRows(_visible));
    return widgets;
  }

  Widget _buildLanguageExplorer() {
    final languages = _catalogueLanguages;
    if (languages.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 124,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        scrollDirection: Axis.horizontal,
        itemCount: languages.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, index) {
          final language = languages[index];
          final count = widget.entries
              .where(
                (entry) =>
                    entry.lang.toLowerCase() == language &&
                    (widget.showNsfw || !entry.isNsfw),
              )
              .length;
          return InkWell(
            onTap: () {
              _searchController.text = language;
              setState(() {
                _searching = true;
              });
              _searchFocus.requestFocus();
            },
            borderRadius: BorderRadius.circular(16),
            child: Ink(
              width: 132,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _palette.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _MarketplaceScreenState._langFlag(language),
                    style: const TextStyle(fontSize: 25),
                  ),
                  SizedBox(height: 5),
                  Text(
                    _MarketplaceScreenState._langDisplayName(language),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: MarketplacePalette.of(context).text,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    context.l10n.marketplace_source_count(count),
                    style: TextStyle(color: _muted, fontSize: 10),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _applySearch(String value) {
    _searchController.text = value;
    _searchController.selection = TextSelection.collapsed(offset: value.length);
    _recordSearch(value);
    setState(() {
      _searching = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocus.requestFocus();
    });
  }

  Widget _buildSearchDiscovery() {
    final popular = _popularSearches;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_recentSearches.isNotEmpty) ...[
            Row(
              children: [
                Expanded(
                  child: _searchDiscoveryTitle(
                    context.l10n.marketplace_recent_searches,
                  ),
                ),
                TextButton(
                  onPressed: _clearRecentSearches,
                  style: TextButton.styleFrom(
                    foregroundColor: _muted,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 30),
                  ),
                  child: const Text(
                    'Effacer',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            ..._recentSearches.map(
              (term) => _SearchDiscoveryRow(
                icon: Icons.history_rounded,
                label: term,
                onTap: () => _applySearch(term),
              ),
            ),
            const SizedBox(height: 18),
          ],
          if (popular.isNotEmpty) ...[
            _searchDiscoveryTitle('Recherches populaires'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: popular
                  .map(
                    (term) => _SearchChip(
                      label: term,
                      onTap: () => _applySearch(term),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 18),
          ],
          _searchDiscoveryTitle(context.l10n.marketplace_browse_by_category),
          _buildCategories(compact: true),
        ],
      ),
    );
  }

  /// Inline name suggestions shown above the results while typing.
  List<Widget> _buildSearchSuggestions() {
    final l10n = context.l10n;
    final suggestions = _suggestionEntries;
    if (suggestions.isEmpty) return const [];
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _searchDiscoveryTitle('Suggestions'),
              const SizedBox(height: 2),
              ...suggestions.map(
                (entry) => _SearchDiscoveryRow(
                  icon: Icons.north_west_rounded,
                  label: entry.name,
                  trailing:
                      '${_playTypeLabel(l10n, entry)} · ${entry.lang.toUpperCase()}',
                  onTap: () => _applySearch(entry.name),
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  Widget _searchDiscoveryTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        title,
        style: TextStyle(
          color: MarketplacePalette.of(context).text,
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, {bool showArrow = false}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 14, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: MarketplacePalette.of(context).text,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (showArrow)
            IconButton(
              onPressed: () => setState(() => _tab = 1),
              icon: Icon(Icons.arrow_forward_rounded, color: _muted),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }

  /// The full catalogue of a tab, as the same 2-column grid the shelves use.
  Widget _buildRows(List<_ExtEntry> entries) {
    if (entries.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 24),
          child: Text(
            context.l10n.catalog_shelf_empty,
            style: TextStyle(color: _muted, fontSize: 13, height: 1.35),
          ),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      sliver: SliverLayoutBuilder(
        builder: (context, constraints) {
          final columns = (constraints.crossAxisExtent / 200).floor().clamp(
            2,
            6,
          );
          return SliverGrid.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: CatalogCardMetrics.gap,
              crossAxisSpacing: CatalogCardMetrics.gap,
              mainAxisExtent: CatalogCardMetrics.cardHeight,
            ),
            itemCount: entries.length,
            itemBuilder: (context, index) => _buildCatalogCard(entries[index]),
          );
        },
      ),
    );
  }

  Widget _buildNsfwGate() {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 34),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _palette.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _palette.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(
                Icons.visibility_off_rounded,
                color: _palette.accentCyan,
                size: 32,
              ),
              const SizedBox(height: 10),
              Text(
                l10n.marketplace_nsfw_gate_title,
                style: TextStyle(
                  color: MarketplacePalette.of(context).text,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.marketplace_nsfw_gate_body,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _palette.muted,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 15),
              FilledButton.tonal(
                onPressed: widget.onEnableNsfw,
                style: FilledButton.styleFrom(
                  foregroundColor: _palette.onAccent,
                  backgroundColor: _palette.accentCyan,
                ),
                child: Text(l10n.marketplace_nsfw_gate_show),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategories({bool compact = false}) {
    final l10n = context.l10n;
    final accents = _palette.typeAccents;
    final categories = [
      (Icons.live_tv_rounded, l10n.catalog_tab_watch, accents[0], 1),
      (Icons.auto_stories_rounded, l10n.catalog_tab_manga, accents[1], 2),
      (Icons.music_note_rounded, l10n.catalog_tab_music, accents[2], 3),
      (Icons.sports_esports_rounded, l10n.catalog_tab_games, accents[3], 4),
      (Icons.menu_book_rounded, l10n.catalog_tab_novels, accents[4], 5),
    ];
    return Padding(
      padding: EdgeInsets.fromLTRB(16, compact ? 4 : 14, 16, 8),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: categories.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 2.35,
        ),
        itemBuilder: (_, index) {
          final category = categories[index];
          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _selectTab(category.$4),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  SizedBox(width: 12),
                  Icon(category.$1, color: category.$3, size: 27),
                  SizedBox(width: 9),
                  Text(
                    category.$2,
                    style: TextStyle(
                      color: MarketplacePalette.of(context).text,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAccount() {
    final l10n = context.l10n;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => setState(() => _accountOpen = false),
                  icon: Icon(
                    Icons.arrow_back_rounded,
                    color: MarketplacePalette.of(context).text,
                  ),
                ),
                Expanded(
                  child: Text(
                    'Compte',
                    style: TextStyle(
                      color: MarketplacePalette.of(context).text,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: widget.onRefresh,
                  icon: Icon(Broken.refresh_2, color: _muted),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Column(
            children: [
              CircleAvatar(
                radius: 42,
                backgroundColor: _palette.avatar,
                child: Icon(
                  Icons.person_rounded,
                  color: MarketplacePalette.of(context).text,
                  size: 48,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.marketplace_account_title,
                style: TextStyle(
                  color: MarketplacePalette.of(context).text,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.marketplace_installed_count(widget.installed.length),
                style: TextStyle(color: _muted, fontSize: 13),
              ),
            ],
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 28, 16, 100),
            child: Column(
              children: [
                _AccountOption(
                  icon: Icons.download_done_rounded,
                  label: l10n.marketplace_manage_installed,
                  onTap: () => setState(() {
                    _accountOpen = false;
                    _tab = 1;
                  }),
                ),
                const _NtfyToggleTile(),
                _AccountOption(
                  icon: Broken.setting_2,
                  label: l10n.marketplace_preferences,
                  onTap: widget.onOpenSettings,
                ),
                _AccountOption(
                  icon: Icons.help_outline_rounded,
                  label: l10n.marketplace_help_feedback,
                  onTap: () => _showComingSoon(l10n.help),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildError() {
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, color: _muted, size: 48),
            const SizedBox(height: 14),
            Text(
              l10n.marketplace_catalog_unavailable,
              style: TextStyle(
                color: MarketplacePalette.of(context).text,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.marketplace_check_connection,
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, fontSize: 13),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: widget.onRefresh,
              style: FilledButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: _palette.onAccent,
              ),
              child: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetails(_ExtEntry entry) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (pageContext) => Scaffold(
          backgroundColor: _surface,
          appBar: AppBar(
            backgroundColor: _surface,
            foregroundColor: MarketplacePalette.of(context).text,
            title: Text(context.l10n.marketplace_details_title),
          ),
          body: _PlayStoreDetails(
            entry: entry,
            installed: widget.installed.contains(entry.id),
            installedVersion: widget.installedVersions[entry.id],
            hasUpdate: _hasUpdate(entry),
            busy: widget.busy[entry.id] == true,
            onSettings: widget.installed.contains(entry.id)
                ? () {
                    Navigator.pop(pageContext);
                    widget.onSettings(entry.id);
                  }
                : null,
            onInstall: () {
              Navigator.pop(pageContext);
              widget.onInstall(entry);
            },
          ),
        ),
      ),
    );
  }

  void _showNotifications(BuildContext context) {
    context.push('/notifications');
  }

  void _showComingSoon(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.marketplace_coming_soon(label)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

String _playDescription(AppLocalizations l10n, _ExtEntry entry) {
  final localized = entry.localizedDescription(l10n.localeName);
  if (localized.isNotEmpty) return localized;
  if (entry.description.trim().isNotEmpty) return entry.description.trim();
  final language = entry.lang == 'fr'
      ? l10n.marketplace_lang_french
      : entry.lang == 'en'
      ? l10n.marketplace_lang_english
      : entry.lang == 'multi' || entry.lang == 'all'
      ? l10n.marketplace_lang_multilingual
      : entry.lang.toUpperCase();
  final kind = switch (entry.itemType) {
    1 => l10n.marketplace_kind_anime,
    0 => l10n.marketplace_kind_manga,
    2 => l10n.marketplace_kind_novel,
    3 => l10n.marketplace_kind_music,
    7 => l10n.marketplace_kind_subtitles,
    _ => l10n.marketplace_kind_default,
  };
  return l10n.marketplace_source_blurb(language, kind);
}

/// Content-type caption. Reuses the tab captions so a card, its detail page and
/// the tab it came from cannot disagree.
String _playTypeLabel(AppLocalizations l10n, _ExtEntry entry) =>
    switch (entry.itemType) {
      1 => l10n.catalog_tab_watch,
      0 => l10n.catalog_tab_manga,
      2 => l10n.catalog_tab_novels,
      3 => l10n.catalog_tab_music,
      7 => l10n.marketplace_type_subtitles,
      _ => l10n.catalog_tab_games,
    };

double _playRating(_ExtEntry entry) => entry.rating.clamp(0.0, 5.0);

int _playReviewCount(_ExtEntry entry) => entry.reviewCount;

String _playSize(AppLocalizations l10n, _ExtEntry entry) {
  if (entry.sizeBytes != null && entry.sizeBytes! > 0) {
    return _formatMktSize(l10n, entry.sizeBytes);
  }
  return l10n.marketplace_unknown_size;
}

String _playRatingLabel(_ExtEntry entry) =>
    _playRating(entry) > 0 ? _playRating(entry).toStringAsFixed(1) : '—';

String _playReviewLabel(AppLocalizations l10n, _ExtEntry entry) =>
    _playReviewCount(entry) > 0
    ? l10n.marketplace_reviews_count(_playReviewCount(entry))
    : l10n.marketplace_reviews_unavailable;

class _SearchDiscoveryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? trailing;
  final VoidCallback onTap;

  const _SearchDiscoveryRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            Icon(icon, color: MarketplacePalette.of(context).muted, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: MarketplacePalette.of(context).text,
                  fontSize: 13,
                ),
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 10),
              Text(
                trailing!,
                style: TextStyle(
                  color: MarketplacePalette.of(context).muted,
                  fontSize: 11,
                ),
              ),
            ],
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_outward_rounded,
              color: MarketplacePalette.of(context).muted,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SearchChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: MarketplacePalette.of(context).surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: MarketplacePalette.of(context).border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: MarketplacePalette.of(context).text,
            fontSize: 12.5,
          ),
        ),
      ),
    );
  }
}

class _MarketplaceTabHeaderDelegate extends SliverPersistentHeaderDelegate {
  final List<String> labels;
  final List<IconData> icons;
  final int selected;
  final ValueChanged<int> onSelected;

  _MarketplaceTabHeaderDelegate({
    required this.labels,
    required this.icons,
    required this.selected,
    required this.onSelected,
  });

  @override
  double get minExtent => 48;

  @override
  double get maxExtent => 48;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final palette = MarketplacePalette.of(context);
    final selectedColor = palette.accentCyan;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.background,
        border: Border(
          bottom: BorderSide(
            color: overlapsContent ? palette.border : Colors.transparent,
          ),
        ),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        scrollDirection: Axis.horizontal,
        itemCount: labels.length,
        separatorBuilder: (_, _) => const SizedBox(width: 26),
        itemBuilder: (_, index) {
          final isSelected = index == selected;
          return GestureDetector(
            onTap: () => onSelected(index),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icons[index],
                      size: 15,
                      color: isSelected ? selectedColor : palette.muted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      labels[index],
                      style: TextStyle(
                        color: isSelected ? palette.text : palette.muted,
                        fontSize: 13,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: isSelected ? 34 : 0,
                  height: 3,
                  decoration: BoxDecoration(color: selectedColor),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _MarketplaceTabHeaderDelegate oldDelegate) =>
      oldDelegate.selected != selected ||
      oldDelegate.labels != labels ||
      oldDelegate.icons != icons ||
      oldDelegate.onSelected != onSelected;
}

class _PlayStoreDetails extends StatelessWidget {
  final _ExtEntry entry;
  final bool installed;
  final String? installedVersion;
  final bool hasUpdate;
  final bool busy;
  final VoidCallback onInstall;
  final VoidCallback? onSettings;

  const _PlayStoreDetails({
    required this.entry,
    required this.installed,
    this.installedVersion,
    this.hasUpdate = false,
    required this.busy,
    required this.onInstall,
    this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PlayStoreIcon(entry: entry, size: 82),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.name,
                        style: TextStyle(
                          color: MarketplacePalette.of(context).text,
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${_playTypeLabel(l10n, entry)} · ${entry.lang.toUpperCase()}',
                        style: TextStyle(
                          color: MarketplacePalette.of(context).muted,
                          fontSize: 12,
                        ),
                      ),
                      if (installed && installedVersion != null) ...[
                        const SizedBox(height: 5),
                        Text(
                          hasUpdate
                              ? l10n.marketplace_update_available(entry.version)
                              : l10n.marketplace_installed_version_label(
                                  installedVersion!,
                                ),
                          style: TextStyle(
                            color: hasUpdate
                                ? MarketplacePalette.of(context).accent
                                : MarketplacePalette.of(context).muted,
                            fontSize: 11,
                            fontWeight: hasUpdate
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                      SizedBox(height: 10),
                      Row(
                        children: [
                          Text(
                            _playRatingLabel(entry),
                            style: TextStyle(
                              color: MarketplacePalette.of(context).text,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.star_rounded,
                            color: MarketplacePalette.of(context).star,
                            size: 17,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _playReviewLabel(l10n, entry),
                            style: TextStyle(
                              color: MarketplacePalette.of(context).muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: FilledButton(
                      onPressed: busy || (!hasUpdate && installed)
                          ? null
                          : onInstall,
                      style: FilledButton.styleFrom(
                        backgroundColor: MarketplacePalette.of(context).accent,
                        foregroundColor: MarketplacePalette.of(
                          context,
                        ).onAccent,
                        disabledBackgroundColor: MarketplacePalette.of(
                          context,
                        ).disabledSurface,
                        disabledForegroundColor: MarketplacePalette.of(
                          context,
                        ).disabledText,
                      ),
                      child: busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              hasUpdate
                                  ? l10n.marketplace_update
                                  : installed
                                  ? l10n.marketplace_extension_installed
                                  : l10n.install,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                  ),
                ),
                if (installed && onSettings != null) ...[
                  const SizedBox(width: 10),
                  IconButton(
                    onPressed: onSettings,
                    tooltip: context.l10n.settings,
                    style: IconButton.styleFrom(
                      backgroundColor: MarketplacePalette.of(
                        context,
                      ).surfaceHighest,
                    ),
                    icon: Icon(
                      Broken.setting_2,
                      color: MarketplacePalette.of(context).muted,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 25),
            Text(
              l10n.marketplace_about_extension,
              style: TextStyle(
                color: MarketplacePalette.of(context).text,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            _ExpandableDescription(text: _playDescription(l10n, entry)),
            const SizedBox(height: 20),
            Text(
              l10n.marketplace_info_information,
              style: TextStyle(
                color: MarketplacePalette.of(context).text,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Column(
              children: [
                _DetailInfoRow(
                  label: l10n.version,
                  value: installed && installedVersion != null
                      ? 'v$installedVersion · '
                            '${l10n.marketplace_available_version(entry.version)}'
                      : 'v${entry.version}',
                ),
                _DetailInfoRow(
                  label: l10n.marketplace_info_size,
                  value: _playSize(l10n, entry),
                ),
                _DetailInfoRow(
                  label: l10n.language,
                  value: entry.lang.toUpperCase(),
                ),
                _DetailInfoRow(
                  label: l10n.marketplace_info_technology,
                  value: entry.compat == SourceCodeLanguage.javascript
                      ? 'JavaScript'
                      : 'Watchtower',
                ),
                if (entry.requiresAccount)
                  _DetailInfoRow(
                    label: l10n.marketplace_info_access,
                    value: l10n.marketplace_access_required,
                  ),
                if (entry.hasDRM)
                  _DetailInfoRow(
                    label: l10n.marketplace_info_reading,
                    value: 'DRM',
                  ),
                if (entry.isAggregator)
                  _DetailInfoRow(
                    label: l10n.marketplace_info_catalog,
                    value: l10n.marketplace_aggregator,
                  ),
                if (entry.supportsComments)
                  _DetailInfoRow(
                    label: l10n.marketplace_info_community,
                    value: l10n.marketplace_comments,
                  ),
                if (entry.subCategories.isNotEmpty)
                  _DetailInfoRow(
                    label: l10n.marketplace_info_content,
                    value: entry.subCategories.join(' · '),
                  ),
              ],
            ),
            const SizedBox(height: 22),
            if (entry.upstream.isNotEmpty) ...[
              Text(
                l10n.marketplace_info_repo,
                style: TextStyle(
                  color: MarketplacePalette.of(context).text,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                entry.upstream,
                style: TextStyle(
                  color: MarketplacePalette.of(context).muted,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 18),
            ],
            Text(
              l10n.marketplace_official_repo_note,
              style: TextStyle(
                color: MarketplacePalette.of(
                  context,
                ).muted.withValues(alpha: 0.8),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailInfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailInfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: TextStyle(
                color: MarketplacePalette.of(context).muted,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: MarketplacePalette.of(context).text,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _AccountOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: Icon(icon, color: MarketplacePalette.of(context).muted),
      title: Text(
        label,
        style: TextStyle(
          color: MarketplacePalette.of(context).text,
          fontSize: 14,
        ),
      ),
      trailing: Icon(
        Broken.arrow_right,
        color: MarketplacePalette.of(context).muted,
      ),
    );
  }
}

/// Account-screen switch for the ntfy crash signal. Kept next to the account
/// options so the toggle lives with the other settings entry points.
class _NtfyToggleTile extends StatefulWidget {
  const _NtfyToggleTile();

  @override
  State<_NtfyToggleTile> createState() => _NtfyToggleTileState();
}

class _NtfyToggleTileState extends State<_NtfyToggleTile> {
  bool _enabled = AppLogger.ntfyEnabled;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      secondary: Icon(
        Icons.notifications_active_rounded,
        color: MarketplacePalette.of(context).muted,
      ),
      title: Text(
        context.l10n.marketplace_ntfy_signals,
        style: TextStyle(
          color: MarketplacePalette.of(context).text,
          fontSize: 14,
        ),
      ),
      subtitle: Text(
        context.l10n.marketplace_ntfy_error_subtitle,
        style: TextStyle(
          color: MarketplacePalette.of(context).muted,
          fontSize: 12,
        ),
      ),
      value: _enabled,
      onChanged: (value) {
        setState(() => _enabled = value);
        AppLogger.setNtfyEnabled(value);
      },
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      dense: true,
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  final IconData icon;
  final String? badge;
  final VoidCallback onTap;
  const _HeaderIcon({required this.icon, this.badge, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: onTap,
          icon: Icon(
            icon,
            color: MarketplacePalette.of(context).text,
            size: 23,
          ),
          visualDensity: VisualDensity.compact,
        ),
        if (badge != null)
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: MarketplacePalette.of(context).alertSurface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                badge!,
                style: TextStyle(
                  color: MarketplacePalette.of(context).onAlertSurface,
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _PlayStoreIcon extends StatelessWidget {
  final _ExtEntry entry;
  final double size;
  const _PlayStoreIcon({required this.entry, required this.size});

  @override
  Widget build(BuildContext context) {
    final url = _mktIconUrl(entry.iconUrl);
    final isSvg =
        url != null &&
        (url.toLowerCase().contains('.svg') ||
            url.toLowerCase().contains('simpleicons.org'));
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.2),
      child: SizedBox(
        width: size,
        height: size,
        child: url == null || url.isEmpty
            ? _fallback(context)
            : isSvg
            ? SvgPicture.network(
                url,
                fit: BoxFit.contain,
                placeholderBuilder: (_) => _fallback(context),
                errorBuilder: (_, _, _) => _fallback(context),
              )
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _fallback(context),
                loadingBuilder: (_, child, progress) =>
                    progress == null ? child : _fallback(context),
              ),
      ),
    );
  }

  Widget _fallback(BuildContext context) {
    final words = entry.name.trim().split(RegExp(r'\s+'));
    final initials = words
        .where((word) => word.isNotEmpty)
        .take(2)
        .map((word) => word.substring(0, 1).toUpperCase())
        .join();
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            MarketplacePalette.of(context).typeColor(entry.contentType),
            MarketplacePalette.of(context).surfaceHigh,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          initials.isEmpty ? '?' : initials,
          maxLines: 1,
          style: TextStyle(
            color: MarketplacePalette.of(context).onAccent,
            fontSize: size * 0.25,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
      ),
    );
  }
}

/// The extension's description, collapsed to four lines with a "see more".
///
/// The text is exactly what the index publishes and what the extension's own
/// settings page shows; the card never rewrites it, it only decides how much
/// of it fits before offering to expand.
class _ExpandableDescription extends StatefulWidget {
  final String text;

  const _ExpandableDescription({required this.text});

  @override
  State<_ExpandableDescription> createState() => _ExpandableDescriptionState();
}

class _ExpandableDescriptionState extends State<_ExpandableDescription> {
  static const int _collapsedLines = 4;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = l10nLocalizations(context)!;
    final style = TextStyle(
      color: MarketplacePalette.of(context).muted,
      fontSize: 13,
      height: 1.45,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          maxLines: _collapsedLines,
          textDirection: Directionality.of(context),
        )..layout(maxWidth: constraints.maxWidth);
        final overflows = painter.didExceedMaxLines;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.text,
              style: style,
              maxLines: _expanded ? null : _collapsedLines,
              overflow: _expanded
                  ? TextOverflow.visible
                  : TextOverflow.ellipsis,
            ),
            if (overflows)
              TextButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  _expanded
                      ? l10n.catalog_card_see_less
                      : l10n.catalog_card_see_more,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _LoadingRows extends StatelessWidget {
  const _LoadingRows();

  Widget _bone(
    BuildContext context, {
    required double width,
    required double height,
    double radius = 7,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: MarketplacePalette.of(context).surfaceHigh,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  Widget _card(BuildContext context, int index) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 9, 16, 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _bone(context, width: 54, height: 54, radius: 14),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _bone(context, width: 130 + (index % 3) * 25.0, height: 14),
                const SizedBox(height: 6),
                _bone(context, width: 92, height: 10, radius: 5),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _bone(context, width: 28, height: 11, radius: 5),
                    const SizedBox(width: 6),
                    _bone(context, width: 13, height: 13, radius: 7),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _bone(
                        context,
                        width: double.infinity,
                        height: 10,
                        radius: 5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _bone(context, width: 54, height: 34, radius: 17),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ShimmerSkeleton(
      effect: ShimmerEffect(
        baseColor: MarketplacePalette.of(context).skeletonBase,
        highlightColor: MarketplacePalette.of(context).skeletonHighlight,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
            child: Row(
              children: [
                _bone(context, width: 94, height: 13),
                const Spacer(),
                _bone(context, width: 78, height: 30, radius: 15),
              ],
            ),
          ),
          ...List.generate(7, (index) => _card(context, index)),
        ],
      ),
    );
  }
}

class _EyeLogo extends StatelessWidget {
  final double size;
  const _EyeLogo({required this.size});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/app_icons/icon.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}
