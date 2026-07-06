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

      class SidebarFooter extends HookConsumerWidget {
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
        final isAuthenticated = authenticated.asData?.value == true;

        if (mediaQuery.mdAndDown) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Badge(
                isLabelVisible: downloadCount > 0,
                label: Text(downloadCount.toString()),
                child: IconButton(
                  icon: const Icon(SpotubeIcons.download),
                  onPressed: () => context.navigateTo(const UserDownloadsRoute()),
                ),
              ),
              const ConnectDeviceButton.sidebar(),
              // Login icon — visible only when no plugin account is connected
              if (!isAuthenticated)
                IconButton(
                  icon: const Icon(SpotubeIcons.login),
                  tooltip: 'Se connecter',
                  onPressed: () =>
                      context.navigateTo(const SettingsMetadataProviderRoute()),
                ),
              // Music Hub settings (playback, comptes, etc.)
              IconButton(
                icon: const Icon(SpotubeIcons.settings),
                tooltip: 'Paramètres Music Hub',
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
            children: [
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: Stack(
                  alignment: Alignment.centerRight,
                  children: [
                    TextButton(
                      onPressed: () {
                        context.navigateTo(const UserDownloadsRoute());
                      },
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(context.l10n.downloads),
                      ),
                    ),
                    if (downloadCount > 0)
                      Positioned(
                        right: 8,
                        child: Badge(
                          label: Text(downloadCount.toString()),
                        ),
                      ),
                  ],
                ),
              ),
              const ConnectDeviceButton.sidebar(),
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (isAuthenticated && data == null)
                    const CircularProgressIndicator()
                  else if (data != null)
                    Flexible(
                      child: GestureDetector(
                        onTap: () {
                          context.navigateTo(const ProfileRoute());
                        },
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              foregroundImage:
                                  UniversalImage.imageProvider(avatarImg),
                              child: Text(
                                data.name.isNotEmpty ? data.name[0] : '?',
                              ),
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                data.name,
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.fade,
                                style: theme.textTheme.bodyMedium!
                                    .copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    // No plugin connected — show login icon
                    IconButton(
                      icon: const Icon(SpotubeIcons.login),
                      tooltip: 'Se connecter',
                      onPressed: () {
                        context.navigateTo(const SettingsMetadataProviderRoute());
                      },
                    ),
                  // Music Hub internal settings (playback, comptes, apparence…)
                  IconButton(
                    icon: const Icon(SpotubeIcons.settings),
                    tooltip: 'Paramètres Music Hub',
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
    