import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
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
  };

  // ── Play Store enhanced filter state ─────────────────────────────────────────
  final Map<int, String?> _repoFilter = {};
  final Map<int, String?> _langFilter = {};
  final Map<int, SourceCodeLanguage?> _progLangFilter = {};
  String _sortBy = 'alpha';
  bool _installedOnly = false;
  bool _withUpdatesOnly = false;
  bool _showNsfw = true;
  String? _globalLangFilter;

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
    _tabCtrl = TabController(length: 6, vsync: this);
    _loadAll();
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

  Future<List<_ExtEntry>> _fetch(String url) async {
    final bust = '?_=${DateTime.now().millisecondsSinceEpoch}';
    final bustUrl = url.contains('?') ? url : url + bust;
    final r = await http
        .get(Uri.parse(bustUrl))
        .timeout(const Duration(seconds: 35));
    if (r.statusCode != 200) {
      throw Exception('HTTP ${r.statusCode} pour $url');
    }
    if (r.body.isEmpty) {
      throw Exception('Réponse vide pour $url');
    }
    final maps = r.bodyBytes.length > 80000
        ? await compute(_parseIndexIsolate, {'body': r.body, 'url': url})
        : _parseIndexIsolate({'body': r.body, 'url': url});
    return _mapsToEntries(maps);
  }

  Future<void> _loadAll({bool bypassCache = false}) async {
      // First entry: skeleton loading. Refresh: keep UI alive, show progress bar.
      if (_all.isEmpty) {
        setState(() { _loading = true; _error = null; });
      } else {
        setState(() { _refreshing = true; });
      }
      try {
        final suffix = bypassCache ? '?_=${DateTime.now().millisecondsSinceEpoch}' : '';
        final results = await Future.wait([
          _fetch('$_kWtBase/manga/index.json$suffix').catchError((_) => <_ExtEntry>[]),
          _fetch('$_kWtBase/watch/index.json$suffix').catchError((_) => <_ExtEntry>[]),
          _fetch('$_kWtBase/novel/index.json$suffix').catchError((_) => <_ExtEntry>[]),
          _fetch('$_kWtBase/music/index.json$suffix').catchError((_) => <_ExtEntry>[]),
          _fetch('$_kWtBase/game/index.json$suffix').catchError((_) => <_ExtEntry>[]),
        ]);
        if (mounted) setState(() {
          _all = results.expand((l) => l).toList();
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
      case _kTabManga: return _all.where((e) => e.contentType == ItemType.manga).toList();
      case _kTabAnime: return _all.where((e) => e.contentType == ItemType.anime).toList();
      case _kTabNovel: return _all.where((e) => e.contentType == ItemType.novel).toList();
      case _kTabGames: return _all.where((e) => e.contentType == ItemType.game).toList();
      case _kTabMusic: return _all.where((e) => e.contentType == ItemType.music).toList();
      default: return _all;
    }
  }

  List<_ExtEntry> _forTab(int tab) {
    List<_ExtEntry> list = List<_ExtEntry>.from(_forTabRaw(tab));
    // 1. NSFW
    if (!_showNsfw) list = list.where((e) => !e.isNsfw).toList();
    // 2. Compat chips (JS/Dart filter)
    final cf = _compatF[tab] ?? _CompatF.all;
    if (cf != _CompatF.all) {
      list = list.where((e) =>
          e.compat == SourceCodeLanguage.javascript ||
          e.compat == SourceCodeLanguage.dart).toList();
    }
    // 3. Repo filter
    final repo = _repoFilter[tab];
    if (repo != null) list = list.where((e) => e.repoUrl.contains(repo)).toList();
    // 4. Language filter
    final lang = _langFilter[tab];
    if (lang != null) list = list.where((e) => e.lang == lang).toList();
    // 5. Prog-lang filter
    final prog = _progLangFilter[tab];
    if (prog != null) list = list.where((e) => e.compat == prog).toList();
    // 6. Advanced toggles
    if (_installedOnly) list = list.where((e) => _installed.contains(e.id)).toList();
    if (_withUpdatesOnly) list = list.where((e) => _hasUpdate(e.id, e.version)).toList();
    // 7. Sort
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
    return _all.where((e) =>
        e.name.toLowerCase().contains(q) ||
        e.lang.toLowerCase().contains(q)).take(60).toList();
  }

  List<_ExtEntry> get _featured => _all
      .where((e) => _kFeaturedNames.contains(e.name))
      .toList()..sort((a, b) => a.name.compareTo(b.name));

  // ── Static helpers ────────────────────────────────────────────────────────────

  static String _compatLabel(SourceCodeLanguage c) => switch (c) {
    SourceCodeLanguage.mihon => 'APK',
    SourceCodeLanguage.lnreader => 'Plugin',
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
    _showNsfw = ref.watch(showNSFWStateProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          if (_error != null && _all.isEmpty)
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
            if (_refreshing)
              Positioned(
                top: 0, left: 0, right: 0,
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
                      width: 42, height: 42,
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
                          fontSize: 19, fontWeight: FontWeight.w800,
                          color: cs.onSurface, letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        'Extension Marketplace',
                        style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant),
                      ),
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
          context.push('/browse/source-repositories');
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
      final counts = [
        _all.length,
        _all.where((e) => e.contentType == ItemType.anime).length,
        _all.where((e) => e.contentType == ItemType.manga).length,
        _all.where((e) => e.contentType == ItemType.novel).length,
        _all.where((e) => e.contentType == ItemType.game).length,
        _all.where((e) => e.contentType == ItemType.music).length,
      ];
      const labels = ['Tout', 'Streaming', 'Manga', 'Novel', 'Game', 'Music'];

      return Container(
        color: theme.scaffoldBackgroundColor,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
              child: AnimatedBuilder(
                animation: _tabCtrl,
                builder: (_, __) {
                  return Wrap(
                    spacing: 7,
                    runSpacing: 6,
                    children: List.generate(6, (i) {
                      final selected = _tabCtrl.index == i;
                      return GestureDetector(
                        onTap: () => _tabCtrl.animateTo(i),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: selected ? cs.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: selected ? Colors.transparent : cs.outline.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                labels[i],
                                style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600,
                                  color: selected ? cs.onPrimary : cs.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? cs.onPrimary.withValues(alpha: 0.22)
                                      : cs.surfaceContainerHigh,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${counts[i]}',
                                  style: TextStyle(
                                    fontSize: 10, fontWeight: FontWeight.w700,
                                    color: selected ? cs.onPrimary : cs.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  );
                },
              ),
            ),
            Divider(height: 1, thickness: 1, color: cs.outline.withValues(alpha: 0.15)),
          ],
        ),
      );
    }

    Widget _buildPersistentSearch(ColorScheme cs, ThemeData theme) {
      return Container(
        color: theme.scaffoldBackgroundColor,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
          child: Container(
            height: 46,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.outline.withValues(alpha: 0.18)),
            ),
            child: Row(
              children: [
                const SizedBox(width: 14),
                Icon(Icons.search_rounded, size: 18, color: cs.onSurfaceVariant),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    style: TextStyle(fontSize: 14, color: cs.onSurface),
                    decoration: InputDecoration(
                      hintText: 'Rechercher une extension…',
                      hintStyle: TextStyle(fontSize: 14, color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  IconButton(
                    icon: Icon(Icons.close_rounded, size: 16, color: cs.onSurfaceVariant),
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

    Widget _buildLangDropdown(ColorScheme cs, ThemeData theme) {
      final langs = (_all.map((e) => e.lang).toSet().toList()..sort());
      return Container(
        color: theme.scaffoldBackgroundColor,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHigh.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: cs.outline.withValues(alpha: 0.22)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: _globalLangFilter,
                    isExpanded: true,
                    icon: Icon(Icons.expand_more_rounded, color: cs.onSurfaceVariant, size: 20),
                    hint: Text('Toutes les langues', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13.5)),
                    style: TextStyle(color: cs.onSurface, fontSize: 13.5),
                    dropdownColor: cs.surfaceContainerHighest,
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('Toutes les langues')),
                      ...langs.map((l) => DropdownMenuItem<String?>(value: l, child: Text(l))),
                    ],
                    onChanged: (v) => setState(() => _globalLangFilter = v),
                  ),
                ),
              ),
            ),
            Divider(height: 1, thickness: 1, color: cs.outline.withValues(alpha: 0.15)),
          ],
        ),
      );
    }

    // ── Loading / Error ────────────────────────────────────────────────────────────
  List<_ExtEntry> _forTab(int tab) {
      List<_ExtEntry> list = List<_ExtEntry>.from(_forTabRaw(tab));
      // 1. Search query
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        list = list.where((e) =>
            e.name.toLowerCase().contains(q) ||
            e.lang.toLowerCase().contains(q)).toList();
      }
      // 2. NSFW
      if (!_showNsfw) list = list.where((e) => !e.isNsfw).toList();
      // 3. Compat chips (JS/Dart filter)
      final cf = _compatF[tab] ?? _CompatF.all;
      if (cf != _CompatF.all) {
        list = list.where((e) =>
            e.compat == SourceCodeLanguage.javascript ||
            e.compat == SourceCodeLanguage.dart).toList();
      }
      // 4. Repo filter
      final repo = _repoFilter[tab];
      if (repo != null) list = list.where((e) => e.repoUrl.contains(repo)).toList();
      // 5. Language filter (global dropdown)
      if (_globalLangFilter != null) {
        list = list.where((e) => e.lang == _globalLangFilter).toList();
      }
      // 6. Per-tab language filter (legacy)
      final lang = _langFilter[tab];
      if (lang != null) list = list.where((e) => e.lang == lang).toList();
      // 7. Prog-lang filter
      final prog = _progLangFilter[tab];
      if (prog != null) list = list.where((e) => e.compat == prog).toList();
      // 8. Advanced toggles
      if (_installedOnly) list = list.where((e) => _installed.contains(e.id)).toList();
      if (_withUpdatesOnly) list = list.where((e) => _hasUpdate(e.id, e.version)).toList();
      // 9. Sort
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
    return _all.where((e) =>
        e.name.toLowerCase().contains(q) ||
        e.lang.toLowerCase().contains(q)).take(60).toList();
  }

  List<_ExtEntry> get _featured => _all
      .where((e) => _kFeaturedNames.contains(e.name))
      .toList()..sort((a, b) => a.name.compareTo(b.name));

  // ── Static helpers ────────────────────────────────────────────────────────────

  static String _compatLabel(SourceCodeLanguage c) => switch (c) {
    SourceCodeLanguage.mihon => 'APK',
    SourceCodeLanguage.lnreader => 'Plugin',
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
                  _buildLangDropdown(cs, theme),
                  Expanded(
                    child: TabBarView(
                      controller: _tabCtrl,
                      children: [
                        _TypeTab(state: this, tab: _kTabHome),
                        _TypeTab(state: this, tab: _kTabAnime),
                        _TypeTab(state: this, tab: _kTabManga),
                        _TypeTab(state: this, tab: _kTabNovel),
                        _TypeTab(state: this, tab: _kTabGames),
                        _TypeTab(state: this, tab: _kTabMusic),
                      ],
                    ),
                  ),
                ],
              ),
            if (_refreshing)
              Positioned(
                top: 0, left: 0, right: 0,
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
              // Account icon with dropdown
              SizedBox(
                key: _accountKey,
                width: 38,
                height: 38,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _accountOpen
                        ? const Color(0xFF7C3AED).withValues(alpha: 0.18)
                        : Colors.transparent,
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      Icons.account_circle_rounded,
                      size: 26,
                      color: _accountOpen ? const Color(0xFF7C3AED) : cs.onSurfaceVariant,
                    ),
                    tooltip: 'Compte',
                    onPressed: _toggleAccountDropdown,
                  ),
                ),
              ),
                ],
              ),
        ),
      ),
    );
  }

  // ── Account dropdown ──────────────────────────────────────────────────────────

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
          context.push('/browse/source-repositories');
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
      (_kTabAnime, Icons.live_tv_rounded, 'Anime', const Color(0xFF9C27B0)),
      (_kTabManga, Icons.auto_stories_rounded, 'Manga', const Color(0xFFE91E63)),
      (_kTabNovel, Icons.menu_book_rounded, 'Novel', const Color(0xFF009688)),
      (_kTabMusic, Icons.music_note_rounded, 'Music', const Color(0xFF0288D1)),
      (_kTabGames, Icons.sports_esports_rounded, 'Jeux', const Color(0xFF607D8B)),
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
                            _tabCtrl.animateTo(categories[i].$1);
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
                              _tabCtrl.animateTo(categories[i + 1].$1);
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
      onRefresh: state._loadAll,
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

class _TypeTab extends StatelessWidget {
  final _MarketplaceScreenState state;
  final int tab;
  const _TypeTab({required this.state, required this.tab});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (state._loading) return _MarketplaceSkeleton(cs: cs);
    final entries = state._forTab(tab);
    return RefreshIndicator(
      onRefresh: state._loadAll,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: state.buildCompatFilter(cs, tab)),
          SliverToBoxAdapter(child: state.buildFilterStrip(tab)),
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
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    TextButton.icon(
                      onPressed: state._loadAll,
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
                childCount: entries.length.clamp(0, 500),
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

    @override
    Widget build(BuildContext context) {
      final cs = Theme.of(context).colorScheme;
      final compatLabel = _MarketplaceScreenState._compatLabel(entry.compat);
      final langCode = _MarketplaceScreenState._langCode(entry.lang);
      final slug = _slugify(entry.name);
      final desc = _description(entry.contentType, entry.lang, entry.isNsfw);

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
    final ColorScheme cs;
    const _CardAction({
      required this.installed,
      required this.hasUpdate,
      required this.busy,
      required this.onInstall,
      required this.onSettings,
      required this.cs,
    });

    @override
    Widget build(BuildContext context) {
      // Loading spinner
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
      // Not installed → download icon button
      if (!installed) {
        return GestureDetector(
          onTap: onInstall,
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.download_rounded,
              size: 20,
              color: cs.onSurfaceVariant,
            ),
          ),
        );
      }
      // Has update → update button
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
              Icons.system_update_alt_rounded,
              size: 20,
              color: Colors.orange.shade600,
            ),
          ),
        );
      }
      // Installed + no update
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onSettings != null)
            Container(
              width: 34,
              height: 34,
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(10),
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.settings_outlined, size: 17, color: cs.onSurfaceVariant),
                onPressed: onSettings,
                tooltip: 'Paramètres',
              ),
            ),
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.check_rounded, size: 20, color: cs.primary),
          ),
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
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.cloud_sync_rounded, size: 18),
                          label: const Text('Forcer rechargement (bypass cache)'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            state._loadAll(bypassCache: true);
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
    final left = (widget.position.dx - _kMenuWidth).clamp(8.0, screenWidth - _kMenuWidth - 8.0);
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

// ─── Advanced filter bottom sheet ──────────────────────────────────────────────

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
    setState(() {
      _sortBy = 'alpha';
      _installedOnly = false;
      _withUpdatesOnly = false;
    });
    widget.state._clearFilters(widget.tab);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tab = widget.tab;
    final state = widget.state;
    final nActive = state._activeFilterCount(tab);

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, ctrl) => Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(color: cs.outline.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(4)),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Icon(Icons.tune_rounded, size: 20, color: cs.primary),
              const SizedBox(width: 8),
              Text('Filtres avancés', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: cs.onSurface)),
              const Spacer(),
              if (nActive > 0)
                TextButton(
                  onPressed: _resetAll,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    foregroundColor: cs.error,
                  ),
                  child: const Text('Tout effacer', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
            ]),
          ),
          Divider(height: 1, color: cs.outline.withValues(alpha: 0.15)),
          Expanded(
            child: ListView(
              controller: ctrl,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              children: [
                // ── Sort ──────────────────────────────────────────────────────
                Text('Trier par', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: cs.onSurface)),
                const SizedBox(height: 10),
                _SortSection(
                  sortBy: _sortBy,
                  onChanged: (v) { setState(() => _sortBy = v); _apply(); },
                  cs: cs,
                ),
                const SizedBox(height: 20),

                // ── Show ──────────────────────────────────────────────────────
                Text('Afficher', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: cs.onSurface)),
                const SizedBox(height: 6),
                _ToggleTile(
                  icon: Icons.download_done_rounded,
                  label: 'Installées uniquement',
                  value: _installedOnly,
                  onChanged: (v) { setState(() { _installedOnly = v; if (v) _withUpdatesOnly = false; }); _apply(); },
                  cs: cs,
                ),
                const SizedBox(height: 4),
                _ToggleTile(
                  icon: Icons.system_update_alt_rounded,
                  label: 'Avec mises à jour',
                  value: _withUpdatesOnly,
                  onChanged: (v) { setState(() { _withUpdatesOnly = v; if (v) _installedOnly = false; }); _apply(); },
                  cs: cs,
                ),
                const SizedBox(height: 24),

                // ── Active filters summary ────────────────────────────────────
                if (nActive > 0) ...[
                  Text('Filtres actifs', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: cs.onSurface)),
                  const SizedBox(height: 8),
                  _ActiveFiltersSummary(state: state, tab: tab, cs: cs, onClear: () {
                    setState(() {});
                    widget.onChanged();
                  }),
                  const SizedBox(height: 16),
                ],

                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Appliquer', style: TextStyle(fontWeight: FontWeight.w700)),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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

class _SortSection extends StatelessWidget {
  final String sortBy;
  final ValueChanged<String> onChanged;
  final ColorScheme cs;
  const _SortSection({required this.sortBy, required this.onChanged, required this.cs});

  static const _options = [
    ('alpha', Icons.sort_by_alpha_rounded, 'Alphabétique'),
    ('installed', Icons.download_done_rounded, 'Installées d\'abord'),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _options.map((opt) {
        final (val, icon, label) = opt;
        final sel = sortBy == val;
        return GestureDetector(
          onTap: () => onChanged(val),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: sel ? cs.primaryContainer : cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: sel ? cs.primary : cs.outline.withValues(alpha: 0.25), width: sel ? 1.5 : 1),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 14, color: sel ? cs.primary : cs.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: sel ? cs.primary : cs.onSurface)),
            ]),
          ),
        );
      }).toList(),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final ColorScheme cs;
  const _ToggleTile({required this.icon, required this.label, required this.value, required this.onChanged, required this.cs});

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      secondary: Icon(icon, size: 20, color: cs.primary),
      title: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      value: value,
      onChanged: onChanged,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      dense: true,
    );
  }
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
        width: 138,
        margin: const EdgeInsets.only(right: 10, bottom: 2),
        padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: widget.cs.outline.withValues(alpha: 0.12)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _bone(width: 54, height: 54, radius: 14),
            const SizedBox(height: 8),
            _bone(width: 90, height: 12),
            const SizedBox(height: 6),
            _bone(width: 50, height: 10),
            const SizedBox(height: 10),
            _bone(width: double.infinity, height: 28, radius: 8),
          ],
        ),
      );
    }

    @override
    Widget build(BuildContext context) {
      return SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section title bone
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
              child: Row(children: [
                _bone(width: 16, height: 16, radius: 4),
                const SizedBox(width: 8),
                _bone(width: 120, height: 14),
              ]),
            ),
            // Horizontal card strip
            SizedBox(
              height: 192,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
                itemCount: 5,
                itemBuilder: (_, __) => _skeletonCard(),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(children: [
                _bone(width: 16, height: 16, radius: 4),
                const SizedBox(width: 8),
                _bone(width: 140, height: 14),
              ]),
            ),
            SizedBox(
              height: 192,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
                itemCount: 5,
                itemBuilder: (_, __) => _skeletonCard(),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(children: [
                _bone(width: 16, height: 16, radius: 4),
                const SizedBox(width: 8),
                _bone(width: 100, height: 14),
              ]),
            ),
            SizedBox(
              height: 192,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
                itemCount: 5,
                itemBuilder: (_, __) => _skeletonCard(),
              ),
            ),
          ],
        ),
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
