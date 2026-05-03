import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:isar_community/isar.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/modules/more/settings/reader/providers/reader_state_provider.dart';
import 'package:watchtower/l10n/generated/app_localizations.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/providers/storage_provider.dart';
import 'package:watchtower/modules/browse/extension/extension_screen.dart';
import 'package:watchtower/modules/browse/marketplace_screen.dart';
import 'package:watchtower/modules/browse/sources/sources_screen.dart';
import 'package:watchtower/modules/library/widgets/search_text_form_field.dart';
import 'package:watchtower/services/extension_diagnostics.dart';
import 'package:watchtower/services/fetch_sources_list.dart';

class BrowseScreen extends ConsumerStatefulWidget {
  const BrowseScreen({super.key});

  @override
  ConsumerState<BrowseScreen> createState() => _BrowseScreenState();
}

/// Sub-section inside a single content type (Sources / Extensions / Marketplace).
enum BrowseSection { sources, extensions, marketplace }

class _BrowseScreenState extends ConsumerState<BrowseScreen>
    with TickerProviderStateMixin {
  late final hideItems = ref.read(hideItemsStateProvider);
  late TabController _tabBarController;

  /// Outer tab order — Watch first as requested.
  late final List<ItemType> _types = [
    if (!hideItems.contains("/AnimeLibrary")) ItemType.anime,
    if (!hideItems.contains("/MangaLibrary")) ItemType.manga,
    if (!hideItems.contains("/NovelLibrary")) ItemType.novel,
    if (!hideItems.contains("/MusicLibrary")) ItemType.music,
    if (!hideItems.contains("/GameLibrary")) ItemType.game,
  ];

  /// Per-type sub-section (Sources / Extensions / Marketplace).
  final Map<ItemType, BrowseSection> _section = {};
  final Map<ItemType, bool> _isSearch = {};
  final Map<ItemType, TextEditingController> _searchControllers = {};

  ItemType get _activeType => _types[_tabBarController.index];
  BrowseSection get _activeSection =>
      _section[_activeType] ?? BrowseSection.sources;

  bool _diagnosing = false;

  @override
  void initState() {
    super.initState();
    _tabBarController = TabController(length: _types.length, vsync: this);
    _tabBarController.addListener(() {
      _checkPermission();
      if (mounted) setState(() {});
    });
    for (final t in _types) {
      _section[t] = BrowseSection.sources;
      _isSearch[t] = false;
      _searchControllers[t] = TextEditingController();
    }
  }

  Future<void> _checkPermission() async {
    await StorageProvider().requestPermission();
  }

  @override
  void dispose() {
    _tabBarController.dispose();
    for (final c in _searchControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _runDiagnostics(BuildContext context, ItemType type) async {
    if (_diagnosing) return;
    _diagnosing = true;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
        content: Row(children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Lancement du diagnostic sur toutes les extensions…',
            ),
          ),
        ]),
      ),
    );
    try {
      final results = await runExtensionDiagnosticsFull(type);
      final ok = results.where((r) => r.allOk).length;
      final failed = results.where((r) => r.anyFailed).length;
      final total = results.length;
      if (!context.mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: failed > 0 ? Colors.red.shade700 : null,
          content: Text(
            'Diagnostic terminé · $ok OK · $failed erreur(s) sur $total. '
            'Voir Logs.',
          ),
          action: SnackBarAction(
            label: 'Logs',
            textColor: Colors.white,
            onPressed: () => context.push('/logViewer'),
          ),
          duration: const Duration(seconds: 6),
        ),
      );
    } finally {
      _diagnosing = false;
    }
  }

  /// Build the right-aligned action icons for the AppBar based on the
  /// currently active tab + section.
  List<Widget> _appBarActions(BuildContext context) {
    final theme = Theme.of(context);
    if (_types.isEmpty) return const [];
    final type = _activeType;
    final section = _activeSection;
    final isExt = section == BrowseSection.extensions;
    final isSources = section == BrowseSection.sources;

    return [
      if (isSources) ...[
        GestureDetector(
          onLongPress: () => context.push('/extensionDiagnostic', extra: type),
          child: IconButton(
            tooltip: 'Global search · long-press to diagnose',
            splashRadius: 20,
            onPressed: () => context.push(
              '/globalSearch',
              extra: (null, type),
            ),
            icon: Icon(Icons.travel_explore_rounded, color: theme.hintColor),
          ),
        ),
        IconButton(
          tooltip: 'Source filters',
          splashRadius: 20,
          onPressed: () => context.push(
            '/sourceFilter',
            extra: type,
          ),
          icon: Icon(Icons.filter_list_sharp, color: theme.hintColor),
        ),
      ],
      if (isExt) ...[
        IconButton(
          tooltip: 'Search extensions',
          splashRadius: 20,
          onPressed: () => setState(() {
            _isSearch[type] = !(_isSearch[type] ?? false);
            if (!(_isSearch[type] ?? false)) {
              _searchControllers[type]?.clear();
            }
          }),
          icon: Icon(
            (_isSearch[type] ?? false) ? Icons.close : Icons.search_rounded,
            color: theme.hintColor,
          ),
        ),
        IconButton(
          tooltip: 'Create extension',
          splashRadius: 20,
          onPressed: () => context.push('/createExtension'),
          icon: Icon(Icons.add_outlined, color: theme.hintColor),
        ),
        GestureDetector(
          onLongPress: () => _isolateDeviceLanguage(context, type),
          child: IconButton(
            tooltip: 'Languages',
            splashRadius: 20,
            onPressed: () => context.push(
              '/ExtensionLang',
              extra: type,
            ),
            icon: Icon(Icons.translate_rounded, color: theme.hintColor),
          ),
        ),
      ],
      const SizedBox(width: 4),
    ];
  }

  String _typeLabel(ItemType t, AppLocalizations l10n) {
    switch (t) {
      case ItemType.anime:
        return l10n.watch;
      case ItemType.manga:
        return l10n.manga;
      case ItemType.novel:
        return l10n.novel;
      case ItemType.music:
        return 'Music';
      case ItemType.game:
        return 'Games';
    }
  }

  IconData _typeIcon(ItemType t) {
    switch (t) {
      case ItemType.anime:
        return Icons.live_tv_outlined;
      case ItemType.manga:
        return Icons.auto_stories_outlined;
      case ItemType.novel:
        return Icons.text_snippet_outlined;
      case ItemType.music:
        return Icons.music_note_outlined;
      case ItemType.game:
        return Icons.sports_esports_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_types.isEmpty) return const SizedBox.shrink();
    final l10n = l10nLocalizations(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: (_isSearch[_activeType] ?? false) &&
                _activeSection == BrowseSection.extensions
            ? SeachFormTextField(
                autofocus: true,
                onChanged: (_) => setState(() {}),
                onSuffixPressed: () {
                  _searchControllers[_activeType]?.clear();
                  setState(() {});
                },
                onPressed: () => setState(() {
                  _isSearch[_activeType] = false;
                  _searchControllers[_activeType]?.clear();
                }),
                controller: _searchControllers[_activeType]!,
              )
            : Text(
                l10n.browse,
                style: TextStyle(color: theme.hintColor),
              ),
        actions: _appBarActions(context),
        bottom: TabBar(
          controller: _tabBarController,
          indicatorSize: TabBarIndicatorSize.tab,
          tabAlignment: TabAlignment.fill,
          dividerColor: Colors.transparent,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.hintColor,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
          tabs: _types
              .map(
                (t) => Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_typeIcon(t), size: 16),
                      const SizedBox(width: 6),
                      Text(_typeLabel(t, l10n)),
                      if (t.isExtensionUpdateRelevant) ...[
                        const SizedBox(width: 6),
                        _extensionUpdateBadge(ref, t),
                      ],
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabBarController,
        physics: const BouncingScrollPhysics(),
        children: _types.map((t) {
          return _BrowseTypeView(
            itemType: t,
            section: _section[t] ?? BrowseSection.sources,
            isSearch: _isSearch[t] ?? false,
            searchController: _searchControllers[t]!,
            onSectionChanged: (s) => setState(() {
              _section[t] = s;
              _isSearch[t] = false;
              _searchControllers[t]?.clear();
            }),
            onSearchClose: () => setState(() {
              _isSearch[t] = false;
              _searchControllers[t]?.clear();
            }),
          );
        }).toList(),
      ),
    );
  }
}

extension _ItemTypeExt on ItemType {
  bool get isExtensionUpdateRelevant => true;
}

/// Per-type body: top SegmentedButton (Sources / Extensions / Marketplace)
/// + per-section action row + the corresponding screen.
class _BrowseTypeView extends ConsumerStatefulWidget {
  final ItemType itemType;
  final BrowseSection section;
  final bool isSearch;
  final TextEditingController searchController;
  final ValueChanged<BrowseSection> onSectionChanged;
  final VoidCallback onSearchClose;

  const _BrowseTypeView({
    required this.itemType,
    required this.section,
    required this.isSearch,
    required this.searchController,
    required this.onSectionChanged,
    required this.onSearchClose,
  });

  @override
  ConsumerState<_BrowseTypeView> createState() => _BrowseTypeViewState();
}

class _BrowseTypeViewState extends ConsumerState<_BrowseTypeView> {
  Widget _segmentedDock() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    Widget seg(BrowseSection s, IconData icon, String label) {
      final active = widget.section == s;
      return InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (!active) {
            widget.onSectionChanged(s);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: active
                ? cs.primary.withValues(alpha: 0.14)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: active ? cs.primary : cs.onSurfaceVariant,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: active ? cs.primary : cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outline.withValues(alpha: 0.10)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            seg(BrowseSection.sources, Icons.cloud_outlined, 'Sources'),
            seg(BrowseSection.extensions, Icons.extension_outlined,
                'Extensions'),
            seg(BrowseSection.marketplace, Icons.storefront_outlined,
                'Market'),
          ],
        ),
      ),
    );
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: SeachFormTextField(
        onChanged: (_) => setState(() {}),
        onSuffixPressed: () {
          widget.searchController.clear();
          setState(() {});
        },
        onPressed: widget.onSearchClose,
        controller: widget.searchController,
      ),
    );
  }

  Widget _body() {
    switch (widget.section) {
      case BrowseSection.sources:
        return SourcesScreen(
          itemType: widget.itemType,
        );
      case BrowseSection.extensions:
        return ExtensionScreen(
          query: widget.searchController.text,
          itemType: widget.itemType,
        );
      case BrowseSection.marketplace:
        return MarketplaceScreen(itemType: widget.itemType);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _segmentedDock(),
        Expanded(child: _body()),
      ],
    );
  }
}

/// Long-press shortcut on the translate icon: keeps only the device's
/// language active (and English as a fallback). Long-press again to restore
/// every language.
void _isolateDeviceLanguage(BuildContext context, ItemType itemType) {
  String deviceLang;
  try {
    deviceLang = Platform.localeName.split(RegExp('[_-]')).first.toLowerCase();
  } catch (_) {
    deviceLang = 'en';
  }
  final entries = isar.sources
      .filter()
      .idIsNotNull()
      .and()
      .itemTypeEqualTo(itemType)
      .findAllSync();

  final isolated = entries.any((s) =>
      (s.isActive ?? false) &&
      s.lang!.toLowerCase() != deviceLang &&
      s.lang!.toLowerCase() != 'en' &&
      s.lang!.toLowerCase() != 'all');
  final shouldIsolate = isolated;

  isar.writeTxnSync(() {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final s in entries) {
      final lang = s.lang!.toLowerCase();
      final keep = lang == deviceLang || lang == 'en' || lang == 'all';
      isar.sources.putSync(
        s
          ..isActive = shouldIsolate ? keep : true
          ..updatedAt = now,
      );
    }
  });

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      duration: const Duration(seconds: 2),
      content: Text(
        shouldIsolate
            ? 'Sources limitées à ${deviceLang.toUpperCase()} + EN'
            : 'Toutes les langues réactivées',
      ),
    ),
  );
}

Widget _extensionUpdateBadge(WidgetRef ref, ItemType itemType) {
  return StreamBuilder(
    stream: isar.sources
        .filter()
        .idIsNotNull()
        .and()
        .isActiveEqualTo(true)
        .itemTypeEqualTo(itemType)
        .watch(fireImmediately: true),
    builder: (context, snapshot) {
      if (snapshot.hasData && snapshot.data!.isNotEmpty) {
        final entries = snapshot.data!
            .where((e) => compareVersions(e.version!, e.versionLast!) < 0)
            .toList();
        return entries.isEmpty
            ? const SizedBox.shrink()
            : Badge(
                backgroundColor: Theme.of(context).focusColor,
                label: Text(
                  entries.length.toString(),
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodySmall!.color,
                  ),
                ),
              );
      }
      return const SizedBox.shrink();
    },
  );
}
