import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/modules/browse/browse_screen.dart';
import 'package:watchtower/modules/widgets/custom_sliver_grouped_list_view.dart';
import 'package:isar_community/isar.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/modules/browse/sources/widgets/source_list_tile.dart';
import 'package:watchtower/modules/more/settings/browse/providers/browse_state_provider.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/utils/language.dart';

class SourcesScreen extends ConsumerStatefulWidget {
  final Function(int) tabIndex;
  final List<BrowseTab> tabs;
  final ItemType itemType;
  const SourcesScreen({
    required this.tabIndex,
    required this.itemType,
    required this.tabs,
    super.key,
  });

  @override
  ConsumerState<SourcesScreen> createState() => _SourcesScreenState();
}

class _SourcesScreenState extends ConsumerState<SourcesScreen> {
  final controller = ScrollController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = l10nLocalizations(context)!;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: StreamBuilder(
        stream: isar.sources
            .filter()
            .idIsNotNull()
            .isAddedEqualTo(true)
            .and()
            .isActiveEqualTo(true)
            .and()
            .itemTypeEqualTo(widget.itemType)
            .watch(fireImmediately: true),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const SizedBox.shrink();
          }
          final showNSFW = ref.watch(showNSFWStateProvider);
          List<Source> sources = snapshot.data!
              .where((e) => showNSFW || !(e.isNsfw ?? false))
              .toList();
          if (sources.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                          Theme.of(context).colorScheme.primary.withValues(alpha: 0.04),
                        ],
                      ),
                    ),
                    child: Icon(
                      Icons.satellite_alt_outlined,
                      size: 56,
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
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
                    context.l10n.no_sources_installed,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).hintColor.withValues(alpha: 0.7),
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    onPressed: () {
                      final extensionIndex = widget.tabs.indexWhere(
                        (t) =>
                            t.type == widget.itemType &&
                            t.kind == BrowseTabKind.extensions,
                      );
                      if (extensionIndex != -1) {
                        widget.tabIndex(extensionIndex);
                      }
                    },
                    icon: const Icon(Icons.extension_rounded, size: 18),
                    label: Text(context.l10n.show_extensions),
                  ),
                  const SizedBox(height: 24),
                  Divider(
                    indent: 40,
                    endIndent: 40,
                    color: Theme.of(context).hintColor.withValues(alpha: 0.2),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.other,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).hintColor,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  SourceListTile(
                    source: Source(
                      name: "local",
                      lang: "",
                      itemType: widget.itemType,
                    ),
                    itemType: widget.itemType,
                  ),
                ],
              ),
            );
          }
          final lastUsedEntries = sources
              .where((element) => element.lastUsed!)
              .toList();
          final isPinnedEntries = sources
              .where((element) => element.isPinned!)
              .toList();
          final allEntriesWithoutIspinned = sources
              .where((element) => !element.isPinned!)
              .toList();
          return Scrollbar(
            interactive: true,
            controller: controller,
            thickness: 12,
            radius: const Radius.circular(10),
            child: CustomScrollView(
              controller: controller,
              slivers: [
                CustomSliverGroupedListView<Source, String>(
                  elements: lastUsedEntries,
                  groupBy: (element) => "",
                  groupSeparatorBuilder: (String groupByValue) => Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Row(
                      children: [
                        Text(
                          l10n.last_used,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  itemBuilder: (context, Source element) {
                    return SourceListTile(
                      source: element,
                      itemType: widget.itemType,
                    );
                  },
                  groupComparator: (group1, group2) => group1.compareTo(group2),
                  itemComparator: (item1, item2) =>
                      item1.name!.compareTo(item2.name!),
                  order: GroupedListOrder.ASC,
                ),
                CustomSliverGroupedListView<Source, String>(
                  elements: isPinnedEntries,
                  groupBy: (element) => "",
                  groupSeparatorBuilder: (String groupByValue) => Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Row(
                      children: [
                        Text(
                          l10n.pinned,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  itemBuilder: (context, Source element) {
                    return SourceListTile(
                      source: element,
                      itemType: widget.itemType,
                    );
                  },
                  groupComparator: (group1, group2) => group1.compareTo(group2),
                  itemComparator: (item1, item2) =>
                      item1.name!.compareTo(item2.name!),
                  order: GroupedListOrder.ASC,
                ),
                CustomSliverGroupedListView<Source, String>(
                  elements: allEntriesWithoutIspinned,
                  groupBy: (element) =>
                      completeLanguageName(element.lang!.toLowerCase()),
                  groupSeparatorBuilder: (String groupByValue) => Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Row(
                      children: [
                        Text(
                          groupByValue,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  itemBuilder: (context, Source element) {
                    return SourceListTile(
                      source: element,
                      itemType: widget.itemType,
                    );
                  },
                  groupComparator: (group1, group2) => group1.compareTo(group2),
                  itemComparator: (item1, item2) =>
                      item1.name!.compareTo(item2.name!),
                  order: GroupedListOrder.ASC,
                ),
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: Row(
                          children: [
                            Text(
                              l10n.other,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SourceListTile(
                        source: Source(
                          name: "local",
                          lang: "",
                          itemType: widget.itemType,
                        ),
                        itemType: widget.itemType,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
