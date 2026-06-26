import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'dart:math' as math;

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
import 'package:watchtower/modules/browse/sources/sources_screen.dart';
  import 'package:watchtower/modules/music/music_discovery_screen.dart';
  import 'package:watchtower/modules/game/game_discovery_screen.dart';
  import 'package:watchtower/modules/music/music_discovery_screen.dart';
  import 'package:watchtower/modules/game/game_discovery_screen.dart';
import 'package:watchtower/services/fetch_item_sources.dart';
import 'package:watchtower/services/fetch_sources_list.dart';
import 'package:watchtower/utils/arrow_popup_menu.dart';

class BrowseScreen extends ConsumerStatefulWidget {
  const BrowseScreen({super.key});

  @override
  ConsumerState<BrowseScreen> createState() => _BrowseScreenState();
}

/// Sub-section inside a single content type (Sources / Extensions / Marketplace).
enum BrowseSection { sources, extensions, marketplace }

class _BrowseScreenState extends ConsumerState<BrowseScreen>
      with TickerProviderStateMixin {
    late TabController _tabBarController;

    List<ItemType> _types = [];

  ItemType get _activeType => _types[_tabBarController.index];

    bool _diagnosing = false;
    bool _bulkWorking = false;

    static List<ItemType> _computeTypes(List<String> hideItems) => [
          if (!hideItems.contains("/AnimeLibrary")) ItemType.anime,
          if (!hideItems.contains("/MangaLibrary")) ItemType.manga,
          if (!hideItems.contains("/NovelLibrary")) ItemType.novel,
          if (!hideItems.contains("/MusicLibrary")) ItemType.music,
          if (!hideItems.contains("/GameLibrary")) ItemType.game,
        ];

    static bool _typesEqual(List<ItemType> a, List<ItemType> b) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (a[i] != b[i]) return false;
      }
      return true;
    }

    void _initTabController(List<ItemType> types, {int initialIndex = 0}) {
      _tabBarController = TabController(
        length: types.length,
        initialIndex: initialIndex.clamp(0, types.length.clamp(0, 9999)),
        vsync: this,
      );
      _tabBarController.addListener(() {
        _checkPermission();
        if (mounted) setState(() {});
      });
    }

    void _applyNewTypes(List<ItemType> newTypes) {
      final prevIndex = _tabBarController.index;
      final newIndex = prevIndex.clamp(0, newTypes.length.clamp(0, 9999));
  
      _types = newTypes;
      _tabBarController.dispose();
      _initTabController(newTypes, initialIndex: newIndex);
    }

    @override
    void initState() {
      super.initState();
      _types = _computeTypes(ref.read(hideItemsStateProvider));
      _initTabController(_types);
    }

  Future<void> _checkPermission() async {
    await StorageProvider().requestPermission(requestIfNeeded: false);
  }

  @override
  void dispose() {
    _tabBarController.dispose();
    super.dispose();
  }

  Future<void> _runDiagnostics(BuildContext context, ItemType type) async {
    context.push('/extensionDiagnostic', extra: type);
  }

  // ── Bulk operations ────────────────────────────────────────────────────────

  Future<void> _installAllExtensions(BuildContext context, ItemType type) async {
    if (_bulkWorking) return;
    setState(() => _bulkWorking = true);
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 999),
        content: Row(children: [
          SizedBox(width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 12),
          Expanded(child: Text('Installation de toutes les extensions…')),
        ]),
      ),
    );
    try {
      final sources = isar.sources
          .filter()
          .itemTypeEqualTo(type)
          .isAddedEqualTo(false)
          .findAllSync();
      int done = 0;
      for (final src in sources) {
        try {
          final provider = fetchItemSourcesListProvider(
            id: src.id, reFresh: true, itemType: src.itemType);
          ref.invalidate(provider);
          await ref.read(provider.future);
          done++;
        } catch (_) {}
      }
      if (context.mounted) {
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('$done extension(s) installée(s).'),
          duration: const Duration(seconds: 3),
        ));
      }
    } finally {
      if (mounted) setState(() => _bulkWorking = false);
    }
  }

  void _uninstallAllExtensions(BuildContext context, ItemType type) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Désinstaller tout'),
        content: const Text(
            'Voulez-vous vraiment désinstaller toutes les extensions installées ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              final sources = isar.sources
                  .filter()
                  .itemTypeEqualTo(type)
                  .isAddedEqualTo(true)
                  .findAllSync();
              isar.writeTxnSync(() {
                final now = DateTime.now().millisecondsSinceEpoch;
                for (final s in sources) {
                  if (!(s.isObsolete ?? false)) {
                    isar.sources.putSync(s
                      ..sourceCode = ''
                      ..isAdded = false
                      ..isPinned = false
                      ..updatedAt = now);
                  } else {
                    isar.sources.deleteSync(s.id!);
                  }
                }
              });
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                behavior: SnackBarBehavior.floating,
                content:
                    Text('${sources.length} extension(s) désinstallée(s).'),
                duration: const Duration(seconds: 3),
              ));
            },
            child: const Text('Désinstaller'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateAllExtensions(BuildContext context, ItemType type) async {
    if (_bulkWorking) return;
    setState(() => _bulkWorking = true);
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 999),
        content: Row(children: [
          SizedBox(width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 12),
          Expanded(child: Text('Mise à jour de toutes les extensions…')),
        ]),
      ),
    );
    try {
      final sources = isar.sources
          .filter()
          .itemTypeEqualTo(type)
          .isAddedEqualTo(true)
          .findAllSync()
          .where((s) => compareVersions(s.version ?? '', s.versionLast ?? '') < 0)
          .toList();
      int done = 0;
      for (final src in sources) {
        try {
          await ref.read(fetchItemSourcesListProvider(
            id: src.id, reFresh: true, itemType: src.itemType).future);
          done++;
        } catch (_) {}
      }
      if (context.mounted) {
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('$done extension(s) mise(s) à jour.'),
          duration: const Duration(seconds: 3),
        ));
      }
    } finally {
      if (mounted) setState(() => _bulkWorking = false);
    }
  }

  // ── Random source opener ───────────────────────────────────────────────────

  void _openRandomSource(BuildContext context, ItemType type) {
    final sources = isar.sources
        .filter()
        .itemTypeEqualTo(type)
        .isAddedEqualTo(true)
        .isActiveEqualTo(true)
        .findAllSync()
        .where((s) => !(s.name == 'local' && (s.lang?.isEmpty ?? true)))
        .where((s) => s.sourceCode != null && s.sourceCode!.isNotEmpty)
        .toList();
    if (sources.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('Aucune source active installée.'),
        duration: Duration(seconds: 2),
      ));
      return;
    }
    final src = sources[math.Random().nextInt(sources.length)];
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      content: Text('Ouverture de "${src.name}"…'),
      duration: const Duration(seconds: 2),
    ));
    context.push('/mangaHome', extra: (src, false));
  }

  // ── Browse settings ────────────────────────────────────────────────────────

  void _openBrowseSettings(BuildContext context, ItemType type) {
    context.push('/sourceFilter', extra: type);
  }

  // ── How To ─────────────────────────────────────────────────────────────────

  void _openHowTo(BuildContext context, ItemType type) {
    context.push('/localHowTo', extra: type);
  }

  // ── AppBar actions ─────────────────────────────────────────────────────────

  List<Widget> _appBarActions(BuildContext context) {
    final theme = Theme.of(context);
    if (_types.isEmpty) return const [];
    final type = _activeType;
    return [
      GestureDetector(
        onLongPress: () => context.push('/extensionDiagnostic', extra: type),
        child: IconButton(
          tooltip: 'Recherche globale · appui long = diagnostic',
          splashRadius: 20,
          onPressed: () => context.push('/globalSearch', extra: (null, type)),
          icon: Icon(Icons.travel_explore_rounded, color: theme.hintColor),
        ),
      ),
      IconButton(
        tooltip: 'Filtres sources',
        splashRadius: 20,
        onPressed: () => context.push('/sourceFilter', extra: type),
        icon: Icon(Icons.filter_list_sharp, color: theme.hintColor),
      ),
      ArrowPopupMenuButton<_SrcMenuAction>(
        tooltip: "Plus d'options",
        icon: Icon(Icons.more_vert, color: theme.hintColor),
        onSelected: (action) => _handleSrcMenuAction(context, type, action),
        itemBuilder: (ctx) => [
          PopupMenuItem(
            value: _SrcMenuAction.market,
            child: _MenuRow(
              icon: Icons.storefront_rounded,
              label: 'Marketplace',
            ),
          ),
          const PopupMenuDivider(),
          PopupMenuItem(
            value: _SrcMenuAction.howTo,
            child: _MenuRow(
              icon: Icons.help_outline_rounded,
              label: 'How To — Source Locale',
            ),
          ),
          PopupMenuItem(
            value: _SrcMenuAction.openRandomSource,
            child: _MenuRow(
              icon: Icons.shuffle_rounded,
              label: 'Source aléatoire',
            ),
          ),
          const PopupMenuDivider(),
          PopupMenuItem(
            value: _SrcMenuAction.diagnostic,
            child: _MenuRow(
              icon: Icons.bug_report_rounded,
              label: 'Diagnostic',
            ),
          ),
          PopupMenuItem(
            value: _SrcMenuAction.browseSettings,
            child: _MenuRow(
              icon: Icons.tune_rounded,
              label: 'Paramètres Browse',
            ),
          ),
        ],
      ),
      const SizedBox(width: 4),
    ];
  }

  void _handleSrcMenuAction(
      BuildContext context, ItemType type, _SrcMenuAction action) {
    switch (action) {
      case _SrcMenuAction.market:
        context.push('/marketplace');
      case _SrcMenuAction.howTo:
        _openHowTo(context, type);
      case _SrcMenuAction.openRandomSource:
        _openRandomSource(context, type);
      case _SrcMenuAction.diagnostic:
        _runDiagnostics(context, type);
      case _SrcMenuAction.browseSettings:
        _openBrowseSettings(context, type);
    }
  }

  PreferredSizeWidget _buildTabBar(BuildContext context, ThemeData theme, AppLocalizations l10n) {
    final screenWidth = MediaQuery.of(context).size.width;
    final tabW = screenWidth / 3;

    Widget makeTab(IconData icon, String label, {Widget? badge}) => SizedBox(
      width: tabW,
      child: Tab(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 6),
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
            if (badge != null) ...[const SizedBox(width: 4), badge],
          ],
        ),
      ),
    );

    return TabBar(
      controller: _tabBarController,
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      padding: EdgeInsets.zero,
      labelPadding: EdgeInsets.zero,
      dividerColor: theme.dividerColor.withValues(alpha: 0.35),
      labelColor: theme.colorScheme.primary,
      unselectedLabelColor: theme.hintColor,
      labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
      indicator: UnderlineTabIndicator(
        borderSide: BorderSide(
          width: 2.5,
          color: theme.colorScheme.primary,
        ),
        insets: const EdgeInsets.symmetric(horizontal: 20),
      ),
      indicatorSize: TabBarIndicatorSize.tab,
      tabs: [
        ..._types.map((t) => makeTab(
          _typeIcon(t),
          _typeLabel(t, l10n),
          badge: t.isExtensionUpdateRelevant
              ? SizedBox(width: 24, height: 18, child: _extensionUpdateBadge(ref, t))
              : null,
        )),
      ],
    );
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
        return Icons.menu_book_outlined;
      case ItemType.music:
        return Icons.music_note_outlined;
      case ItemType.game:
        return Icons.sports_esports_outlined;
    }
  }

  @override
    Widget build(BuildContext context) {
      ref.listen<List<String>>(hideItemsStateProvider, (_, next) {
        final newTypes = _computeTypes(next);
        if (!_typesEqual(newTypes, _types) && mounted) {
          setState(() => _applyNewTypes(newTypes));
        }
      });
      if (_types.isEmpty) return const SizedBox.shrink();
      final l10n = l10nLocalizations(context)!;
      final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: Colors.transparent,
        title: Text(l10n.browse, style: TextStyle(color: theme.hintColor)),
        actions: _appBarActions(context),
        bottom: _buildTabBar(context, theme, l10n),
      ),
      body: TabBarView(
        controller: _tabBarController,
        physics: const ClampingScrollPhysics(),
        children: [
          ..._types.map((t) => _BrowseTypeView(itemType: t)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Menu action enum
// ─────────────────────────────────────────────────────────────────────────────

enum _SrcMenuAction {
  market,
  howTo,
  openRandomSource,
  diagnostic,
  browseSettings,
}

// ─────────────────────────────────────────────────────────────────────────────
// Menu row widget
// ─────────────────────────────────────────────────────────────────────────────

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool danger;
  final bool enabled;

  const _MenuRow({
    required this.icon,
    required this.label,
    this.danger = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger
        ? Colors.red.shade400
        : enabled
            ? null
            : Theme.of(context).disabledColor;
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Text(label,
            style: TextStyle(
              color: color,
              fontWeight: danger ? FontWeight.w600 : null,
            )),
      ],
    );
  }
}

extension _ItemTypeExt on ItemType {
  bool get isExtensionUpdateRelevant => true;
}

class _BrowseTypeView extends ConsumerStatefulWidget {
  final ItemType itemType;
  const _BrowseTypeView({required this.itemType});

  @override
  ConsumerState<_BrowseTypeView> createState() => _BrowseTypeViewState();
}

class _BrowseTypeViewState extends ConsumerState<_BrowseTypeView> {
    @override
    Widget build(BuildContext context) {
      if (widget.itemType == ItemType.music) {
        return const MusicDiscoveryScreen();
      }
      if (widget.itemType == ItemType.game) {
        return const GameDiscoveryScreen();
      }
      return SourcesScreen(
        itemType: widget.itemType,
        onShowExtensions: () => context.push('/marketplace'),
      );
    }
  }

/// Long-press shortcut on the translate icon: keeps only the device's
/// language active (and English as a fallback). Long-press again to restore.
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

  isar.writeTxnSync(() {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final s in entries) {
      final lang = s.lang!.toLowerCase();
      final keep = lang == deviceLang || lang == 'en' || lang == 'all';
      isar.sources.putSync(
        s
          ..isActive = isolated ? keep : true
          ..updatedAt = now,
      );
    }
  });

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
      content: Text(
        isolated
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
