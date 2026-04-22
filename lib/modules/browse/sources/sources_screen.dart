import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/modules/browse/browse_screen.dart';
import 'package:isar_community/isar.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/modules/browse/sources/widgets/source_list_tile.dart';
import 'package:watchtower/modules/more/settings/browse/providers/browse_state_provider.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/utils/language.dart';

class SourcesScreen extends ConsumerStatefulWidget {
  final ItemType itemType;
  const SourcesScreen({
    required this.itemType,
    super.key,
  });

  @override
  ConsumerState<SourcesScreen> createState() => _SourcesScreenState();
}

class _SourcesScreenState extends ConsumerState<SourcesScreen> {
  final controller = ScrollController();
  final Map<String, bool> _collapsed = {};

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
                      DefaultTabController.of(context).animateTo(1);
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
          final allEntriesWithoutPinned = sources
              .where((element) => !element.isPinned!)
              .toList();

          // Group by language for collapsible sections
          final Map<String, List<Source>> grouped = {};
          for (final src in allEntriesWithoutPinned) {
            final lang = completeLanguageName(src.lang!.toLowerCase());
            grouped.putIfAbsent(lang, () => []).add(src);
          }
          // Pre-sort each language group
          for (final list in grouped.values) {
            list.sort((a, b) => a.name!.compareTo(b.name!));
          }
          final sortedLangs = grouped.keys.toList()..sort();

          return Scrollbar(
            interactive: true,
            controller: controller,
            thickness: 12,
            radius: const Radius.circular(10),
            child: CustomScrollView(
              controller: controller,
              slivers: [
                // Last Used section
                if (lastUsedEntries.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12, right: 12, bottom: 2),
                      child: Row(
                        children: [
                          Text(
                            l10n.last_used,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 6),
                          _CountBadge(count: lastUsedEntries.length),
                        ],
                      ),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => SourceListTile(
                        source: lastUsedEntries[index],
                        itemType: widget.itemType,
                      ),
                      childCount: lastUsedEntries.length,
                    ),
                  ),
                ],

                // Pinned section
                if (isPinnedEntries.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12, right: 12, bottom: 2),
                      child: Row(
                        children: [
                          Text(
                            l10n.pinned,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 6),
                          _CountBadge(count: isPinnedEntries.length),
                        ],
                      ),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => SourceListTile(
                        source: isPinnedEntries[index],
                        itemType: widget.itemType,
                      ),
                      childCount: isPinnedEntries.length,
                    ),
                  ),
                ],

                // Language sections (collapsible)
                for (final lang in sortedLangs) ...[
                  _CollapsibleLanguageHeader(
                    lang: lang,
                    count: grouped[lang]!.length,
                    isCollapsed: _collapsed[lang] ?? false,
                    onToggle: () {
                      setState(() {
                        _collapsed[lang] = !(_collapsed[lang] ?? false);
                      });
                    },
                  ),
                  if (!(_collapsed[lang] ?? false))
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => SourceListTile(
                          source: grouped[lang]![index],
                          itemType: widget.itemType,
                        ),
                        childCount: grouped[lang]!.length,
                      ),
                    ),
                ],

                // Other (local source)
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

class _CollapsibleLanguageHeader extends StatelessWidget {
  final String lang;
  final int count;
  final bool isCollapsed;
  final VoidCallback onToggle;

  const _CollapsibleLanguageHeader({
    required this.lang,
    required this.count,
    required this.isCollapsed,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: InkWell(
        onTap: onToggle,
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
              _CountBadge(count: count),
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
    );
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
