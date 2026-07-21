import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:watchtower/modules/music/components/fallbacks/error_box.dart';
import 'package:watchtower/modules/music/components/horizontal_playbutton_card_view/horizontal_playbutton_card_view.dart';
import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:watchtower/modules/music/models/metadata/metadata.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/album/releases.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/core/auth.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/utils/common.dart';
import 'package:watchtower/modules/music/services/metadata/errors/exceptions.dart';

class HomeNewReleasesSection extends HookConsumerWidget {
  const HomeNewReleasesSection({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final authenticated = ref.watch(metadataPluginAuthenticatedProvider);

    final newReleases = ref.watch(metadataPluginAlbumReleasesProvider);
    final newReleasesNotifier =
        ref.read(metadataPluginAlbumReleasesProvider.notifier);

    if (authenticated.asData?.value != true ||
        newReleases.isLoading ||
        newReleases.asData?.value.items.isEmpty == true) {
      return const SizedBox.shrink();
    }

    if (newReleases.error
        case MetadataPluginException(
          errorCode: MetadataPluginErrorCode.noDefaultMetadataPlugin,
          message: _,
        )) {
      return const SizedBox.shrink();
    }

    return HorizontalPlaybuttonCardView<SpotubeSimpleAlbumObject>(
      items: newReleases.asData?.value.items ?? [],
      title: Text(context.l10n.new_releases),
      isLoadingNextPage: newReleases.isLoadingNextPage,
      hasNextPage: newReleases.asData?.value.hasMore ?? false,
      onFetchMore: newReleasesNotifier.fetchMore,
      error: newReleases.hasError
          ? Center(
              child: ErrorBox(
                error: newReleases.error!,
                onRetry: () {
                  ref.invalidate(metadataPluginAlbumReleasesProvider);
                },
              ),
            )
          : null,
    );
  }
}
