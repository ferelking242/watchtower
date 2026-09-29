import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:watchtower/modules/music/models/metadata/metadata.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/metadata_plugin_provider.dart';
import 'package:watchtower/modules/music/services/logger/logger.dart';

final metadataPluginUpdateCheckerProvider =
    FutureProvider<PluginUpdateAvailable?>((ref) async {
  final metadataPluginConfigs = await ref.watch(metadataPluginsProvider.future);
  final metadataPlugin = await ref.watch(metadataPluginProvider.future);

  if (metadataPlugin == null ||
      metadataPluginConfigs.defaultMetadataPluginConfig == null) {
    return null;
  }

  try {
    return await metadataPlugin.core
        .checkUpdate(metadataPluginConfigs.defaultMetadataPluginConfig!);
  } catch (e, stack) {
    AppLogger.reportError(e, stack);
    return null;
  }
});

final audioSourcePluginUpdateCheckerProvider =
    FutureProvider<PluginUpdateAvailable?>((ref) async {
  final audioSourcePluginConfigs =
      await ref.watch(metadataPluginsProvider.future);
  final audioSourcePlugin = await ref.watch(audioSourcePluginProvider.future);

  if (audioSourcePlugin == null ||
      audioSourcePluginConfigs.defaultAudioSourcePluginConfig == null) {
    return null;
  }

  try {
    return await audioSourcePlugin.core
        .checkUpdate(audioSourcePluginConfigs.defaultAudioSourcePluginConfig!);
  } catch (e, stack) {
    AppLogger.reportError(e, stack);
    return null;
  }
});
