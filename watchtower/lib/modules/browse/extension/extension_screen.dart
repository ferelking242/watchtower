import 'package:flutter/material.dart';
import 'package:flutter_qjs/quickjs/ffi.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/modules/more/settings/browse/providers/browse_state_provider.dart';
import 'package:watchtower/modules/widgets/custom_sliver_grouped_list_view.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/modules/browse/extension/providers/extensions_provider.dart';
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
  final Map<String, bool> _collapsed = {};

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

    final l10n = l10nLocalizations(context)!;

    return RefreshIndicator(
      onRefresh: _refreshSources,
      child: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: streamExtensions.when(
          data: (data) {
            final filteredData = widget.query.isEmpty
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

            final updateEntries = <Source>[];
            final installedEntries = <Source>[];
            final notInstalledEntries = <Source>[];

            for (var element in filteredData) {
              if (repositories
                      .firstWhereOrNull((e) => e == element.repo)
                      ?.hidden ??
                  false) {
                continue;
              }
              if (!showNSFW && (element.isNsfw ?? false)) {
                continue;
              }
              final isLatestVersion = element.version == element.versionLast;

              if (compareVersions(
                    element.version ?? '',
                    element.versionLast ?? '',
                  ) <
                  0) {
                updateEntries.add(element);
              } else if (isLatestVersion) {
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
              thickness: 12,
              radius: const Radius.circular(10),
              child: CustomScrollView(
                controller: controller,
                slivers: [
                  if (updateEntries.isNotEmpty)
                    _buildUpdateSection(updateEntries, l10n),
                  if (installedEntries.isNotEmpty)
                    _buildInstalledSection(installedEntries, l10n),
                  if (notInstalledEntries.isNotEmpty)
                    ..._buildAvailableSection(notInstalledEntries),
                  if (!hasAnyEntry)
                    SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 110,
                              height: 110,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    Theme.of(context).colorScheme.secondary.withValues(alpha: 0.15),
                                    Theme.of(context).colorScheme.secondary.withValues(alpha: 0.03),
                                  ],
                                ),
                              ),
                              child: Icon(
                                Icons.extension_off_outlined,
                                size: 52,
                                color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.5),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              "Nothing here",
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).hintColor,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.query.isEmpty
                                  ? l10n.refresh
                                  : "No results for \"${widget.query}\"",
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

  Widget _buildUpdateSection(List<Source> updateEntries, dynamic l10n) {
    return CustomSliverGroupedListView<Source, String>(
      elements: updateEntries,
      groupBy: (_) => "",
      groupSeparatorBuilder: (_) => StatefulBuilder(
        builder: (context, setState) {
          return Padding(
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
                            if (mounted) {
                              setState(() => isUpdating = false);
                            }
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
          );
        },
      ),
      itemBuilder: (context, Source element) =>
          ref.watch(extensionListTileWidget(element)),
      groupComparator: (group1, group2) => group1.compareTo(group2),
      itemComparator: (item1, item2) =>
          item1.name?.compareTo(item2.name ?? '') ?? 0,
      order: GroupedListOrder.ASC,
    );
  }

  Widget _buildInstalledSection(List<Source> installedEntries, dynamic l10n) {
    return CustomSliverGroupedListView<Source, String>(
      elements: installedEntries,
      groupBy: (_) => "",
      groupSeparatorBuilder: (_) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Text(
              l10n.installed,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(width: 6),
            _CountBadge(count: installedEntries.length),
          ],
        ),
      ),
      itemBuilder: (context, Source element) =>
          ref.watch(extensionListTileWidget(element)),
      groupComparator: (group1, group2) => group1.compareTo(group2),
      itemComparator: (item1, item2) =>
          item1.name?.compareTo(item2.name ?? '') ?? 0,
      order: GroupedListOrder.ASC,
    );
  }

  List<Widget> _buildAvailableSection(List<Source> notInstalledEntries) {
    // Group by language
    final Map<String, List<Source>> grouped = {};
    for (final src in notInstalledEntries) {
      final lang = completeLanguageName(src.lang?.toLowerCase() ?? '');
      grouped.putIfAbsent(lang, () => []).add(src);
    }
    final sortedLangs = grouped.keys.toList()..sort();

    final slivers = <Widget>[];

    // Available header with total count
    slivers.add(
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(left: 12, right: 12, bottom: 4),
          child: Row(
            children: [
              Text(
                "Available",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 6),
              _CountBadge(count: notInstalledEntries.length),
            ],
          ),
        ),
      ),
    );

    for (final lang in sortedLangs) {
      final items = grouped[lang]!;
      items.sort((a, b) => (a.name ?? '').compareTo(b.name ?? ''));
      final isCollapsed = _collapsed[lang] ?? false;

      // Language section header (collapsible)
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

      // Items (visible only when not collapsed)
      if (!isCollapsed) {
        slivers.add(
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => ref.watch(
                extensionListTileWidget(items[index]),
              ),
              childCount: items.length,
            ),
          ),
        );
      }
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
        '$count',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
