import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:watchtower/modules/music/provider/connect/clients.dart';

class SelectDeviceDialog extends HookConsumerWidget {
  const SelectDeviceDialog({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final isRemoteService = useState(false);

    final connectClients = ref.watch(connectClientsProvider);
    final remoteService = connectClients.asData!.value.resolvedService!;

    return AlertDialog(
      title: Text(context.l10n.choose_the_device),
      content: RadioGroup(
        value: isRemoteService.value,
        onChanged: (value) {
          isRemoteService.value = value;
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.multiple_device_connected),
            SizedBox(height: 16),
            RadioItem(
              trailing: Text(remoteService.name),
              value: true,
            ),
            SizedBox(height: 8),
            RadioItem(
              trailing: Text(context.l10n.this_device),
              value: false,
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop(isRemoteService.value);
          },
          child: Text(context.l10n.select),
        ),
      ],
    );
  }
}

Future<bool?> showSelectDeviceDialog(
    BuildContext context, WidgetRef ref) async {
  final connectClients = ref.read(connectClientsProvider);

  if (connectClients.asData?.value.resolvedService == null) {
    return false;
  }

  final isRemote = await showDialog<bool>(
    context: context,
    builder: (context) => const SelectDeviceDialog(),
  );

  return isRemote;
}
