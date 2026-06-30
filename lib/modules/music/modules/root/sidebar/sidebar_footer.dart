import 'package:auto_route/auto_route.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter/material.dart';

import 'package:watchtower/modules/music/collections/routes.gr.dart';
import 'package:watchtower/modules/music/collections/spotube_icons.dart';
import 'package:watchtower/modules/music/components/image/universal_image.dart';
import 'package:watchtower/modules/music/extensions/constrains.dart';
import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:watchtower/modules/music/models/metadata/metadata.dart';
import 'package:watchtower/modules/music/modules/connect/connect_device.dart';
import 'package:watchtower/modules/music/provider/download_manager_provider.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/core/auth.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/core/user.dart';

class SidebarFooter extends HookConsumerWidget implements NavigationBarItem {
  const SidebarFooter({
    super.key,
  });

  @override
  Widget build(BuildContext context, ref) {
    final theme = Theme.of(context);
    final router = AutoRouter.of(context, watch: true);
    final mediaQuery = MediaQuery.of(context);
    final downloadCount = ref
        .watch(downloadManagerProvider)
        .where((e) =>
            e.status == DownloadStatus.downloading ||
            e.status == DownloadStatus.queued)
        .length;
    final userSnapshot = ref.watch(metadataPluginUserProvider);
    final data = userSnapshot.asData?.value;

    final avatarImg = (data?.images).asUrlString(
      index: (data?.images.length ?? 1) - 1,
      placeholder: ImagePlaceholder.artist,
    );

    final authenticated = ref.watch(metadataPluginAuthenticatedProvider);

    if (mediaQuery.mdAndDown) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 10,
        children: [
          Badge(
            isLabelVisible: downloadCount > 0,
            label: Text(downloadCount.toString()),
            child: IconButton(.topRoute.name == UserDownloadsRoute.name
                  ? null : null,
              icon: const Icon(SpotubeIcons.download),
              onPressed: () => context.navigateTo(const UserDownloadsRoute()),
            ),
          ),
          const ConnectDeviceButton.sidebar(),
          IconButton(
            icon: const Icon(SpotubeIcons.settings),
            onPressed: () => context.navigateTo(const SettingsRoute()),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.only(left: 12),
      width: 180,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 10,
        children: [
          SizedBox(
            width: double.infinity,
            child: TextButton(
              style: router.topRoute.name == UserDownloadsRoute.name
                  ? null : null,
              onPressed: () {
                context.navigateTo(const UserDownloadsRoute());
              },
              trailing: downloadCount > 0
                  ? PrimaryBadge(
                      child: Text(downloadCount.toString()),
                    )
                  : null,
              child: Text(context.l10n.downloads),
            ),
          ),
          const ConnectDeviceButton.sidebar(),
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (authenticated.asData?.value == true && data == null)
                const CircularProgressIndicator()
              else if (data != null)
                Flexible(
                  child: GestureDetector(
                    onTap: () {
                      context.navigateTo(const ProfileRoute());
                    },
                    child: Row(
                      children: [
                        Avatar(
                          initials: Avatar.getInitials(data.name),
                          provider: UniversalImage.imageProvider(avatarImg),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            data.name,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.fade,
                            style: Theme.of(context).textTheme.bodyMedium!
                                .copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              IconButton(
                icon: const Icon(SpotubeIcons.settings),
                onPressed: () {
                  context.navigateTo(const SettingsRoute());
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  bool get selectable => false;
}
