import 'dart:async';
import 'dart:convert';
import 'dart:ui';
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
import 'package:go_router/go_router.dart';

// ─── Constants ─────────────────────────────────────────────────────────────────

const _kWtBase =
    'https://raw.githubusercontent.com/ferelking242/watchtower-extensions/main';
const _kKeiyoushiBase =
    'https://raw.githubusercontent.com/keiyoushi/extensions/repo';
const _kAniyomiBase =
    'https://raw.githubusercontent.com/aniyomiorg/aniyomi-extensions/repo';

const _kFeaturedNames = {
  'MangaDex', 'Webtoons', 'Comick', 'MangaPlus', 'NovelUpdates',
  'AsuraScans', 'ReaperScans', 'Bato.to', 'Viz', 'CrunchyRoll',
};

// ─── Compat filter ─────────────────────────────────────────────────────────────

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
        'id': 'mihon-${firstSrc['id']}'.hashCode,
        'name': (e['name'] ?? firstSrc['name'] ?? '?') as String,
        'iconUrl': iconUrl,
        'lang': lang,
        'version': (e['version'] ?? '?') as String,
        'contentType': isAnime ? 1 : 0,
        'compat': 2,
        'isNsfw': (e['nsfw'] as int? ?? 0) == 1,
        'repoUrl': url,
      });
    } else if (e['id'] is String && e['site'] != null && e['url'] != null) {
      final lang = _mktConvertLang(e);
      results.add({
        'id': 'lnreader-plugin-"${e['name']}"."$lang"'.hashCode,
        'name': (e['name'] ?? '?') as String,
        'iconUrl': e['iconUrl'] as String?,
        'lang': lang,
        'version': e['version']?.toString() ?? '?',
        'contentType': 2,
        'compat': 3,
        'isNsfw': false,
        'repoUrl': url,
      });
    } else if (e['id'] != null && e['name'] != null) {
      final itemTypeIdx = (e['itemType'] as int? ?? 0).clamp(0, 4);
      final compatIdx = (e['sourceCodeLanguage'] as int? ?? 1).clamp(0, 3);
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

// Tab indices
const _kTabHome  = 0;
const _kTabManga = 1;
const _kTabAnime = 2;
const _kTabNovel = 3;
const _kTabGames = 4;
const _kTabMusic = 5;

class _MarketplaceScreenState extends ConsumerState<MarketplaceScreen>
    with TickerProviderStateMixin {

  // ── Data ─────────────────────────────────────────────────────────────────────
  List<_ExtEntry> _all = [];
  Set<int> _installed = {};
  final Map<int, bool> _busy = {};
  Map<int, String> _installedVersions = {};
  Map<int, Source> _installedSources = {};
  bool _loading = true;
  String? _error;

  // ── Tabs ─────────────────────────────────────────────────────────────────────
  late TabController _tabCtrl;

  // ── Search overlay ───────────────────────────────────────────────────────────
  bool _searchOpen = false;
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();

  // ── Per-tab compat filter ─────────────────────────────────────────────────────
  final Map<int, _CompatF> _compatF = {
    _kTabHome: _CompatF.all,
    _kTabManga: _CompatF.all,
    _kTabAnime: _CompatF.all,
    _kTabNovel: _CompatF.all,
    _kTabGames: _CompatF.all,
    _kTabMusic: _CompatF.all,
  };

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
    _tabCtrl = TabController(length: 6, vsync: this);
    _loadAll();
    _refreshInstalled();
  }

  @override
  void dispose() {
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

  Future<List<_ExtEntry>> _fetch(String url) async {
    final r = await http
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 25));
    final maps = r.bodyBytes.length > 80000
        ? await compute(_parseIndexIsolate, {'body': r.body, 'url': url})
        : _parseIndexIsolate({'body': r.body, 'url': url});
    return _mapsToEntries(maps);
  }

  Future<void> _loadAll() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        _fetch('$_kWtBase/manga/index.json').catchError((_) => <_ExtEntry>[]),
        _fetch('$_kWtBase/watch/index.json').catchError((_) => <_ExtEntry>[]),
        _fetch('$_kWtBase/novel/index.json').catchError((_) => <_ExtEntry>[]),
        _fetch('$_kWtBase/music/index.json').catchError((_) => <_ExtEntry>[]),
        _fetch('$_kWtBase/game/index.json').catchError((_) => <_ExtEntry>[]),
        _fetch('$_kKeiyoushiBase/index.min.json').catchError((_) => <_ExtEntry>[]),
        _fetch('$_kAniyomiBase/index.min.json').catchError((_) => <_ExtEntry>[]),
      ]);
      if (mounted) setState(() { _all = results.expand((l) => l).toList(); _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  // ── Install ───────────────────────────────────────────────────────────────────

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
        id: entry.id,
        repo: repo,
        refresh: true,
        androidProxyServer: proxyServer,
        autoUpdateExtensions: true,
        itemType: entry.contentType,
      );
      await _refreshInstalled();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('${entry.name} installée ✓'),
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Erreur : $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 3),
        ));
      }
    } finally {
      if (mounted) setState(() => _busy.remove(entry.id));
    }
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('${entry.name} désinstallée ✓'),
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Erreur désinstallation : $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ));
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

  List<_ExtEntry> _forTab(int tab) {
    List<_ExtEntry> list;
    switch (tab) {
      case _kTabManga: list = _all.where((e) => e.contentType == ItemType.manga).toList(); break;
      case _kTabAnime: list = _all.where((e) => e.contentType == ItemType.anime).toList(); break;
      case _kTabNovel: list = _all.where((e) => e.contentType == ItemType.novel).toList(); break;
      case _kTabGames: list = _all.where((e) => e.contentType == ItemType.game).toList(); break;
      case _kTabMusic: list = _all.where((e) => e.contentType == ItemType.music).toList(); break;
      default: return _all;
    }
    final cf = _compatF[tab] ?? _CompatF.all;
    if (cf != _CompatF.all) {
      final c = cf == _CompatF.mihon
          ? SourceCodeLanguage.mihon
          : cf == _CompatF.lnreader
              ? SourceCodeLanguage.lnreader
              : SourceCodeLanguage.javascript;
      list = list.where((e) => e.compat == c).toList();
    }
    return list;
  }

  List<_ExtEntry> get _searchResults {
    if (_searchQuery.isEmpty) return [];
    final q = _searchQuery.toLowerCase();
    return _all.where((e) =>
        e.name.toLowerCase().contains(q) ||
        e.lang.toLowerCase().contains(q)).take(60).toList();
  }

  List<_ExtEntry> get _featured => _all
      .where((e) => _kFeaturedNames.contains(e.name))
      .toList()..sort((a, b) => a.name.compareTo(b.name));

  // ── Static helpers ────────────────────────────────────────────────────────────

  static String _compatLabel(SourceCodeLanguage c) => switch (c) {
    SourceCodeLanguage.mihon => 'Mihon',
    SourceCodeLanguage.lnreader => 'LNReader',
    SourceCodeLanguage.javascript => 'JS',
    SourceCodeLanguage.dart => 'Dart',
  };

  static Color _compatColor(SourceCodeLanguage c, ColorScheme cs) => switch (c) {
    SourceCodeLanguage.mihon => const Color(0xFF2196F3),
    SourceCodeLanguage.lnreader => const Color(0xFF4CAF50),
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

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          if (_loading)
            _buildLoading(cs)
          else if (_error != null)
            _buildError(cs)
          else
            NestedScrollView(
              headerSliverBuilder: (ctx, innerBoxIsScrolled) => [
                SliverToBoxAdapter(child: _buildLogoRow(cs, theme)),
              ],
              body: Column(
                children: [
                  _buildTabBarRow(cs, theme),
                  Expanded(
                    child: TabBarView(
                      controller: _tabCtrl,
                      children: [
                        _HomeTab(state: this),
                        _TypeTab(state: this, tab: _kTabManga),
                        _TypeTab(state: this, tab: _kTabAnime),
                        _TypeTab(state: this, tab: _kTabNovel),
                        _TypeTab(state: this, tab: _kTabGames),
                        _TypeTab(state: this, tab: _kTabMusic),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          if (_searchOpen) _buildSearchOverlay(cs, theme),
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
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          child: Row(
            children: [
              // PlayStore icon
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/icons/playstore_icon.png',
                  width: 38,
                  height: 38,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 10),
              const Spacer(),
              // Search icon
              SizedBox(
                width: 38,
                height: 38,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: Icon(Icons.search_rounded, size: 22, color: cs.onSurfaceVariant),
                  tooltip: 'Rechercher',
                  onPressed: () {
                    setState(() => _searchOpen = true);
                    Future.delayed(const Duration(milliseconds: 80), () {
                      _searchFocus.requestFocus();
                    });
                  },
                ),
              ),
              const SizedBox(width: 4),
              // Marketplace settings icon
              SizedBox(
                width: 38,
                height: 38,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: Icon(Icons.tune_rounded, size: 22, color: cs.onSurfaceVariant),
                  tooltip: 'Paramètres marketplace',
                  onPressed: _showMarketplaceSettings,
                ),
              ),
                ],
              ),
        ),
      ),
    );
  }

  // ── Tab bar row (pinned — inside NestedScrollView body) ───────────────────────

  Widget _buildTabBarRow(ColorScheme cs, ThemeData theme) {
    return Container(
      color: theme.scaffoldBackgroundColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TabBar(
            controller: _tabCtrl,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelColor: cs.primary,
            unselectedLabelColor: theme.hintColor,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            tabs: [
              _iconTab(Icons.home_outlined, 'Pour vous'),
              _iconTab(Icons.auto_stories_outlined, 'Manga'),
              _iconTab(Icons.live_tv_outlined, 'Anime'),
              _iconTab(Icons.menu_book_outlined, 'Novel'),
              _iconTab(Icons.sports_esports_outlined, 'Jeux'),
              _iconTab(Icons.music_note_outlined, 'Music'),
            ],
          ),
          Divider(height: 1, thickness: 1, color: cs.outline.withValues(alpha: 0.20)),
        ],
      ),
    );
  }

  Tab _iconTab(IconData icon, String label) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 5),
          Text(label),
        ],
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
      FilledButton.tonal(onPressed: _loadAll, child: const Text('Réessayer')),
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
      height: 140,
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

  // ── Search overlay ─────────────────────────────────────────────────────────────

  Widget _buildSearchOverlay(ColorScheme cs, ThemeData theme) {
    return Container(
      color: theme.scaffoldBackgroundColor,
      child: SafeArea(
        child: Column(
          children: [
            // Search field
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () {
                      setState(() {
                        _searchOpen = false;
                        _searchQuery = '';
                        _searchCtrl.clear();
                      });
                    },
                  ),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      focusNode: _searchFocus,
                      autofocus: true,
                      onChanged: (v) => setState(() => _searchQuery = v),
                      decoration: InputDecoration(
                        hintText: 'Rechercher extensions, sources…',
                        hintStyle: TextStyle(fontSize: 14, color: cs.onSurfaceVariant.withValues(alpha: 0.55)),
                        filled: true,
                        fillColor: cs.surfaceContainerHigh,
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () { _searchCtrl.clear(); setState(() => _searchQuery = ''); },
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
            // Results
            Expanded(
              child: _searchQuery.isEmpty
                  ? _buildSearchEmpty(cs)
                  : _searchResults.isEmpty
                      ? Center(
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Text('(・_・;)', style: TextStyle(fontSize: 46, color: cs.onSurfaceVariant.withValues(alpha: 0.5))),
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

  Widget _buildSearchEmpty(ColorScheme cs) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionTitle(cs, 'Extensions populaires', Icons.trending_up_rounded, color: cs.primary),
          ..._featured.take(5).map((e) => _PlayStoreCard(
            entry: e,
            installed: _installed.contains(e.id),
            hasUpdate: _hasUpdate(e.id, e.version),
            busy: _busy[e.id] == true,
            onInstall: () => _install(e),
            onSettings: _installed.contains(e.id) ? () => _openSettings(e.id) : null,
            onUninstall: () => _uninstall(e),
          )),
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
      (_CompatF.mihon, Icons.android_rounded, 'Mihon'),
      (_CompatF.lnreader, Icons.menu_book_outlined, 'LNReader'),
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
}

// ─── Home tab ──────────────────────────────────────────────────────────────────

class _HomeTab extends StatelessWidget {
  final _MarketplaceScreenState state;
  const _HomeTab({required this.state});

  static const _manhuaLangs = {'zh', 'ko', 'zh-hk', 'zh-tw', 'zh-cn'};

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final all = state._all;
    final featured = state._featured;

    // Content-type sections — order: Watch, Manga, Light Novel, Music, Game
    final watchExt = all.where((e) => e.contentType == ItemType.anime).toList();
    final mangaExt = all.where((e) => e.contentType == ItemType.manga).toList();
    final novelExt = all.where((e) => e.contentType == ItemType.novel).toList();
    final musicExt = all.where((e) => e.contentType == ItemType.music).toList();
    final gameExt  = all.where((e) => e.contentType == ItemType.game).toList();

    return RefreshIndicator(
      onRefresh: state._loadAll,
      child: CustomScrollView(
        slivers: [
          // ── Dépôts d'extensions ──────────────────────────────────────────
          SliverToBoxAdapter(
            child: state.sectionTitle(
              cs, "Dépôts d'extensions", Icons.source_rounded,
              color: cs.primary,
              subtitle: 'Sources actives · gérez vos dépôts',
            ),
          ),
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
                subtitle: '${watchExt.length} extensions · Aniyomi & Watchtower',
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

class _TypeTab extends StatelessWidget {
  final _MarketplaceScreenState state;
  final int tab;
  const _TypeTab({required this.state, required this.tab});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final entries = state._forTab(tab);
    return RefreshIndicator(
      onRefresh: state._loadAll,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: state.buildCompatFilter(cs, tab)),
          if (entries.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('ε=ε=(ノ≧∇≦)ノ', style: TextStyle(fontSize: 44, color: cs.onSurfaceVariant.withValues(alpha: 0.5))),
                  const SizedBox(height: 14),
                  Text('Aucune extension', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
                  const SizedBox(height: 6),
                  Text('Réessayez plus tard ou vérifiez la connexion', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant.withValues(alpha: 0.6))),
                  const SizedBox(height: 20),
                  TextButton.icon(
                    onPressed: state._loadAll,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Actualiser'),
                  ),
                ]),
              ),
            )
          else
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
                childCount: entries.length.clamp(0, 300),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
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
      (SourceCodeLanguage.mihon, Icons.android_rounded, 'Mihon/Aniyomi'),
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final compatColor = _MarketplaceScreenState._compatColor(entry.compat, cs);
    final compatLabel = _MarketplaceScreenState._compatLabel(entry.compat);
    final typeColor = _MarketplaceScreenState._typeColor(entry.contentType);
    final langCode = _MarketplaceScreenState._langCode(entry.lang);

    return GestureDetector(
        onLongPress: (installed && onUninstall != null) ? onUninstall : null,
        child: InkWell(
      onTap: null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // ── Icon ───────────────────────────────────────────────────────
            _ExtIcon(iconUrl: entry.iconUrl, type: entry.contentType, size: 56),
            const SizedBox(width: 14),
            // ── Info ───────────────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.name,
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: compatColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: compatColor.withValues(alpha: 0.3)),
                        ),
                        child: Text(compatLabel, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: compatColor, letterSpacing: 0.2)),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: _MarketplaceScreenState._langColor(entry.lang).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: _MarketplaceScreenState._langColor(entry.lang).withValues(alpha: 0.3)),
                        ),
                        child: Text(langCode, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: _MarketplaceScreenState._langColor(entry.lang), letterSpacing: 0.3)),
                      ),
                      if (entry.isNsfw) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(color: Colors.red.shade400.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.red.shade400.withValues(alpha: 0.3))),
                          child: Text('18+', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Colors.red.shade400)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(children: [
                    Icon(_MarketplaceScreenState._typeIcon(entry.contentType), size: 11, color: typeColor),
                    const SizedBox(width: 4),
                    Text('v${entry.version}', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                  ]),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // ── Action area ────────────────────────────────────────────────
            if (installed)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Gear: settings
                  if (onSettings != null)
                    SizedBox(
                      width: 30,
                      height: 30,
                      child: IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        icon: Icon(Icons.settings_outlined, size: 17, color: cs.onSurfaceVariant),
                        onPressed: onSettings,
                        tooltip: 'Paramètres',
                      ),
                    ),
                  const SizedBox(width: 6),
                  // Update or installed indicator
                  hasUpdate
                      ? SizedBox(
                          width: 64,
                          height: 32,
                          child: FilledButton(
                            onPressed: busy ? null : onInstall,
                            style: FilledButton.styleFrom(
                              padding: EdgeInsets.zero,
                              backgroundColor: Colors.orange.shade700,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: busy
                                ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Màj ↑', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                          ),
                        )
                      : Container(
                          width: 36,
                          height: 32,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: cs.primaryContainer.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.check_rounded, size: 18, color: cs.primary),
                        ),
                ],
              )
            else
              SizedBox(
                width: 80,
                height: 32,
                child: FilledButton(
                  onPressed: busy ? null : onInstall,
                  style: FilledButton.styleFrom(
                    padding: EdgeInsets.zero,
                    backgroundColor: cs.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: busy
                      ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: cs.onPrimary))
                      : Text('Installer', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: cs.onPrimary)),
                ),
              ),
          ],
        ),
      ),
      ),
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
  const _MiniCard({
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
    return Container(
      width: 100,
      height: 128,
      margin: const EdgeInsets.only(right: 10, bottom: 2),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: installed ? cs.primary.withValues(alpha: 0.4) : cs.outline.withValues(alpha: 0.12)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _ExtIcon(iconUrl: entry.iconUrl, type: entry.contentType, size: 40),
          const SizedBox(height: 5),
          Text(entry.name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700), maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
          const SizedBox(height: 3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: _MarketplaceScreenState._langColor(entry.lang).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: _MarketplaceScreenState._langColor(entry.lang).withValues(alpha: 0.25)),
            ),
            child: Text(_MarketplaceScreenState._langCode(entry.lang), style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: _MarketplaceScreenState._langColor(entry.lang))),
          ),
          const SizedBox(height: 5),
          SizedBox(
            width: double.infinity,
            height: 26,
            child: installed
                ? hasUpdate
                    ? FilledButton(
                        onPressed: busy ? null : onInstall,
                        style: FilledButton.styleFrom(
                          padding: EdgeInsets.zero,
                          backgroundColor: Colors.orange.shade700,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
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
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                        ),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.settings_outlined, size: 11, color: cs.primary),
                          const SizedBox(width: 2),
                          Icon(Icons.check_rounded, size: 11, color: cs.primary),
                        ]),
                      )
                : FilledButton(
                    onPressed: busy ? null : onInstall,
                    style: FilledButton.styleFrom(padding: EdgeInsets.zero, backgroundColor: cs.primaryContainer, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7))),
                    child: busy
                        ? SizedBox(width: 11, height: 11, child: CircularProgressIndicator(strokeWidth: 1.5, color: cs.onPrimaryContainer))
                        : Icon(Icons.download_rounded, size: 14, color: cs.onPrimaryContainer),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Stats bar ─────────────────────────────────────────────────────────────────

class _StatsBar extends StatelessWidget {
  final int keiyoushi, aniyomi, wt, ln, installed;
  final ColorScheme cs;
  const _StatsBar({
    required this.keiyoushi,
    required this.aniyomi,
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
          _Pill('$keiyoushi', 'Keiyoushi', const Color(0xFF2196F3)),
          _vdivider(cs),
          _Pill('$aniyomi', 'Aniyomi', const Color(0xFF7B2FBE)),
          _vdivider(cs),
          _Pill('$wt', 'Watchtower', const Color(0xFFF5A623)),
          if (ln > 0) ...[_vdivider(cs), _Pill('$ln', 'LNReader', const Color(0xFF4CAF50))],
          _vdivider(cs),
          _Pill('$installed', 'Installées', cs.primary),
        ],
      ),
    );
  }

  Widget _vdivider(ColorScheme cs) =>
      Container(width: 1, height: 28, color: cs.outline.withValues(alpha: 0.2));
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
            ? Image.network(iconUrl!, width: size, height: size, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fallback(cs, color))
            : _fallback(cs, color),
      ),
    );
  }

  Widget _fallback(ColorScheme cs, Color color) => Center(
    child: Icon(_MarketplaceScreenState._typeIcon(type), size: size * 0.48, color: color),
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

  class _RepoCarousel extends StatelessWidget {
    final _MarketplaceScreenState state;
    const _RepoCarousel({required this.state});

    static const _repos = [
      _RepoInfo(
        name: 'Watchtower',
        description: 'Extensions officielles Watchtower (anime, manga, novel)',
        icon: Icons.whatshot_rounded,
        color: Color(0xFF6C63FF),
        tag: 'Officiel',
      ),
      _RepoInfo(
        name: 'Keiyoushi',
        description: 'Extensions manga multi-langues (Mihon-compatible)',
        icon: Icons.auto_stories_rounded,
        color: Color(0xFFE91E63),
        tag: 'Mihon',
      ),
      _RepoInfo(
        name: 'Aniyomi',
        description: 'Extensions anime populaires (Aniyomi-compatible)',
        icon: Icons.live_tv_rounded,
        color: Color(0xFF9C27B0),
        tag: 'Anime',
      ),
    ];

    @override
    Widget build(BuildContext context) {
      final cs = Theme.of(context).colorScheme;
      final allCount = state._all.length;
      final installedCount = state._installed.length;

      return SizedBox(
        height: 112,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          children: [
            _buildStatsCard(cs, allCount, installedCount),
            const SizedBox(width: 10),
            ..._repos.map((r) => Padding(
              padding: const EdgeInsets.only(right: 10),
              child: _buildRepoCard(cs, r),
            )),
          ],
        ),
      );
    }

    Widget _buildStatsCard(ColorScheme cs, int total, int installed) {
      return Container(
        width: 200,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6C63FF), Color(0xFF9C27B0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: const Color(0xFF6C63FF).withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              const Icon(Icons.whatshot_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 6),
              const Expanded(child: Text('Watchtower', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(6)),
                child: const Text('Officiel', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
              ),
            ]),
            const SizedBox(height: 4),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('$total', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, height: 1)),
                const Text('disponibles', style: TextStyle(color: Colors.white70, fontSize: 10)),
              ]),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('$installed', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, height: 1)),
                const Text('installées', style: TextStyle(color: Colors.white70, fontSize: 10)),
              ]),
            ]),
          ],
        ),
      );
    }

    Widget _buildRepoCard(ColorScheme cs, _RepoInfo r) {
      return Container(
        width: 160,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [r.color, r.color.withValues(alpha: 0.65)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: r.color.withValues(alpha: 0.28), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              Icon(r.icon, color: Colors.white, size: 16),
              const SizedBox(width: 5),
              Expanded(child: Text(r.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12), overflow: TextOverflow.ellipsis)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(5)),
                child: Text(r.tag, style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800)),
              ),
            ]),
            Text(r.description, style: const TextStyle(color: Colors.white70, fontSize: 9.5), maxLines: 2, overflow: TextOverflow.ellipsis),
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
    const _RepoInfo({required this.name, required this.description, required this.icon, required this.color, required this.tag});
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
        builder: (_, sc) => Column(
          children: [
            const SizedBox(height: 8),
            Container(width: 36, height: 4, decoration: BoxDecoration(color: cs.outline.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                Icon(Icons.tune_rounded, size: 20, color: cs.primary),
                const SizedBox(width: 10),
                Text('Paramètres marketplace', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: cs.onSurface)),
              ]),
            ),
            const SizedBox(height: 8),
            Divider(height: 1, color: cs.outline.withValues(alpha: 0.15)),
            Expanded(
              child: ListView(
                controller: sc,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                children: [
                  _SettingsTile(
                    icon: Icons.update_rounded,
                    title: 'Vérifier les mises à jour',
                    subtitle: 'Vérifie les nouvelles versions au démarrage',
                    value: checkUpdates,
                    onChanged: (v) => ref.read(checkForExtensionsUpdateStateProvider.notifier).set(v),
                    cs: cs,
                  ),
                  _SettingsTile(
                    icon: Icons.system_update_alt_rounded,
                    title: 'Mise à jour automatique',
                    subtitle: 'Met à jour les extensions automatiquement',
                    value: autoUpdate,
                    onChanged: (v) => ref.read(autoUpdateExtensionsStateProvider.notifier).set(v),
                    cs: cs,
                  ),
                  _SettingsTile(
                    icon: Icons.explicit,
                    title: 'Contenu adulte (18+)',
                    subtitle: 'Afficher les extensions NSFW dans le marketplace',
                    value: showNsfw,
                    onChanged: (v) => ref.read(showNSFWStateProvider.notifier).set(v),
                    cs: cs,
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('Dépôts d\'extensions', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant)),
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.folder_special_rounded, size: 18),
                        label: const Text('Gérer les dépôts'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          context.push('/browse/source-repositories');
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Recharger le marketplace'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          state._loadAll();
                        },
                      ),
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
  