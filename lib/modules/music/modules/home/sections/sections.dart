import 'package:auto_route/auto_route.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:watchtower/modules/music/collections/routes.gr.dart';
import 'package:watchtower/modules/music/components/fallbacks/error_box.dart';
import 'package:watchtower/modules/music/components/fallbacks/no_default_metadata_plugin.dart';
import 'package:watchtower/modules/music/components/horizontal_playbutton_card_view/horizontal_playbutton_card_view.dart';
import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/browse/sections.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/utils/common.dart';
import 'package:watchtower/modules/music/services/metadata/errors/exceptions.dart';
import 'package:very_good_infinite_list/very_good_infinite_list.dart';
import 'package:flutter_undraw/flutter_undraw.dart';

class HomePageBrowseSection extends HookConsumerWidget {
  const HomePageBrowseSection({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final browseSections = ref.watch(metadataPluginBrowseSectionsProvider);
    final sections = browseSections.asData?.value.items;
    final ThemeData(:colorScheme) = Theme.of(context);

    if (browseSections.isLoading) {
      return SliverToBoxAdapter(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 16,
          children: [
            Undraw(
              height: 200,
              illustration: UndrawIllustration.process,
              color: colorScheme.primary,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 8,
              children: [
                const CircularProgressIndicator(),
                Opacity(opacity: 0.6, child: Text(context.l10n.building_your_timeline)),
              ],
            ),
            SizedBox(height: 16),
          ],
        ),
      );
    }

    if (browseSections.error
        case MetadataPluginException(
          errorCode: MetadataPluginErrorCode.noDefaultMetadataPlugin,
          message: _,
        )) {
      return const SliverFillRemaining(
        child: Center(child: NoDefaultMetadataPlugin()),
      );
    }

    if (browseSections.hasError) {
      return SliverFillRemaining(
        child: Center(
          child: ErrorBox(
            error: browseSections.error!,
            onRetry: () {
              ref.invalidate(metadataPluginBrowseSectionsProvider);
            },
          ),
        ),
      );
    }

    // Plugin is configured and the request succeeded, but there is simply
    // nothing to show (e.g. a fresh/empty catalog). Without this branch the
    // sliver renders zero items and — combined with the other home sections
    // also being empty — the whole Music Hub screen appears as a blank/black
    // page with no error ever logged. Always surface *something* instead.
    if ((sections?.isEmpty ?? true)) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 12,
              children: [
                Icon(
                  Icons.library_music_outlined,
                  size: 56,
                  color: colorScheme.onSurface.withValues(alpha: 0.3),
                ),
                Text(
                  context.l10n.nothing_found,
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                FilledButton.icon(
                  onPressed: () {
                    ref.invalidate(metadataPluginBrowseSectionsProvider);
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(context.l10n.retry),
                ),
              ],
            ),
          ),
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
          title: Text(section.title),
          hasNextPage: false,
          isLoadingNextPage: false,
          onFetchMore: () {},
          titleTrailing: section.browseMore
              ? TextButton(
                  child: Text(context.l10n.browse_all),
                  onPressed: () {
                    context.navigateTo(
                      HomeBrowseSectionItemsRoute(
                        sectionId: section.id,
                        section: section,
                      ),
                    );
                  },
                )
              : null,
        );
      },
    );
  }
}
