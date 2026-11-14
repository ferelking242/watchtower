
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:isar_community/isar.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/modules/browse/sources/widgets/source_list_tile.dart';
import 'package:watchtower/modules/browse/sources/widgets/smart_library_source_tile.dart';
import 'package:watchtower/modules/browse/widgets/browse_source_filter_menu.dart';
import 'package:watchtower/modules/more/settings/browse/providers/browse_state_provider.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/services/fetch_item_sources.dart';
import 'package:watchtower/utils/adaptive_overlay_menu.dart';
import 'package:watchtower/utils/language.dart';
import 'package:watchtower/widgets/shimmer_skeleton.dart';

/// Actions of a language-group three-dot menu in the Explorer.
enum _SectionMenuAction { enableAll, disableAll, pinAll, unpinAll, clearFilter }

class _SectionMenuRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SectionMenuRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(label)),
      ],
    );
  }
}

class SourcesScreen extends ConsumerStatefulWidget {
  final ItemType itemType;
  final String searchQuery;
  final BrowseSourceFilters filters;
  final VoidCallback? onShowExtensions;
  const SourcesScreen({
    required this.itemType,
    this.searchQuery = '',
    this.filters = const BrowseSourceFilters(),
    this.onShowExtensions,
    super.key,
  });

  @override
  ConsumerState<SourcesScreen> createState() => _SourcesScreenState();
}

class _SourcesScreenState extends ConsumerState<SourcesScreen> {
  final _scrollController = ScrollController();
  final Map<String, bool> _collapsed = {};

  /// Per-language filter, applied only to the tiles of that language group.
  /// Empty by default: the global filter ([widget.filters]) still applies to
  /// the whole screen.
  final Map<String, BrowseSourceFilters> _sectionFilters = {};

  List<Source> _sourcesForCurrentType(Iterable<Source> sources) {
    return sources
        // Browse is the installed-source surface. Repository/catalogue
        // entries are persisted too, but must stay out of this screen until
        // their source code has actually been installed.
        .where(
          (source) =>
              source.itemType == widget.itemType &&
              source.isAdded == true &&
              source.sourceCodeLanguage != SourceCodeLanguage.unsupported,
        )
        .where((source) => widget.filters.matches(source, widget.searchQuery))
        .toList();
  }

  Future<void> _refreshSources() async {
    final sources = _sourcesForCurrentType(isar.sources.where().findAllSync());

    await Future.wait<void>(
      sources.take(24).map((source) async {
        try {
          await ref.read(
            fetchItemSourcesListProvider(
              id: source.id,
              reFresh: true,
              itemType: widget.itemType,
            ).future,
          );
        } catch (_) {
          // One unavailable extension must not cancel the refresh of the rest.
        }
      }),
    ).timeout(const Duration(seconds: 25), onTimeout: () => <void>[]);
  }

  /// Filter + three-dot controls for one language group. The filter uses the
  /// shared [BrowseSourceFilterMenu] (same overlay as the Library) scoped to
  /// the group's sources; the icon turns primary when that group is filtered.
  Widget _sectionTrailing(String lang, List<Source> entries) {
    final theme = Theme.of(context);
    final filters = _sectionFilters[lang] ?? const BrowseSourceFilters();
    final active = filters.hasAny;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AdaptiveOverlayMenuButton(
          menuWidth: 300,
          trigger: Icon(
            // Same Library filter glyph; the primary colour marks an active
            // filter on this language group.
            Broken.slider_horizontal,
            size: 18,
            color: active ? theme.colorScheme.primary : theme.hintColor,
          ),
          contentBuilder: (close) => BrowseSourceFilterMenu(
            filters: filters,
            availableSources: entries,
            onChanged: (next) {
              setState(() => _sectionFilters[lang] = next);
              if (!next.hasAny) _sectionFilters.remove(lang);
            },
          ),
        ),
        AdaptiveOverlayMenu<_SectionMenuAction>(
          tooltip: 'Options de la section',
          icon: Icon(Broken.more_2, size: 18, color: theme.hintColor),
          menuWidth: 240,
          onSelected: (action) {
            switch (action) {
              case _SectionMenuAction.enableAll:
                _setSectionActive(entries, true);
              case _SectionMenuAction.disableAll:
                _setSectionActive(entries, false);
              case _SectionMenuAction.pinAll:
                _setSectionPinned(entries, true);
              case _SectionMenuAction.unpinAll:
                _setSectionPinned(entries, false);
              case _SectionMenuAction.clearFilter:
                setState(() => _sectionFilters.remove(lang));
            }
          },
          itemBuilder: (ctx) => [
            PopupMenuItem(
              value: _SectionMenuAction.enableAll,
              child: _SectionMenuRow(
                icon: Broken.play,
                label: 'Activer la section',
              ),
            ),
            PopupMenuItem(
              value: _SectionMenuAction.disableAll,
              child: _SectionMenuRow(
                icon: Broken.pause,
                label: 'Désactiver la section',
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: _SectionMenuAction.pinAll,
              child: _SectionMenuRow(
                icon: Broken.bookmark,
                label: 'Épingler la section',
              ),
            ),
            PopupMenuItem(
              value: _SectionMenuAction.unpinAll,
              child: _SectionMenuRow(
                icon: Broken.bookmark_2,
                label: 'Désépingler la section',
              ),
            ),
            if (active) ...[
              const PopupMenuDivider(),
              PopupMenuItem(
                value: _SectionMenuAction.clearFilter,
                child: _SectionMenuRow(
                  icon: Broken.filter_remove,
                  label: 'Effacer les filtres',
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  void _setSectionActive(List<Source> entries, bool active) {
    final ids = entries.map((e) => e.id).whereType<int>().toSet();
    isar.writeTxnSync(() {
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final source in isar.sources.where().findAllSync()) {
        if (ids.contains(source.id)) {
          isar.sources.putSync(source..isActive = active..updatedAt = now);
        }
      }
    });
    if (mounted) setState(() {});
  }

  void _setSectionPinned(List<Source> entries, bool pinned) {
    final ids = entries.map((e) => e.id).whereType<int>().toSet();
    isar.writeTxnSync(() {
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final source in isar.sources.where().findAllSync()) {
        if (ids.contains(source.id)) {
          isar.sources.putSync(source..isPinned = pinned..updatedAt = now);
        }
      }
    });
    if (mounted) setState(() {});
  }

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
            child: StreamBuilder<List<Source>>(
              // Avoid Isar filters on nullable bool properties. The
              // collection is observed without filters and narrowed in Dart.
              stream: isar.sources.where().watch(fireImmediately: true),
              initialData:
                  isar.sources.where().findAllSync(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _SourcesLoadError(onRetry: () => setState(() {}));
                }
                if (!snapshot.hasData) {
                  return _SourcesSkeleton(
                    colorScheme: Theme.of(context).colorScheme,
                  );
                }
                final showNSFW = ref.watch(showNSFWStateProvider);
                List<Source> sources = _sourcesForCurrentType(
                  snapshot.data ?? const <Source>[],
                )
                    .where((e) => e.id != null)
                    .where((e) => showNSFW || !(e.isNsfw ?? false))
                    // "local" source is always shown via the fixed section
                    // at the bottom of the column — exclude it from the
                    // grouped list so it never appears twice.
                    .where(
                      (e) => !(e.name == 'local' && (e.lang ?? '').isEmpty),
                    )
                    .toList();
                {
                  final seen = <String>{};
                  sources = sources
                      .where((s) => seen.add(s.name ?? s.id.toString()))
                      .toList();
                }

                if (sources.isEmpty) {
                  final hasInstalledExtension = (snapshot.data ?? const [])
                      .any(
                        (source) =>
                            source.itemType == widget.itemType &&
                            source.isAdded == true &&
                            !(source.name == 'local' &&
                                (source.lang ?? '').isEmpty),
                      );
                  return hasInstalledExtension
                      ? const _NoMatchingSources()
                      : _EmptyState(
                          onShowExtensions: widget.onShowExtensions,
                          itemType: widget.itemType,
                        );
                }

                // Grouped view
                // Pinned sources must remain visible after toggling the pin.
                // They are rendered in their own section instead of being
                // removed from the language groups and silently disappearing.
                final isPinnedEntries = sources
                    .where((e) => e.isPinned == true)
                    .toList()
                  ..sort((a, b) => (a.name ?? '').compareTo(b.name ?? ''));
                final lastUsedEntries = sources
                    .where(
                      (e) => e.lastUsed == true && e.isPinned != true,
                    )
                    .toList();
                final allEntriesWithoutPinned = sources
                    .where((e) => !(e.isPinned ?? false))
                    .toList();

                final Map<String, List<Source>> grouped = {};
                for (final src in allEntriesWithoutPinned) {
                  final lang = completeLanguageName(
                    (src.lang ?? '').toLowerCase(),
                  );
                  grouped.putIfAbsent(lang, () => []).add(src);
                }
                for (final list in grouped.values) {
                  list.sort((a, b) => (a.name ?? '').compareTo(b.name ?? ''));
                }
                final sortedLangs = grouped.keys.toList()..sort();

                return RefreshIndicator(
                  onRefresh: _refreshSources,
                  color: Theme.of(context).colorScheme.primary,
                  child: Scrollbar(
                    interactive: true,
                    controller: _scrollController,
                    thickness: 6,
                    radius: const Radius.circular(10),
                    child: CustomScrollView(
                      controller: _scrollController,
                      slivers: [
                        if (isPinnedEntries.isNotEmpty) ...[
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.only(
                                left: 12,
                                right: 12,
                                bottom: 2,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Broken.bookmark,
                                    size: 15,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary,
                                  ),
                                  const SizedBox(width: 6),
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
                              (_, i) => SourceListTile(
                                source: isPinnedEntries[i],
                                itemType: widget.itemType,
                              ),
                              childCount: isPinnedEntries.length,
                            ),
                          ),
                        ],
                        if (lastUsedEntries.isNotEmpty) ...[
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.only(
                                left: 12,
                                right: 12,
                                bottom: 2,
                              ),
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
                              (_, i) => SourceListTile(
                                source: lastUsedEntries[i],
                                itemType: widget.itemType,
                              ),
                              childCount: lastUsedEntries.length,
                            ),
                          ),
                        ],

                        for (final lang in sortedLangs)
                          ...(() {
                            final entries = (grouped[lang] ?? const [])
                                .where(
                                  (source) =>
                                      (_sectionFilters[lang] ??
                                              const BrowseSourceFilters())
                                          .matches(source, widget.searchQuery),
                                )
                                .toList();
                            if (entries.isEmpty) return const <Widget>[];
                            return <Widget>[
                              _CollapsibleLanguageHeader(
                                lang: lang,
                                count: entries.length,
                                isCollapsed: _collapsed[lang] ?? false,
                                onToggle: () => setState(() {
                                  _collapsed[lang] =
                                      !(_collapsed[lang] ?? false);
                                }),
                                langCode:
                                    entries.first.lang?.toLowerCase() ?? '',
                                trailing: _sectionTrailing(lang, entries),
                              ),
                              if (!(_collapsed[lang] ?? false))
                                SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                    (_, i) => SourceListTile(
                                      source: entries[i],
                                      itemType: widget.itemType,
                                    ),
                                    childCount: entries.length,
                                  ),
                                ),
                            ];
                          })(),

                        // ── Other / local source section ─────────────────
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(
                              left: 12,
                              top: 10,
                              bottom: 2,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Broken.element_3,
                                  size: 15,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 6),
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
                        ),
                        SliverToBoxAdapter(
                          child: SourceListTile(
                            source: Source(
                              name: "local",
                              lang: "",
                              itemType: widget.itemType,
                            ),
                            itemType: widget.itemType,
                          ),
                        ),
                        if (widget.itemType == ItemType.anime ||
                            widget.itemType == ItemType.manga)
                          SliverToBoxAdapter(
                            child: SmartLibrarySourceTile(
                              itemType: widget.itemType,
                            ),
                          ),
                        // Espace en bas : remonte la source locale au-dessus du dock
                        const SliverToBoxAdapter(child: SizedBox(height: 120)),
                      ],
                    ),
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

class _SourcesSkeleton extends StatelessWidget {
  final ColorScheme colorScheme;

  const _SourcesSkeleton({required this.colorScheme});

  Widget _bone({
    required double width,
    required double height,
    double radius = 8,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  Widget _sourceCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          _bone(width: 42, height: 42, radius: 10),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _bone(width: 150, height: 14),
                const SizedBox(height: 8),
                _bone(width: 94, height: 10, radius: 5),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _bone(width: 42, height: 30, radius: 15),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final effect = ShimmerEffect(
      baseColor: colorScheme.surfaceContainerHigh,
      highlightColor: colorScheme.surfaceContainerHighest,
    );
    return ShimmerSkeleton(
      effect: effect,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 120),
        children: [
          Row(
            children: [
              _bone(width: 110, height: 15),
              const Spacer(),
              _bone(width: 76, height: 30, radius: 15),
            ],
          ),
          const SizedBox(height: 12),
          _sourceCard(),
          _sourceCard(),
          const SizedBox(height: 12),
          Row(
            children: [
              _bone(width: 96, height: 15),
              const Spacer(),
              _bone(width: 42, height: 22, radius: 11),
            ],
          ),
          const SizedBox(height: 6),
          _sourceCard(),
          _sourceCard(),
          _sourceCard(),
          const SizedBox(height: 12),
          _bone(width: double.infinity, height: 48, radius: 14),
        ],
      ),
    );
  }
}

class _SourcesLoadError extends StatelessWidget {
  final VoidCallback onRetry;

  const _SourcesLoadError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              color: colors.onSurfaceVariant,
              size: 42,
            ),
            const SizedBox(height: 12),
            Text(
              'Impossible de charger les extensions',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Réessaie après avoir vérifié la connexion.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback? onShowExtensions;
  final ItemType itemType;

  const _EmptyState({required this.onShowExtensions, required this.itemType});

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
                  Icon(
                    Icons.extension_off_rounded,
                    size: 56,
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.l10n.no_sources_installed,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Installe une extension depuis le Marketplace',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.45),
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
                    onPressed: () =>
                        context.push('/localHowTo', extra: itemType),
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

class _NoMatchingSources extends StatelessWidget {
  const _NoMatchingSources();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Broken.search_normal,
              size: 46,
              color: colors.primary.withValues(alpha: 0.45),
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.no_result,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Aucune extension ne correspond à la recherche ou aux filtres.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.55),
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
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

  /// Filter + three-dot controls pinned before the collapse caret, so a
  /// language group can be filtered in place (same overlay as the Library).
  final Widget? trailing;

  const _CollapsibleLanguageHeader({
    required this.lang,
    required this.langCode,
    required this.count,
    required this.isCollapsed,
    required this.onToggle,
    this.trailing,
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
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              _CountBadge(count: count),
              if (trailing != null) ...[const SizedBox(width: 4), trailing!],
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
