import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/settings.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/modules/more/settings/browse/providers/browse_state_provider.dart';
import 'package:watchtower/services/fetch_sources_list.dart';
import 'package:go_router/go_router.dart';
import 'package:watchtower/modules/more/widgets/binaries_section.dart';
import 'package:watchtower/modules/more/settings/browse/extension_repositories_screen.dart';
import 'package:watchtower/modules/music/models/metadata/metadata.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/metadata_plugin_provider.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/core/repositories.dart';

// ─── Constants ─────────────────────────────────────────────────────────────────

// raw.githubusercontent.com — _fetch already appends ?_=timestamp so every
// refresh is a cache-miss and always reflects the latest push immediately.
// No CDN purge needed.
const _kWtBase =
    'https://raw.githubusercontent.com/ferelking242/watchtower-extensions/main';

const _kFeaturedNames = {
  'MangaDex', 'Webtoons', 'Comick', 'MangaPlus', 'NovelUpdates',
  'AsuraScans', 'ReaperScans', 'Bato.to', 'Viz', 'CrunchyRoll',
};

// ─── Compat filter ─────────────────────────────────────────────────────────────

enum _CompatF { all, js }

// ─── Data model ────────────────────────────────────────────────────────────────

class _ExtEntry {
  final int id;
  final String name;
  final String? iconUrl;
  final String lang;
  final String version;
  final ItemType contentType;
  final SourceCodeLanguage compat;
  final bool isNsfw;
  final String repoUrl;
  final List<_ExtVersionEntry> versions;
  final List<String> subCategories;
  final bool requiresAccount;
  final bool hasDRM;
  final bool isAggregator;
  final String paywall;
  final bool supportsComments;
  final String upstream;
  final String description;

  const _ExtEntry({
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
    this.requiresAccount = false,
    this.hasDRM = false,
    this.isAggregator = false,
    this.paywall = 'free',
    this.supportsComments = false,
    this.upstream = '',
    this.description = '',
  });
}

// ─── Top-level parse helpers ───────────────────────────────────────────────────

String _mktConvertLang(Map<dynamic, dynamic> e) {
  final raw = (e['lang'] ?? e['language'] ?? 'en') as String;
  return raw.toLowerCase().replaceAll(' ', '-');
}

List<Map<String, dynamic>> _parseIndexIsolate(Map<String, String> args) {
  final String body = args['body']!;
  final String url = args['url']!;
  final List<dynamic> list;
  try {
    list = jsonDecode(body) as List;
  } catch (_) {
    return [];
  }
  final results = <Map<String, dynamic>>[];
  for (final dynamic raw in list) {
    final e = raw as Map<dynamic, dynamic>;
    if (e['pkg'] != null && e['sources'] != null) {
      final sources = e['sources'] as List;
      if (sources.isEmpty) continue;
      final repoBase = url.replaceFirst('/index.min.json', '');
      final iconUrl = '$repoBase/icon/${e['pkg']}.png';
      final isAnime = (e['pkg'] as String)
          .startsWith('eu.kanade.tachiyomi.animeextension');
      final firstSrc = sources[0] as Map<dynamic, dynamic>;
      final langs = sources.map((s) => (s['lang'] ?? 'en') as String).toSet();
      final lang = langs.length == 1 ? langs.first.toLowerCase() : 'multi';
      results.add({
        'id': 'ext-${firstSrc['id']}'.hashCode,
        'name': (e['name'] ?? firstSrc['name'] ?? '?') as String,
        'iconUrl': iconUrl,
        'lang': lang,
        'version': (e['version'] ?? '?') as String,
        'contentType': isAnime ? 1 : 0,
        'compat': 2,
        'isNsfw': (e['nsfw'] as int? ?? 0) == 1,
        'repoUrl': url,
      });
    } else if (e['id'] != null && e['name'] != null) {
      final itemTypeIdx = (e['itemType'] as int? ?? 0).clamp(0, 4);
      final compatIdx = (e['sourceCodeLanguage'] as int? ?? 1).clamp(0, 2);
      results.add({
        'id': (e['id'] as num).toInt(),
        'name': (e['name'] ?? '?') as String,
        'iconUrl': e['iconUrl'] as String?,
        'lang': (e['lang'] as String? ?? 'all').toLowerCase(),
        'version': (e['version'] ?? '?') as String,
        'contentType': itemTypeIdx,
        'compat': compatIdx,
        'isNsfw': e['isNsfw'] as bool? ?? false,
        'repoUrl': url,
        'subCategories': (e['subCategories'] as List<dynamic>?)?.cast<String>() ?? <String>[],
        'requiresAccount': e['requiresAccount'] as bool? ?? false,
        'hasDRM': e['hasDRM'] as bool? ?? false,
        'isAggregator': e['isAggregator'] as bool? ?? false,
        'paywall': e['paywall'] as String? ?? 'free',
        'supportsComments': e['supportsComments'] as bool? ?? false,
        'upstream': e['upstream'] as String? ?? '',
        'description': e['description'] as String? ?? '',
      });
    }
  }
  final seen = <String>{};
  return results.where((r) {
    final k = '${r["name"]}|${r["contentType"]}|${r["lang"]}';
    return seen.add(k);
  }).toList();
}

List<_ExtEntry> _mapsToEntries(List<Map<String, dynamic>> maps) => maps
    .map((m) => _ExtEntry(
          id: m['id'] as int,
          name: m['name'] as String,
          iconUrl: m['iconUrl'] as String?,
          lang: m['lang'] as String,
          version: m['version'] as String,
          contentType: ItemType.values[m['contentType'] as int],
          compat: SourceCodeLanguage.values[m['compat'] as int],
          isNsfw: m['isNsfw'] as bool,
          repoUrl: m['repoUrl'] as String,
          subCategories: (m['subCategories'] as List<dynamic>?)?.cast<String>() ?? [],
          requiresAccount: m['requiresAccount'] as bool? ?? false,
          hasDRM: m['hasDRM'] as bool? ?? false,
          isAggregator: m['isAggregator'] as bool? ?? false,
          paywall: m['paywall'] as String? ?? 'free',
          supportsComments: m['supportsComments'] as bool? ?? false,
          upstream: m['upstream'] as String? ?? '',
          description: m['description'] as String? ?? '',
        ))
    .toList();

// ─── Screen ────────────────────────────────────────────────────────────────────

class MarketplaceScreen extends ConsumerStatefulWidget {
  const MarketplaceScreen({super.key});
  @override
  ConsumerState<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

// Tab indices
const _kTabHome    = 0;
const _kTabManga   = 1;
const _kTabAnime   = 2;
const _kTabNovel   = 3;
const _kTabGames   = 4;
const _kTabMusic   = 5;
const _kTabBinary  = 6;
const _kTabMihon   = 7;
const _kTabAniyomi = 8;

// Mihon / Aniyomi community APK repo index URLs
const _kMihonMangaRepos = [
  'https://raw.githubusercontent.com/keiyoushi/extensions/repo/index.min.json',
  'https://raw.githubusercontent.com/yuzono/manga-repo/repo/index.min.json',
  'https://raw.githubusercontent.com/Kareadita/tach-extension/repo/index.min.json',
];
const _kAniyomiAnimeRepos = [
  'https://raw.githubusercontent.com/aniyomiorg/aniyomi-extensions/repo/index.min.json',
];

class _MarketplaceScreenState extends ConsumerState<MarketplaceScreen>
    with TickerProviderStateMixin {

  // ── Data ─────────────────────────────────────────────────────────────────────
  List<_ExtEntry> _all = [];
  List<_ExtEntry> _mihonEntries = [];
  List<_ExtEntry> _aniyomiEntries = [];
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
    _kTabMihon: _CompatF.all,
    _kTabAniyomi: _CompatF.all,
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
  static List<_ExtEntry>? _cachedMihon;
  static List<_ExtEntry>? _cachedAniyomi;
  static DateTime? _cacheTime;
  String? _globalLangFilter;
  String? _globalRepoFilter;
  SourceCodeLanguage? _globalProgLangFilter;

  // ── Account dropdown ─────────────────────────────────────────────────────────
  final _accountKey = GlobalKey();
  OverlayEntry? _accountOverlay;
  bool _accountOpen = false;

  // ── Banner ───────────────────────────────────────────────────────────────────
  final _bannerCtrl = PageController(viewportFraction: 0.88);
  Timer? _bannerTimer;
  int _bannerPage = 0;

  void _startBannerTimer(int count) {
    _bannerTimer?.cancel();
    if (count <= 1) return;
    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      _bannerPage = (_bannerPage + 1) % count;
      _bannerCtrl.animateToPage(
        _bannerPage,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  // ── Init ─────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 9, vsync: this);
    if (_cachedAll != null && _cacheTime != null &&
        DateTime.now().difference(_cacheTime!) < const Duration(seconds: 30)) {
      _all = _cachedAll!;
      _mihonEntries = _cachedMihon ?? [];
      _aniyomiEntries = _cachedAniyomi ?? [];
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

  Future<void> _refreshInstalled() async {
    try {
      final allSrcs = await isar.sources.buildQuery<Source>().findAll();
      final sources = allSrcs.where((s) => s.isAdded == true).toList();
      if (mounted) {
        setState(() {
          _installed = sources.map((s) => s.id).whereType<int>().toSet();
          _installedVersions = {
            for (final s in sources)
              if (s.id != null && s.version != null) s.id!: s.version!,
          };
          _installedSources = {
            for (final s in sources) if (s.id != null) s.id!: s,
          };
        });
      }
    } catch (_) {}
  }

  // ── Toast notification ─────────────────────────────────────────────────
  void _showToast(BuildContext ctx, String message, {bool isError = false, IconData? icon}) {
    final overlay = Overlay.of(ctx);
    late OverlayEntry oe;
    oe = OverlayEntry(builder: (_) => _WTToast(
      message: message, isError: isError, icon: icon,
      onDismiss: () { try { oe.remove(); } catch (_) {} },
    ));
    overlay.insert(oe);
    Future.delayed(const Duration(milliseconds: 2800), () {
      try { oe.remove(); } catch (_) {}
    });
  }

  Future<List<_ExtEntry>> _fetch(String url) async {
    final bust = '?_=${DateTime.now().millisecondsSinceEpoch}';
    final bustUrl = url.contains('?') ? url : url + bust;
    final r = await http
        .get(Uri.parse(bustUrl))
        .timeout(const Duration(seconds: 35));
    if (r.statusCode != 200) {
      throw Exception('HTTP ${r.statusCode} pour $url');
    }
    if (r.bodyBytes.isEmpty) {
      throw Exception('Réponse vide pour $url');
    }
    final decodedBody = utf8.decode(r.bodyBytes, allowMalformed: true);
    final maps = r.bodyBytes.length > 80000
        ? await compute(_parseIndexIsolate, {'body': decodedBody, 'url': url})
        : _parseIndexIsolate({'body': decodedBody, 'url': url});
    return _mapsToEntries(maps);
  }

  Future<void> _loadAll({bool bypassCache = false}) async {
      if (_all.isEmpty && _mihonEntries.isEmpty) {
        setState(() { _loading = true; _error = null; });
      } else {
        setState(() { _refreshing = true; });
      }
      if (bypassCache) {
        _cachedAll = null;
        _cachedMihon = null;
        _cachedAniyomi = null;
        _cacheTime = null;
        await _purgeJsDelivr();
      }
      try {
        final results = await Future.wait([
          _fetch('$_kWtBase/index/manga.json').catchError((_) => <_ExtEntry>[]),
          _fetch('$_kWtBase/index/watch.json').catchError((_) => <_ExtEntry>[]),
          _fetch('$_kWtBase/index/novel.json').catchError((_) => <_ExtEntry>[]),
          _fetch('$_kWtBase/index/music.json').catchError((_) => <_ExtEntry>[]),
          _fetch('$_kWtBase/index/game.json').catchError((_) => <_ExtEntry>[]),
          _fetchMihonMerged(_kMihonMangaRepos).catchError((_) => <_ExtEntry>[]),
          _fetchMihonMerged(_kAniyomiAnimeRepos).catchError((_) => <_ExtEntry>[]),
        ]);
        if (mounted) setState(() {
          _all = results.take(5).expand((l) => l).toList();
          _mihonEntries = results[5];
          _aniyomiEntries = results[6];
          _cachedAll = _all;
          _cachedMihon = _mihonEntries;
          _cachedAniyomi = _aniyomiEntries;
          _cacheTime = DateTime.now();
          _loading = false;
          _refreshing = false;
          _error = null;
        });
      } catch (e) {
        if (mounted) setState(() {
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
    const indexes = [
      'index/manga.json',
      'index/watch.json',
      'index/novel.json',
      'index/music.json',
      'index/game.json',
    ];
    await Future.wait(
      indexes.map((p) => http
          .get(Uri.parse('$purgeBase/$p'))
          .timeout(const Duration(seconds: 8))
          .catchError((_) => http.Response('', 200))),
    );
  }

  // ── Install ───────────────────────────────────────────────────────────────────

  Future<void> _install(_ExtEntry entry) async {
    if (_busy[entry.id] == true) return;
    setState(() => _busy[entry.id] = true);
    try {
      // Entrées music (ItemType.music) → plugin Spotube (.smplug) via metadata
      // plugin provider, pas via fetchSourcesList (JS extensions).
      if (entry.contentType == ItemType.music) {
        final repoUrl = entry.upstream.isNotEmpty
            ? entry.upstream
            : entry.repoUrl;
        final pluginsNotifier =
            ref.read(metadataPluginsProvider.notifier);
        final pluginConfig =
            await pluginsNotifier.downloadAndCachePlugin(repoUrl);
        await pluginsNotifier.addPlugin(pluginConfig);
        if (mounted) {
          _showToast(context, '${entry.name} installé',
              icon: Icons.check_circle_rounded);
        }
        return;
      }

      final proxyServer = ref.read(androidProxyServerStateProvider);
      final repo = Repo(
        jsonUrl: entry.repoUrl,
        name: _compatLabel(entry.compat),
        website: '',
      );
      await fetchSourcesList(
        id: entry.id,
        repo: repo,
        refresh: true,
        androidProxyServer: proxyServer,
        autoUpdateExtensions: true,
        itemType: entry.contentType,
      );
      await _refreshInstalled();
      if (mounted) {
        _showToast(context, '${entry.name} installée', icon: Icons.check_circle_rounded);
      }
    } catch (e) {
      if (mounted) {
        _showToast(context, 'Erreur : $e', isError: true, icon: Icons.error_rounded);
      }
    } finally {
      if (mounted) setState(() => _busy.remove(entry.id));
    }
  }



    // ── Silent core: no toasts, no setState ─────────────────────────────────
    Future<void> _installOneCore(_ExtEntry entry) async {
      final proxyServer = ref.read(androidProxyServerStateProvider);
      final repo = Repo(
        jsonUrl: entry.repoUrl,
        name: _compatLabel(entry.compat),
        website: '',
      );
      await fetchSourcesList(
        id: entry.id,
        repo: repo,
        refresh: true,
        androidProxyServer: proxyServer,
        autoUpdateExtensions: true,
        itemType: entry.contentType,
      );
    }

    // ── Bulk install: parallel batches of 4, no toasts, single refresh ──────
    Future<void> _installBulk({
      required List<_ExtEntry> entries,
      required void Function(int done, int total) onProgress,
    }) async {
      if (entries.isEmpty) return;
      var done = 0;
      const batchSize = 4;
      for (int i = 0; i < entries.length; i += batchSize) {
        if (!mounted) break;
        final batch = entries.skip(i).take(batchSize).toList();
        await Future.wait(batch.map((entry) async {
          try {
            await _installOneCore(entry);
          } catch (_) {}
          done++;
          onProgress(done, entries.length);
        }));
      }
      await _refreshInstalled();
    }

    // ── Uninstall ─────────────────────────────────────────────────────────────────

  Future<void> _uninstall(_ExtEntry entry) async {
    final source = _installedSources[entry.id];
    if (source == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Désinstaller ${entry.name}'),
        content: const Text("L'extension sera désinstallée. Réinstallable à tout moment."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Désinstaller'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy[entry.id] = true);
    try {
      await isar.writeTxn(() async {
        final s = await isar.sources.get(source.id!);
        if (s != null) {
          await isar.sources.put(s
            ..isAdded = false
            ..sourceCode = null
            ..updatedAt = DateTime.now().millisecondsSinceEpoch);
        }
      });
      await _refreshInstalled();
      if (mounted) {
      _showToast(context, '${entry.name} désinstallée', icon: Icons.delete_rounded);
      }
    } catch (e) {
      if (mounted) {
      _showToast(context, 'Erreur désinstallation : $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _busy.remove(entry.id));
    }
  }

  // ── Marketplace settings ──────────────────────────────────────────────────────

  void _showVersionHistory(_ExtEntry entry) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => _VersionHistorySheet(entry: entry, state: this),
      );
    }

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
      case _kTabManga:   return _all.where((e) => e.contentType == ItemType.manga).toList();
      case _kTabAnime:   return _all.where((e) => e.contentType == ItemType.anime).toList();
      case _kTabNovel:   return _all.where((e) => e.contentType == ItemType.novel).toList();
      case _kTabGames:   return _all.where((e) => e.contentType == ItemType.game).toList();
      case _kTabMusic:   return _all.where((e) => e.contentType == ItemType.music).toList();
      case _kTabBinary:  return [];
      case _kTabMihon:   return _mihonEntries;
      case _kTabAniyomi: return _aniyomiEntries;
      default:           return [..._all, ..._mihonEntries, ..._aniyomiEntries];
    }
  }

  // Maps visual tab-controller index → logical tab constant
  int _visualToTabConst(int visual) {
    const m = [
      _kTabHome,    // 0
      _kTabAnime,   // 1 Watch
      _kTabManga,   // 2 Manga
      _kTabMihon,   // 3 Mihon
      _kTabAniyomi, // 4 Aniyomi
      _kTabNovel,   // 5 Novel
      _kTabGames,   // 6 Game
      _kTabMusic,   // 7 Music
      _kTabBinary,  // 9 Binary
    ];
    return visual < m.length ? m[visual] : _kTabHome;
  }

  // Maps logical tab constant → visual tab-controller index
  int _tabConstToVisual(int tabConst) {
    const m = {
      _kTabHome: 0,    _kTabAnime: 1,   _kTabManga: 2,
      _kTabMihon: 3,   _kTabAniyomi: 4, _kTabNovel: 5,
      _kTabGames: 6,   _kTabMusic: 7,
      _kTabBinary: 8,
    };
    return m[tabConst] ?? 0;
  }

  // Compare version strings (e.g. "14.12.3" vs "14.13.0")
  int _compareVersions(String a, String b) {
    final pa = a.split('.').map((v) => int.tryParse(v) ?? 0).toList();
    final pb = b.split('.').map((v) => int.tryParse(v) ?? 0).toList();
    for (int i = 0; i < pa.length || i < pb.length; i++) {
      final va = i < pa.length ? pa[i] : 0;
      final vb = i < pb.length ? pb[i] : 0;
      if (va != vb) return va.compareTo(vb);
    }
    return 0;
  }

  // Fetch from multiple repos and deduplicate by name|contentType keeping
  // the highest version (same dedup strategy as Mihon itself)
  Future<List<_ExtEntry>> _fetchMihonMerged(List<String> repoUrls) async {
    final all = <_ExtEntry>[];
    for (final url in repoUrls) {
      try {
        all.addAll(await _fetch(url));
      } catch (_) {}
    }
    final best = <String, _ExtEntry>{};
    for (final e in all) {
      final key = '${e.name.toLowerCase()}|${e.contentType.index}|${e.lang}';
      final ex = best[key];
      if (ex == null || _compareVersions(e.version, ex.version) > 0) {
        best[key] = e;
      }
    }
    return best.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  List<_ExtEntry> _forTab(int tab) {
      List<_ExtEntry> list = List<_ExtEntry>.from(_forTabRaw(tab));
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        list = list.where((e) =>
            e.name.toLowerCase().contains(q) ||
            e.lang.toLowerCase().contains(q)).toList();
      }
      if (!_showNsfw) list = list.where((e) => !e.isNsfw).toList();
      if (_globalRepoFilter != null) {
        list = list.where((e) => e.repoUrl.contains(_globalRepoFilter!)).toList();
      }
      if (_globalProgLangFilter != null) {
        list = list.where((e) => e.compat == _globalProgLangFilter).toList();
      }
      if (_globalLangFilter != null) {
        list = list.where((e) => e.lang == _globalLangFilter).toList();
      }
      if (_installedOnly) list = list.where((e) => _installed.contains(e.id)).toList();
      if (_withUpdatesOnly) list = list.where((e) => _hasUpdate(e.id, e.version)).toList();
      if (_sortBy == 'alpha') {
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      } else if (_sortBy == 'installed') {
        list.sort((a, b) {
          final ai = _installed.contains(a.id) ? 0 : 1;
          final bi = _installed.contains(b.id) ? 0 : 1;
          if (ai != bi) return ai.compareTo(bi);
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
      }
      return list;
    }
  List<_ExtEntry> get _searchResults {
    if (_searchQuery.isEmpty) return [];
    final q = _searchQuery.toLowerCase();
    return [..._all, ..._mihonEntries, ..._aniyomiEntries]
        .where((e) => e.name.toLowerCase().contains(q) || e.lang.toLowerCase().contains(q))
        .take(80)
        .toList();
  }

  List<_ExtEntry> get _featured => _all
      .where((e) => _kFeaturedNames.contains(e.name))
      .toList()..sort((a, b) => a.name.compareTo(b.name));

  // ── Static helpers ────────────────────────────────────────────────────────────

  static String _compatLabel(SourceCodeLanguage c) => switch (c) {
    SourceCodeLanguage.mihon => 'APK',
    SourceCodeLanguage.javascript => 'JS',
    SourceCodeLanguage.dart => 'Dart',
  };

  static Color _compatColor(SourceCodeLanguage c, ColorScheme cs) => switch (c) {
    SourceCodeLanguage.mihon => const Color(0xFF2196F3),
    SourceCodeLanguage.javascript => const Color(0xFFF5A623),
    SourceCodeLanguage.dart => const Color(0xFF00B4D8),
  };

  static IconData _typeIcon(ItemType t) => switch (t) {
    ItemType.anime => Icons.live_tv_rounded,
    ItemType.manga => Icons.auto_stories_rounded,
    ItemType.novel => Icons.menu_book_rounded,
    ItemType.music => Icons.music_note_rounded,
    _ => Icons.sports_esports_rounded,
  };

  static Color _typeColor(ItemType t) => switch (t) {
    ItemType.anime => const Color(0xFF9C27B0),
    ItemType.manga => const Color(0xFFE91E63),
    ItemType.novel => const Color(0xFF009688),
    ItemType.music => const Color(0xFF0288D1),
    _ => const Color(0xFF607D8B),
  };

  static String _langCode(String lang) {
    final l = lang.toLowerCase();
    if (l == 'all' || l == 'multi') return 'MULTI';
    if (l.contains('-')) return l.split('-').map((p) => p.toUpperCase()).join('-');
    return l.length > 3 ? l.substring(0, 3).toUpperCase() : l.toUpperCase();
  }

  static Color _langColor(String lang) {
    const colors = <String, Color>{
      'en': Color(0xFF1565C0), 'fr': Color(0xFFC62828), 'ja': Color(0xFFAD1457),
      'zh': Color(0xFFB71C1C), 'ko': Color(0xFF283593), 'es': Color(0xFFF57F17),
      'pt': Color(0xFF2E7D32), 'de': Color(0xFF37474F), 'it': Color(0xFF558B2F),
      'ru': Color(0xFF4527A0), 'ar': Color(0xFF00695C), 'tr': Color(0xFFBF360C),
    };
    return colors[lang.toLowerCase()] ?? const Color(0xFF546E7A);
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
      final cs = Theme.of(context).colorScheme;
      final theme = Theme.of(context);
      _showNsfw = ref.watch(showNSFWStateProvider);

      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            if (_error != null && _all.isEmpty)
              _buildError(cs)
            else
              Column(
                children: [
                  _buildLogoRow(cs, theme),
                  _buildPersistentSearch(cs, theme),
                  _buildTabBarRow(cs, theme),
                  _buildFilterRows(cs, theme),
                  Expanded(
                    child: TabBarView(
                      controller: _tabCtrl,
                      children: [
                        _TypeTab(state: this, tab: _kTabHome),    // 0 Tout
                        _TypeTab(state: this, tab: _kTabAnime),   // 1 Watch
                        _TypeTab(state: this, tab: _kTabManga),   // 2 Manga
                        _TypeTab(state: this, tab: _kTabMihon),   // 3 Mihon
                        _TypeTab(state: this, tab: _kTabAniyomi), // 4 Aniyomi
                        _TypeTab(state: this, tab: _kTabNovel),   // 5 Novel
                        _TypeTab(state: this, tab: _kTabGames),   // 6 Game
                        _TypeTab(state: this, tab: _kTabMusic),   // 7 Music
                        const _BinaryTab(),                       // 9 Binary
                      ],
                    ),
                  ),
                ],
              ),
            if (_refreshing)
              Positioned(
                top: 0, left: 0, right: 0,
                child: LinearProgressIndicator(
                  minHeight: 2, color: cs.primary,
                  backgroundColor: Colors.transparent,
                ),
              ),
          ],
        ),
      );
    }

    // ── Mass install ─────────────────────────────────────────────────────────────

  Future<void> _massInstall({required String lang, SourceCodeLanguage? compat}) async {
    var toInstall = _all
        .where((e) => e.lang == lang && !_installed.contains(e.id))
        .toList();
    if (compat != null) {
      toInstall = toInstall.where((e) => e.compat == compat).toList();
    }
    for (final entry in toInstall) {
      await _install(entry);
    }
  }

  void _showMassInstallSheet() {
    final langs = _all.map((e) => e.lang).toSet().toList()..sort();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _MassInstallSheet(
        state: this,
        langs: langs,
        installedIds: _installed,
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
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/icons/playstore_icon.png',
                      width: 42, height: 42, fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Watchtower',
                        style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800,
                          color: cs.onSurface, letterSpacing: -0.3)),
                      Text('Extension Marketplace',
                        style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('18+', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
                    const SizedBox(width: 2),
                    Transform.scale(
                      scale: 0.78,
                      child: Switch(
                        value: _showNsfw,
                        onChanged: (v) => ref.read(showNSFWStateProvider.notifier).state = v,
                        activeColor: Colors.red.shade400,
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
  void _toggleAccountDropdown() {
    if (_accountOpen) {
      _closeAccountDropdown();
    } else {
      _openAccountDropdown();
    }
  }

  void _openAccountDropdown() {
    setState(() => _accountOpen = true);
    final renderBox = _accountKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    _accountOverlay = OverlayEntry(
      builder: (_) => _AccountDropdownOverlay(
        position: Offset(offset.dx + size.width, offset.dy + size.height + 6),
        onDismiss: _closeAccountDropdown,
        onSettings: () {
          _closeAccountDropdown();
          _showMarketplaceSettings();
        },
        onRepos: () {
          _closeAccountDropdown();
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => const ExtensionRepositoriesScreen(),
          ));
        },
      ),
    );
    Overlay.of(context).insert(_accountOverlay!);
  }

  void _closeAccountDropdown() {
    _accountOverlay?.remove();
    _accountOverlay = null;
    if (mounted) setState(() => _accountOpen = false);
  }


  // ── Tab bar row (pinned — inside NestedScrollView body) ───────────────────────

  Widget _buildTabBarRow(ColorScheme cs, ThemeData theme) {
    // Row 1: Tout | Watch | Manga | Mihon | Aniyomi
    // Row 2: Novel | Game | Music | Binary
    const labels = [
      'Tout', 'Watch', 'Manga', 'Mihon', 'Aniyomi',
      'Novel', 'Game', 'Music', 'Plugin', 'Binary',
    ];
    const icons = <IconData>[
      Icons.apps_rounded, Icons.live_tv_rounded, Icons.auto_stories_rounded,
      Icons.android_rounded, Icons.smart_display_rounded,
      Icons.menu_book_rounded, Icons.sports_esports_rounded,
      Icons.music_note_rounded, Icons.extension_rounded, Icons.memory_rounded,
    ];
    return Container(
      color: theme.scaffoldBackgroundColor,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
        child: AnimatedBuilder(
          animation: _tabCtrl,
          builder: (_, __) => Container(
            width: double.infinity,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFF18181B),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF27272A)),
            ),
            child: Column(
              children: () {
                Widget chip(int i) {
                  final sel = _tabCtrl.index == i;
                  return Expanded(child: GestureDetector(
                    onTap: () { _tabCtrl.animateTo(i); setState(() { _globalLangFilter = null; _globalRepoFilter = null; _globalProgLangFilter = null; }); },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
                      decoration: BoxDecoration(
                        color: sel ? const Color(0xFF27272A) : Colors.transparent,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(icons[i], size: 11, color: sel ? const Color(0xFFE4E4E7) : const Color(0xFF52525B)),
                        const SizedBox(width: 3),
                        Flexible(child: Text(labels[i], style: TextStyle(fontSize: 11,
                          fontWeight: sel ? FontWeight.w600 : FontWeight.w500,
                          color: sel ? const Color(0xFFE4E4E7) : const Color(0xFF71717A)),
                          overflow: TextOverflow.ellipsis, maxLines: 1)),
                      ]),
                    ),
                  ));
                }
                return <Widget>[
                  Row(children: [chip(0), chip(1), chip(2), chip(3), chip(4)]),
                  const SizedBox(height: 2),
                  Row(children: [chip(5), chip(6), chip(7), chip(8), chip(9)]),
                ];
              }(),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildPersistentSearch(ColorScheme cs, ThemeData theme) {
      return Container(
        color: theme.scaffoldBackgroundColor,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
          child: Container(
            height: 42,
            decoration: const BoxDecoration(
              color: Color(0xFF1C1C1F),
              borderRadius: BorderRadius.all(Radius.circular(10)),
              border: Border.fromBorderSide(
                BorderSide(color: Color(0xFF2A2A2E)),
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 12),
                const Icon(Icons.search_rounded, size: 16, color: Color(0xFF71717A)),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    style: const TextStyle(fontSize: 14, color: Color(0xFFE4E4E7)),
                    decoration: InputDecoration(
                      hintText: 'Rechercher une extension…',
                      hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF52525B)),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 14, color: Color(0xFF71717A)),
                    onPressed: () { _searchCtrl.clear(); setState(() => _searchQuery = ''); },
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                const SizedBox(width: 10),
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
    final activeCount = (_globalRepoFilter != null ? 1 : 0)
        + (_globalProgLangFilter != null ? 1 : 0)
        + (_globalLangFilter != null ? 1 : 0);

    BoxDecoration deco(bool active) => BoxDecoration(
      color: const Color(0xFF18181B),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: active ? const Color(0xFF4F46E5) : const Color(0xFF27272A)),
    );

    return Container(
      color: theme.scaffoldBackgroundColor,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 4),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Expanded(
              child: Container(
                height: 36, padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: deco(_globalRepoFilter != null),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: _globalRepoFilter, isExpanded: true, isDense: true,
                    icon: const Icon(Icons.expand_more_rounded, size: 14, color: Color(0xFF71717A)),
                    style: TextStyle(fontSize: 12, color: _globalRepoFilter != null ? const Color(0xFFA5B4FC) : const Color(0xFFA1A1AA)),
                    dropdownColor: const Color(0xFF1C1C1F),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('D\u00e9p\u00f4t', style: TextStyle(fontSize: 12, color: Color(0xFFA1A1AA)))),
                      ...repos.map((r) {
                        final label = r.contains('ferelking242') ? '\u2b50 Official' : r.split('/').lastOrNull ?? r;
                        return DropdownMenuItem<String?>(value: r,
                          child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFFE4E4E7))));
                      }),
                    ],
                    onChanged: (v) => setState(() => _globalRepoFilter = v),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 92,
              child: Container(
                height: 36, padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: deco(_globalProgLangFilter != null),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<SourceCodeLanguage?>(
                    value: _globalProgLangFilter, isExpanded: true, isDense: true,
                    icon: const Icon(Icons.expand_more_rounded, size: 12, color: Color(0xFF71717A)),
                    dropdownColor: const Color(0xFF1C1C1F),
                    selectedItemBuilder: (_) => [
                      Center(child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.code_rounded, size: 12, color: Color(0xFFA1A1AA)), const SizedBox(width: 4), const Text('Lang', style: TextStyle(fontSize: 11, color: Color(0xFFA1A1AA)))])),
                      Center(child: Row(mainAxisSize: MainAxisSize.min, children: [_ProgLangBadge(color: const Color(0xFFF7DF1E), textColor: const Color(0xFF000000), label: 'JS'), const SizedBox(width: 4), const Text('JS', style: TextStyle(fontSize: 11, color: Color(0xFFA5B4FC)))])),
                      Center(child: Row(mainAxisSize: MainAxisSize.min, children: [_ProgLangBadge(color: const Color(0xFF0175C2), textColor: Colors.white, label: 'D'), const SizedBox(width: 4), const Text('Dart', style: TextStyle(fontSize: 11, color: Color(0xFFA5B4FC)))])),
                    ],
                    items: const [
                      DropdownMenuItem<SourceCodeLanguage?>(value: null, child: Text('Tous', style: TextStyle(fontSize: 12, color: Color(0xFFA1A1AA)))),
                      DropdownMenuItem<SourceCodeLanguage?>(value: SourceCodeLanguage.javascript,
                        child: Row(children: [_ProgLangBadge(color: Color(0xFFF7DF1E), textColor: Color(0xFF000000), label: 'JS'), SizedBox(width: 8), Text('JavaScript', style: TextStyle(fontSize: 12, color: Color(0xFFE4E4E7)))])),
                      DropdownMenuItem<SourceCodeLanguage?>(value: SourceCodeLanguage.dart,
                        child: Row(children: [_ProgLangBadge(color: Color(0xFF0175C2), textColor: Colors.white, label: 'D'), SizedBox(width: 8), Text('Dart', style: TextStyle(fontSize: 12, color: Color(0xFFE4E4E7)))])),
                    ],
                    onChanged: (v) => setState(() => _globalProgLangFilter = v),
                  ),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _showLangGridPicker(humanLangs),
                child: Container(
                  height: 36, padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: deco(_globalLangFilter != null),
                  child: Row(children: [
                    const Icon(Icons.language_outlined, size: 14, color: Color(0xFF71717A)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(
                      _globalLangFilter != null ? '${_MarketplaceScreenState._langFlag(_globalLangFilter!)} ${_MarketplaceScreenState._langDisplayName(_globalLangFilter!)}' : 'Langue',
                      style: TextStyle(fontSize: 12, color: _globalLangFilter != null ? const Color(0xFFA5B4FC) : const Color(0xFFA1A1AA)),
                      overflow: TextOverflow.ellipsis,
                    )),
                    const Icon(Icons.expand_more_rounded, size: 14, color: Color(0xFF71717A)),
                  ]),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Stack(clipBehavior: Clip.none, children: [
              GestureDetector(
                onTap: _showMarketplaceSettings,
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF18181B), borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: activeCount > 0 ? const Color(0xFF4F46E5) : const Color(0xFF27272A)),
                  ),
                  child: Icon(Icons.tune_rounded, size: 16,
                      color: activeCount > 0 ? const Color(0xFF818CF8) : const Color(0xFF71717A)),
                ),
              ),
              if (activeCount > 0) Positioned(top: -5, right: -5,
                child: Container(
                  width: 14, height: 14,
                  decoration: const BoxDecoration(color: Color(0xFF4F46E5), shape: BoxShape.circle),
                  child: Center(child: Text('$activeCount', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white))),
                )),
            ]),
          ]),
        ]),
      ),
    );
  }

  static String _langFlag(String lang) {
    const flags = <String, String>{
      'en': '\u{1F1EC}\u{1F1E7}', 'fr': '\u{1F1EB}\u{1F1F7}',
      'ja': '\u{1F1EF}\u{1F1F5}', 'zh': '\u{1F1E8}\u{1F1F3}',
      'ko': '\u{1F1F0}\u{1F1F7}', 'es': '\u{1F1EA}\u{1F1F8}',
      'pt': '\u{1F1E7}\u{1F1F7}', 'de': '\u{1F1E9}\u{1F1EA}',
      'it': '\u{1F1EE}\u{1F1F9}', 'ru': '\u{1F1F7}\u{1F1FA}',
      'ar': '\u{1F1F8}\u{1F1E6}', 'tr': '\u{1F1F9}\u{1F1F7}',
      'pl': '\u{1F1F5}\u{1F1F1}', 'nl': '\u{1F1F3}\u{1F1F1}',
      'id': '\u{1F1EE}\u{1F1E9}', 'th': '\u{1F1F9}\u{1F1ED}',
      'vi': '\u{1F1FB}\u{1F1F3}', 'uk': '\u{1F1FA}\u{1F1E6}',
      'cs': '\u{1F1E8}\u{1F1FF}', 'ro': '\u{1F1F7}\u{1F1F4}',
      'sv': '\u{1F1F8}\u{1F1EA}', 'he': '\u{1F1EE}\u{1F1F1}',
      'hi': '\u{1F1EE}\u{1F1F3}', 'hu': '\u{1F1ED}\u{1F1FA}',
    };
    return flags[lang.toLowerCase()] ?? '\u{1F5FA}';
  }

  static String _langDisplayName(String lang) {
    const names = <String, String>{
      'en': 'English', 'fr': 'Fran\u00e7ais', 'ja': '\u65e5\u672c\u8a9e',
      'zh': '\u4e2d\u6587', 'ko': '\ud55c\uad6d\uc5b4', 'es': 'Espa\u00f1ol',
      'pt': 'Portugu\u00eas', 'de': 'Deutsch', 'it': 'Italiano',
      'ru': '\u0420\u0443\u0441\u0441\u043a\u0438\u0439', 'ar': '\u0639\u0631\u0628\u064a',
      'tr': 'T\u00fcrk\u00e7e', 'pl': 'Polski', 'nl': 'Nederlands',
      'id': 'Bahasa Indonesia', 'th': '\u0e20\u0e32\u0e29\u0e32\u0e44\u0e17\u0e22',
      'vi': 'Ti\u1ebfng Vi\u1ec7t', 'uk': '\u0423\u043a\u0440\u0430\u0457\u043d\u0441\u044c\u043a\u0430',
      'cs': '\u010ce\u0161tina', 'ro': 'Rom\u00e2n\u0103',
      'sv': 'Svenska', 'he': '\u05e2\u05d1\u05e8\u05d9\u05ea',
      'hi': '\u0939\u093f\u0902\u0926\u0940', 'hu': 'Magyar',
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
        onPick: (v) { setState(() => _globalLangFilter = v); Navigator.pop(context); },
      ),
    );
  }
  
  // ── Loading / Error ────────────────────────────────────────────────────────────

  Widget _buildLoading(ColorScheme cs) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      CircularProgressIndicator(color: cs.primary),
      const SizedBox(height: 14),
      Text('Chargement des extensions…', style: TextStyle(color: cs.onSurfaceVariant)),
    ]),
  );

  Widget _buildError(ColorScheme cs) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.wifi_off_rounded, size: 52, color: cs.error.withValues(alpha: 0.6)),
      const SizedBox(height: 12),
      Text('Erreur de chargement', style: TextStyle(fontWeight: FontWeight.w700, color: cs.onSurface)),
      const SizedBox(height: 6),
      FilledButton.tonal(onPressed: () => _loadAll(bypassCache: true), child: const Text('Réessayer')),
    ]),
  );

  // ── Section title ──────────────────────────────────────────────────────────────

  Widget sectionTitle(ColorScheme cs, String title, IconData icon,
      {Color? color, String? subtitle, VoidCallback? onSeeAll}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 12, 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color ?? cs.primary),
          const SizedBox(width: 7),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: cs.onSurface)),
              if (subtitle != null)
                Text(subtitle, style: TextStyle(fontSize: 10.5, color: cs.onSurfaceVariant.withValues(alpha: 0.7))),
            ]),
          ),
          if (onSeeAll != null)
            TextButton(
              onPressed: onSeeAll,
              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: const Size(0, 28)),
              child: Text('Voir tout', style: TextStyle(fontSize: 11.5, color: color ?? cs.primary)),
            ),
        ],
      ),
    );
  }

  // ── Banner (featured auto-scroll) ─────────────────────────────────────────────

  Widget buildBanner(List<_ExtEntry> entries, ColorScheme cs) {
    if (entries.isEmpty) return const SizedBox.shrink();
    final show = entries.take(8).toList();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startBannerTimer(show.length));
    return SizedBox(
      height: 170,
      child: PageView.builder(
        controller: _bannerCtrl,
        itemCount: show.length,
        onPageChanged: (p) => _bannerPage = p,
        itemBuilder: (ctx, i) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: _BannerCard(
            entry: show[i],
            installed: _installed.contains(show[i].id),
            hasUpdate: _hasUpdate(show[i].id, show[i].version),
            busy: _busy[show[i].id] == true,
            onInstall: () => _install(show[i]),
            onSettings: _installed.contains(show[i].id) ? () => _openSettings(show[i].id) : null,
          ),
        ),
      ),
    );
  }

  // ── Horizontal mini-carousel ───────────────────────────────────────────────────

  Widget buildHorizontal(List<_ExtEntry> entries, ColorScheme cs) {
    final show = entries.take(20).toList();
    return SizedBox(
      height: 192,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
        itemCount: show.length,
        itemBuilder: (ctx, i) => _MiniCard(
          entry: show[i],
          installed: _installed.contains(show[i].id),
          hasUpdate: _hasUpdate(show[i].id, show[i].version),
          busy: _busy[show[i].id] == true,
          onInstall: () => _install(show[i]),
          onSettings: _installed.contains(show[i].id) ? () => _openSettings(show[i].id) : null,
        ),
      ),
    );
  }

  // ── Search overlay (Play Store style) ────────────────────────────────────────

  void _closeSearch() {
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
                          Icon(Icons.search_rounded, size: 20, color: cs.onSurfaceVariant),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _searchCtrl,
                              focusNode: _searchFocus,
                              autofocus: true,
                              onChanged: (v) => setState(() => _searchQuery = v),
                              style: TextStyle(fontSize: 15, color: cs.onSurface),
                              decoration: InputDecoration(
                                hintText: 'Rechercher des applis et des je…',
                                hintStyle: TextStyle(fontSize: 15, color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                          if (_searchQuery.isNotEmpty)
                            IconButton(
                              icon: Icon(Icons.close_rounded, size: 18, color: cs.onSurfaceVariant),
                              onPressed: () { _searchCtrl.clear(); setState(() => _searchQuery = ''); },
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            ),
                          const SizedBox(width: 8),
                          Icon(Icons.mic_rounded, size: 22, color: cs.onSurfaceVariant),
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
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Text('(・_・;)', style: TextStyle(fontSize: 46, color: cs.onSurfaceVariant.withValues(alpha: 0.4))),
                            const SizedBox(height: 12),
                            Text('Aucune extension trouvée', style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
                            const SizedBox(height: 4),
                            Text('Essaye un autre nom ou une langue', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant.withValues(alpha: 0.6))),
                          ]),
                        )
                      : ListView.builder(
                          itemCount: _searchResults.length,
                          itemBuilder: (ctx, i) => _PlayStoreCard(
                            entry: _searchResults[i],
                            installed: _installed.contains(_searchResults[i].id),
                            hasUpdate: _hasUpdate(_searchResults[i].id, _searchResults[i].version),
                            busy: _busy[_searchResults[i].id] == true,
                            onInstall: () => _install(_searchResults[i]),
                            onSettings: _installed.contains(_searchResults[i].id) ? () => _openSettings(_searchResults[i].id) : null,
                            onUninstall: _installed.contains(_searchResults[i].id) ? () => _uninstall(_searchResults[i]) : null,
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
    final categories = [
      (_kTabAnime,   Icons.live_tv_rounded,       'Anime',   const Color(0xFF9C27B0)),
      (_kTabManga,   Icons.auto_stories_rounded,  'Manga',   const Color(0xFFE91E63)),
      (_kTabMihon,   Icons.android_rounded,       'Mihon',   const Color(0xFF2196F3)),
      (_kTabAniyomi, Icons.smart_display_rounded, 'Aniyomi', const Color(0xFF00BCD4)),
      (_kTabNovel,   Icons.menu_book_rounded,     'Novel',   const Color(0xFF009688)),
      (_kTabMusic,   Icons.music_note_rounded,    'Music',   const Color(0xFF0288D1)),
      (_kTabGames,   Icons.sports_esports_rounded,'Jeux',    const Color(0xFF607D8B)),
    ];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Text(
              'Parcourir les extensions',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: cs.onSurface),
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
                        Expanded(child: _SearchCategoryTile(
                          icon: categories[i].$2,
                          label: categories[i].$3,
                          color: categories[i].$4,
                          onTap: () {
                            _closeSearch();
                            _tabCtrl.animateTo(_tabConstToVisual(categories[i].$1));
                          },
                        )),
                        const SizedBox(width: 8),
                        if (i + 1 < categories.length)
                          Expanded(child: _SearchCategoryTile(
                            icon: categories[i + 1].$2,
                            label: categories[i + 1].$3,
                            color: categories[i + 1].$4,
                            onTap: () {
                              _closeSearch();
                              _tabCtrl.animateTo(_tabConstToVisual(categories[i + 1].$1));
                            },
                          ))
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
                  Text('Recommandations', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: cs.onSurface)),
                  const Spacer(),
                  Icon(Icons.more_vert_rounded, size: 20, color: cs.onSurfaceVariant),
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
                  hasUpdate: _hasUpdate(_featured[i].id, _featured[i].version),
                  busy: _busy[_featured[i].id] == true,
                  onInstall: () => _install(_featured[i]),
                  onSettings: _installed.contains(_featured[i].id) ? () => _openSettings(_featured[i].id) : null,
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

  bool _hasUpdate(int id, String availableVersion) {
    final installed = _installedVersions[id];
    if (installed == null) return false;
    try {
      return compareVersions(installed, availableVersion) < 0;
    } catch (_) {
      return false;
    }
  }

  int get _updatableCount => _all
      .where((e) => _installed.contains(e.id) && _hasUpdate(e.id, e.version))
      .length;

  void _openSettings(int id) {
    final source = _installedSources[id];
    if (source == null) return;
    context.push('/extension_detail', extra: source);
  }

  // ── Compat filter strip ────────────────────────────────────────────────────────

  Widget buildCompatFilter(ColorScheme cs, int tab) {
    final items = [
      (_CompatF.all, Icons.apps_rounded, 'Tout'),
      
      (_CompatF.js, Icons.code_rounded, 'JS / Dart'),
    ];
    final cf = _compatF[tab] ?? _CompatF.all;
    return SizedBox(
      height: 42,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        itemCount: items.length,
        itemBuilder: (_, i) {
          final (f, icon, label) = items[i];
          final active = cf == f;
          return _IconChip(
            icon: icon, label: label, active: active,
            onTap: () => setState(() => _compatF[tab] = active ? _CompatF.all : f),
          );
        },
      ),
    );
  }

  // ── Play Store filter strip (3 dropdowns + funnel) ───────────────────────────

  static String _repoLabel(String url) {
    if (url.contains('ferelking') || url.contains('watchtower-extensions')) {
      if (url.contains('/manga/')) return 'Watchtower Manga';
      if (url.contains('/watch/')) return 'Watchtower Watch';
      if (url.contains('/novel/')) return 'Watchtower Novel';
      if (url.contains('/music/')) return 'Watchtower Music';
      if (url.contains('/game/')) return 'Watchtower Jeux';
      return 'Watchtower';
    }
    final parts = url.split('/');
    return parts.length >= 5 ? parts[4] : url;
  }

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

  Widget buildFilterStrip(int tab) {
    final cs = Theme.of(context).colorScheme;
    final raw = _forTabRaw(tab);
    final repos = raw.map((e) => e.repoUrl).toSet().toList()..sort();
    final langs = raw.map((e) => e.lang).toSet().toList()..sort();
    final progLangs = raw.map((e) => e.compat).toSet().toList();

    final nActive = _activeFilterCount(tab);

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Dépôt
                  _FilterChipButton(
                    label: _repoFilter[tab] != null
                        ? _repoShortLabel(_repoFilter[tab]!)
                        : 'Dépôt',
                    active: _repoFilter[tab] != null,
                    icon: Icons.folder_outlined,
                    onTap: () => _showRepoMenu(tab, repos),
                  ),
                  const SizedBox(width: 7),
                  // Langue
                  _FilterChipButton(
                    label: _langFilter[tab] != null
                        ? _langCode(_langFilter[tab]!)
                        : 'Langue',
                    active: _langFilter[tab] != null,
                    icon: Icons.language_outlined,
                    onTap: () => _showLangMenu(tab, langs),
                  ),
                  const SizedBox(width: 7),
                  // Langage de prog
                  _FilterChipButton(
                    label: _progLangFilter[tab] != null
                        ? _compatLabel(_progLangFilter[tab]!)
                        : 'Langage',
                    active: _progLangFilter[tab] != null,
                    icon: Icons.code_outlined,
                    onTap: () => _showProgLangMenu(tab, progLangs),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Funnel icon — advanced
          GestureDetector(
            onTap: () => _showAdvancedFilterSheet(tab),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 38,
              height: 34,
              decoration: BoxDecoration(
                color: nActive > 0 ? cs.primary : cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.tune_rounded,
                    size: 18,
                    color: nActive > 0 ? cs.onPrimary : cs.onSurfaceVariant,
                  ),
                  if (nActive > 0)
                    Positioned(
                      top: 3,
                      right: 3,
                      child: Container(
                        width: 13,
                        height: 13,
                        decoration: BoxDecoration(
                          color: cs.error,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '$nActive',
                            style: TextStyle(fontSize: 7.5, color: cs.onError, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showRepoMenu(int tab, List<String> repos) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _SimplePickerSheet(
        title: 'Dépôt',
        allLabel: 'Tous les dépôts',
        items: repos.map((r) => (r, _repoLabel(r))).toList(),
        selected: _repoFilter[tab],
        onPick: (v) { setState(() => _repoFilter[tab] = v); Navigator.pop(context); },
      ),
    );
  }

  void _showLangMenu(int tab, List<String> langs) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _SimplePickerSheet(
        title: 'Langue',
        allLabel: 'Toutes les langues',
        items: langs.map((l) => (l, '${_langCode(l)} — $l')).toList(),
        selected: _langFilter[tab],
        onPick: (v) { setState(() => _langFilter[tab] = v); Navigator.pop(context); },
      ),
    );
  }

  void _showProgLangMenu(int tab, List<SourceCodeLanguage> progLangs) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _SimplePickerSheet(
        title: 'Langage de programmation',
        allLabel: 'Tous les langages',
        items: progLangs.map((p) => (p.index.toString(), _compatLabel(p))).toList(),
        selected: _progLangFilter[tab]?.index.toString(),
        onPick: (v) {
          setState(() => _progLangFilter[tab] = v == null ? null : SourceCodeLanguage.values[int.parse(v)]);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showAdvancedFilterSheet(int tab) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _AdvancedFilterSheet(
        state: this,
        tab: tab,
        onChanged: () => setState(() {}),
      ),
    );
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

  void markDirty() => setState(() {});
}

// ─── Home tab ──────────────────────────────────────────────────────────────────

class _HomeTab extends StatelessWidget {
  final _MarketplaceScreenState state;
  const _HomeTab({required this.state});

  static const _manhuaLangs = {'zh', 'ko', 'zh-hk', 'zh-tw', 'zh-cn'};

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (state._loading) return _MarketplaceSkeleton(cs: cs);
    final all = state._all;
    final featured = state._featured;

    // Content-type sections — order: Watch, Manga, Light Novel, Music, Game
    final watchExt = all.where((e) => e.contentType == ItemType.anime).toList();
    final mangaExt = all.where((e) => e.contentType == ItemType.manga).toList();
    final novelExt = all.where((e) => e.contentType == ItemType.novel).toList();
    final musicExt = all.where((e) => e.contentType == ItemType.music).toList();
    final gameExt  = all.where((e) => e.contentType == ItemType.game).toList();

    return RefreshIndicator(
      onRefresh: () => state._loadAll(bypassCache: true),
      child: CustomScrollView(
        slivers: [
          // ── Dépôts ───────────────────────────────────────────────────────
          SliverToBoxAdapter(child: _RepoCarousel(state: state)),
          // Install all repo card
          SliverToBoxAdapter(child: _MassInstallCard(state: state)),
          // Updates available banner
          if (state._updatableCount > 0)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade700.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: Colors.orange.shade700.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.system_update_alt_rounded, color: Colors.orange.shade700, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${state._updatableCount} mise${state._updatableCount > 1 ? "s" : ""} à jour disponible${state._updatableCount > 1 ? "s" : ""}',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.orange.shade800),
                        ),
                      ),
                      Text(
                        'Appuie sur "Màj ↑"',
                        style: TextStyle(fontSize: 10.5, color: Colors.orange.shade700.withValues(alpha: 0.8)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // Watch (Anime · Films · Séries)
          if (watchExt.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: state.sectionTitle(
                cs, 'Watch',
                Icons.live_tv_rounded,
                color: const Color(0xFF7B2FBE),
                subtitle: '${watchExt.length} extensions · Watchtower',
                onSeeAll: () => state._tabCtrl.animateTo(_kTabAnime),
              ),
            ),
            SliverToBoxAdapter(child: state.buildHorizontal(watchExt, cs)),
          ],
          // Manga
          if (mangaExt.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: state.sectionTitle(
                cs, 'Manga · ${mangaExt.length}',
                Icons.auto_stories_rounded,
                color: const Color(0xFFE91E63),
                subtitle: 'Japonais, anglais et plus',
                onSeeAll: () => state._tabCtrl.animateTo(_kTabManga),
              ),
            ),
            SliverToBoxAdapter(child: state.buildHorizontal(mangaExt, cs)),
          ],
          // Light Novels
          if (novelExt.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: state.sectionTitle(
                cs, 'Light Novels · ${novelExt.length}',
                Icons.menu_book_rounded,
                color: const Color(0xFF009688),
                subtitle: 'Romans & Web novels',
                onSeeAll: () => state._tabCtrl.animateTo(_kTabNovel),
              ),
            ),
            SliverToBoxAdapter(child: state.buildHorizontal(novelExt, cs)),
          ],
          // Music
          if (musicExt.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: state.sectionTitle(
                cs, 'Music · ${musicExt.length}',
                Icons.music_note_rounded,
                color: const Color(0xFF0288D1),
                subtitle: 'Extensions musicales',
                onSeeAll: () => state._tabCtrl.animateTo(_kTabMusic),
              ),
            ),
            SliverToBoxAdapter(child: state.buildHorizontal(musicExt, cs)),
          ],
          // Game
          if (gameExt.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: state.sectionTitle(
                cs, 'Game · ${gameExt.length}',
                Icons.sports_esports_rounded,
                color: const Color(0xFF607D8B),
                subtitle: 'ROMs & émulateurs',
                onSeeAll: () => state._tabCtrl.animateTo(_kTabGames),
              ),
            ),
            SliverToBoxAdapter(child: state.buildHorizontal(gameExt, cs)),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }
}

// ─── Mass install card ─────────────────────────────────────────────────────────

class _MassOption {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final Color color;
  const _MassOption({required this.icon, required this.label, required this.subtitle, required this.onTap, required this.color});
}

class _MassInstallCard extends StatefulWidget {
  final _MarketplaceScreenState state;
  const _MassInstallCard({required this.state});

  @override
  State<_MassInstallCard> createState() => _MassInstallCardState();
}

class _MassInstallCardState extends State<_MassInstallCard> {
  bool _expanded = false;

  String get _userLang {
    final locale = WidgetsBinding.instance.platformDispatcher.locale;
    return locale.languageCode;
  }

  void _doInstall(String lang) {
    widget.state._massInstall(lang: lang);
    setState(() => _expanded = false);
  }

  void _doInstallAll() {
    for (final entry in widget.state._all) {
      if (!widget.state._installed.contains(entry.id)) {
        widget.state._install(entry);
      }
    }
    setState(() => _expanded = false);
  }

  void _doSelectLang() {
    widget.state._showMassInstallSheet();
    setState(() => _expanded = false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final options = [
      _MassOption(
        icon: Icons.language_rounded,
        label: 'Pour ma langue',
        subtitle: 'Extensions en ${_userLang.toUpperCase()}',
        onTap: () => _doInstall(_userLang),
        color: cs.primary,
      ),
      _MassOption(
        icon: Icons.public_rounded,
        label: 'All language',
        subtitle: 'Toutes les langues disponibles',
        onTap: () => _doInstall('all'),
        color: const Color(0xFF0288D1),
      ),
      _MassOption(
        icon: Icons.translate_rounded,
        label: 'Sélect langue',
        subtitle: 'Choisir une langue spécifique',
        onTap: _doSelectLang,
        color: const Color(0xFF009688),
      ),
      _MassOption(
        icon: Icons.download_for_offline_rounded,
        label: 'Tout complet',
        subtitle: 'Installe absolutement tout',
        onTap: _doInstallAll,
        color: Colors.deepOrange,
      ),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 10, 14, 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary.withValues(alpha: 0.12), cs.secondary.withValues(alpha: 0.08)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.primary.withValues(alpha: 0.25), width: 1),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: cs.primary.withValues(alpha: 0.15)),
                    child: Icon(Icons.download_for_offline_rounded, color: cs.primary, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Install all repo', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: cs.onSurface)),
                        Text('Installe tout les extensions d\'un repo', style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.expand_more_rounded, size: 22, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(height: 0, width: double.infinity),
            secondChild: Column(
              children: [
                Divider(height: 1, color: cs.primary.withValues(alpha: 0.15)),
                ...options.map((opt) => InkWell(
                  onTap: opt.onTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: opt.color.withValues(alpha: 0.12)),
                          child: Icon(opt.icon, color: opt.color, size: 17),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(opt.label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: cs.onSurface)),
                              Text(opt.subtitle, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, size: 18, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
                      ],
                    ),
                  ),
                )),
                const SizedBox(height: 4),
              ],
            ),
            crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 220),
          ),
        ],
      ),
    );
  }
}

// ─── Type tab (Manga / Anime / Novel / Jeux) ───────────────────────────────────

class _TypeTab extends StatefulWidget {
  final _MarketplaceScreenState state;
  final int tab;
  const _TypeTab({required this.state, required this.tab});

  @override
  State<_TypeTab> createState() => _TypeTabState();
}

class _TypeTabState extends State<_TypeTab> {
  bool _updatesExpanded = true;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final state = widget.state;
    final tab = widget.tab;
    final entries = state._forTab(tab);
    if (state._loading) return _MarketplaceSkeleton(cs: cs);
    final updatableEntries = entries
        .where((e) =>
            state._installed.contains(e.id) &&
            state._hasUpdate(e.id, e.version))
        .toList();
    return RefreshIndicator(
      onRefresh: () => state._loadAll(bypassCache: true),
      child: CustomScrollView(
        slivers: [
          if (entries.isEmpty && tab != _kTabMusic)
            SliverFillRemaining(
              child: Center(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('ε=ε=(ノ≧∇≦)ノ', style: TextStyle(fontSize: 44, color: cs.onSurfaceVariant.withValues(alpha: 0.5))),
                  const SizedBox(height: 14),
                  Text('Aucune extension', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
                  const SizedBox(height: 6),
                  Text('Réessayez plus tard ou vérifiez la connexion', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant.withValues(alpha: 0.6))),
                  const SizedBox(height: 20),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    TextButton.icon(
                      onPressed: () => state._loadAll(bypassCache: true),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Actualiser'),
                    ),
                    const SizedBox(width: 10),
                    TextButton.icon(
                      onPressed: () => state._clearFilters(tab),
                      icon: const Icon(Icons.filter_alt_off_rounded),
                      label: const Text('Effacer filtres'),
                    ),
                  ]),
                ]),
              ),
            )
          else ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: Row(children: [
                  Text(
                    '${entries.length} extension${entries.length == 1 ? "" : "s"}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () async {
                      await state._refreshInstalled();
                      final upd = state._updatableCount;
                      if (context.mounted) {
                        state._showToast(
                          context,
                          upd == 0 ? 'Tout est à jour ✓' : '$upd mise${upd == 1 ? "" : "s"} à jour disponible${upd == 1 ? "" : "s"}',
                          icon: upd == 0 ? Icons.check_circle_rounded : Icons.system_update_alt_rounded,
                        );
                      }
                    },
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.refresh_rounded, size: 13, color: cs.primary),
                      const SizedBox(width: 4),
                      Text('Vérifier màj', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.primary)),
                    ]),
                  ),
                ]),
              ),
            ),

            // ── Updates-first collapsible banner ──────────────────────────────
            if (updatableEntries.isNotEmpty)
              SliverToBoxAdapter(
                child: _UpdatesSection(
                  entries: updatableEntries,
                  state: state,
                  expanded: _updatesExpanded,
                  onToggle: () => setState(() => _updatesExpanded = !_updatesExpanded),
                  cs: cs,
                ),
              ),

              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _PlayStoreCard(
                    entry: entries[i],
                    installed: state._installed.contains(entries[i].id),
                    hasUpdate: state._hasUpdate(entries[i].id, entries[i].version),
                    busy: state._busy[entries[i].id] == true,
                    onInstall: () => state._install(entries[i]),
                    onSettings: state._installed.contains(entries[i].id) ? () => state._openSettings(entries[i].id) : null,
                    onUninstall: state._installed.contains(entries[i].id) ? () => state._uninstall(entries[i]) : null,
                  ),
                  childCount: entries.length.clamp(0, 500),
                ),
              ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }
}

// ─── Collapsible updates section ───────────────────────────────────────────────

class _UpdatesSection extends StatelessWidget {
  final List<_ExtEntry> entries;
  final _MarketplaceScreenState state;
  final bool expanded;
  final VoidCallback onToggle;
  final ColorScheme cs;

  const _UpdatesSection({
    required this.entries,
    required this.state,
    required this.expanded,
    required this.onToggle,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    final anyBusy = entries.any((e) => state._busy[e.id] == true);
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 4, 14, 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF7C3AED).withValues(alpha: 0.14),
            const Color(0xFF4F46E5).withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.30)),
      ),
      child: Column(
        children: [
          // ── Header row ────────────────────────────────────────────────────
          InkWell(
            onTap: onToggle,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
              child: Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.18),
                  ),
                  child: const Icon(Icons.system_update_alt_rounded,
                      color: Color(0xFFA78BFA), size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Text('Mises à jour',
                          style: TextStyle(fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFE4E4E7))),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C3AED),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('${entries.length}',
                            style: const TextStyle(fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                      ),
                    ]),
                    Text(
                      '${entries.length} extension${entries.length == 1 ? "" : "s"} à mettre à jour',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF71717A)),
                    ),
                  ]),
                ),
                if (!anyBusy)
                  GestureDetector(
                    onTap: () async {
                      for (final e in entries) {
                        await state._install(e);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C3AED),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('Tout màj',
                          style: TextStyle(fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ),
                  )
                else
                  const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Color(0xFFA78BFA))),
                const SizedBox(width: 8),
                AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFF71717A), size: 20),
                ),
              ]),
            ),
          ),
          // ── Expanded list ─────────────────────────────────────────────────
          AnimatedCrossFade(
            firstChild: const SizedBox(height: 0, width: double.infinity),
            secondChild: Column(
              children: [
                Divider(height: 1,
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.20)),
                ...entries.map((e) =>
                    _UpdateRow(entry: e, state: state, cs: cs)),
                const SizedBox(height: 4),
              ],
            ),
            crossFadeState:
                expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 220),
          ),
        ],
      ),
    );
  }
}

// ─── Single update row inside the banner ───────────────────────────────────────

class _UpdateRow extends StatelessWidget {
  final _ExtEntry entry;
  final _MarketplaceScreenState state;
  final ColorScheme cs;
  const _UpdateRow({required this.entry, required this.state, required this.cs});

  @override
  Widget build(BuildContext context) {
    final busy = state._busy[entry.id] == true;
    final installedV = state._installedVersions[entry.id] ?? '?';
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: entry.iconUrl != null
              ? Image.network(
                  entry.iconUrl!,
                  width: 38, height: 38, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: _MarketplaceScreenState._typeColor(entry.contentType)
                          .withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _MarketplaceScreenState._typeIcon(entry.contentType),
                      color: _MarketplaceScreenState._typeColor(entry.contentType),
                      size: 18,
                    ),
                  ),
                )
              : Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: _MarketplaceScreenState._typeColor(entry.contentType)
                        .withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _MarketplaceScreenState._typeIcon(entry.contentType),
                    color: _MarketplaceScreenState._typeColor(entry.contentType),
                    size: 18,
                  ),
                ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(entry.name,
                style: const TextStyle(fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFE4E4E7))),
            Row(children: [
              Text(installedV,
                  style: const TextStyle(fontSize: 10, color: Color(0xFF71717A))),
              const Text(' → ',
                  style: TextStyle(fontSize: 10, color: Color(0xFF71717A))),
              Text(entry.version,
                  style: const TextStyle(fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFA78BFA))),
            ]),
          ]),
        ),
        const SizedBox(width: 8),
        busy
            ? const SizedBox(
                width: 24, height: 24,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Color(0xFFA78BFA)))
            : GestureDetector(
                onTap: () => state._install(entry),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: const Color(0xFF7C3AED).withValues(alpha: 0.40)),
                  ),
                  child: const Text('Màj',
                      style: TextStyle(fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFA78BFA))),
                ),
              ),
      ]),
    );
  }
}

// ─── Mass install sheet ────────────────────────────────────────────────────────

class _MassInstallSheet extends StatefulWidget {
  final _MarketplaceScreenState state;
  final List<String> langs;
  final Set<int> installedIds;
  const _MassInstallSheet({
    required this.state,
    required this.langs,
    required this.installedIds,
  });

  @override
  State<_MassInstallSheet> createState() => _MassInstallSheetState();
}

class _MassInstallSheetState extends State<_MassInstallSheet> {
  String? _selectedLang;
  SourceCodeLanguage? _selectedCompat;
  bool _running = false;
  int _done = 0;
  int _total = 0;

  List<_ExtEntry> get _toInstall {
    if (_selectedLang == null) return [];
    var list = widget.state._all
        .where((e) => e.lang == _selectedLang && !widget.installedIds.contains(e.id))
        .toList();
    if (_selectedCompat != null) {
      list = list.where((e) => e.compat == _selectedCompat).toList();
    }
    return list;
  }

  Future<void> _doInstall() async {
    final list = _toInstall;
    if (list.isEmpty) return;
    setState(() { _running = true; _done = 0; _total = list.length; });
    for (final entry in list) {
      await widget.state._install(entry);
      if (mounted) setState(() => _done++);
    }
    if (mounted) setState(() => _running = false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final toInstall = _toInstall;

    final compatItems = [
      (null, Icons.apps_rounded, 'Tous types'),
      (SourceCodeLanguage.javascript, Icons.code_rounded, 'JS/Web'),
      (SourceCodeLanguage.dart, Icons.flutter_dash, 'Dart'),
      (SourceCodeLanguage.javascript, Icons.code_rounded, 'JS'),
    ];

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      maxChildSize: 0.85,
      builder: (_, ctrl) => Container(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: ListView(
          controller: ctrl,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text('Installer en masse',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800,
                    color: cs.onSurface)),
            const SizedBox(height: 4),
            Text('Installe toutes les extensions d\'une langue ou d\'un dépôt.',
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
            const SizedBox(height: 20),

            // Language dropdown
            Text('Langue',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: cs.onSurface)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedLang,
              isExpanded: true,
              hint: const Text('Sélectionner une langue'),
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              items: widget.langs.map((l) {
                final count = widget.state._all
                    .where((e) => e.lang == l && !widget.installedIds.contains(e.id))
                    .length;
                final code = _MarketplaceScreenState._langCode(l);
                return DropdownMenuItem(
                  value: l,
                  child: Text('$code — $count non installées'),
                );
              }).toList(),
              onChanged: _running ? null : (v) => setState(() => _selectedLang = v),
            ),

            const SizedBox(height: 16),

            // Compat filter
            Text('Type (optionnel)',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: cs.onSurface)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: compatItems.map<Widget>(((SourceCodeLanguage?, IconData, String) item) {
                final (compat, icon, label) = item;
                final sel = _selectedCompat == compat;
                return GestureDetector(
                  onTap: _running ? null : () => setState(() => _selectedCompat = compat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                    decoration: BoxDecoration(
                      color: sel ? cs.primaryContainer : cs.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: sel ? cs.primary : cs.outlineVariant,
                        width: sel ? 1.5 : 1,
                      ),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(icon, size: 13, color: sel ? cs.primary : cs.onSurfaceVariant),
                      const SizedBox(width: 5),
                      Text(label,
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600,
                              color: sel ? cs.primary : cs.onSurface)),
                    ]),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            // Progress
            if (_running) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _total > 0 ? _done / _total : null,
                  minHeight: 6,
                  backgroundColor: cs.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation(cs.primary),
                ),
              ),
              const SizedBox(height: 6),
              Text('$_done / $_total installées…',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              const SizedBox(height: 16),
            ],

            // Summary + install button
            if (_selectedLang != null && !_running) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${toInstall.length} extension(s) à installer pour '
                  '${_MarketplaceScreenState._langCode(_selectedLang!)}',
                  style: TextStyle(fontSize: 13, color: cs.onSurface),
                ),
              ),
              const SizedBox(height: 14),
            ],

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: _running
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.download_rounded),
                label: Text(
                  _running
                      ? 'Installation en cours…'
                      : toInstall.isEmpty
                          ? 'Aucune extension à installer'
                          : 'Installer ${toInstall.length} extension(s)',
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: (_running || toInstall.isEmpty)
                    ? null
                    : _doInstall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Play Store-style card ─────────────────────────────────────────────────────

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

    String _description(ItemType t, String lang, bool isNsfw) {
      final typeName = switch (t) {
        ItemType.anime  => 'anime et séries',
        ItemType.manga  => 'manga et comics',
        ItemType.novel  => 'romans et light novels',
        ItemType.music  => 'musique',
        _               => 'jeux',
      };
      final langCode = _MarketplaceScreenState._langCode(lang);
      return 'Parcourez du $typeName en $langCode${isNsfw ? " (contenu adulte)" : ""}.';
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
      final desc = entry.description.isNotEmpty
          ? entry.description
          : _description(entry.contentType, entry.lang, entry.isNsfw);

      return GestureDetector(
        onLongPress: (installed && onUninstall != null) ? onUninstall : null,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header row ──────────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ExtIcon(iconUrl: entry.iconUrl, type: entry.contentType, size: 48),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.name,
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
              // ── Tags ─────────────────────────────────────────────────
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _TagChip(label: langCode, cs: cs),
                  _TagChip(label: compatLabel, cs: cs),
                  if (entry.isNsfw)
                    _TagChip(label: '18+', cs: cs, color: Colors.red.shade400),
                  if (hasUpdate)
                    _TagChip(
                      label: '↑ v${entry.version}',
                      cs: cs,
                      color: Colors.orange.shade400,
                    ),
                  ...entry.subCategories.take(2).map(
                    (c) => _TagChip(label: c, cs: cs, color: cs.primary),
                  ),
                  if (entry.requiresAccount)
                    _TagChip(label: '🔐 Compte requis', cs: cs, color: Colors.blue.shade400),
                  if (entry.hasDRM)
                    _TagChip(label: '🔒 DRM', cs: cs, color: Colors.orange.shade600),
                  if (entry.paywall != 'free' && entry.paywall.isNotEmpty)
                    _TagChip(label: entry.paywall, cs: cs, color: Colors.amber.shade600),
                  if (entry.isAggregator)
                    _TagChip(label: 'Agrégateur', cs: cs, color: cs.secondary),
                ],
              ),
            ],
          ),
        ),
      );
    }
  }

  class _TagChip extends StatelessWidget {
    final String label;
    final ColorScheme cs;
    final Color? color;
    const _TagChip({required this.label, required this.cs, this.color});

    @override
    Widget build(BuildContext context) {
      final fg = color ?? cs.onSurfaceVariant;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: fg.withValues(alpha: 0.45)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: fg,
          ),
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
            width: 36, height: 36, padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(color: cs.surfaceContainerHigh, borderRadius: BorderRadius.circular(10)),
            child: CircularProgressIndicator(strokeWidth: 2.2, color: cs.primary),
          );
        }
        if (!installed) {
          return GestureDetector(
            onTap: onInstall,
            child: Container(
              width: 36, height: 36, alignment: Alignment.center,
              decoration: BoxDecoration(color: cs.surfaceContainerHigh, borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.download_rounded, size: 20, color: cs.onSurfaceVariant),
            ),
          );
        }
        if (hasUpdate) {
          return GestureDetector(
            onTap: onInstall,
            child: Container(
              width: 36, height: 36, alignment: Alignment.center,
              decoration: BoxDecoration(color: Colors.orange.shade700.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.system_update_alt_rounded, size: 20, color: Colors.orange.shade600),
            ),
          );
        }
        // Installed, no update → vertical: ⋮ menu, <> code, settings
        Widget iconBtn(IconData icon, VoidCallback? onTap, {Color? color}) => GestureDetector(
          onTap: onTap,
          child: Container(
            width: 30, height: 30, alignment: Alignment.center,
            decoration: BoxDecoration(color: cs.surfaceContainerHigh, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 15, color: color ?? cs.onSurfaceVariant),
          ),
        );
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PopupMenuButton<String>(
              padding: EdgeInsets.zero,
              tooltip: '',
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onSelected: (v) async {
                if (v == 'update') onInstall();
                else if (v == 'uninstall') onUninstall?.call();
                else if (v == 'code') onCode?.call();
              },
              itemBuilder: (_) => [
                if (onUninstall != null) PopupMenuItem(value: 'uninstall', child: Row(children: [
                  Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red.shade400),
                  const SizedBox(width: 10), Text('Désinstaller', style: TextStyle(color: Colors.red.shade400)),
])),
                PopupMenuItem(value: 'code', child: Row(children: [
                  Icon(Icons.code_rounded, size: 16, color: cs.onSurfaceVariant),
                  const SizedBox(width: 10), const Text('Code source'),
                ])),
              ],
              child: Container(
                width: 30, height: 30, alignment: Alignment.center,
                decoration: BoxDecoration(color: cs.surfaceContainerHigh, borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.more_vert_rounded, size: 15, color: cs.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 5),
            iconBtn(Icons.code_rounded, onCode),
            const SizedBox(height: 5),
            iconBtn(Icons.settings_outlined, onSettings),
          ],
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
        'spotube-metadata-plugin' => 'Métadata',
        'spotube-audio-source-plugin' => 'Source Audio',
        _ => topic,
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final plugins = ref.watch(metadataPluginsProvider);
    final pluginsNotifier = ref.watch(metadataPluginsProvider.notifier);

    final isInstalled = plugins.asData?.value.plugins
            .any((p) => p.repository == _repo.repoUrl) ??
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
        .where((t) =>
            t == 'spotube-metadata-plugin' || t == 'spotube-audio-source-plugin')
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
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isInstalled
                ? cs.primary.withValues(alpha: 0.35)
                : cs.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row ──────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Plugin icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0288D1).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF0288D1).withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Icon(
                    Icons.extension_rounded,
                    size: 26,
                    color: Color(0xFF0288D1),
                  ),
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
                        strokeWidth: 2.2, color: cs.primary),
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
                              title: const Text('Installer ce plugin ?'),
                              content: Text(
                                'Plugin tiers de ${_repo.owner}.\n\n'
                                'Il accèdera aux APIs déclarées dans son manifest.\n\n'
                                'Long-press sur la carte pour désinstaller.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(ctx, false),
                                  child: const Text('Annuler'),
                                ),
                                FilledButton(
                                  onPressed: () =>
                                      Navigator.pop(ctx, true),
                                  child: const Text('Installer'),
                                ),
                              ],
                            ),
                          );
                          if (allowed == true && context.mounted) {
                            await pluginsNotifier.addPlugin(pluginConfig);
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
                      child: Icon(Icons.download_rounded,
                          size: 20, color: cs.onSurfaceVariant),
                    ),
                  )
                else
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.check_rounded,
                        size: 20, color: cs.primary),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: Colors.blue.shade400
                              .withValues(alpha: 0.45)),
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
                ...topics.map(
                  (t) => _TagChip(label: t, cs: cs),
                ),
              ],
            ),
            // ── Login button (plugins avec authentication) ───────────────
            if (needsLogin) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.login_rounded, size: 16),
                  label: const Text('Se connecter',
                      style: TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => showModalBottomSheet(
                    context: context,
                    builder: (ctx) => SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock_open_rounded,
                                size: 40,
                                color:
                                    Theme.of(ctx).colorScheme.primary),
                            const SizedBox(height: 12),
                            Text(
                              'Connexion — $_displayName',
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Ce plugin nécessite une authentification.\n'
                              'Ouvrez le Hub Musique → Paramètres → Sources, '
                              'sélectionnez ce plugin comme source par défaut, '
                              'puis appuyez sur « Se connecter ».',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Theme.of(ctx)
                                      .colorScheme
                                      .onSurfaceVariant),
                            ),
                            const SizedBox(height: 20),
                            FilledButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Compris'),
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
}

// ─── Music Plugins Section (injecté dans le tab Music) ──────────────────────

class _MusicPluginsSection extends ConsumerWidget {
  const _MusicPluginsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final snapshot = ref.watch(metadataPluginRepositoriesProvider);
    final repos = snapshot.asData?.value.items ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Section header ───────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFF0288D1).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.extension_rounded,
                    size: 16, color: Color(0xFF0288D1)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Plugins Musique',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
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
        // ── Cards ────────────────────────────────────────────────────────
        if (repos.isEmpty && !snapshot.isLoading)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              'Aucun plugin trouvé',
              style: TextStyle(
                  fontSize: 13, color: cs.onSurfaceVariant),
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
    final typeColor = _MarketplaceScreenState._typeColor(entry.contentType);
    final compatColor = _MarketplaceScreenState._compatColor(entry.compat, cs);
    final hasIcon = entry.iconUrl != null && entry.iconUrl!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: typeColor.withValues(alpha: 0.30), blurRadius: 14, offset: const Offset(0, 5))],
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
                  errorBuilder: (_, __, ___) => Container(
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
                    colors: [typeColor.withValues(alpha: 0.85), compatColor.withValues(alpha: 0.65)],
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
                  _ExtIcon(iconUrl: entry.iconUrl, type: entry.contentType, size: 60),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Text(entry.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white, shadows: [Shadow(blurRadius: 4, color: Colors.black45)]), maxLines: 2, overflow: TextOverflow.ellipsis),
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(5)),
                            child: Text(_MarketplaceScreenState._compatLabel(entry.compat), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.3)),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(5)),
                            child: Text(_MarketplaceScreenState._langCode(entry.lang), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.3)),
                          ),
                        ]),
                        SizedBox(
                          width: double.infinity,
                          height: 32,
                          child: installed
                              ? Row(children: [
                                  // Gear icon
                                  if (onSettings != null)
                                    GestureDetector(
                                      onTap: onSettings,
                                      child: Container(
                                        width: 34, height: 32,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.22),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(Icons.settings_outlined, size: 15, color: Colors.white),
                                      ),
                                    ),
                                  if (onSettings != null) const SizedBox(width: 6),
                                  Expanded(
                                    child: hasUpdate
                                        ? GestureDetector(
                                            onTap: busy ? null : onInstall,
                                            child: Container(
                                              height: 32,
                                              alignment: Alignment.center,
                                              decoration: BoxDecoration(
                                                color: Colors.orange.shade700.withValues(alpha: 0.85),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: busy
                                                  ? const SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                                  : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                                      Icon(Icons.system_update_alt_rounded, size: 13, color: Colors.white),
                                                      SizedBox(width: 5),
                                                      Text('Màj dispo', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700)),
                                                    ]),
                                            ),
                                          )
                                        : Container(
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(8)),
                                            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                              Icon(Icons.check_rounded, size: 14, color: Colors.white),
                                              SizedBox(width: 5),
                                              Text('Installée', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w700)),
                                            ]),
                                          ),
                                  ),
                                ])
                              : FilledButton(
                                  onPressed: busy ? null : onInstall,
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    backgroundColor: Colors.white.withValues(alpha: 0.25),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: busy
                                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                      : const Text('Installer', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
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

// ─── Mini card ─────────────────────────────────────────────────────────────────

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

  String get _codeUrl {
    final url = entry.repoUrl;
    if (url.contains('ferelking242') || url.contains('watchtower-extensions')) {
      return 'https://github.com/ferelking242/watchtower-extensions';
    }
    return url;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: 138,
      margin: const EdgeInsets.only(right: 10, bottom: 2),
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: installed
              ? cs.primary.withValues(alpha: 0.35)
              : cs.outline.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _ExtIcon(iconUrl: entry.iconUrl, type: entry.contentType, size: 54),
          const SizedBox(height: 8),
          Text(
            entry.name,
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: cs.onSurface),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'v${entry.version}',
            style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant.withValues(alpha: 0.55)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // <> view code button
              GestureDetector(
                onTap: () async {
                  final url = Uri.parse(_codeUrl);
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                },
                child: Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.code_rounded, size: 15, color: cs.onSurfaceVariant),
                ),
              ),
              const SizedBox(width: 4),
              // ⋮ three-dot menu
              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                tooltip: '',
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (value) async {
                  if (value == 'install') onInstall();
                  else if (value == 'update') onInstall();
                  else if (value == 'settings') onSettings?.call();
                  else if (value == 'code') {
                    await launchUrl(Uri.parse(_codeUrl), mode: LaunchMode.externalApplication);
                  }
                },
                itemBuilder: (ctx) => [
                  if (!installed)
                    PopupMenuItem(
                      value: 'install',
                      child: Row(children: [
                        Icon(Icons.download_rounded, size: 16, color: cs.primary),
                        const SizedBox(width: 10),
                        const Text('Installer'),
                      ]),
                    ),
                  if (installed && hasUpdate)
                    PopupMenuItem(
                      value: 'update',
                      child: Row(children: [
                        Icon(Icons.system_update_alt_rounded, size: 16, color: Colors.orange.shade700),
                        const SizedBox(width: 10),
                        const Text('Mettre à jour'),
                      ]),
                    ),
                  if (installed && onSettings != null)
                    PopupMenuItem(
                      value: 'settings',
                      child: Row(children: [
                        Icon(Icons.settings_outlined, size: 16, color: cs.onSurfaceVariant),
                        const SizedBox(width: 10),
                        const Text('Paramètres'),
                      ]),
                    ),
                  PopupMenuItem(
                    value: 'code',
                    child: Row(children: [
                      Icon(Icons.code_rounded, size: 16, color: cs.onSurfaceVariant),
                      const SizedBox(width: 10),
                      const Text('Voir le code'),
                    ]),
                  ),
                ],
                child: Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.more_vert_rounded, size: 15, color: cs.onSurfaceVariant),
                ),
              ),
              const SizedBox(width: 5),
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
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                              ),
                              child: busy
                                  ? const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white))
                                  : const Text('Màj', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)),
                            )
                          : OutlinedButton(
                              onPressed: onSettings,
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.zero,
                                side: BorderSide(color: cs.primary.withValues(alpha: 0.4)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                              ),
                              child: Icon(Icons.check_rounded, size: 14, color: cs.primary),
                            )
                      : FilledButton(
                          onPressed: busy ? null : onInstall,
                          style: FilledButton.styleFrom(
                            padding: EdgeInsets.zero,
                            backgroundColor: cs.primaryContainer,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                          ),
                          child: busy
                              ? SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5, color: cs.onPrimaryContainer))
                              : Icon(Icons.download_rounded, size: 15, color: cs.onPrimaryContainer),
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

class _StatsBar extends StatelessWidget {
    final int wt, ln, installed;
    final ColorScheme cs;
    const _StatsBar({
      required this.wt,
      required this.ln,
      required this.installed,
      required this.cs,
    });

    @override
    Widget build(BuildContext context) {
      return Container(
        margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outline.withValues(alpha: 0.1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _Pill('$wt', 'Watchtower', const Color(0xFF7C3AED)),
            Container(width: 1, height: 32, color: cs.outline.withValues(alpha: 0.25)),
            _Pill('$ln', 'Light Novel', const Color(0xFF009688)),
            Container(width: 1, height: 32, color: cs.outline.withValues(alpha: 0.25)),
            _Pill('$installed', 'Installées', const Color(0xFF43A047)),
          ],
        ),
      );
    }
  }
class _Pill extends StatelessWidget {
  final String count, label;
  final Color color;
  const _Pill(this.count, this.label, this.color);
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(count, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
      Text(label, style: TextStyle(fontSize: 9.5, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.8))),
    ],
  );
}

// ─── Extension icon ─────────────────────────────────────────────────────────────

class _ExtIcon extends StatelessWidget {
    final String? iconUrl;
    final ItemType type;
    final double size;
    const _ExtIcon({this.iconUrl, required this.type, required this.size});

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
      final color = _MarketplaceScreenState._typeColor(type);
      return Container(
        width: size, height: size,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
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
                      placeholderBuilder: (_) => _SkeletonShimmer(width: size, height: size, radius: 12),
                    )
                  : Image.network(
                      iconUrl!, width: size, height: size, fit: BoxFit.cover,
                      loadingBuilder: (_, child, progress) => progress == null
                          ? child
                          : _SkeletonShimmer(width: size, height: size, radius: 12),
                      errorBuilder: (_, __, ___) => _fallback(cs, color),
                    )
              : _fallback(cs, color),
        ),
      );
    }

    Widget _fallback(ColorScheme cs, Color color) =>
        Center(child: Icon(_MarketplaceScreenState._typeIcon(type), size: size * 0.48, color: color));
  }

  // ─── Skeleton shimmer ────────────────────────────────────────────────────────

  class _SkeletonShimmer extends StatefulWidget {
    final double width, height, radius;
    const _SkeletonShimmer({required this.width, required this.height, this.radius = 8});
    @override
    State<_SkeletonShimmer> createState() => _SkeletonShimmerState();
  }

  class _SkeletonShimmerState extends State<_SkeletonShimmer> with SingleTickerProviderStateMixin {
    late final AnimationController _ctrl;
    late final Animation<double> _anim;
    @override
    void initState() {
      super.initState();
      _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))
          ..repeat(reverse: true);
      _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    }
    @override
    void dispose() { _ctrl.dispose(); super.dispose(); }
    @override
    Widget build(BuildContext context) => AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: widget.width, height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          gradient: LinearGradient(
            begin: Alignment(-1 + 2 * _anim.value, 0),
            end: Alignment(1 + 2 * _anim.value, 0),
            colors: const [Color(0xFF2A2A2E), Color(0xFF3F3F46), Color(0xFF2A2A2E)],
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
  const _IconChip({required this.icon, required this.label, required this.active, required this.onTap});

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
          border: Border.all(color: active ? cs.primary : cs.outline.withValues(alpha: 0.2)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: active ? cs.onPrimary : cs.onSurfaceVariant),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: active ? cs.onPrimary : cs.onSurfaceVariant)),
        ]),
      ),
    );
  }
}


  // ─── Repo Carousel ─────────────────────────────────────────────────────────────

  class _RepoCarousel extends StatefulWidget {
    final _MarketplaceScreenState state;
    const _RepoCarousel({required this.state});

    @override
    State<_RepoCarousel> createState() => _RepoCarouselState();
  }

  class _RepoCarouselState extends State<_RepoCarousel> {
    final _ctrl = PageController();
    int _page = 0;

    static const _repos = [
      _RepoInfo(
        name: 'Watchtower',
        description: 'Extensions officielles Watchtower — anime, manga, novels, musique et jeux',
        icon: Icons.whatshot_rounded,
        color: Color(0xFF6C63FF),
        tag: 'Officiel',
        githubUrl: 'https://github.com/ferelking242/watchtower-extensions',
      ),
    ];

    @override
    void dispose() {
      _ctrl.dispose();
      super.dispose();
    }

    @override
    Widget build(BuildContext context) {
      final cs = Theme.of(context).colorScheme;
      final allCount = widget.state._all.length;
      final installedCount = widget.state._installed.length;
      final totalPages = 1 + _repos.length;

      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 162,
              child: PageView.builder(
                controller: _ctrl,
                itemCount: totalPages,
                onPageChanged: (p) => setState(() => _page = p),
                itemBuilder: (ctx, i) {
                  if (i == 0) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildStatsCard(cs, allCount, installedCount),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildRepoCard(cs, _repos[i - 1]),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(totalPages, (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _page == i ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: _page == i ? cs.primary : cs.outline.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(3),
                ),
              )),
            ),
            const SizedBox(height: 4),
          ],
        ),
      );
    }

    Widget _buildStatsCard(ColorScheme cs, int total, int installed) {
      return Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6C63FF), Color(0xFF9C27B0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: const Color(0xFF6C63FF).withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 5))],
        ),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              const Icon(Icons.whatshot_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Watchtower Marketplace',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(8)),
                child: const Text('Officiel', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
              ),
            ]),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('$total', style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900, height: 1)),
                  const Text('disponibles', style: TextStyle(color: Colors.white70, fontSize: 11)),
                ]),
                Container(width: 1, height: 40, color: Colors.white.withValues(alpha: 0.3)),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('$installed', style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900, height: 1)),
                  const Text('installées', style: TextStyle(color: Colors.white70, fontSize: 11)),
                ]),
              ],
            ),
          ],
        ),
      );
    }

    Widget _buildRepoCard(ColorScheme cs, _RepoInfo r) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [r.color, r.color.withValues(alpha: 0.72)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: r.color.withValues(alpha: 0.30), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              Icon(r.icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  r.name,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(8)),
                child: Text(r.tag, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
              ),
            ]),
            Text(
              r.description,
              style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.4),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(
              height: 34,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.open_in_new_rounded, size: 14, color: Colors.white),
                label: const Text('Voir le dépôt', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  side: const BorderSide(color: Colors.white54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  await launchUrl(Uri.parse(r.githubUrl), mode: LaunchMode.externalApplication);
                },
              ),
            ),
          ],
        ),
      );
    }
  }

  class _RepoInfo {
    final String name;
    final String description;
    final IconData icon;
    final Color color;
    final String tag;
    final String githubUrl;
    const _RepoInfo({
      required this.name,
      required this.description,
      required this.icon,
      required this.color,
      required this.tag,
      required this.githubUrl,
    });
  }

  // ─── Marketplace Settings Sheet ───────────────────────────────────────────────

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
                  width: 36, height: 4,
                  margin: const EdgeInsets.only(top: 10, bottom: 14),
                  decoration: BoxDecoration(color: cs.outlineVariant, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text('Paramètres', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: cs.onSurface)),
              ),
              Divider(height: 1, indent: 20, endIndent: 20, color: cs.outlineVariant.withValues(alpha: 0.5)),
              Expanded(
                child: ListView(
                  controller: sc,
                  padding: const EdgeInsets.only(top: 8, bottom: 32),
                  children: [
                    // ── Section : Comportement ─────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
                      child: Text('Comportement',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                              color: cs.primary, letterSpacing: 0.6)),
                    ),
                    _LightSettingsTile(
                      icon: Icons.update_rounded,
                      title: 'Vérifier les mises à jour',
                      subtitle: 'Au démarrage de l\'app',
                      value: checkUpdates,
                      onChanged: (v) => ref.read(checkForExtensionsUpdateStateProvider.notifier).set(v),
                    ),
                    _LightSettingsTile(
                      icon: Icons.system_update_alt_rounded,
                      title: 'Mise à jour automatique',
                      subtitle: 'Sans confirmation',
                      value: autoUpdate,
                      onChanged: (v) => ref.read(autoUpdateExtensionsStateProvider.notifier).set(v),
                    ),
                    _LightSettingsTile(
                      icon: Icons.explicit_rounded,
                      title: 'Contenu 18+',
                      subtitle: 'Afficher les extensions NSFW',
                      value: showNsfw,
                      onChanged: (v) => ref.read(showNSFWStateProvider.notifier).set(v),
                    ),
                    Divider(height: 1, indent: 20, endIndent: 20, color: cs.outlineVariant.withValues(alpha: 0.4)),
                    // ── Section : Dépôts ───────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                      child: Text('Dépôts',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                              color: cs.primary, letterSpacing: 0.6)),
                    ),
                    _LightActionTile(
                      icon: Icons.folder_special_rounded,
                      title: 'Gérer les dépôts',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => const ExtensionRepositoriesScreen(),
                        ));
                      },
                    ),
                    Divider(height: 1, indent: 20, endIndent: 20, color: cs.outlineVariant.withValues(alpha: 0.4)),
                    // ── Section : Cache ────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                      child: Text('Cache',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                              color: cs.primary, letterSpacing: 0.6)),
                    ),
                    _LightActionTile(
                      icon: Icons.refresh_rounded,
                      title: 'Recharger le catalogue',
                      onTap: () { Navigator.pop(context); state._loadAll(bypassCache: true); },
                    ),
                    _LightActionTile(
                      icon: Icons.cloud_sync_rounded,
                      title: 'Forcer rechargement (bypass cache)',
                      onTap: () { Navigator.pop(context); state._loadAll(bypassCache: true); },
                    ),
                    Divider(height: 1, indent: 20, endIndent: 20, color: cs.outlineVariant.withValues(alpha: 0.4)),
                    // ── Section : Actions ──────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                      child: Text('Actions',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                              color: cs.primary, letterSpacing: 0.6)),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: FilledButton.icon(
                        icon: const Icon(Icons.download_for_offline_rounded, size: 18),
                        label: const Text('Installer en masse…'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  class _SettingsTile extends StatelessWidget {
    final IconData icon;
    final String title;
    final String subtitle;
    final bool value;
    final ValueChanged<bool> onChanged;
    final ColorScheme cs;
    const _SettingsTile({required this.icon, required this.title, required this.subtitle, required this.value, required this.onChanged, required this.cs});

    @override
    Widget build(BuildContext context) {
      return SwitchListTile.adaptive(
        secondary: Icon(icon, size: 22, color: cs.primary),
        title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        value: value,
        onChanged: onChanged,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
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
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle,
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant.withValues(alpha: 0.7))),
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
  const _LightActionTile({required this.icon, required this.title, required this.onTap});

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
              child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: cs.outlineVariant),
          ],
        ),
      ),
    );
  }
}

// ─── Account dropdown overlay ─────────────────────────────────────────────────

class _AccountDropdownOverlay extends StatefulWidget {
  final Offset position;
  final VoidCallback onDismiss;
  final VoidCallback onSettings;
  final VoidCallback onRepos;
  const _AccountDropdownOverlay({
    required this.position,
    required this.onDismiss,
    required this.onSettings,
    required this.onRepos,
  });

  @override
  State<_AccountDropdownOverlay> createState() => _AccountDropdownOverlayState();
}

class _AccountDropdownOverlayState extends State<_AccountDropdownOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  static const _kMenuWidth = 210.0;
  static const _kRadius = 16.0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    // Guard against narrow screens where screenWidth - _kMenuWidth - 8 < 8,
    // which would make clamp's upper bound smaller than its lower bound and
    // throw (same class of bug fixed in main_screen.dart's dock pill width).
    final maxLeft = math.max(8.0, screenWidth - _kMenuWidth - 8.0);
    final left = (widget.position.dx - _kMenuWidth).clamp(8.0, maxLeft);
    final top = widget.position.dy;

    return Stack(
      children: [
        // Barrier to dismiss
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onDismiss,
            behavior: HitTestBehavior.translucent,
            child: const SizedBox.expand(),
          ),
        ),
        // Dropdown menu
        Positioned(
          left: left,
          top: top,
          width: _kMenuWidth,
          child: FadeTransition(
            opacity: _fade,
            child: SlideTransition(
              position: _slide,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF12163A),
                    borderRadius: BorderRadius.circular(_kRadius),
                    border: Border.all(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.35),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.45),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(_kRadius),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header
                        Container(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF7C3AED), Color(0xFF06B6D4)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.22),
                                ),
                                child: const Icon(Icons.person_rounded, size: 20, color: Colors.white),
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Watchtower', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                                    Text('Marketplace', style: TextStyle(color: Colors.white70, fontSize: 10.5)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        _DropItem(
                          icon: Icons.tune_rounded,
                          label: 'Paramètres marketplace',
                          onTap: widget.onSettings,
                        ),
                        _DropDivider(),
                        _DropItem(
                          icon: Icons.folder_special_rounded,
                          label: 'Gérer les dépôts',
                          onTap: widget.onRepos,
                        ),
                        _DropDivider(),
                        _DropItem(
                          icon: Icons.info_outline_rounded,
                          label: 'À propos',
                          onTap: widget.onDismiss,
                        ),
                        const SizedBox(height: 4),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DropItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _DropItem({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Icon(icon, size: 17, color: const Color(0xFF06B6D4)),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DropDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(height: 1, color: const Color(0xFF7C3AED).withValues(alpha: 0.18));
  }
}

// ─── Search category tile ─────────────────────────────────────────────────────

class _SearchCategoryTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _SearchCategoryTile({required this.icon, required this.label, required this.color, required this.onTap});

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
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface),
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
  final List<(String, String)> items;  // (value, display)
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
            width: 36, height: 4,
            decoration: BoxDecoration(color: cs.outline.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(4)),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Icon(Icons.filter_list_rounded, size: 18, color: cs.primary),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: cs.onSurface)),
            ]),
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
                ...items.map((item) => _PickerTile(
                  label: item.$2,
                  selected: selected == item.$1,
                  onTap: () => onPick(item.$1),
                  cs: cs,
                )),
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
  const _PickerTile({required this.label, required this.selected, required this.onTap, required this.cs});

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
          ? Icon(Icons.check_rounded, size: 18, color: cs.primary)
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
    const _LangGridPickerSheet({required this.langs, this.selected, required this.onPick});
    @override
    State<_LangGridPickerSheet> createState() => _LangGridPickerSheetState();
  }

  class _LangGridPickerSheetState extends State<_LangGridPickerSheet> {
    final _search = TextEditingController();
    String _query = '';

    @override
    void dispose() { _search.dispose(); super.dispose(); }

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
        decoration: const BoxDecoration(
          color: Color(0xFF18181B),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.78),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          Container(width: 36, height: 4,
            decoration: BoxDecoration(color: const Color(0xFF3F3F46), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              const Icon(Icons.language_rounded, size: 18, color: Color(0xFF818CF8)),
              const SizedBox(width: 8),
              Text('Langue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: cs.onSurface)),
              const Spacer(),
              if (widget.selected != null)
                TextButton(
                  onPressed: () => widget.onPick(null),
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFFF87171), padding: EdgeInsets.zero),
                  child: const Text('Effacer', style: TextStyle(fontSize: 13)),
                ),
            ]),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFF27272A),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                const SizedBox(width: 10),
                const Icon(Icons.search_rounded, size: 16, color: Color(0xFF71717A)),
                const SizedBox(width: 8),
                Expanded(child: TextField(
                  controller: _search,
                  onChanged: (v) => setState(() => _query = v),
                  style: const TextStyle(fontSize: 13, color: Color(0xFFE4E4E7)),
                  decoration: const InputDecoration(
                    hintText: 'Rechercher une langue...',
                    hintStyle: TextStyle(fontSize: 13, color: Color(0xFF52525B)),
                    border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero,
                  ),
                )),
              ]),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 2.4,
              ),
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final l = filtered[i];
                final isAll = l == 'all';
                final sel = isAll ? widget.selected == null : widget.selected == l;
                return GestureDetector(
                  onTap: () => widget.onPick(isAll ? null : l),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    decoration: BoxDecoration(
                      color: sel ? const Color(0xFF4F46E5).withValues(alpha: 0.2) : const Color(0xFF27272A),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: sel ? const Color(0xFF4F46E5) : Colors.transparent),
                    ),
                    child: Center(child: isAll
                      ? Text('Toutes', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                          color: sel ? const Color(0xFFA5B4FC) : const Color(0xFFA1A1AA)))
                      : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text(_MarketplaceScreenState._langFlag(l), style: const TextStyle(fontSize: 18)),
                          const SizedBox(height: 1),
                          Text(_MarketplaceScreenState._langDisplayName(l),
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                                color: sel ? const Color(0xFFA5B4FC) : const Color(0xFFA1A1AA)),
                            overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                        ]),
                    ),
                  ),
                );
              },
            ),
          ),
        ]),
      );
    }
  }

  // ─── Prog lang badge ─────────────────────────────────────────────────────────

  class _ProgLangBadge extends StatelessWidget {
    final Color color, textColor;
    final String label;
    const _ProgLangBadge({required this.color, required this.textColor, required this.label});
    @override
    Widget build(BuildContext context) => Container(
      width: 18, height: 18,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
      child: Center(child: Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: textColor))),
    );
  }
class _AdvancedFilterSheet extends StatefulWidget {
  final _MarketplaceScreenState state;
  final int tab;
  final VoidCallback onChanged;
  const _AdvancedFilterSheet({required this.state, required this.tab, required this.onChanged});

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
      setState(() { _sortBy = 'alpha'; _installedOnly = false; _withUpdatesOnly = false; });
      widget.state._clearFilters(widget.tab);
      Navigator.pop(context);
    }

    Widget _section(String title, Widget child) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
            color: Color(0xFF71717A), letterSpacing: 0.8)),
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
          decoration: const BoxDecoration(
            color: Color(0xFF18181B),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(children: [
            const SizedBox(height: 8),
            Container(width: 36, height: 4,
              decoration: BoxDecoration(color: const Color(0xFF3F3F46), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(color: const Color(0xFF4F46E5).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.tune_rounded, size: 16, color: Color(0xFF818CF8)),
                ),
                const SizedBox(width: 10),
                const Text('Filtres avancés', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFFE4E4E7))),
                const Spacer(),
                if (nActive > 0)
                  TextButton(
                    onPressed: _resetAll,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      backgroundColor: const Color(0xFFF87171).withValues(alpha: 0.1),
                      foregroundColor: const Color(0xFFF87171),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Effacer tout', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
              ]),
            ),
            const SizedBox(height: 12),
            Divider(height: 1, color: const Color(0xFF27272A)),
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                children: [
                  // Sort section
                  _section('TRIER PAR', Wrap(spacing: 8, runSpacing: 8, children: [
                    _SortChip(label: 'A → Z', icon: Icons.sort_by_alpha_rounded,
                      active: _sortBy == 'alpha',
                      onTap: () { setState(() => _sortBy = 'alpha'); _apply(); }),
                    _SortChip(label: 'Installées', icon: Icons.download_done_rounded,
                      active: _sortBy == 'installed',
                      onTap: () { setState(() => _sortBy = 'installed'); _apply(); }),
                  ])),
                  const SizedBox(height: 20),

                  // Show section
                  _section('AFFICHER', Column(children: [
                    _FilterToggleTile(
                      icon: Icons.download_done_rounded,
                      label: 'Installées uniquement',
                      sub: 'Masquer les extensions non installées',
                      value: _installedOnly,
                      onChanged: (v) { setState(() { _installedOnly = v; if (v) _withUpdatesOnly = false; }); _apply(); },
                      cs: cs,
                    ),
                    const SizedBox(height: 6),
                    _FilterToggleTile(
                      icon: Icons.system_update_alt_rounded,
                      label: 'Mises à jour disponibles',
                      sub: 'Extensions avec une nouvelle version',
                      value: _withUpdatesOnly,
                      onChanged: (v) { setState(() { _withUpdatesOnly = v; if (v) _installedOnly = false; }); _apply(); },
                      cs: cs,
                    ),
                  ])),
                  const SizedBox(height: 20),

                  // Active filters
                  if (nActive > 0) ...[
                    _section('FILTRES ACTIFS', _ActiveFiltersSummary(
                      state: widget.state, tab: widget.tab, cs: cs,
                      onClear: () { setState(() {}); widget.onChanged(); },
                    )),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Appliquer', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ]),
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
    const _SortChip({required this.label, required this.icon, required this.active, required this.onTap});
    @override
    Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF4F46E5).withValues(alpha: 0.15) : const Color(0xFF27272A),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? const Color(0xFF4F46E5) : Colors.transparent),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: active ? const Color(0xFFA5B4FC) : const Color(0xFF71717A)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
            color: active ? const Color(0xFFA5B4FC) : const Color(0xFFA1A1AA))),
        ]),
      ),
    );
  }

  // ─── Filter toggle tile ───────────────────────────────────────────────────────

  class _FilterToggleTile extends StatelessWidget {
    final IconData icon;
    final String label, sub;
    final bool value;
    final ValueChanged<bool> onChanged;
    final ColorScheme cs;
    const _FilterToggleTile({required this.icon, required this.label, required this.sub,
      required this.value, required this.onChanged, required this.cs});
    @override
    Widget build(BuildContext context) => GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: value ? const Color(0xFF4F46E5).withValues(alpha: 0.08) : const Color(0xFF27272A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: value ? const Color(0xFF4F46E5).withValues(alpha: 0.4) : Colors.transparent),
        ),
        child: Row(children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: value ? const Color(0xFF4F46E5).withValues(alpha: 0.2) : cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: value ? const Color(0xFF818CF8) : cs.onSurfaceVariant),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
              color: value ? const Color(0xFFE4E4E7) : cs.onSurface)),
            const SizedBox(height: 2),
            Text(sub, style: const TextStyle(fontSize: 11, color: Color(0xFF71717A))),
          ])),
          _FToggle(value: value),
        ]),
      ),
    );
  }

  class _FToggle extends StatelessWidget {
    final bool value;
    const _FToggle({required this.value});
    @override
    Widget build(BuildContext context) => AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 38, height: 22,
      decoration: BoxDecoration(
        color: value ? const Color(0xFF4F46E5) : const Color(0xFF3F3F46),
        borderRadius: BorderRadius.circular(11),
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 200),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 16, height: 16, margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4)]),
        ),
      ),
    );
  }

class _ActiveFiltersSummary extends StatelessWidget {
  final _MarketplaceScreenState state;
  final int tab;
  final ColorScheme cs;
  final VoidCallback onClear;
  const _ActiveFiltersSummary({required this.state, required this.tab, required this.cs, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final chips = <(String, VoidCallback)>[];
    final repo = state._repoFilter[tab];
    if (repo != null) chips.add((_MarketplaceScreenState._repoShortLabel(repo), () {
      state._repoFilter.remove(tab);
      onClear();
    }));
    final lang = state._langFilter[tab];
    if (lang != null) chips.add((_MarketplaceScreenState._langCode(lang), () {
      state._langFilter.remove(tab);
      onClear();
    }));
    final prog = state._progLangFilter[tab];
    if (prog != null) chips.add((_MarketplaceScreenState._compatLabel(prog), () {
      state._progLangFilter.remove(tab);
      onClear();
    }));
    if (state._installedOnly) chips.add(('Installées', () {
      state._installedOnly = false;
      onClear();
    }));
    if (state._withUpdatesOnly) chips.add(('Avec Màj', () {
      state._withUpdatesOnly = false;
      onClear();
    }));
    if (state._sortBy != 'alpha') chips.add(('Tri: ${state._sortBy}', () {
      state._sortBy = 'alpha';
      onClear();
    }));

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: chips.map((c) => GestureDetector(
        onTap: c.$2,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: cs.errorContainer.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(c.$1, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: cs.onErrorContainer)),
            const SizedBox(width: 4),
            Icon(Icons.close_rounded, size: 13, color: cs.onErrorContainer),
          ]),
        ),
      )).toList(),
    );
  }
}

  // ─── Marketplace skeleton loading ──────────────────────────────────────────────

  class _MarketplaceSkeleton extends StatefulWidget {
    final ColorScheme cs;
    const _MarketplaceSkeleton({required this.cs});

    @override
    State<_MarketplaceSkeleton> createState() => _MarketplaceSkeletonState();
  }

  class _MarketplaceSkeletonState extends State<_MarketplaceSkeleton>
      with SingleTickerProviderStateMixin {
    late final AnimationController _ctrl;
    late final Animation<double> _anim;

    @override
    void initState() {
      super.initState();
      _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
        ..repeat(reverse: true);
      _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    }

    @override
    void dispose() {
      _ctrl.dispose();
      super.dispose();
    }

    Widget _bone({double width = double.infinity, double height = 14, double radius = 8}) {
      return AnimatedBuilder(
        animation: _anim,
        builder: (_, __) => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            color: Color.lerp(
              widget.cs.surfaceContainerHigh,
              widget.cs.surfaceContainerHighest,
              _anim.value,
            ),
          ),
        ),
      );
    }

    Widget _skeletonCard() {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: widget.cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: widget.cs.outlineVariant.withValues(alpha: 0.25)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          _bone(width: 48, height: 48, radius: 12),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _bone(height: 14, radius: 7),
            const SizedBox(height: 6),
            _bone(width: 140, height: 11, radius: 6),
            const SizedBox(height: 8),
            Row(children: [_bone(width: 48, height: 20, radius: 6), const SizedBox(width: 8), _bone(width: 64, height: 20, radius: 6)]),
          ])),
          const SizedBox(width: 10),
          _bone(width: 36, height: 36, radius: 10),
        ]),
      );
    }

    @override
    Widget build(BuildContext context) {
      return ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 14, bottom: 100),
        itemCount: 8,
        itemBuilder: (_, i) {
          if (i == 0) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: Row(children: [
                _bone(width: 80, height: 12, radius: 6),
                const Spacer(),
                _bone(width: 90, height: 12, radius: 6),
              ]),
            ),
            _skeletonCard(),
          ]);
          return _skeletonCard();
        },
      );
    }
  }

  // ─── Extension version entry ────────────────────────────────────────────────────

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

  class _VersionHistorySheet extends StatelessWidget {
    final _ExtEntry entry;
    final _MarketplaceScreenState state;
    const _VersionHistorySheet({required this.entry, required this.state});

    static Color _tagColor(String tag, ColorScheme cs) {
      switch (tag) {
        case 'stable': return const Color(0xFF43A047);
        case 'broken': return const Color(0xFFE53935);
        case 'unstable': return const Color(0xFFFB8C00);
        case 'major-fix': return const Color(0xFF1E88E5);
        case 'deprecated': return const Color(0xFF757575);
        default: return cs.primary;
      }
    }

    static IconData _tagIcon(String tag) {
      switch (tag) {
        case 'stable': return Icons.verified_rounded;
        case 'broken': return Icons.broken_image_rounded;
        case 'unstable': return Icons.warning_amber_rounded;
        case 'major-fix': return Icons.build_circle_rounded;
        case 'deprecated': return Icons.archive_rounded;
        default: return Icons.label_rounded;
      }
    }

    @override
    Widget build(BuildContext context) {
      final cs = Theme.of(context).colorScheme;
      final versions = entry.versions;
      return DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.35,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, ctrl) => Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: cs.outline.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                _ExtIcon(iconUrl: entry.iconUrl, type: entry.contentType, size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(entry.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: cs.onSurface)),
                    Text('Historique des versions', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            Divider(height: 1, color: cs.outline.withValues(alpha: 0.15)),
            Expanded(
              child: versions.isEmpty
                  ? Center(
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.history_rounded, size: 48, color: cs.onSurfaceVariant.withValues(alpha: 0.3)),
                        const SizedBox(height: 12),
                        Text(
                          'Version actuelle : v${entry.version}',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: cs.onSurface),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "L'historique détaillé sera disponible\nquand l'extension supporte les versions.",
                          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, height: 1.5),
                          textAlign: TextAlign.center,
                        ),
                      ]),
                    )
                  : ListView.separated(
                      controller: ctrl,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      separatorBuilder: (_, __) => Divider(height: 1, indent: 16, endIndent: 16, color: cs.outline.withValues(alpha: 0.10)),
                      itemCount: versions.length,
                      itemBuilder: (ctx, i) {
                        final v = versions[i];
                        final isCurrent = v.version == entry.version;
                        return ListTile(
                          leading: Container(
                            width: 40, height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isCurrent ? cs.primaryContainer : cs.surfaceContainerHigh,
                            ),
                            child: Icon(
                              isCurrent ? Icons.check_circle_rounded : Icons.history_rounded,
                              size: 20,
                              color: isCurrent ? cs.primary : cs.onSurfaceVariant,
                            ),
                          ),
                          title: Row(children: [
                            Text('v${v.version}', style: TextStyle(fontWeight: FontWeight.w700, color: cs.onSurface)),
                            if (isCurrent) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: cs.primaryContainer,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text('installée', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: cs.primary)),
                              ),
                            ],
                            ...v.tags.map((tag) => Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _tagColor(tag, cs).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(color: _tagColor(tag, cs).withValues(alpha: 0.4)),
                                ),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  Icon(_tagIcon(tag), size: 9, color: _tagColor(tag, cs)),
                                  const SizedBox(width: 3),
                                  Text(tag, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: _tagColor(tag, cs))),
                                ]),
                              ),
                            )),
                          ]),
                          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            if (v.date != null)
                              Text(v.date!, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                            if (v.changelog != null && v.changelog!.isNotEmpty)
                              Text(v.changelog!, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, height: 1.4)),
                          ]),
                          trailing: isCurrent
                              ? null
                              : TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    // Trigger install of this specific version
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                      behavior: SnackBarBehavior.floating,
                                      content: Text('Retour à v${v.version} en cours…'),
                                      duration: const Duration(seconds: 2),
                                    ));
                                    state._install(entry);
                                  },
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    minimumSize: const Size(0, 28),
                                  ),
                                  child: Text('Wayback', style: TextStyle(fontSize: 11, color: cs.primary)),
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
      final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      return sorted.map((e) => (e.key, e.value)).toList();
    }

    List<_ExtEntry> get _toInstall {
      var list = widget.state._all
          .where((e) => !widget.state._installed.contains(e.id))
          .toList();
      if (_selLangs.isNotEmpty) list = list.where((e) => _selLangs.contains(e.lang)).toList();
      if (_selTypes.isNotEmpty) list = list.where((e) => _selTypes.contains(e.contentType)).toList();
      return list;
    }

    Future<void> _start() async {
      final entries = List<_ExtEntry>.from(_toInstall);
      if (entries.isEmpty) return;
      setState(() { _running = true; _done = 0; _total = entries.length; });
      await widget.state._installBulk(
        entries: entries,
        onProgress: (done, total) {
          if (mounted) setState(() { _done = done; _total = total; });
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
                width: 36, height: 4,
                margin: const EdgeInsets.only(top: 10, bottom: 4),
                decoration: BoxDecoration(color: cs.outlineVariant, borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Row(
                  children: [
                    Icon(Icons.download_for_offline_rounded, size: 20, color: cs.primary),
                    const SizedBox(width: 10),
                    Text('Installer en masse', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: cs.onSurface)),
                    const Spacer(),
                    if (!_running)
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: cs.onSurfaceVariant, size: 20),
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
                    Text('Catégories', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: cs.onSurface)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _typeItems.map<Widget>(((ItemType, IconData, String) item) {
                        final (type, icon, label) = item;
                        final sel = _selTypes.contains(type);
                        return GestureDetector(
                          onTap: _running ? null : () => setState(() {
                            sel ? _selTypes.remove(type) : _selTypes.add(type);
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 140),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: sel ? cs.primaryContainer : cs.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: sel ? cs.primary : cs.outlineVariant, width: sel ? 1.5 : 1),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(icon, size: 13, color: sel ? cs.primary : cs.onSurfaceVariant),
                              const SizedBox(width: 5),
                              Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: sel ? cs.primary : cs.onSurface)),
                            ]),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Text('Langue', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: cs.onSurface)),
                        const SizedBox(width: 8),
                        Text(
                          _selLangs.isEmpty ? '(toutes)' : '(${_selLangs.length} sélectionnées)',
                          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
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
                          onTap: _running ? null : () => setState(() {
                            sel ? _selLangs.remove(lang) : _selLangs.add(lang);
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 140),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: sel ? cs.primaryContainer : cs.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: sel ? cs.primary : cs.outlineVariant, width: sel ? 1.5 : 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(flag, style: const TextStyle(fontSize: 14)),
                                const SizedBox(width: 5),
                                Text(
                                  '$code ($count)',
                                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: sel ? cs.primary : cs.onSurface),
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
                        border: Border.all(color: cs.primary.withValues(alpha: 0.20)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded, size: 16, color: cs.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${toInstall.length} extension${toInstall.length > 1 ? "s" : ""} à installer',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface),
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
                          '$_done / $_total installées',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: _running
                          ? OutlinedButton.icon(
                              icon: const SizedBox(
                                width: 14, height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              label: Text('Installation… $_done/$_total'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: null,
                            )
                          : FilledButton.icon(
                              icon: const Icon(Icons.download_for_offline_rounded, size: 18),
                              label: Text(
                                toInstall.isEmpty
                                    ? 'Rien à installer'
                                    : 'Installer ${toInstall.length} extension${toInstall.length > 1 ? "s" : ""}',
                              ),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
  const _WTToast({required this.message, required this.onDismiss, this.isError = false, this.icon});
  @override
  State<_WTToast> createState() => _WTToastState();
}

class _WTToastState extends State<_WTToast> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _slide = Tween<Offset>(begin: const Offset(0, 1.5), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
    Future.delayed(const Duration(milliseconds: 2200), () async {
      if (!mounted) return;
      await _ctrl.reverse();
      widget.onDismiss();
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final accent = widget.isError ? Colors.red.shade500 : Colors.deepPurple.shade400;
    return Positioned(
      bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      left: 32, right: 32,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: SafeArea(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF18181B).withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: accent.withValues(alpha: 0.35), width: 1),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 20, spreadRadius: 2)],
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(widget.icon ?? (widget.isError ? Icons.error_rounded : Icons.info_rounded), size: 18, color: accent),
                    const SizedBox(width: 10),
                    Expanded(child: Text(widget.message,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFE4E4E7)),
                      maxLines: 2, overflow: TextOverflow.ellipsis)),
                  ]),
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

  class _EngineCard extends ConsumerWidget {
    final String id;
    final String name;
    final String desc;
    final String version;
    final IconData icon;
    final Color clr;
    final ColorScheme cs;
    const _EngineCard({required this.id, required this.name, required this.desc, required this.version, required this.icon, required this.clr, required this.cs});

    void _showBinarySheet(BuildContext context) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => DraggableScrollableSheet(
          initialChildSize: 0.55,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (ctx, sc) => Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border.all(color: const Color(0xFF2A2A2E)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 8),
                Container(width: 36, height: 4,
                  decoration: BoxDecoration(color: const Color(0xFF3A3A3E), borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Row(children: [
                    Icon(Icons.memory_rounded, size: 16, color: clr),
                    const SizedBox(width: 8),
                    Text('Moteurs binaires', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: clr)),
                  ]),
                ),
                const SizedBox(height: 4),
                Expanded(child: SingleChildScrollView(
                  controller: sc,
                  padding: const EdgeInsets.only(top: 12, bottom: 24),
                  child: const BinariesSection(),
                )),
              ],
            ),
          ),
        ),
      );
    }

    @override
    Widget build(BuildContext context, WidgetRef ref) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
        child: Material(
          color: const Color(0xFF1A1A1E),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () => _showBinarySheet(context),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: clr.withValues(alpha: 0.25)),
              ),
              child: Row(children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: clr.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: clr.withValues(alpha: 0.3)),
                  ),
                  child: Icon(icon, color: clr, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFFE4E4E7))),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(color: clr.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                      child: Text('v$version', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: clr)),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(color: const Color(0xFF27272A), borderRadius: BorderRadius.circular(4)),
                      child: const Text('Moteur', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFF71717A))),
                    ),
                  ]),
                  const SizedBox(height: 3),
                  Text(desc, style: const TextStyle(fontSize: 11, color: Color(0xFF71717A)), maxLines: 2, overflow: TextOverflow.ellipsis),
                ])),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: () => _showBinarySheet(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: clr,
                    side: BorderSide(color: clr.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: const Size(0, 32),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Installer'),
                ),
              ]),
            ),
          ),
        ),
      );
    }
  }


// ─── Binary tab ────────────────────────────────────────────────────────────────
// Shown as the 8th tab in the marketplace — displays downloadable binary engines
// (aria2c) using the same BinariesSection used in Settings.

class _BinaryTab extends StatelessWidget {
  const _BinaryTab();

  @override
  Widget build(BuildContext context) {
    return const CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: SizedBox(height: 12)),
        SliverToBoxAdapter(child: BinariesSection()),
        SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }
}
  