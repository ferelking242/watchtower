import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:watchtower/main.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/settings.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/modules/more/settings/browse/providers/browse_state_provider.dart';
import 'package:watchtower/services/fetch_sources_list.dart';

// ─── Constants ─────────────────────────────────────────────────────────────────

const _kWtBase =
    'https://cdn.jsdelivr.net/gh/ferelking242/watchtower-extensions@main';
// Keiyoushi = communauté officielle Mihon/Tachiyomi (manga, 1 468 packages)
const _kKeiyoushiBase =
    'https://raw.githubusercontent.com/keiyoushi/extensions/repo';
// Aniyomi = extensions anime officielles (3 génériques : Jellyfin, Drive…)
const _kAniyomiBase =
    'https://raw.githubusercontent.com/aniyomiorg/aniyomi-extensions/repo';

const _kFeaturedNames = {
  'MangaDex', 'Webtoons', 'Comick', 'MangaPlus', 'NovelUpdates',
  'AsuraScans', 'ReaperScans', 'Bato.to', 'Viz', 'CrunchyRoll',
};

// ─── Filters ───────────────────────────────────────────────────────────────────

enum _TypeF { all, anime, manga, novel, game }
enum _CompatF { all, mihon, lnreader, js }

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
  });
}

// ─── Top-level parse helpers (top-level = usable by compute()) ─────────────────

String _mktConvertLang(Map<dynamic, dynamic> e) {
  final raw = (e['lang'] ?? e['language'] ?? 'en') as String;
  return raw.toLowerCase().replaceAll(' ', '-');
}

// compute() isolate bridge — receives/returns primitives only (Maps, Strings, ints, bools).
// Returns List<Map<String,dynamic>> which is safe across the isolate boundary.
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

    // ── Mihon: one card per package (deduplicated) ───────────────────────────
    if (e['pkg'] != null && e['sources'] != null) {
      final sources = e['sources'] as List;
      if (sources.isEmpty) continue;
      final repoBase = url.replaceFirst('/index.min.json', '');
      final iconUrl = '$repoBase/icon/${e['pkg']}.png';
      final isAnime = (e['pkg'] as String)
          .startsWith('eu.kanade.tachiyomi.animeextension');
      final firstSrc = sources[0] as Map<dynamic, dynamic>;
      final langs =
          sources.map((s) => (s['lang'] ?? 'en') as String).toSet();
      final lang = langs.length == 1 ? langs.first.toLowerCase() : 'multi';
      results.add({
        'id': 'mihon-${firstSrc['id']}'.hashCode,
        'name': (e['name'] ?? firstSrc['name'] ?? '?') as String,
        'iconUrl': iconUrl,
        'lang': lang,
        'version': (e['version'] ?? '?') as String,
        'contentType': isAnime ? 1 : 0, // ItemType index
        'compat': 2, // SourceCodeLanguage.mihon index
        'isNsfw': (e['nsfw'] as int? ?? 0) == 1,
        'repoUrl': url,
      });
    }
    // ── LNReader ─────────────────────────────────────────────────────────────
    else if (e['id'] is String && e['site'] != null && e['url'] != null) {
      final lang = _mktConvertLang(e);
      results.add({
        'id': 'lnreader-plugin-"${e['name']}"."$lang"'.hashCode,
        'name': (e['name'] ?? '?') as String,
        'iconUrl': e['iconUrl'] as String?,
        'lang': lang,
        'version': e['version']?.toString() ?? '?',
        'contentType': 2, // ItemType.novel index
        'compat': 3, // SourceCodeLanguage.lnreader index
        'isNsfw': false,
        'repoUrl': url,
      });
    }
    // ── Watchtower native ─────────────────────────────────────────────────────
    else if (e['id'] != null && e['name'] != null) {
      final itemTypeIdx = (e['itemType'] as int? ?? 0)
          .clamp(0, 4); // ItemType has 5 values
      final compatIdx = (e['sourceCodeLanguage'] as int? ?? 1)
          .clamp(0, 3); // SourceCodeLanguage has 4 values
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
      });
    }
  }
  return results;
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
        ))
    .toList();

// ─── Screen ────────────────────────────────────────────────────────────────────

class MarketplaceScreen extends ConsumerStatefulWidget {
  const MarketplaceScreen({super.key});
  @override
  ConsumerState<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends ConsumerState<MarketplaceScreen> {
  List<_ExtEntry> _all = [];
  Set<int> _installed = {};
  final Map<int, int> _ratings = {};
  final Map<int, bool> _busy = {};
  bool _loading = true;
  String? _error;
  String _search = '';
  _TypeF _typeF = _TypeF.all;
  _CompatF _compatF = _CompatF.all;
  final _searchCtrl = TextEditingController();

  // ── Init ───────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadAll();
    _refreshInstalled();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _refreshInstalled() async {
    try {
      final sources =
          await isar.sources.filter().isAddedEqualTo(true).findAll();
      if (mounted) {
        setState(() =>
            _installed = sources.map((s) => s.id).whereType<int>().toSet());
      }
    } catch (_) {}
  }

  // ── Fetch ──────────────────────────────────────────────────────────────────

  Future<List<_ExtEntry>> _fetch(String url) async {
    final r = await http
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 25));
    // Offload heavy JSON decode (e.g. Mihon's ~2 MB index) to a separate isolate.
    final maps = r.bodyBytes.length > 80000
        ? await compute(_parseIndexIsolate, {'body': r.body, 'url': url})
        : _parseIndexIsolate({'body': r.body, 'url': url});
    return _mapsToEntries(maps);
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        // Watchtower natif (jsDelivr)
        _fetch('$_kWtBase/manga/index.json').catchError((_) => <_ExtEntry>[]),
        _fetch('$_kWtBase/watch/index.json').catchError((_) => <_ExtEntry>[]),
        _fetch('$_kWtBase/novel/index.json').catchError((_) => <_ExtEntry>[]),
        // Keiyoushi — communauté Mihon/Tachiyomi manga (1 468 packages)
        _fetch('$_kKeiyoushiBase/index.min.json').catchError((_) => <_ExtEntry>[]),
        // Aniyomi — extensions anime officielles (Jellyfin, Google Drive…)
        _fetch('$_kAniyomiBase/index.min.json').catchError((_) => <_ExtEntry>[]),
      ]);
      final merged = results.expand((l) => l).toList();
      if (mounted) setState(() { _all = merged; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  // ── Install ────────────────────────────────────────────────────────────────

  Future<void> _install(_ExtEntry entry) async {
    if (_busy[entry.id] == true) return;
    setState(() => _busy[entry.id] = true);
    try {
      final proxyServer = ref.read(androidProxyServerStateProvider);
      final repo = Repo(
        jsonUrl: entry.repoUrl,
        name: _compatLabel(entry.compat),
        website: '',
      );
      await fetchSourcesList(
        repo: repo,
        refresh: true,
        id: entry.id,
        androidProxyServer: proxyServer,
        autoUpdateExtensions: true,
        itemType: entry.contentType,
      );
      await _refreshInstalled();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${entry.name} installée'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy.remove(entry.id));
    }
  }

  // ── Filter helpers ─────────────────────────────────────────────────────────

  List<_ExtEntry> get _filtered {
    var list = _all;
    if (_typeF != _TypeF.all) {
      final t = _typeF == _TypeF.anime
          ? ItemType.anime
          : _typeF == _TypeF.manga
              ? ItemType.manga
              : _typeF == _TypeF.novel
                  ? ItemType.novel
                  : ItemType.game;
      list = list.where((e) => e.contentType == t).toList();
    }
    if (_compatF != _CompatF.all) {
      final c = _compatF == _CompatF.mihon
          ? SourceCodeLanguage.mihon
          : _compatF == _CompatF.lnreader
              ? SourceCodeLanguage.lnreader
              : SourceCodeLanguage.javascript;
      list = list.where((e) => e.compat == c).toList();
    }
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((e) =>
          e.name.toLowerCase().contains(q) ||
          e.lang.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  bool get _hasFilter =>
      _typeF != _TypeF.all ||
      _compatF != _CompatF.all ||
      _search.isNotEmpty;

  List<_ExtEntry> _byCompat(SourceCodeLanguage c) =>
      _all.where((e) => e.compat == c).toList();

  List<_ExtEntry> get _featured => _all
      .where((e) => _kFeaturedNames.contains(e.name))
      .toList()
    ..sort((a, b) => a.name.compareTo(b.name));

  // ── Stats ──────────────────────────────────────────────────────────────────

  int get _totalCount => _all.length;
  int get _mihonCount =>
      _all.where((e) => e.compat == SourceCodeLanguage.mihon).length;
  int get _lnCount =>
      _all.where((e) => e.compat == SourceCodeLanguage.lnreader).length;
  int get _wtCount =>
      _all
          .where((e) =>
              e.compat == SourceCodeLanguage.javascript ||
              e.compat == SourceCodeLanguage.dart)
          .length;

  // ── Labels / helpers ───────────────────────────────────────────────────────

  static String _compatLabel(SourceCodeLanguage c) => switch (c) {
        SourceCodeLanguage.mihon => 'Mihon',
        SourceCodeLanguage.lnreader => 'LNReader',
        SourceCodeLanguage.javascript => 'JS',
        SourceCodeLanguage.dart => 'Dart',
      };

  static Color _compatColor(SourceCodeLanguage c, ColorScheme cs) =>
      switch (c) {
        SourceCodeLanguage.mihon => const Color(0xFF2196F3),
        SourceCodeLanguage.lnreader => const Color(0xFF4CAF50),
        SourceCodeLanguage.javascript => const Color(0xFFF5A623),
        SourceCodeLanguage.dart => const Color(0xFF00B4D8),
      };

  static IconData _typeIcon(ItemType t) => switch (t) {
        ItemType.anime => Icons.live_tv_rounded,
        ItemType.manga => Icons.auto_stories_rounded,
        ItemType.novel => Icons.menu_book_rounded,
        _ => Icons.sports_esports_rounded,
      };

  static Color _typeColor(ItemType t) => switch (t) {
        ItemType.anime => const Color(0xFF9C27B0),
        ItemType.manga => const Color(0xFFE91E63),
        ItemType.novel => const Color(0xFF009688),
        _ => const Color(0xFF607D8B),
      };

  static String _langFlag(String lang) {
    const flags = {
      'en': '🇬🇧', 'fr': '🇫🇷', 'ja': '🇯🇵', 'zh': '🇨🇳', 'ko': '🇰🇷',
      'es': '🇪🇸', 'pt': '🇵🇹', 'pt-br': '🇧🇷', 'de': '🇩🇪', 'it': '🇮🇹',
      'ru': '🇷🇺', 'ar': '🇸🇦', 'tr': '🇹🇷', 'pl': '🇵🇱', 'vi': '🇻🇳',
      'id': '🇮🇩', 'th': '🇹🇭', 'uk': '🇺🇦', 'all': '🌐',
    };
    return flags[lang.toLowerCase()] ?? '🌐';
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: CustomScrollView(
          slivers: [
            // Header
            SliverToBoxAdapter(child: _buildHeader(cs)),
            // Search
            SliverToBoxAdapter(child: _buildSearch(cs)),
            // Type filter
            SliverToBoxAdapter(child: _buildTypeFilter(cs)),
            // Compat filter
            SliverToBoxAdapter(child: _buildCompatFilter(cs)),

            if (_loading) ...[
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: cs.primary),
                      const SizedBox(height: 14),
                      Text(
                        'Chargement des extensions…',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
            ] else if (_error != null) ...[
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.wifi_off_rounded,
                          size: 52, color: cs.error.withValues(alpha: 0.6)),
                      const SizedBox(height: 12),
                      Text('Erreur de chargement',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface)),
                      const SizedBox(height: 6),
                      FilledButton.tonal(
                        onPressed: _loadAll,
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                ),
              ),
            ] else if (_hasFilter) ...[
              // ── Filtered list ──────────────────────────────────────────────
              SliverToBoxAdapter(
                child: _sectionTitle(
                    cs, '${_filtered.length} résultat(s)', Icons.list_rounded),
              ),
              if (_filtered.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off_rounded,
                            size: 52,
                            color:
                                cs.onSurfaceVariant.withValues(alpha: 0.4)),
                        const SizedBox(height: 10),
                        Text('Aucune extension trouvée',
                            style: TextStyle(color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _ExtCard(
                      entry: _filtered[i],
                      installed: _installed.contains(_filtered[i].id),
                      busy: _busy[_filtered[i].id] == true,
                      rating: _ratings[_filtered[i].id] ?? 0,
                      onInstall: () => _install(_filtered[i]),
                      onRate: (v) =>
                          setState(() => _ratings[_filtered[i].id] = v),
                    ),
                    childCount: _filtered.length.clamp(0, 200),
                  ),
                ),
            ] else ...[
              // ── Stats bar ─────────────────────────────────────────────────
              SliverToBoxAdapter(child: _buildStats(cs)),

              // ── Featured ─────────────────────────────────────────────────
              if (_featured.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: _sectionTitle(
                      cs, 'À la une', Icons.star_rounded,
                      color: Colors.amber),
                ),
                SliverToBoxAdapter(
                  child: _buildHorizontal(
                      _featured, cs, featured: true),
                ),
              ],

              // ── Mihon section ─────────────────────────────────────────────
              if (_mihonCount > 0) ...[
                SliverToBoxAdapter(
                  child: _sectionTitle(
                      cs,
                      'Mihon · $_mihonCount extensions',
                      Icons.android_rounded,
                      color: const Color(0xFF2196F3),
                      subtitle: 'Android uniquement · Tachiyomi/Aniyomi',
                      onSeeAll: () =>
                          setState(() => _compatF = _CompatF.mihon)),
                ),
                SliverToBoxAdapter(
                  child:
                      _buildHorizontal(_byCompat(SourceCodeLanguage.mihon), cs),
                ),
              ],

              // ── LNReader section ──────────────────────────────────────────
              if (_lnCount > 0) ...[
                SliverToBoxAdapter(
                  child: _sectionTitle(
                      cs,
                      'LNReader · $_lnCount extensions',
                      Icons.menu_book_rounded,
                      color: const Color(0xFF4CAF50),
                      subtitle: 'Light novels & Web novels',
                      onSeeAll: () =>
                          setState(() => _compatF = _CompatF.lnreader)),
                ),
                SliverToBoxAdapter(
                  child: _buildHorizontal(
                      _byCompat(SourceCodeLanguage.lnreader), cs),
                ),
              ],

              // ── Watchtower JS section ─────────────────────────────────────
              if (_wtCount > 0) ...[
                SliverToBoxAdapter(
                  child: _sectionTitle(
                      cs,
                      'Watchtower · $_wtCount extensions',
                      Icons.extension_rounded,
                      color: const Color(0xFFF5A623),
                      subtitle: 'JS natif · toutes plateformes',
                      onSeeAll: () =>
                          setState(() => _compatF = _CompatF.js)),
                ),
                SliverToBoxAdapter(
                  child: _buildHorizontal(
                      _all
                          .where((e) =>
                              e.compat == SourceCodeLanguage.javascript ||
                              e.compat == SourceCodeLanguage.dart)
                          .toList(),
                      cs),
                ),
              ],
            ],

            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
    );
  }

  // ─── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.primaryContainer.withValues(alpha: 0.85),
            cs.tertiaryContainer.withValues(alpha: 0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: cs.primary.withValues(alpha: 0.15), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [cs.primary, cs.tertiary],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: cs.primary.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.storefront_rounded,
                color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Marketplace',
                    style: TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w800)),
                Text(
                  'Extensions · Keiyoushi · Aniyomi · Watchtower JS',
                  style:
                      TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (!_loading && _totalCount > 0)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$_totalCount',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: cs.primary),
                ),
                Text('extensions',
                    style: TextStyle(
                        fontSize: 10,
                        color: cs.onSurfaceVariant)),
              ],
            ),
        ],
      ),
    );
  }

  // ─── Search ────────────────────────────────────────────────────────────────

  Widget _buildSearch(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _search = v),
        decoration: InputDecoration(
          hintText: 'Rechercher par nom, langue…',
          hintStyle: TextStyle(
              fontSize: 13,
              color: cs.onSurfaceVariant.withValues(alpha: 0.55)),
          prefixIcon: Icon(Icons.search_rounded, color: cs.primary, size: 20),
          suffixIcon: _search.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _search = '');
                  },
                )
              : null,
          filled: true,
          fillColor: cs.surfaceContainerHigh,
          isDense: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        ),
      ),
    );
  }

  // ─── Type filter ───────────────────────────────────────────────────────────

  Widget _buildTypeFilter(ColorScheme cs) {
    const items = [
      (_TypeF.all, '🌐 Tout'),
      (_TypeF.anime, '📺 Anime'),
      (_TypeF.manga, '📚 Manga'),
      (_TypeF.novel, '📖 Novel'),
      (_TypeF.game, '🎮 Game'),
    ];
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: items.length,
        itemBuilder: (_, i) {
          final (f, label) = items[i];
          final active = _typeF == f;
          return _FilterChip(
            label: label,
            active: active,
            onTap: () => setState(() => _typeF = active ? _TypeF.all : f),
          );
        },
      ),
    );
  }

  // ─── Compat filter ─────────────────────────────────────────────────────────

  Widget _buildCompatFilter(ColorScheme cs) {
    const items = [
      (_CompatF.all, '✦ Tout'),
      (_CompatF.mihon, '🔵 Mihon'),
      (_CompatF.lnreader, '📗 LNReader'),
      (_CompatF.js, '🎯 JS / Dart'),
    ];
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        itemCount: items.length,
        itemBuilder: (_, i) {
          final (f, label) = items[i];
          final active = _compatF == f;
          return _FilterChip(
            label: label,
            active: active,
            small: true,
            onTap: () =>
                setState(() => _compatF = active ? _CompatF.all : f),
          );
        },
      ),
    );
  }

  // ─── Stats bar ─────────────────────────────────────────────────────────────

  Widget _buildStats(ColorScheme cs) {
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
          _StatPill('$_mihonCount', 'Keiyoushi', const Color(0xFF2196F3)),
          _divider(cs),
          _StatPill('$_wtCount', 'Watchtower', const Color(0xFFF5A623)),
          _divider(cs),
          if (_lnCount > 0) ...[
            _StatPill('$_lnCount', 'LNReader', const Color(0xFF4CAF50)),
            _divider(cs),
          ],
          _StatPill('${_installed.length}', 'Installées', cs.primary),
        ],
      ),
    );
  }

  Widget _divider(ColorScheme cs) => Container(
      width: 1, height: 28,
      color: cs.outline.withValues(alpha: 0.2));

  // ─── Section title ─────────────────────────────────────────────────────────

  Widget _sectionTitle(ColorScheme cs, String title, IconData icon,
      {Color? color, String? subtitle, VoidCallback? onSeeAll}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 12, 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color ?? cs.primary),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface,
                    )),
                if (subtitle != null)
                  Text(subtitle,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                      )),
              ],
            ),
          ),
          if (onSeeAll != null)
            TextButton(
              onPressed: onSeeAll,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 28),
              ),
              child: Text('Voir tout →',
                  style:
                      TextStyle(fontSize: 11.5, color: color ?? cs.primary)),
            ),
        ],
      ),
    );
  }

  // ─── Horizontal carousel ──────────────────────────────────────────────────

  Widget _buildHorizontal(List<_ExtEntry> entries, ColorScheme cs,
      {bool featured = false}) {
    final show = entries.take(20).toList();
    final h = featured ? 170.0 : 140.0;
    return SizedBox(
      height: h,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
        itemCount: show.length,
        itemBuilder: (ctx, i) => featured
            ? _FeaturedMiniCard(
                entry: show[i],
                installed: _installed.contains(show[i].id),
                busy: _busy[show[i].id] == true,
                onInstall: () => _install(show[i]),
              )
            : _MiniCard(
                entry: show[i],
                installed: _installed.contains(show[i].id),
                busy: _busy[show[i].id] == true,
                onInstall: () => _install(show[i]),
              ),
      ),
    );
  }
}

// ─── Filter chip ───────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final bool small;
  const _FilterChip(
      {required this.label,
      required this.active,
      required this.onTap,
      this.small = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 8),
        padding: EdgeInsets.symmetric(
            horizontal: small ? 11 : 13, vertical: small ? 4 : 5),
        decoration: BoxDecoration(
          color: active ? cs.primary : cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active
                  ? cs.primary
                  : cs.outline.withValues(alpha: 0.2)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: small ? 11.5 : 12.5,
            fontWeight: FontWeight.w600,
            color: active ? cs.onPrimary : cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

// ─── Stat pill ─────────────────────────────────────────────────────────────────

class _StatPill extends StatelessWidget {
  final String count;
  final String label;
  final Color color;
  const _StatPill(this.count, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(count,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: color)),
        Text(label,
            style: TextStyle(
                fontSize: 9.5,
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant
                    .withValues(alpha: 0.8))),
      ],
    );
  }
}

// ─── Extension card (list) ─────────────────────────────────────────────────────

class _ExtCard extends StatelessWidget {
  final _ExtEntry entry;
  final bool installed;
  final bool busy;
  final int rating;
  final VoidCallback onInstall;
  final ValueChanged<int> onRate;

  const _ExtCard({
    required this.entry,
    required this.installed,
    required this.busy,
    required this.rating,
    required this.onInstall,
    required this.onRate,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final compatColor = _MarketplaceScreenState._compatColor(entry.compat, cs);
    final compatLabel = _MarketplaceScreenState._compatLabel(entry.compat);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withValues(alpha: 0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon
          _ExtIcon(iconUrl: entry.iconUrl, type: entry.contentType, size: 52),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name + badges row
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.name,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (entry.isNsfw)
                      _Badge('18+', const Color(0xFFE53935), cs),
                    const SizedBox(width: 4),
                    _Badge(compatLabel, compatColor, cs),
                  ],
                ),
                const SizedBox(height: 3),
                // Lang + version
                Row(
                  children: [
                    Text(
                      _MarketplaceScreenState._langFlag(entry.lang),
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      entry.lang.toUpperCase(),
                      style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(width: 8),
                    Icon(_MarketplaceScreenState._typeIcon(entry.contentType),
                        size: 11,
                        color: _MarketplaceScreenState._typeColor(
                            entry.contentType)),
                    const SizedBox(width: 3),
                    Text(
                      'v${entry.version}',
                      style: TextStyle(
                          fontSize: 10.5, color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                // Stars row
                Row(
                  children: List.generate(5, (i) => GestureDetector(
                    onTap: () => onRate(i + 1),
                    child: Icon(
                      i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 15,
                      color: i < rating ? Colors.amber : cs.onSurfaceVariant.withValues(alpha: 0.35),
                    ),
                  )),
                ),
                const SizedBox(height: 7),
                // Install button
                SizedBox(
                  width: double.infinity,
                  height: 32,
                  child: installed
                      ? OutlinedButton.icon(
                          onPressed: null,
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            side: BorderSide(
                                color: cs.primary.withValues(alpha: 0.4)),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: Icon(Icons.check_circle_rounded,
                              size: 14, color: cs.primary),
                          label: Text('Installée',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: cs.primary)),
                        )
                      : FilledButton(
                          onPressed: busy ? null : onInstall,
                          style: FilledButton.styleFrom(
                            padding: EdgeInsets.zero,
                            backgroundColor: cs.primary,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          child: busy
                              ? SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: cs.onPrimary),
                                )
                              : Text('Installer',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: cs.onPrimary)),
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

// ─── Badge ─────────────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final ColorScheme cs;
  const _Badge(this.label, this.color, this.cs);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.2)),
    );
  }
}

// ─── Extension icon ────────────────────────────────────────────────────────────

class _ExtIcon extends StatelessWidget {
  final String? iconUrl;
  final ItemType type;
  final double size;
  const _ExtIcon({this.iconUrl, required this.type, required this.size});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = _MarketplaceScreenState._typeColor(type);
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
            ? Image.network(
                iconUrl!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fallbackIcon(cs, color),
              )
            : _fallbackIcon(cs, color),
      ),
    );
  }

  Widget _fallbackIcon(ColorScheme cs, Color color) => Center(
        child: Icon(
          _MarketplaceScreenState._typeIcon(type),
          size: size * 0.48,
          color: color,
        ),
      );
}

// ─── Mini card (horizontal carousel) ──────────────────────────────────────────

class _MiniCard extends StatelessWidget {
  final _ExtEntry entry;
  final bool installed;
  final bool busy;
  final VoidCallback onInstall;
  const _MiniCard(
      {required this.entry,
      required this.installed,
      required this.busy,
      required this.onInstall});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final compatColor =
        _MarketplaceScreenState._compatColor(entry.compat, cs);

    return Container(
      width: 100,
      margin: const EdgeInsets.only(right: 10, bottom: 2),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: installed
                ? cs.primary.withValues(alpha: 0.4)
                : cs.outline.withValues(alpha: 0.12)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _ExtIcon(iconUrl: entry.iconUrl, type: entry.contentType, size: 40),
          const SizedBox(height: 5),
          Text(
            entry.name,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 3),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_MarketplaceScreenState._langFlag(entry.lang),
                  style: const TextStyle(fontSize: 10)),
              const SizedBox(width: 3),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: compatColor,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          SizedBox(
            width: double.infinity,
            height: 26,
            child: installed
                ? OutlinedButton(
                    onPressed: null,
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      side: BorderSide(
                          color: cs.primary.withValues(alpha: 0.4)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(7)),
                    ),
                    child: Icon(Icons.check_rounded,
                        size: 13, color: cs.primary),
                  )
                : FilledButton(
                    onPressed: busy ? null : onInstall,
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.zero,
                      backgroundColor: cs.primaryContainer,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(7)),
                    ),
                    child: busy
                        ? SizedBox(
                            width: 11,
                            height: 11,
                            child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: cs.onPrimaryContainer),
                          )
                        : Icon(Icons.download_rounded,
                            size: 14,
                            color: cs.onPrimaryContainer),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Featured mini card ────────────────────────────────────────────────────────

class _FeaturedMiniCard extends StatelessWidget {
  final _ExtEntry entry;
  final bool installed;
  final bool busy;
  final VoidCallback onInstall;
  const _FeaturedMiniCard(
      {required this.entry,
      required this.installed,
      required this.busy,
      required this.onInstall});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final compatColor =
        _MarketplaceScreenState._compatColor(entry.compat, cs);
    final typeColor = _MarketplaceScreenState._typeColor(entry.contentType);

    return Container(
      width: 200,
      margin: const EdgeInsets.only(right: 12, bottom: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            typeColor.withValues(alpha: 0.75),
            compatColor.withValues(alpha: 0.55),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: typeColor.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            _ExtIcon(
                iconUrl: entry.iconUrl,
                type: entry.contentType,
                size: 48),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(entry.name,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  Row(
                    children: [
                      Text(
                          _MarketplaceScreenState._langFlag(entry.lang),
                          style: const TextStyle(fontSize: 11)),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _MarketplaceScreenState._compatLabel(entry.compat),
                          style: const TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    width: double.infinity,
                    height: 28,
                    child: installed
                        ? Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_rounded,
                                    size: 13, color: Colors.white),
                                SizedBox(width: 4),
                                Text('Installée',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700)),
                              ],
                            ),
                          )
                        : FilledButton(
                            onPressed: busy ? null : onInstall,
                            style: FilledButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.25),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(7)),
                            ),
                            child: busy
                                ? const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 1.5,
                                        color: Colors.white),
                                  )
                                : const Text('Installer',
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white)),
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
