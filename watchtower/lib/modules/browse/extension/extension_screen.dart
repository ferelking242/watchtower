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
                    _buildNotInstalledSection(notInstalledEntries),
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
                Text(
                  l10n.update_pending,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
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
        child: Text(
          l10n.installed,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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

  Widget _buildNotInstalledSection(List<Source> notInstalledEntries) {
    return CustomSliverGroupedListView<Source, String>(
      elements: notInstalledEntries,
      groupBy: (element) =>
          completeLanguageName(element.lang?.toLowerCase() ?? ''),
      groupSeparatorBuilder: (String groupByValue) => Padding(
        padding: const EdgeInsets.only(left: 12),
        child: Text(
          groupByValue,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
}
