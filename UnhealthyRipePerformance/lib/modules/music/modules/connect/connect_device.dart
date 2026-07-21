import 'package:flutter/material.dart';
import 'package:auto_route/auto_route.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:watchtower/modules/music/collections/routes.gr.dart';
import 'package:watchtower/modules/music/collections/spotube_icons.dart';
import 'package:watchtower/modules/music/extensions/constrains.dart';
import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:watchtower/modules/music/provider/connect/clients.dart';

class ConnectDeviceButton extends HookConsumerWidget {
  final bool _sidebar;
  const ConnectDeviceButton({super.key}) : _sidebar = false;
  const ConnectDeviceButton.sidebar({super.key}) : _sidebar = true;

  @override
  Widget build(BuildContext context, ref) {
    final connectClients = ref.watch(connectClientsProvider);

    final hasServices =
        connectClients.asData?.value.services.isNotEmpty == true;

    if (_sidebar) {
      final mediaQuery = MediaQuery.sizeOf(context);

      if (mediaQuery.mdAndDown) {
        return IconButton(
          icon: const Icon(SpotubeIcons.speaker),
          onPressed: () {
            context.navigateTo(const ConnectRoute());
          },
        );
      }

      return SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: () {
            context.navigateTo(const ConnectRoute());
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "${context.l10n.devices}"
                "${hasServices ? " (${connectClients.asData?.value.services.length})" : ""}",
              ),
              const SizedBox(width: 8),
              const Icon(SpotubeIcons.speaker),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        OutlinedButton(
          onPressed: () {
            context.navigateTo(const ConnectRoute());
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (connectClients.asData?.value.resolvedService != null)
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
              Text(
                "${context.l10n.devices}"
                "${hasServices ? " (${connectClients.asData?.value.services.length})" : ""}",
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        FilledButton.tonal(
          onPressed: () {
            context.navigateTo(const ConnectRoute());
          },
          style: FilledButton.styleFrom(
            minimumSize: const Size(40, 40),
            padding: EdgeInsets.zero,
            shape: const CircleBorder(),
          ),
          child: const Icon(SpotubeIcons.speaker),
        ),
      ],
    );
  }
}
