import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:watchtower/modules/music/collections/spotube_icons.dart';
import 'package:watchtower/modules/music/components/markdown/markdown.dart';
import 'package:watchtower/modules/music/extensions/constrains.dart';
import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:watchtower/modules/music/models/metadata/metadata.dart';
import 'package:watchtower/modules/music/modules/metadata_plugins/plugin_update_available_dialog.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/core/auth.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/core/support.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/metadata_plugin_provider.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/updater/update_checker.dart';
import 'package:url_launcher/url_launcher.dart';

final validAbilities = {
  PluginAbilities.metadata: ("Metadata", SpotubeIcons.album),
  PluginAbilities.audioSource: ("Audio Source", SpotubeIcons.music),
};

// Wraps [child] with the captured shadcn ThemeData so dialogs opened via
// showDialog() inherit the correct colour scheme even though they run in a
// separate overlay entry (no ShadcnApp ancestor available there).
Widget _withTheme(ThemeData data, Widget child) =>
    Theme(data: data, child: child);

class MetadataInstalledPluginItem extends HookConsumerWidget {
  final PluginConfiguration plugin;
  final bool isDefaultMetadata;
  final bool isDefaultAudioSource;
  const MetadataInstalledPluginItem({
    super.key,
    required this.plugin,
    required this.isDefaultMetadata,
    required this.isDefaultAudioSource,
  });

  @override
  Widget build(BuildContext context, ref) {
    final mediaQuery = MediaQuery.sizeOf(context);

    final metadataPlugin = ref.watch(metadataPluginProvider);
    final audioSourcePlugin = ref.watch(audioSourcePluginProvider);
    final pluginSnapshot = switch ((isDefaultMetadata, isDefaultAudioSource)) {
      (true, _) => metadataPlugin,
      (false, true) => audioSourcePlugin,
      _ => null,
    };

    final pluginsNotifier = ref.watch(metadataPluginsProvider.notifier);

    final requiresAuth = (isDefaultMetadata || isDefaultAudioSource) &&
        plugin.abilities.contains(PluginAbilities.authentication);
    final supportsScrobbling = isDefaultMetadata &&
        plugin.abilities.contains(PluginAbilities.scrobbling);

    final isMetadataAuthenticatedSnapshot =
        ref.watch(metadataPluginAuthenticatedProvider);
    final isAudioSourceAuthenticatedSnapshot =
        ref.watch(audioSourcePluginAuthenticatedProvider);
    final isAuthenticated = (isDefaultMetadata &&
            isMetadataAuthenticatedSnapshot.asData?.value == true) ||
        (isDefaultAudioSource &&
            isAudioSourceAuthenticatedSnapshot.asData?.value == true);

    final metadataUpdateAvailable =
        ref.watch(metadataPluginUpdateCheckerProvider);
    final audioSourceUpdateAvailable =
        ref.watch(audioSourcePluginUpdateCheckerProvider);
    final updateAvailable = switch ((isDefaultMetadata, isDefaultAudioSource)) {
      (true, _) => metadataUpdateAvailable,
      (false, true) => audioSourceUpdateAvailable,
      _ => null,
    };
    final hasUpdate = updateAvailable?.asData?.value != null;

    // Capture theme once so dialog builders can use it.
    final themeData = Theme.of(context);

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        spacing: 12,
        children: [
          FutureBuilder(
            future: pluginsNotifier.getLogoPath(plugin),
            builder: (context, snapshot) {
              final repoUrl = plugin.repository != null
                  ? Uri.tryParse(plugin.repository!)
                  : null;
              final repoOwner = repoUrl?.pathSegments.firstOrNull;

              final isOfficial =
                  repoUrl?.host == "github.com" && repoOwner == "KRTirtho";

              return ListTile(
                leading: snapshot.hasData
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          snapshot.data!,
                          width: 36,
                          height: 36,
                        ),
                      )
                    : Container(
                        height: 36,
                        width: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.secondary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(SpotubeIcons.plugin),
                      ),
                title: Text(plugin.name),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 8,
                  children: [
                    Text(plugin.description),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final ability in plugin.abilities)
                          if (validAbilities.keys.contains(ability))
                            SecondaryBadge(
                              child: Text(validAbilities[ability]!.$1),
                            ),
                      ],
                    ),
                    if (repoUrl != null)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (isOfficial)
                            PrimaryBadge(
                              child: Text(context.l10n.official),
                            )
                          else ...[
                            Text(context.l10n.author_name(plugin.author)),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                spacing: 4,
                                children: [
                                  const Icon(SpotubeIcons.warning, size: 14),
                                  Text(
                                    context.l10n.third_party,
                                    style: const TextStyle(color: Colors.white),
                                  ).xSmall
                                ],
                              ),
                            ),
                          ],
                          SecondaryBadge(
                            child: Text(repoUrl.host),
                            onPressed: () {
                              launchUrl(repoUrl);
                            },
                          ),
                          SecondaryBadge(
                            child: Padding(
                              padding: const EdgeInsets.all(1),
                              child: Text(
                                "${context.l10n.version}: ${plugin.version}",
                              ),
                            ),
                          ),
                        ],
                      )
                  ],
                ),
                trailing: IconButton(
                  onPressed: () async {
                    await pluginsNotifier.removePlugin(plugin);
                  },
                  icon: const Icon(
                    SpotubeIcons.trash,
                    color: Colors.red,
                  ),
                ),
              );
            },
          ),
          if ((requiresAuth && !isAuthenticated) ||
              hasUpdate ||
              supportsScrobbling)
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondary,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                spacing: 12,
                children: [
                  if (requiresAuth && !isAuthenticated)
                    Row(
                      spacing: 8,
                      children: [
                        const Icon(SpotubeIcons.warning, color: Colors.yellow),
                        Text(context.l10n.plugin_requires_authentication),
                      ],
                    ),
                  if (hasUpdate)
                    SizedBox(
                      width: double.infinity,
                      child: ListTile(
                        title: Text(context.l10n.update_available),
                          updateAvailable!.asData!.value!.version,
                        ),
                        trailing: FilledButton(
                          onPressed: () {
                            // ponytail: wrap with _withTheme so the dialog
                            // inherits the shadcn colour scheme through the
                            // overlay (no ShadcnApp ancestor in dialog route).
                            showDialog(
                              context: context,
                              builder: (ctx) => _withTheme(
                                themeData,
                                MetadataPluginUpdateAvailableDialog(
                                  plugin: plugin,
                                  update: updateAvailable.asData!.value!,
                                ),
                              ),
                            );
                          },
                          child: Text(context.l10n.update),
                        ),
                      ),
                    ),
                  if (supportsScrobbling)
                    SizedBox(
                      width: double.infinity,
                      child: ListTile(
                        title: Text(context.l10n.supports_scrobbling),
                      ),
                    )
                ],
              ),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (plugin.abilities.contains(PluginAbilities.metadata))
                    ElevatedButton(
                      enabled: !isDefaultMetadata,
                      onPressed: () async {
                        await pluginsNotifier.setDefaultMetadataPlugin(plugin);
                      },
                      child: Text(
                        isDefaultMetadata
                            ? context.l10n.default_metadata_source
                            : context.l10n.set_default_metadata_source,
                      ),
                    ),
                  if (plugin.abilities.contains(PluginAbilities.audioSource))
                    ElevatedButton(
                      enabled: !isDefaultAudioSource,
                      onPressed: () async {
                        await pluginsNotifier
                            .setDefaultAudioSourcePlugin(plugin);
                      },
                      child: Text(
                        isDefaultAudioSource
                            ? context.l10n.default_audio_source
                            : context.l10n.set_default_audio_source,
                      ),
                    ),
                ],
              ),
              Row(
                mainAxisSize:
                    mediaQuery.smAndUp ? MainAxisSize.min : MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.end,
                spacing: 8,
                children: [
                  if (isDefaultMetadata || isDefaultAudioSource)
                    Consumer(builder: (context, ref, _) {
                      final metadataSupportTextSnapshot =
                          ref.watch(metadataPluginSupportTextProvider);
                      final audioSourceSupportTextSnapshot =
                          ref.watch(audioSourcePluginSupportTextProvider);

                      final supportTextSnapshot =
                          switch ((isDefaultMetadata, isDefaultAudioSource)) {
                        (true, _) => metadataSupportTextSnapshot,
                        (false, true) => audioSourceSupportTextSnapshot,
                        _ => null,
                      };

                      if ((supportTextSnapshot?.hasValue ?? false) &&
                          supportTextSnapshot?.value == null) {
                        return const SizedBox.shrink();
                      }

                      final bgColor =
                          Theme.of(context).brightness == Brightness.dark
                              ? const Color.fromARGB(255, 255, 145, 175)
                              : Colors.pink[600];
                      final textColor =
                          Theme.of(context).brightness == Brightness.dark
                              ? Colors.pink[700]
                              : Colors.pink[50];

                      final mediaQuery = MediaQuery.sizeOf(context);

                      return TextButton(
.copyWith(
                          decoration: (context, states, value) {
                            return value.copyWithIfBoxDecoration(
                              color: bgColor,
                            );
                          },
                          textStyle: (context, states, value) {
                            return value.copyWith(
                              color: textColor,
                            );
                          },
                          iconTheme: (context, states, value) {
                            return value.copyWith(
                              color: textColor,
                            );
                          },
                        ),
                        child: Text(context.l10n.support),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => _withTheme(
                              themeData,
                              AlertDialog(
                                title: Text(
                                    context.l10n.support_plugin_development),
                                content: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxHeight: mediaQuery.height * 0.8,
                                    maxWidth: 720,
                                  ),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: SingleChildScrollView(
                                      child: AppMarkdown(
                                        data: supportTextSnapshot
                                                ?.asData?.value ??
                                            "",
                                      ),
                                    ),
                                  ),
                                ),
                                actions: [
                                  ElevatedButton(
                                    onPressed: () {
                                      Navigator.of(ctx).pop();
                                    },
                                    child: Text(context.l10n.close),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    }),
                  // Login button: guard against still-loading plugin snapshot.
                  // ponytail: pluginSnapshot?.asData?.value is null while the
                  // async provider is loading — show disabled state instead of
                  // silently doing nothing.
                  if ((isDefaultMetadata || isDefaultAudioSource) &&
                      requiresAuth &&
                      !isAuthenticated)
                    FilledButton(
                      enabled: pluginSnapshot?.asData?.value != null,
                      onPressed: () async {
                        final plugin = pluginSnapshot?.asData?.value;
                        if (plugin == null) return;
                        await plugin.auth.authenticate();
                      },
                      leading: pluginSnapshot?.isLoading == true
                          ? const CircularProgressIndicator()
                          : const Icon(SpotubeIcons.login),
                      child: Text(context.l10n.login),
                    )
                  else if ((isDefaultMetadata || isDefaultAudioSource) &&
                      requiresAuth &&
                      isAuthenticated)
                    ElevatedButton(
                      onPressed: () async {
                        await pluginSnapshot?.asData?.value?.auth.logout();
                      },
                      child: Text(context.l10n.logout),
                    ),
                ],
              )
            ],
          )
        ],
      ),
    );
  }
}
