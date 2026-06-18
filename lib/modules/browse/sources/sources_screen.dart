import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:isar_community/isar.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/modules/browse/sources/widgets/source_list_tile.dart';
import 'package:watchtower/modules/more/settings/browse/providers/browse_state_provider.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/services/fetch_item_sources.dart';
import 'package:watchtower/utils/language.dart';

class SourcesScreen extends ConsumerStatefulWidget {
  final ItemType itemType;
  final VoidCallback? onShowExtensions;
  const SourcesScreen({
    required this.itemType,
    this.onShowExtensions,
    super.key,
  });

  @override
  ConsumerState<SourcesScreen> createState() => _SourcesScreenState();
}

class _SourcesScreenState extends ConsumerState<SourcesScreen> {
  final _scrollController = ScrollController();
  final Map<String, bool> _collapsed = {};


  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = l10nLocalizations(context)!;
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
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
                    .where((e) => e.id != null)
                    .where((e) => e.isAdded == true)
                    .where((e) => e.isActive == true)
                    .where((e) => e.itemType == widget.itemType)
                    .where((e) => showNSFW || !(e.isNsfw ?? false))
                    .toList();
                {
                  final seen = <String>{};
                  sources = sources
                      .where((s) => seen.add(s.name ?? s.id.toString()))
                      .toList();
                }

                final filtered = _applyFilters(sources);
                final isFiltering = _searchQuery.isNotEmpty ||
                    _langFilter != null ||
                    _typeFilter != null;

                if (sources.isEmpty) {
                  return _EmptyState(
                    onShowExtensions: widget.onShowExtensions,
                    itemType: widget.itemType,
                  );
                }

                if (filtered.isEmpty && isFiltering) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off_rounded,
                            size: 48,
                            color: cs.onSurfaceVariant.withOpacity(0.4)),
                        const SizedBox(height: 12),
                        Text('Aucune source trouvée',
                            style: TextStyle(color: cs.onSurfaceVariant)),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => setState(() {
                            _searchQuery = '';
                            _langFilter = null;
                            _typeFilter = null;
                            _searchController.clear();
                          }),
                          child: const Text('Effacer les filtres'),
                        ),
                      ],
                    ),
                  );
                }

                // When filtering by search/type, show flat list (no grouping)
                if (isFiltering) {
                  return _FlatSourceList(
                    sources: filtered,
                    itemType: widget.itemType,
                    controller: _scrollController,
                    l10n: l10n,
                  );
                }

                // Normal grouped view
                final lastUsedEntries =
                    filtered.where((e) => e.lastUsed!).toList();
                final isPinnedEntries =
                    filtered.where((e) => e.isPinned!).toList();
                final allEntriesWithoutPinned =
                    filtered.where((e) => !e.isPinned!).toList();

                final Map<String, List<Source>> grouped = {};
                for (final src in allEntriesWithoutPinned) {
                  final lang =
                      completeLanguageName(src.lang!.toLowerCase());
                  grouped.putIfAbsent(lang, () => []).add(src);
                }
                for (final list in grouped.values) {
                  list.sort((a, b) => a.name!.compareTo(b.name!));
                }
                final sortedLangs = grouped.keys.toList()..sort();

                return Scrollbar(
                  interactive: true,
                  controller: _scrollController,
                  thickness: 12,
                  radius: const Radius.circular(10),
                  child: CustomScrollView(
                    controller: _scrollController,
                    slivers: [
                      if (lastUsedEntries.isNotEmpty) ...[
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(
                                left: 12, right: 12, bottom: 2),
                            child: Row(children: [
                              Text(l10n.last_used,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13)),
                              const SizedBox(width: 6),
                              _CountBadge(count: lastUsedEntries.length),
                            ]),
                          ),
                        ),
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (_, i) => SourceListTile(
                              source: lastUsedEntries[i],
                              itemType: widget.itemType,
                            ),
                            childCount: lastUsedEntries.length,
                          ),
                        ),
                      ],
                      if (isPinnedEntries.isNotEmpty) ...[
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(
                                left: 12, right: 12, bottom: 2),
                            child: Row(children: [
                              Text(l10n.pinned,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13)),
                              const SizedBox(width: 6),
                              _CountBadge(count: isPinnedEntries.length),
                            ]),
                          ),
                        ),
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (_, i) => SourceListTile(
                              source: isPinnedEntries[i],
                              itemType: widget.itemType,
                            ),
                            childCount: isPinnedEntries.length,
                          ),
                        ),
                      ],
                      for (final lang in sortedLangs) ...[
                        _CollapsibleLanguageHeader(
                          lang: lang,
                          count: grouped[lang]!.length,
                          isCollapsed: _collapsed[lang] ?? false,
                          onToggle: () => setState(() {
                            _collapsed[lang] = !(_collapsed[lang] ?? false);
                          }),
                          langCode:
                              grouped[lang]!.first.lang?.toLowerCase() ?? '',
                        ),
                        if (!(_collapsed[lang] ?? false))
                          SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (_, i) => SourceListTile(
                                source: grouped[lang]![i],
                                itemType: widget.itemType,
                              ),
                              childCount: grouped[lang]!.length,
                            ),
                          ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}


// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback? onShowExtensions;
  final ItemType itemType;

  const _EmptyState({
    required this.onShowExtensions,
    required this.itemType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'ヽ(°〇°)ﾉ',
                    style: TextStyle(
                      fontSize: 52,
                      color: Theme.of(context)
                          .hintColor
                          .withValues(alpha: 0.55),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Nothing here",
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).hintColor,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.no_sources_installed,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(
                          color: Theme.of(context)
                              .hintColor
                              .withValues(alpha: 0.7),
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    onPressed: onShowExtensions,
                    icon: const Icon(Icons.storefront_rounded, size: 18),
                    label: const Text('Go to Market'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => context.push(
                      '/localHowTo',
                      extra: itemType,
                    ),
                    icon: const Icon(Icons.help_outline_rounded, size: 18),
                    label: const Text('How To — Source Locale'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Collapsible language header ──────────────────────────────────────────────

class _CollapsibleLanguageHeader extends StatelessWidget {
  final String lang;
  final String langCode;
  final int count;
  final bool isCollapsed;
  final VoidCallback onToggle;

  const _CollapsibleLanguageHeader({
    required this.lang,
    required this.langCode,
    required this.count,
    required this.isCollapsed,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final flag = langFlagEmoji(langCode);
    return SliverToBoxAdapter(
      child: InkWell(
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Text(flag, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  lang,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13),
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

// ─── Scan status bar ──────────────────────────────────────────────────────────

class _ScanStatusBar extends ConsumerWidget {
  final ItemType itemType;
  const _ScanStatusBar({required this.itemType});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isScanning = ref.watch(extensionScanningProvider);
    if (!isScanning) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          Text(
            'Scanning extensions…',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

// ─── Count badge ─────────────────────────────────────────────────────────────

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
