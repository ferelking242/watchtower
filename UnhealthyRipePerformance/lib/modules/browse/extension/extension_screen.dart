import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:watchtower/stubs/js_ffi_exports.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/modules/more/settings/browse/providers/browse_state_provider.dart';
import 'package:watchtower/modules/widgets/custom_sliver_grouped_list_view.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/modules/browse/extension/providers/extensions_provider.dart';
import 'package:watchtower/modules/browse/extension/providers/extension_layout_provider.dart';
import 'package:watchtower/services/fetch_item_sources.dart';
import 'package:watchtower/modules/widgets/progress_center.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/services/fetch_sources_list.dart';
import 'package:watchtower/utils/language.dart';
import 'package:watchtower/modules/browse/extension/widgets/extension_list_tile_widget.dart';

class ExtensionScreen extends ConsumerStatefulWidget {
  final ItemType itemType;
  final String query;
  const ExtensionScreen({
    required this.query,
    required this.itemType,
    super.key,
  });

  @override
  ConsumerState<ExtensionScreen> createState() => _ExtensionScreenState();
}

class _ExtensionScreenState extends ConsumerState<ExtensionScreen> {
  final ScrollController controller = ScrollController();
  bool isUpdating = false;
  bool _installingAll = false;
  final Map<String, bool> _collapsed = {};
  final Map<String, bool> _installingLang = {};

  // ── Lazy loading for the "Available" section ──────────────────────────────
  static const _kPageSize = 20;
  int _visibleInstalled = 20;
  int _visibleAvailLangs = 8; // number of language groups shown

  @override
  void initState() {
    super.initState();
    controller.addListener(_onScroll);
  }

  void _onScroll() {
    if (!controller.hasClients) return;
    final pos = controller.position;
    // Load more when within 300 px of the bottom
    if (pos.pixels >= pos.maxScrollExtent - 300) {
      bool changed = false;
      if (_visibleInstalled < 1000000) {
        _visibleInstalled += _kPageSize;
        changed = true;
      }
      if (_visibleAvailLangs < 10000) {
        _visibleAvailLangs += 4;
        changed = true;
      }
      if (changed && mounted) setState(() {});
    }
  }

  Future<void> _refreshSources() {
    return ref.refresh(
      fetchItemSourcesListProvider(
        id: null,
        reFresh: true,
        itemType: widget.itemType,
      ).future,
    );
  }

  @override
  void dispose() {
    controller.removeListener(_onScroll);
    controller.dispose();
    super.dispose();
  }

  Future<void> _updateSource(Source source) {
    return ref.read(
      fetchItemSourcesListProvider(
        id: source.id,
        reFresh: true,
        itemType: source.itemType,
      ).future,
    );
  }

  Future<void> _installSource(Source source) async {
    final provider = fetchItemSourcesListProvider(
      id: source.id,
      reFresh: true,
      itemType: source.itemType,
    );
    await ref.read(provider.future);
  }

  Future<void> _installAll(List<Source> sources, {String? lang}) async {
    if (lang != null) {
      if (mounted) setState(() => _installingLang[lang] = true);
    } else {
      if (mounted) setState(() => _installingAll = true);
    }
    final installed = <Source>[];
    try {
      for (final source in sources) {
        if (!(source.isAdded ?? false)) {
          await _installSource(source);
          installed.add(source);
        }
      }
    } finally {
      for (final source in installed) {
        ref.invalidate(fetchItemSourcesListProvider(
          id: source.id,
          reFresh: true,
          itemType: source.itemType,
        ));
      }
      if (mounted) {
        setState(() {
          if (lang != null) {
            _installingLang[lang] = false;
          } else {
            _installingAll = false;
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.read(
      fetchItemSourcesListProvider(
        id: null,
        reFresh: false,
        itemType: widget.itemType,
      ),
    );

    final streamExtensions = ref.watch(
      getExtensionsStreamProvider(widget.itemType),
    );
    final repositories = ref.watch(
      extensionsRepoStateProvider(widget.itemType),
    );
    final showNSFW = ref.watch(showNSFWStateProvider);
    final layoutMode = ref.watch(extensionLayoutModeProvider);

    final l10n = l10nLocalizations(context)!;

    return RefreshIndicator(
      onRefresh: _refreshSources,
      child: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: streamExtensions.when(
          data: (data) {
            final rawFiltered = widget.query.isEmpty
                ? data
                : data
                      .where(
                        (element) =>
                            element.name?.toLowerCase().contains(
                              widget.query.toLowerCase(),
                            ) ??
                            false,
                      )
                      .toList();

            final Map<String, Source> _deduped = {};
            for (final src in rawFiltered) {
              // Include pkgPath so same-named extensions from different repos stay distinct.
              final key = '${(src.name ?? '').toLowerCase()}_${(src.lang ?? '').toLowerCase()}_${src.itemType.name}_${(src.pkgPath ?? '').isNotEmpty ? src.pkgPath! : (src.repo?.name ?? '')}';
              final prev = _deduped[key];
              if (prev == null) {
                _deduped[key] = src;
              } else {
                final srcAdded = src.isAdded ?? false;
                final prevAdded = prev.isAdded ?? false;
                if (srcAdded && !prevAdded) {
                  _deduped[key] = src;
                } else if (srcAdded == prevAdded) {
                  if (compareVersions(
                        src.versionLast ?? '',
                        prev.versionLast ?? '',
                      ) >
                      0) {
                    _deduped[key] = src;
                  }
                }
              }
            }
            final filteredData = _deduped.values.toList();

            final updateEntries = <Source>[];
            final installedEntries = <Source>[];
            final notInstalledEntries = <Source>[];

            for (var element in filteredData) {
              if (repositories
                      .where((e) => e == element.repo).firstOrNull
                      ?.hidden ??
                  false) {
                continue;
              }
              if (!showNSFW && (element.isNsfw ?? false)) {
                continue;
              }

              if (compareVersions(
                    element.version ?? '',
                    element.versionLast ?? '',
                  ) <
                  0) {
                updateEntries.add(element);
              } else {
                if (element.isAdded ?? false) {
                  installedEntries.add(element);
                } else {
                  notInstalledEntries.add(element);
                }
              }
            }

            final hasAnyEntry = updateEntries.isNotEmpty ||
                installedEntries.isNotEmpty ||
                notInstalledEntries.isNotEmpty;

            return Scrollbar(
              interactive: true,
              controller: controller,
              thickness: 3,
              radius: const Radius.circular(10),
              child: CustomScrollView(
                controller: controller,
                slivers: [
                  if (updateEntries.isNotEmpty)
                    _buildUpdateSection(updateEntries, l10n, layoutMode: layoutMode),
                  if (installedEntries.isNotEmpty)
                    _buildInstalledSection(installedEntries, l10n, layoutMode: layoutMode),
                  if (notInstalledEntries.isNotEmpty)
                    ..._buildAvailableSection(notInstalledEntries, layoutMode: layoutMode),
                  if (!hasAnyEntry)
                    SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              widget.query.isEmpty ? 'ε=ε=(ノ≧∇≦)ノ' : '(・_・;)',
                              style: TextStyle(
                                fontSize: 48,
                                color: Theme.of(context).hintColor.withValues(alpha: 0.55),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              widget.query.isEmpty ? "Rien ici" : "Aucun résultat",
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).hintColor,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.query.isEmpty
                                  ? l10n.refresh
                                  : "Aucun résultat pour « ${widget.query} »",
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).hintColor.withValues(alpha: 0.7),
                                  ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
          error: (error, _) => Center(
            child: ElevatedButton(
              onPressed: _refreshSources,
              child: Text(context.l10n.refresh),
            ),
          ),
          loading: () => const ProgressCenter(),
        ),
      ),
    );
  }

  Widget _buildSliverListOrGrid({
    required List<Source> items,
    required int layoutMode,
  }) {
    if (layoutMode == 0) {
      return SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => ref.watch(extensionListTileWidget(items[index])),
          childCount: items.length,
        ),
      );
    }
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: layoutMode == 2 ? 3 : 2,
        childAspectRatio: layoutMode == 2 ? 3.6 : 3.2,
        crossAxisSpacing: 0,
        mainAxisSpacing: 0,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) => ref.watch(extensionListTileWidget(items[index])),
        childCount: items.length,
      ),
    );
  }

  Widget _buildUpdateSection(List<Source> updateEntries, dynamic l10n,
      {int layoutMode = 1}) {
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: StatefulBuilder(
            builder: (context, setState) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        l10n.update_pending,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 6),
                      _CountBadge(count: updateEntries.length),
                    ],
                  ),
                  ElevatedButton(
                    onPressed: isUpdating
                        ? null
                        : () async {
                            setState(() => isUpdating = true);
                            try {
                              for (var source in updateEntries) {
                                await _updateSource(source);
                              }
                            } finally {
                              if (mounted) setState(() => isUpdating = false);
                            }
                          },
                    child: isUpdating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.update_all),
                  ),
                ],
              ),
            ),
          ),
        ),
        _buildSliverListOrGrid(items: updateEntries, layoutMode: layoutMode),
      ],
    );
  }

  Widget _buildInstalledSection(List<Source> installedEntries, dynamic l10n,
      {int layoutMode = 1}) {
    final visible = installedEntries.take(_visibleInstalled).toList();
    final hasMore = visible.length < installedEntries.length;
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Text(
                  l10n.installed,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(width: 6),
                _CountBadge(count: installedEntries.length),
              ],
            ),
          ),
        ),
        _buildSliverListOrGrid(items: visible, layoutMode: layoutMode),
        if (hasMore)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          ),
      ],
    );
  }

  List<Widget> _buildAvailableSection(List<Source> notInstalledEntries,
      {int layoutMode = 1}) {
    // Group by language code (raw) for flag lookup, display name for label
    final Map<String, List<Source>> grouped = {};
    for (final src in notInstalledEntries) {
      final langCode = src.lang?.toLowerCase() ?? '';
      final name = completeLanguageName(langCode);
      grouped.putIfAbsent(name, () => []).add(src);
    }
    final allLangs = grouped.keys.toList()..sort();
    // Lazy loading: only render up to _visibleAvailLangs language groups
    final sortedLangs = allLangs.take(_visibleAvailLangs).toList();
    final hasMoreLangs = allLangs.length > sortedLangs.length;

    final slivers = <Widget>[];

    // Available header with total count + Install All button
    slivers.add(
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(left: 12, right: 12, bottom: 4),
          child: Row(
            children: [
              Text(
                "Disponibles",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 6),
              _CountBadge(count: notInstalledEntries.length),
              const Spacer(),
              ElevatedButton(
                onPressed: _installingAll
                    ? null
                    : () => _installAll(notInstalledEntries),
                child: _installingAll
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text("Tout installer", style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
      ),
    );

    for (final lang in sortedLangs) {
      final items = grouped[lang]!;
      items.sort((a, b) => (a.name ?? '').compareTo(b.name ?? ''));
      final isCollapsed = _collapsed[lang] ?? false;
      final isInstallingLang = _installingLang[lang] ?? false;

      // Get flag from the first item's lang code
      final firstLangCode = items.first.lang?.toLowerCase() ?? '';
      final flag = langFlagEmoji(firstLangCode);

      slivers.add(
        SliverToBoxAdapter(
          child: InkWell(
            onTap: () {
              setState(() {
                _collapsed[lang] = !isCollapsed;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  // Flag emoji
                  Text(flag, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      lang,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  _CountBadge(count: items.length),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: isInstallingLang
                        ? null
                        : () => _installAll(items, lang: lang),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: isInstallingLang
                          ? const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              "Tout",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onPrimaryContainer,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: isCollapsed ? -0.25 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.expand_more, size: 18),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      if (!isCollapsed) {
        slivers.add(
          _buildSliverListOrGrid(items: items, layoutMode: layoutMode),
        );
      }
    }

    // "Load more" spinner at the bottom
    if (hasMoreLangs) {
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${allLangs.length - sortedLangs.length} langues supplémentaires…',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return slivers;
  }
}

class _CountBadge extends StatelessWidget {
  final int count;
  const _CountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count.toString().padLeft(3, '0'),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
