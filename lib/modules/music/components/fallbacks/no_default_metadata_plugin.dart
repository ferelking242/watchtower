import 'dart:developer' as dev;

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter_undraw/flutter_undraw.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:watchtower/modules/music/models/metadata/metadata.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/metadata_plugin_provider.dart';
import 'package:watchtower/modules/music/utils/open_marketplace.dart';

class NoDefaultMetadataPlugin extends ConsumerWidget {
  const NoDefaultMetadataPlugin({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pluginsState = ref.watch(metadataPluginsProvider);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          spacing: 10,
          children: [
            Undraw(
              height: 200,
              illustration: UndrawIllustration.dreamer,
              color: Theme.of(context).colorScheme.primary,
            ),
            AutoSizeText(
              context.l10n.no_default_metadata_provider_selected,
              style: Theme.of(context).textTheme.titleLarge!,
              maxLines: 1,
              textAlign: TextAlign.center,
            ),
            // Diagnostic info
            pluginsState.whenOrNull(
              data: (state) {
                final metaPlugins = state.plugins
                    .where((p) => p.abilities.contains(PluginAbilities.metadata))
                    .toList();
                dev.log(
                  '[NoDefaultMetadataPlugin] plugins=${state.plugins.length} '
                  'metadataPlugins=${metaPlugins.length} '
                  'defaultIdx=${state.defaultMetadataPlugin}',
                  name: 'Watchtower.Music',
                );
                if (metaPlugins.isNotEmpty) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 8,
                    children: [
                      // Force auto-detect button
                      OutlinedButton.icon(
                        icon: const Icon(Icons.bug_report_outlined),
                        label: const Text('Force auto-detect metadata plugin'),
                        onPressed: () async {
                          final notifier = ref.read(metadataPluginsProvider.notifier);
                          final first = metaPlugins.first;
                          try {
                            await notifier.setDefaultMetadataPlugin(first);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Set default: ${first.name}'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                            dev.log(
                              '[NoDefaultMetadataPlugin] Force-set default to: '
                              '${first.name} by ${first.author}',
                              name: 'Watchtower.Music',
                            );
                          } catch (e, st) {
                            dev.log(
                              '[NoDefaultMetadataPlugin] FAILED to set default: $e',
                              name: 'Watchtower.Music',
                              error: e,
                              stackTrace: st,
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                          // Force rebuild of metadataPluginProvider
                          ref.invalidate(metadataPluginProvider);
                        },
                      ),
                      // Invalidate + refresh
                      OutlinedButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: const Text('Refresh plugin state'),
                        onPressed: () {
                          ref.invalidate(metadataPluginsProvider);
                          ref.invalidate(metadataPluginProvider);
                          dev.log(
                            '[NoDefaultMetadataPlugin] Invalidated all metadata '
                            'providers — rebuilding from DB',
                            name: 'Watchtower.Music',
                          );
                        },
                      ),
                    ],
                  );
                }
                return const SizedBox.shrink();
              },
              orElse: () => const SizedBox.shrink(),
            ),
            FilledButton(
              child: Text(context.l10n.manage_metadata_providers),
              onPressed: () => openMarketplace(context),
            ),
          ],
        ),
      ),
    );
  }
}
