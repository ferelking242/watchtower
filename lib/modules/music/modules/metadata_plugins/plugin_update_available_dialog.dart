import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:watchtower/modules/music/collections/spotube_icons.dart';
import 'package:watchtower/modules/music/components/markdown/markdown.dart';
import 'package:watchtower/modules/music/models/metadata/metadata.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/metadata_plugin_provider.dart';

class MetadataPluginUpdateAvailableDialog extends HookConsumerWidget {
  final PluginConfiguration plugin;
  final PluginUpdateAvailable update;
  const MetadataPluginUpdateAvailableDialog({
    super.key,
    required this.plugin,
    required this.update,
  });

  @override
  Widget build(BuildContext context, ref) {
    final isUpdating = useState(false);

    void showErrorSnackbar(BuildContext ctx, String message) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(message)),
              IconButton(
                iconSize: 20.0,
                icon: const Icon(SpotubeIcons.close),
                onPressed: () {
                  ScaffoldMessenger.of(ctx).hideCurrentSnackBar();
                },
              ),
            ],
          ),
        ),
      );
    }

    return AlertDialog(
      title: const Text('Plugin update available'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${plugin.name} (${update.version}) available.'),
          if (update.changelog != null && update.changelog!.isNotEmpty)
            const SizedBox(height: 8),
          if (update.changelog != null && update.changelog!.isNotEmpty)
            AppMarkdown(
              data: '### Changelog: \n\n${update.changelog}',
            ),
        ],
      ),
      actions: [
        OutlinedButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Dismiss'),
        ),
        FilledButton(
          onPressed: isUpdating.value
              ? null
              : () async {
                  isUpdating.value = true;
                  try {
                    await ref
                        .read(metadataPluginsProvider.notifier)
                        .updatePlugin(plugin, update);
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  } catch (e) {
                    if (context.mounted) {
                      showErrorSnackbar(context, e.toString());
                    }
                  } finally {
                    if (context.mounted) {
                      isUpdating.value = false;
                    }
                  }
                },
          child: const Text('Update'),
        ),
      ],
    );
  }
}
