import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:very_good_infinite_list/very_good_infinite_list.dart';
import 'package:watchtower/modules/media/app_ui_components.dart';
import 'package:watchtower/modules/music/collections/routes.gr.dart';
import 'package:watchtower/modules/music/components/fallbacks/error_box.dart';
import 'package:watchtower/modules/music/components/fallbacks/no_default_metadata_plugin.dart';
import 'package:watchtower/modules/music/components/horizontal_playbutton_card_view/horizontal_playbutton_card_view.dart';
import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/browse/sections.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/utils/common.dart';
import 'package:watchtower/modules/music/services/metadata/errors/exceptions.dart';

class HomePageBrowseSection extends HookConsumerWidget {
  const HomePageBrowseSection({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final browseSections = ref.watch(metadataPluginBrowseSectionsProvider);
    final sections = browseSections.asData?.value.items;

    if (browseSections.isLoading) {
      return const SliverToBoxAdapter(child: AppMediaRowShimmer());
    }

    if (browseSections.error
        case MetadataPluginException(
          errorCode: MetadataPluginErrorCode.noDefaultMetadataPlugin,
          message: _,
        )) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: NoDefaultMetadataPlugin(),
      );
    }

    if (browseSections.hasError) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: ErrorBox(
            error: browseSections.error!,
            onRetry: () =>
                ref.invalidate(metadataPluginBrowseSectionsProvider),
          ),
        ),
      );
    }

    // Plugin configured and the request succeeded, but the catalogue is
    // empty. Render an explicit empty state instead of a silent black page.
    if (sections?.isEmpty ?? true) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: AppEmptyState(
          icon: Broken.music_library_2,
          title: context.l10n.music,
          message: context.l10n.nothing_found,
          actionLabel: context.l10n.retry,
          onAction: () =>
              ref.invalidate(metadataPluginBrowseSectionsProvider),
        ),
      );
    }

    return SliverInfiniteList(
      hasReachedMax: browseSections.asData?.value.hasMore == false,
      isLoading: !browseSections.isLoading && browseSections.isLoadingNextPage,
      onFetchData: () {
        ref.read(metadataPluginBrowseSectionsProvider.notifier).fetchMore();
      },
      itemCount: sections?.length ?? 0,
      itemBuilder: (context, index) {
        final section = sections![index];
        if (section.items.isEmpty) return const SizedBox.shrink();

        return HorizontalPlaybuttonCardView(
          items: section.items,
          title: section.title,
          hasNextPage: false,
          isLoadingNextPage: false,
          onFetchMore: () {},
          actionLabel: section.browseMore ? context.l10n.browse_all : null,
          onAction: section.browseMore
              ? () {
                  context.navigateTo(
                    HomeBrowseSectionItemsRoute(
                      sectionId: section.id,
                      section: section,
                    ),
                  );
                }
              : null,
        );
      },
    );
  }
}
