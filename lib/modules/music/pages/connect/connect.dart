import 'package:flutter/material.dart';
import 'package:auto_route/auto_route.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:watchtower/modules/music/collections/routes.gr.dart';
import 'package:watchtower/modules/music/collections/spotube_icons.dart';
import 'package:watchtower/modules/music/components/ui/button_tile.dart';
import 'package:watchtower/modules/music/modules/connect/local_devices.dart';
import 'package:watchtower/modules/music/components/titlebar/titlebar.dart';
import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:watchtower/modules/music/provider/connect/clients.dart';

class ConnectPage extends HookConsumerWidget {
  static const name = "connect";

  const ConnectPage({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final connectClients = ref.watch(connectClientsProvider);
    final connectClientsNotifier = ref.read(connectClientsProvider.notifier);
    final discoveredDevices = connectClients.asData?.value.services;

    return SafeArea(
      bottom: false,
      child: Scaffold(
        appBar: AppBar(title: Text(context.l10n.devices)),
        body: Padding(
          padding: const EdgeInsets.all(10.0),
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    context.l10n.remote,
                    style: textTheme.bodyLarge!
                        .copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 10)),
              SliverList.separated(
                itemCount: discoveredDevices?.length ?? 0,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final device = discoveredDevices![index];
                  final selected =
                      connectClients.asData?.value.resolvedService?.name ==
                          device.name;
                  return ButtonTile(
                    selected: selected,
                    leading: const Icon(SpotubeIcons.monitor),
                    title: Text(device.name),
                    subtitle: selected
                        ? Text(
                            "${connectClients.asData?.value.resolvedService?.host}"
                            ":${connectClients.asData?.value.resolvedService?.port}",
                          )
                        : null,
                    trailing: selected
                        ? IconButton(
                            icon: const Icon(SpotubeIcons.power),
                            onPressed: () =>
                                connectClientsNotifier.clearResolvedService(),
                          )
                        : null,
                    onPressed: () {
                      if (selected) {
                        context.navigateTo(const ConnectControlRoute());
                      } else {
                        connectClientsNotifier.resolveService(device);
                      }
                    },
                  );
                },
              ),
              const ConnectPageLocalDevices(),
            ],
          ),
        ),
      ),
    );
  }
}
