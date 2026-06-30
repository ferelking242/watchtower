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

          return Column(
            children: [
              // Search bar with autocomplete
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Autocomplete<String>(
                  optionsBuilder: (textEditingValue) {
                    final text = textEditingValue.text;
                    final recent = KVStoreService.recentSearches;
                    final base = text.isEmpty
                        ? [
                            ...recent.take(3),
                            if (recent.length < 3) ...[
                              "Twenty One Pilots",
                              "Linkin Park",
                            ],
                          ]
                        : recent
                            .where((s) =>
                                weightedRatio(
                                    s.toLowerCase(), text.toLowerCase()) >
                                50)
                            .take(5)
                            .toList();
                    return base;
                  },
                  onSelected: onSubmitted,
                  fieldViewBuilder: (
                    context,
                    fieldController,
                    fieldFocusNode,
                    onFieldSubmitted,
                  ) {
                    return TextField(
                      controller: fieldController,
                      focusNode: fieldFocusNode,
                      textInputAction: TextInputAction.search,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: context.l10n.search,
                        prefixIcon: const Icon(SpotubeIcons.search),
                        suffixIcon: ValueListenableBuilder<TextEditingValue>(
                          valueListenable: fieldController,
                          builder: (context, value, _) =>
                              value.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(SpotubeIcons.close),
                                      onPressed: () {
                                        fieldController.clear();
                                        controller.clear();
                                        ref
                                            .read(searchTermStateProvider
                                                .notifier)
                                            .state = '';
                                      },
                                    )
                                  : const SizedBox.shrink(),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(28),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 20),
                      ),
                      onSubmitted: (value) {
                        onSubmitted(value);
                        onFieldSubmitted();
                      },
                    );
                  },
                  optionsViewBuilder: (context, onSelected, options) {
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(12),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                              maxHeight: 220, maxWidth: 400),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: options.length,
                            itemBuilder: (context, index) {
                              final option = options.elementAt(index);
                              return ListTile(
                                title: Text(option),
                                onTap: () => onSelected(option),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Filter chips
              if (searchChipSnapshot.asData?.value != null)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      const SizedBox(width: 4),
                      for (final chip in searchChipSnapshot.asData!.value) ...[
                        FilterChip(
                          label: Text(chip.capitalize()),
                          selected: selectedChip.value == chip,
                          onSelected: (_) {
                            selectedChip.value = chip;
                          },
                          showCheckmark: false,
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: 4),

              // Results
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
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
