import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:watchtower/modules/music/collections/riverpod_compat.dart';
import 'package:watchtower/modules/music/collections/routes.gr.dart';
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
import 'package:watchtower/modules/widgets/inline_filter_chips_mixin.dart';

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

    final searchTerm = ref.watch(searchTermStateProvider);
    final searchChipSnapshot = ref.watch(metadataPluginSearchChipsProvider);
    final selectedChip = useState<String?>(
      searchChipSnapshot.asData?.value.first ?? "all",
    );
    // Tracks whether the inline filter chip row is visible
    final showFilterChips = useState(true);

    ref.listen(
      metadataPluginSearchChipsProvider,
      (previous, next) {
        selectedChip.value = next.asData?.value.first ?? "all";
      },
    );

    useEffect(() {
      controller.text = searchTerm;
      return null;
    }, []);

    void onSubmitted(String value) {
      ref.read(searchTermStateProvider.notifier).state = value;
      focusNode.unfocus();
      if (value.trim().isEmpty) return;
      KVStoreService.setRecentSearches(
        {value, ...KVStoreService.recentSearches}.toList(),
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

          final chips = searchChipSnapshot.asData?.value ?? <String>[];
          // Active if a specific category is selected (not "all")
          final isFiltered = selectedChip.value != null &&
              selectedChip.value != "all" &&
              selectedChip.value != chips.firstOrNull;
          final activeCount = isFiltered ? 1 : 0;

          return ColoredBox(
            color: cs.surface,
            child: Column(
              children: [
                // ── Search bar + filter icon ─────────────────────────────────
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
                            // ── Filter icon (même style que Watch Discovery) ──
                            FilterIconBtn(
                              activeCount: activeCount,
                              onTap: () {
                                showFilterChips.value =
                                    !showFilterChips.value;
                              },
                            ),
                            const SizedBox(width: 6),
                            // ── Search field ─────────────────────────────────
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
                                      color:
                                          cs.onSurface.withValues(alpha: 0.5),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextField(
                                        controller: controller,
                                        focusNode: focusNode,
                                        onSubmitted: onSubmitted,
                                        textInputAction:
                                            TextInputAction.search,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                                fontSize:
                                                    isSmallScreen ? 13 : 14),
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
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  vertical: 0),
                                        ),
                                      ),
                                    ),
                                    if (controller.text.isNotEmpty)
                                      GestureDetector(
                                        onTap: () {
                                          controller.clear();
                                          ref
                                              .read(searchTermStateProvider
                                                  .notifier)
                                              .state = '';
                                          focusNode.requestFocus();
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8),
                                          child: Icon(
                                            Icons.close_rounded,
                                            size: 16,
                                            color: cs.onSurface
                                                .withValues(alpha: 0.5),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ── Inline category chips (Track / Album / Artist…) ──
                      // Shown/hidden by the filter icon — même comportement
                      // que les chips de filtre Watch Discovery.
                      if (showFilterChips.value && chips.isNotEmpty)
                        SizedBox(
                          height: 38,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.fromLTRB(12, 2, 12, 4),
                            children: [
                              for (final chip in chips) ...[
                                _MusicFilterChip(
                                  label: chip.capitalize(),
                                  isActive: selectedChip.value == chip,
                                  onTap: () {
                                    selectedChip.value = chip;
                                  },
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

                // ── Results ─────────────────────────────────────────────────
                Expanded(
                  child: ColoredBox(
                    color: cs.surface,
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
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

// ── Music category filter chip ────────────────────────────────────────────────
// Stylé comme FilterChipBtn (watch) : fond transparent, bordure légère,
// couleur primary quand actif.
class _MusicFilterChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _MusicFilterChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? cs.primary.withValues(alpha: 0.13)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? cs.primary
                : cs.onSurface.withValues(alpha: 0.15),
            width: isActive ? 1.2 : 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? cs.primary : cs.onSurface.withValues(alpha: 0.75),
            fontSize: 13,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
