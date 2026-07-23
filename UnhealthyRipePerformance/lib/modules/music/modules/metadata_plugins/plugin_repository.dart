import 'package:flutter/gestures.dart';
  import 'package:flutter_hooks/flutter_hooks.dart';
  import 'package:hooks_riverpod/hooks_riverpod.dart';
  import 'package:flutter/material.dart';
  import 'package:watchtower/modules/music/collections/spotube_icons.dart';
  import 'package:watchtower/modules/music/components/markdown/markdown.dart';
  import 'package:watchtower/modules/music/extensions/context.dart';
  import 'package:watchtower/modules/music/models/metadata/metadata.dart';
  import 'package:watchtower/modules/music/provider/metadata_plugin/metadata_plugin_provider.dart';
  import 'package:url_launcher/url_launcher_string.dart';
  import 'package:change_case/change_case.dart';

  final validTopics = {
    "spotube-metadata-plugin": ("Meta", SpotubeIcons.album),
    "spotube-audio-source-plugin": ("Audio", SpotubeIcons.music),
  };

  Widget _badgePrimary(BuildContext context, {required Widget child}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(6),
        ),
        child: DefaultTextStyle(
          style: Theme.of(context)
              .textTheme
              .bodySmall!
              .copyWith(color: Theme.of(context).colorScheme.onPrimaryContainer),
          child: child,
        ),
      );

  Widget _badgeSecondary(
    BuildContext context, {
    required Widget child,
    Widget? leading,
    VoidCallback? onPressed,
  }) {
    Widget content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: leading != null
          ? Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 4,
              children: [
                IconTheme(
                  data: IconThemeData(
                    size: 14,
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                  child: leading,
                ),
                DefaultTextStyle(
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(
                        color:
                            Theme.of(context).colorScheme.onSecondaryContainer,
                      ),
                  child: child,
                ),
              ],
            )
          : DefaultTextStyle(
              style: Theme.of(context).textTheme.bodySmall!.copyWith(
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
              child: child,
            ),
    );
    if (onPressed != null) {
      return GestureDetector(onTap: onPressed, child: content);
    }
    return content;
  }

  class MetadataPluginRepositoryItem extends HookConsumerWidget {
    final MetadataPluginRepository pluginRepo;
    const MetadataPluginRepositoryItem({
      super.key,
      required this.pluginRepo,
    });

    @override
    Widget build(BuildContext context, ref) {
      final pluginsNotifier = ref.watch(metadataPluginsProvider.notifier);
      final host = useMemoized(
        () => Uri.parse(pluginRepo.repoUrl).host,
        [pluginRepo.repoUrl],
      );
      final isInstalling = useState(false);
      // Track just-installed plugin so we can show set-as-default button
      final installedConfig = useState<PluginConfiguration?>(null);

      final isAudioSourcePlugin =
          pluginRepo.topics.contains("spotube-audio-source-plugin");
      final isMetadataPlugin =
          pluginRepo.topics.contains("spotube-metadata-plugin");

      return Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Line 1: name + install button ────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        pluginRepo.name.startsWith("spotube-plugin")
                            ? pluginRepo.name
                                .replaceFirst("spotube-plugin-", "")
                                .trim()
                                .toCapitalCase()
                            : pluginRepo.name.toCapitalCase(),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 0),
                        minimumSize: const Size(0, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: isInstalling.value
                          ? null
                          : () async {
                              try {
                                isInstalling.value = true;
                                final pluginConfig = await pluginsNotifier
                                    .downloadAndCachePlugin(
                                        pluginRepo.repoUrl);

                                if (!context.mounted) return;
                                final isOfficialPlugin =
                                    pluginRepo.owner == "KRTirtho";

                                final isAllowed = isOfficialPlugin
                                    ? true
                                    : await showDialog<bool>(
                                        context: context,
                                        builder: (context) {
                                          final pluginAbilities = pluginConfig
                                              .apis
                                              .map((e) => context.l10n
                                                  .can_access_name_api(
                                                      e.name))
                                              .join("\n\n");
                                          return AlertDialog(
                                            title: Text(
                                              context.l10n
                                                  .do_you_want_to_install_this_plugin,
                                            ),
                                            content: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(context.l10n
                                                    .third_party_plugin_warning),
                                                const SizedBox(height: 8),
                                                FutureBuilder(
                                                  future: pluginsNotifier
                                                      .getLogoPath(pluginConfig),
                                                  builder: (context, snapshot) {
                                                    return ListTile(
                                                      leading: snapshot.hasData
                                                          ? Image.file(
                                                              snapshot.data!,
                                                              width: 36,
                                                              height: 36,
                                                            )
                                                          : Container(
                                                              height: 36,
                                                              width: 36,
                                                              alignment:
                                                                  Alignment
                                                                      .center,
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: Theme.of(
                                                                        context)
                                                                    .colorScheme
                                                                    .secondary,
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            8),
                                                              ),
                                                              child: const Icon(
                                                                  SpotubeIcons
                                                                      .plugin),
                                                            ),
                                                      title: Text(
                                                          pluginConfig.name),
                                                    );
                                                  },
                                                ),
                                                const SizedBox(height: 8),
                                                AppMarkdown(
                                                  data:
                                                      "**${context.l10n.author}**: ${pluginConfig.author}\n\n"
                                                      "**${context.l10n.repository}**: [${pluginConfig.repository ?? 'N/A'}](${pluginConfig.repository})\n\n\n\n"
                                                      "${context.l10n.this_plugin_can_do_following}:\n\n"
                                                      "$pluginAbilities",
                                                ),
                                              ],
                                            ),
                                            actions: [
                                              ElevatedButton(
                                                onPressed: () {
                                                  Navigator.of(context)
                                                      .pop(false);
                                                },
                                                child:
                                                    Text(context.l10n.decline),
                                              ),
                                              FilledButton(
                                                onPressed: () {
                                                  Navigator.of(context)
                                                      .pop(true);
                                                },
                                                child:
                                                    Text(context.l10n.accept),
                                              ),
                                            ],
                                          );
                                        },
                                      );

                                if (isAllowed != true) return;
                                await pluginsNotifier.addPlugin(pluginConfig);
                                installedConfig.value = pluginConfig;
                              } finally {
                                if (context.mounted) {
                                  isInstalling.value = false;
                                }
                              }
                            },
                      child: isInstalling.value
                          ? const SizedBox.square(
                              dimension: 16,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(context.l10n.install),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 6),

              // ── Line 2: badges + source link ─────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (pluginRepo.owner == "KRTirtho")
                      _badgePrimary(
                        context,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          spacing: 4,
                          children: [
                            const Icon(SpotubeIcons.done,
                                size: 12,
                                color: Colors.white),
                            Text(context.l10n.official),
                          ],
                        ),
                      )
                    else
                      Text(
                        context.l10n.author_name(pluginRepo.owner),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    for (final topic in pluginRepo.topics)
                      if (validTopics.containsKey(topic))
                        _badgeSecondary(
                          context,
                          leading: Icon(validTopics[topic]!.$2),
                          child: Text(validTopics[topic]!.$1),
                        ),
                    _badgeSecondary(
                      context,
                      leading: host == "github.com"
                          ? const Icon(SpotubeIcons.github)
                          : null,
                      child: Text(host),
                      onPressed: () => launchUrlString(pluginRepo.repoUrl),
                    ),
                  ],
                ),
              ),

              // ── Set-as-default button (shown after install) ───────────
              if (installedConfig.value != null) ...[
                const SizedBox(height: 8),
                const Divider(height: 0, indent: 12, endIndent: 12),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Consumer(
                    builder: (context, ref, _) {
                      final pluginsState = ref.watch(metadataPluginsProvider);
                      final notifier =
                          ref.watch(metadataPluginsProvider.notifier);
                      final cfg = installedConfig.value!;

                      final isDefaultAudio = pluginsState
                              .asData?.value.defaultAudioSourcePluginConfig
                              ?.slug ==
                          cfg.slug;
                      final isDefaultMeta = pluginsState
                              .asData?.value.defaultMetadataPluginConfig
                              ?.slug ==
                          cfg.slug;

                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (isAudioSourcePlugin)
                            FilledButton.tonal(
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 0),
                                minimumSize: const Size(0, 28),
                                tapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                textStyle:
                                    Theme.of(context).textTheme.labelSmall,
                              ),
                              onPressed: isDefaultAudio
                                  ? null
                                  : () async {
                                      await notifier
                                          .setDefaultAudioSourcePlugin(cfg);
                                    },
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                spacing: 4,
                                children: [
                                  Icon(SpotubeIcons.music,
                                      size: 14,
                                      color: isDefaultAudio
                                          ? Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.4)
                                          : null),
                                  Text(
                                    isDefaultAudio
                                        ? context.l10n.default_audio_source
                                        : context
                                            .l10n.set_default_audio_source,
                                  ),
                                ],
                              ),
                            ),
                          if (isMetadataPlugin)
                            FilledButton.tonal(
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 0),
                                minimumSize: const Size(0, 28),
                                tapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                textStyle:
                                    Theme.of(context).textTheme.labelSmall,
                              ),
                              onPressed: isDefaultMeta
                                  ? null
                                  : () async {
                                      await notifier
                                          .setDefaultMetadataPlugin(cfg);
                                    },
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                spacing: 4,
                                children: [
                                  Icon(SpotubeIcons.album,
                                      size: 14,
                                      color: isDefaultMeta
                                          ? Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.4)
                                          : null),
                                  Text(
                                    isDefaultMeta
                                        ? context.l10n.default_metadata_source
                                        : context
                                            .l10n.set_default_metadata_source,
                                  ),
                                ],
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ],

              const SizedBox(height: 4),
            ],
          ),
        ),
      );
    }
  }
