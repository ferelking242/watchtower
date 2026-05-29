import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
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
import 'package:watchtower/modules/browse/sources/sources_screen.dart';
import 'package:watchtower/services/extension_diagnostics.dart';
import 'package:watchtower/services/fetch_item_sources.dart';
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
    late TabController _tabBarController;

    /// Outer tab order — computed dynamically from current navigation settings.
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
        initialIndex: initialIndex.clamp(0, (types.length - 1).clamp(0, 9999)),
        vsync: this,
      );
      _tabBarController.addListener(() {
        _checkPermission();
        if (mounted) setState(() {});
      });
    }

    void _applyNewTypes(List<ItemType> newTypes) {
      final prevIndex = _tabBarController.index;
      final newIndex = prevIndex.clamp(0, (newTypes.length - 1).clamp(0, 9999));
  
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
          Expanded(child: Text('Diagnostic en cours…')),
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
          content: Text('Diagnostic · $ok OK · $failed erreur(s) sur $total.'),
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

  void _activateAllSources(BuildContext context, ItemType type) {
    isar.writeTxnSync(() {
      final now = DateTime.now().millisecondsSinceEpoch;
      final sources = isar.sources
          .filter()
          .itemTypeEqualTo(type)
          .findAllSync();
      for (final s in sources) {
        isar.sources.putSync(s..isActive = true..updatedAt = now);
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      behavior: SnackBarBehavior.floating,
      content: Text('Toutes les sources activées.'),
      duration: Duration(seconds: 2),
    ));
  }

  void _deactivateAllSources(BuildContext context, ItemType type) {
    isar.writeTxnSync(() {
      final now = DateTime.now().millisecondsSinceEpoch;
      final sources = isar.sources
          .filter()
          .itemTypeEqualTo(type)
          .findAllSync();
      for (final s in sources) {
        isar.sources.putSync(s..isActive = false..updatedAt = now);
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      behavior: SnackBarBehavior.floating,
      content: Text('Toutes les sources désactivées.'),
      duration: Duration(seconds: 2),
    ));
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
      PopupMenuButton<_SrcMenuAction>(
        tooltip: "Plus d'options",
        icon: Icon(Icons.more_vert, color: theme.hintColor),
        onSelected: (action) => _handleSrcMenuAction(context, type, action),
        itemBuilder: (ctx) => [
          PopupMenuItem(
            value: _SrcMenuAction.activateAll,
            child: _MenuRow(
              icon: Icons.toggle_on_rounded,
              label: 'Activer toutes les sources',
            ),
          ),
          PopupMenuItem(
            value: _SrcMenuAction.deactivateAll,
            child: _MenuRow(
              icon: Icons.toggle_off_rounded,
              label: 'Désactiver toutes les sources',
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
        ],
      ),
      const SizedBox(width: 4),
    ];
  }

  void _handleSrcMenuAction(
      BuildContext context, ItemType type, _SrcMenuAction action) {
    switch (action) {
      case _SrcMenuAction.activateAll:
        _activateAllSources(context, type);
      case _SrcMenuAction.deactivateAll:
        _deactivateAllSources(context, type);
      case _SrcMenuAction.diagnostic:
        _runDiagnostics(context, type);
    }
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
        children: _types.map((t) => _BrowseTypeView(itemType: t)).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Menu action enum
// ─────────────────────────────────────────────────────────────────────────────

enum _SrcMenuAction {
  activateAll,
  deactivateAll,
  diagnostic,
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
