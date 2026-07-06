import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fuzzywuzzy/fuzzywuzzy.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:watchtower/modules/music/collections/riverpod_compat.dart';
import 'package:watchtower/modules/music/collections/routes.gr.dart';
import 'package:watchtower/modules/music/collections/spotube_icons.dart';
import 'package:watchtower/modules/music/components/fallbacks/error_box.dart';
import 'package:watchtower/modules/music/components/fallbacks/no_default_metadata_plugin.dart';
import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:watchtower/modules/music/extensions/string.dart';
import 'package:watchtower/modules/music/pages/search/tabs/albums.dart';
import 'package:watchtower/modules/music/pages/search/tabs/all.dart';
import 'package:watchtower/modules/music/pages/search/tabs/artists.dart';
import 'package:watchtower/modules/music/pages/search/tabs/playlists.dart';
import 'package:watchtower/modules/music/pages/search/tabs/tracks.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/search/all.dart';
import 'package:watchtower/modules/music/services/kv_store/kv_store.dart';
import 'package:watchtower/modules/music/services/metadata/errors/exceptions.dart';

final searchTermStateProvider = StateProvider<String>((ref) {
  return "";
});

class SearchPage extends HookConsumerWidget {
  static const name = "search";
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final controller = useTextEditingController();
    final focusNode = useFocusNode();
    final showSuggestions = useState(false);

    final searchTerm = ref.watch(searchTermStateProvider);
    final searchChipSnapshot = ref.watch(metadataPluginSearchChipsProvider);
    final selectedChip = useState<String?>(
      searchChipSnapshot.asData?.value.first ?? "all",
    );

    ref.listen(
      metadataPluginSearchChipsProvider,
      (previous, next) {
        selectedChip.value = next.asData?.value.first ?? "all";
      },
    );

    useEffect(() {
      controller.text = searchTerm;
      void onFocus() => showSuggestions.value = focusNode.hasFocus;
      focusNode.addListener(onFocus);
      return () => focusNode.removeListener(onFocus);
    }, []);

    void onSubmitted(String value) {
      ref.read(searchTermStateProvider.notifier).state = value;
      showSuggestions.value = false;
      focusNode.unfocus();
      if (value.trim().isEmpty) return;
      KVStoreService.setRecentSearches(
        {value, ...KVStoreService.recentSearches}.toList(),
      );
    }

    void clearHistory(String term) {
      final current = KVStoreService.recentSearches;
      KVStoreService.setRecentSearches(
        current.where((e) => e != term).toList(),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        context.navigateTo(const HomeRoute());
      },
      child: SafeArea(
        bottom: false,
        child: Builder(builder: (context) {
          if (searchChipSnapshot.error
              case MetadataPluginException(
                errorCode: MetadataPluginErrorCode.noDefaultMetadataPlugin,
              )) {
            return const NoDefaultMetadataPlugin();
          }
          if (searchChipSnapshot.hasError) {
            return ErrorBox(
              error: searchChipSnapshot.error!,
              onRetry: () {
                ref.invalidate(metadataPluginSearchChipsProvider);
              },
            );
          }

          final theme = Theme.of(context);
          final cs = theme.colorScheme;
          final screenWidth = MediaQuery.of(context).size.width;
          final isSmallScreen = screenWidth < 400;

          return Column(
            children: [
              // ── Compact search bar ──────────────────────────────────────────
              Material(
                color: cs.surface,
                elevation: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        12,
                        isSmallScreen ? 8 : 10,
                        12,
                        4,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: isSmallScreen ? 38 : 42,
                              decoration: BoxDecoration(
                                color: cs.surfaceContainerHighest
                                    .withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const SizedBox(width: 10),
                                  Icon(
                                    Icons.search_rounded,
                                    size: isSmallScreen ? 18 : 20,
                                    color: cs.onSurface.withValues(alpha: 0.5),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: controller,
                                      focusNode: focusNode,
                                      onSubmitted: onSubmitted,
                                      textInputAction: TextInputAction.search,
                                      onChanged: (v) {
                                        showSuggestions.value = true;
                                      },
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(fontSize: isSmallScreen ? 13 : 14),
                                      decoration: InputDecoration(
                                        hintText: context.l10n.search_tracks,
                                        hintStyle: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                          color: cs.onSurface
                                              .withValues(alpha: 0.4),
                                          fontSize: isSmallScreen ? 13 : 14,
                                        ),
                                        border: InputBorder.none,
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(
                                          vertical: 0,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (controller.text.isNotEmpty)
                                    GestureDetector(
                                      onTap: () {
                                        controller.clear();
                                        ref
                                            .read(searchTermStateProvider.notifier)
                                            .state = '';
                                        showSuggestions.value = false;
                                        focusNode.requestFocus();
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                        child: Icon(
                                          Icons.close_rounded,
                                          size: 16,
                                          color: cs.onSurface.withValues(alpha: 0.5),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Filter icon
                          Container(
                            width: isSmallScreen ? 36 : 40,
                            height: isSmallScreen ? 36 : 40,
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHighest
                                  .withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              icon: Icon(
                                SpotubeIcons.filter,
                                size: isSmallScreen ? 17 : 19,
                              ),
                              color: cs.onSurface.withValues(alpha: 0.7),
                              padding: EdgeInsets.zero,
                              onPressed: () {
                                // Show filter bottom sheet
                                showModalBottomSheet(
                                  context: context,
                                  useRootNavigator: false,
                                  backgroundColor: cs.surface,
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(20),
                                    ),
                                  ),
                                  builder: (_) => _FilterSheet(
                                    chips: searchChipSnapshot.asData?.value ?? [],
                                    selected: selectedChip.value,
                                    onSelected: (chip) {
                                      selectedChip.value = chip;
                                      Navigator.of(context).pop();
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Compact inline suggestions / history ─────────────────
                    if (showSuggestions.value) ...[
                      _SearchSuggestions(
                        query: controller.text,
                        isSmallScreen: isSmallScreen,
                        onTap: (term) {
                          controller.text = term;
                          onSubmitted(term);
                        },
                        onDelete: (term) {
                          clearHistory(term);
                          // rebuild
                          ref.read(searchTermStateProvider);
                        },
                      ),
                    ],

                    // ── Category chips (compact horizontal scroll) ───────────
                    if (!showSuggestions.value &&
                        searchChipSnapshot.asData?.value != null)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
                        child: Row(
                          children: [
                            for (final chip
                                in searchChipSnapshot.asData!.value) ...[
                              _CompactChip(
                                label: chip.capitalize(),
                                selected: selectedChip.value == chip,
                                isSmallScreen: isSmallScreen,
                                onTap: () => selectedChip.value = chip,
                              ),
                              const SizedBox(width: 6),
                            ],
                          ],
                        ),
                      ),
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: cs.outlineVariant.withValues(alpha: 0.3),
                    ),
                  ],
                ),
              ),

              // ── Results ─────────────────────────────────────────────────────
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: switch (selectedChip.value) {
                    "tracks" => const SearchPageTracksTab(),
                    "albums" => const SearchPageAlbumsTab(),
                    "artists" => const SearchPageArtistsTab(),
                    "playlists" => const SearchPagePlaylistsTab(),
                    _ => const SearchPageAllTab(),
                  },
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

// ─── Compact chip ─────────────────────────────────────────────────────────────

class _CompactChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isSmallScreen;
  final VoidCallback onTap;

  const _CompactChip({
    required this.label,
    required this.selected,
    required this.isSmallScreen,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 10 : 13,
          vertical: isSmallScreen ? 4 : 5,
        ),
        decoration: BoxDecoration(
          color: selected ? cs.primary : cs.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? cs.onPrimary : cs.onSurface.withValues(alpha: 0.75),
            fontSize: isSmallScreen ? 11 : 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

// ─── Suggestions widget ───────────────────────────────────────────────────────

class _SearchSuggestions extends HookConsumerWidget {
  final String query;
  final bool isSmallScreen;
  final ValueChanged<String> onTap;
  final ValueChanged<String> onDelete;

  const _SearchSuggestions({
    required this.query,
    required this.isSmallScreen,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, ref) {
    final cs = Theme.of(context).colorScheme;
    final recent = KVStoreService.recentSearches;

    final List<String> base = query.isEmpty
        ? [...recent.take(isSmallScreen ? 3 : 5)]
        : [
            ...recent
                .where((r) => r.toLowerCase().contains(query.toLowerCase()))
                .take(2),
            if (query.length >= 2)
              ...extractTop(
                query: query,
                choices: [
                  "Twenty One Pilots",
                  "The Weeknd",
                  "Taylor Swift",
                  "Ed Sheeran",
                  "Billie Eilish",
                  "Drake",
                  "Kendrick Lamar",
                  "Olivia Rodrigo",
                ],
                limit: 2,
                cutoff: 40,
              ).map((e) => e.choice),
          ];

    final suggestions = base.take(isSmallScreen ? 3 : 5).toList();

    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Container(
      color: cs.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final s in suggestions)
            InkWell(
              onTap: () => onTap(s),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: isSmallScreen ? 7 : 9,
                ),
                child: Row(
                  children: [
                    Icon(
                      recent.contains(s)
                          ? Icons.history_rounded
                          : Icons.search_rounded,
                      size: 16,
                      color: cs.onSurface.withValues(alpha: 0.4),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        s,
                        style: TextStyle(
                          fontSize: isSmallScreen ? 13 : 14,
                          color: cs.onSurface.withValues(alpha: 0.85),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (recent.contains(s))
                      GestureDetector(
                        onTap: () => onDelete(s),
                        child: Icon(
                          Icons.close_rounded,
                          size: 15,
                          color: cs.onSurface.withValues(alpha: 0.3),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          Divider(
            height: 1,
            thickness: 1,
            color: cs.outlineVariant.withValues(alpha: 0.25),
          ),
        ],
      ),
    );
  }
}

// ─── Filter bottom sheet ──────────────────────────────────────────────────────

class _FilterSheet extends StatelessWidget {
  final List<String> chips;
  final String? selected;
  final ValueChanged<String> onSelected;

  const _FilterSheet({
    required this.chips,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Filter by',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final chip in chips)
                ChoiceChip(
                  label: Text(chip.capitalize()),
                  selected: selected == chip,
                  onSelected: (_) => onSelected(chip),
                  showCheckmark: false,
                  selectedColor: cs.primary,
                  labelStyle: TextStyle(
                    color: selected == chip ? cs.onPrimary : cs.onSurface,
                    fontWeight: selected == chip ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
