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
  final _searchController = TextEditingController();
  final Map<String, bool> _collapsed = {};

  // Filter state
  String _searchQuery = '';
  String? _langFilter;           // null = all languages
  SourceCodeLanguage? _typeFilter; // null = all types

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<Source> _applyFilters(List<Source> sources) {
    var result = sources;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result
          .where((s) => (s.name ?? '').toLowerCase().contains(q))
          .toList();
    }
    if (_langFilter != null) {
      result = result
          .where((s) => s.lang?.toLowerCase() == _langFilter)
          .toList();
    }
    if (_typeFilter != null) {
      result = result.where((s) => s.sourceCodeLanguage == _typeFilter).toList();
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = l10nLocalizations(context)!;
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        // ── Search bar + filters ──────────────────────────────────────────
        _SourcesFilterBar(
          searchController: _searchController,
          searchQuery: _searchQuery,
          langFilter: _langFilter,
          typeFilter: _typeFilter,
          onSearchChanged: (v) => setState(() => _searchQuery = v),
          onLangChanged: (v) => setState(() => _langFilter = v),
          onTypeChanged: (v) => setState(() => _typeFilter = v),
          onClearAll: () => setState(() {
            _searchQuery = '';
            _langFilter = null;
            _typeFilter = null;
            _searchController.clear();
          }),
          itemType: widget.itemType,
          cs: cs,
        ),
        if (!kIsWeb && Platform.isAndroid)
          _ScanStatusBar(itemType: widget.itemType),
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

// ─── Filter bar ───────────────────────────────────────────────────────────────

class _SourcesFilterBar extends StatelessWidget {
  final TextEditingController searchController;
  final String searchQuery;
  final String? langFilter;
  final SourceCodeLanguage? typeFilter;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onLangChanged;
  final ValueChanged<SourceCodeLanguage?> onTypeChanged;
  final VoidCallback onClearAll;
  final ItemType itemType;
  final ColorScheme cs;

  const _SourcesFilterBar({
    required this.searchController,
    required this.searchQuery,
    required this.langFilter,
    required this.typeFilter,
    required this.onSearchChanged,
    required this.onLangChanged,
    required this.onTypeChanged,
    required this.onClearAll,
    required this.itemType,
    required this.cs,
  });

  bool get _hasFilters =>
      searchQuery.isNotEmpty || langFilter != null || typeFilter != null;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: cs.surface,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Search field ────────────────────────────────────────────────
          SizedBox(
            height: 42,
            child: TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Titre…',
                hintStyle:
                    TextStyle(color: cs.onSurfaceVariant.withOpacity(0.6)),
                prefixIcon: Icon(Icons.search_rounded,
                    size: 18, color: cs.onSurfaceVariant.withOpacity(0.7)),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.close_rounded,
                            size: 16, color: cs.onSurfaceVariant),
                        onPressed: () {
                          searchController.clear();
                          onSearchChanged('');
                        },
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 32, minHeight: 32),
                      )
                    : null,
                filled: true,
                fillColor: cs.surfaceContainerHigh,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide(color: cs.primary, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // ── Filter chips row ────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // Language dropdown chip
                      _LangFilterChip(
                        selected: langFilter,
                        cs: cs,
                        itemType: itemType,
                        onChanged: onLangChanged,
                      ),
                      const SizedBox(width: 8),
                      // Type chips: JS, Dart, Mihon, LNReader
                      ...[
                        (null, Icons.apps_rounded, 'Tout'),
                        (SourceCodeLanguage.javascript, Icons.code_rounded, 'JS'),
                        (
                          SourceCodeLanguage.dart,
                          Icons.flutter_dash,
                          'Dart'
                        ),
                        (
                          SourceCodeLanguage.mihon,
                          Icons.android_rounded,
                          'Mihon'
                        ),
                        (
                          SourceCodeLanguage.lnreader,
                          Icons.menu_book_rounded,
                          'LNReader'
                        ),
                      ].map(
                        ((SourceCodeLanguage?, IconData, String) item) {
                          final (lang, icon, label) = item;
                          final sel = typeFilter == lang;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: _FilterChip(
                              icon: icon,
                              label: label,
                              selected: sel,
                              cs: cs,
                              onTap: () => onTypeChanged(lang),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              if (_hasFilters) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: onClearAll,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: cs.errorContainer.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.filter_alt_off_rounded,
                        size: 16, color: cs.error),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Language dropdown chip ───────────────────────────────────────────────────

class _LangFilterChip extends StatelessWidget {
  final String? selected;
  final ColorScheme cs;
  final ItemType itemType;
  final ValueChanged<String?> onChanged;

  const _LangFilterChip({
    required this.selected,
    required this.cs,
    required this.itemType,
    required this.onChanged,
  });

  List<Source> _allSources() {
    return isar.sources
        .filter()
        .idIsNotNull()
        .isAddedEqualTo(true)
        .and()
        .isActiveEqualTo(true)
        .and()
        .itemTypeEqualTo(itemType)
        .findAllSync()
        .where((s) => !(s.name == 'local' && (s.lang?.isEmpty ?? true)))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final langs = _allSources()
        .map((s) => s.lang?.toLowerCase() ?? '')
        .where((l) => l.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    final isActive = selected != null;
    final label = selected != null
        ? completeLanguageName(selected!)
        : 'Langue';

    return GestureDetector(
      onTap: () async {
        final result = await showModalBottomSheet<String?>(
          context: context,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (_) => _LangPickerSheet(
            langs: langs,
            selected: selected,
            cs: cs,
          ),
        );
        if (result != null) {
          // Special sentinel for "clear"
          onChanged(result == '__all__' ? null : result);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color:
              isActive ? cs.primaryContainer : cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? cs.primary : Colors.transparent,
            width: isActive ? 1.5 : 0,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.language_rounded,
              size: 13,
              color: isActive ? cs.primary : cs.onSurfaceVariant),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isActive ? cs.primary : cs.onSurface,
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.keyboard_arrow_down_rounded,
              size: 14,
              color: isActive ? cs.primary : cs.onSurfaceVariant),
        ]),
      ),
    );
  }
}

class _LangPickerSheet extends StatelessWidget {
  final List<String> langs;
  final String? selected;
  final ColorScheme cs;

  const _LangPickerSheet({
    required this.langs,
    required this.selected,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text('Langue',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                if (selected != null)
                  TextButton(
                    onPressed: () => Navigator.pop(context, '__all__'),
                    child: const Text('Tout'),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: langs.length,
              itemBuilder: (_, i) {
                final lang = langs[i];
                final name = completeLanguageName(lang);
                final flag = langFlagEmoji(lang);
                final isSelected = selected == lang;
                return ListTile(
                  leading: Text(flag,
                      style: const TextStyle(fontSize: 22)),
                  title: Text(name),
                  trailing: isSelected
                      ? Icon(Icons.check_rounded, color: cs.primary)
                      : null,
                  selected: isSelected,
                  selectedColor: cs.primary,
                  onTap: () => Navigator.pop(context, lang),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─── Generic filter chip ──────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final ColorScheme cs;
  final VoidCallback onTap;

  const _FilterChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.cs,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? cs.primaryContainer : cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? cs.primary : Colors.transparent,
            width: selected ? 1.5 : 0,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon,
              size: 12,
              color: selected ? cs.primary : cs.onSurfaceVariant),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? cs.primary : cs.onSurface)),
        ]),
      ),
    );
  }
}

// ─── Flat list (used when search/type filter active) ─────────────────────────

class _FlatSourceList extends StatelessWidget {
  final List<Source> sources;
  final ItemType itemType;
  final ScrollController controller;
  final dynamic l10n;

  const _FlatSourceList({
    required this.sources,
    required this.itemType,
    required this.controller,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.only(top: 4, bottom: 20),
      itemCount: sources.length,
      itemBuilder: (_, i) => SourceListTile(
        source: sources[i],
        itemType: itemType,
      ),
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
