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
    "spotube-metadata-plugin": ("Metadata", SpotubeIcons.album),
    "spotube-audio-source-plugin": ("Audio Source", SpotubeIcons.music),
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

      return Card(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 8,
          children: [
            ListTile(
              title: Text(
                pluginRepo.name.startsWith("spotube-plugin")
                    ? pluginRepo.name
                        .replaceFirst("spotube-plugin-", "")
                        .trim()
                        .toCapitalCase()
                    : pluginRepo.name.toCapitalCase(),
              ),
              trailing: FilledButton(
                onPressed: isInstalling.value
                    ? null
                    : () async {
                        try {
                          isInstalling.value = true;
                          final pluginConfig = await pluginsNotifier
                              .downloadAndCachePlugin(pluginRepo.repoUrl);

                          if (!context.mounted) return;
                          final isOfficialPlugin = pluginRepo.owner == "KRTirtho";

                          final isAllowed = isOfficialPlugin
                              ? true
                              : await showDialog<bool>(
                                  context: context,
                                  builder: (context) {
                                    final pluginAbilities = pluginConfig.apis
                                        .map((e) => context.l10n
                                            .can_access_name_api(e.name))
                                        .join("\n\n");

                                    return AlertDialog(
                                      title: Text(
                                        context.l10n
                                            .do_you_want_to_install_this_plugin,
                                      ),
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment:
                                            MainAxisAlignment.start,
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
                                                            Alignment.center,
                                                        decoration: BoxDecoration(
                                                          color: Theme.of(context)
                                                              .colorScheme
                                                              .secondary,
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(8),
                                                        ),
                                                        child: const Icon(
                                                            SpotubeIcons.plugin),
                                                      ),
                                                title: Text(pluginConfig.name),
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
                                            Navigator.of(context).pop(false);
                                          },
                                          child: Text(context.l10n.decline),
                                        ),
                                        FilledButton(
                                          onPressed: () {
                                            Navigator.of(context).pop(true);
                                          },
                                          child: Text(context.l10n.accept),
                                        ),
                                      ],
                                    );
                                  },
                                );

                          if (isAllowed != true) return;
                          await pluginsNotifier.addPlugin(pluginConfig);
                        } finally {
                          if (context.mounted) {
                            isInstalling.value = false;
                          }
                        }
                      },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 8,
                  children: [
                    if (isInstalling.value)
                      SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      )
                    else
                      const Icon(SpotubeIcons.add, size: 18),
                    Text(context.l10n.install),
                  ],
                ),
              ),
            ),
            if (pluginRepo.owner != "KRTirtho")
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: context.l10n.source),
                    TextSpan(
                      text: pluginRepo.repoUrl.replaceAll("https://", ""),
                      style: const TextStyle(
                        color: Colors.blue,
                        decoration: TextDecoration.underline,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () async {
                          launchUrlString(pluginRepo.repoUrl);
                        },
                    ),
                  ],
                ),
                style: Theme.of(context).textTheme.labelSmall!,
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (pluginRepo.owner == "KRTirtho")
                  _badgePrimary(context, child: Text(context.l10n.official))
                else ...[
                  Text(
                    context.l10n.author_name(pluginRepo.owner),
                    style: Theme.of(context).textTheme.labelSmall!,
                  ),
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
                        const Icon(SpotubeIcons.warning, size: 14,
                            color: Colors.white),
                        Text(
                          context.l10n.third_party,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall!
                              .copyWith(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
                for (final topic in pluginRepo.topics)
                  if (validTopics.keys.contains(topic))
                    _badgeSecondary(
                      context,
                      child: Text(validTopics[topic]!.$1),
                    ),
                _badgeSecondary(
                  context,
                  leading: host == "github.com"
                      ? const Icon(SpotubeIcons.github)
                      : null,
                  child: Text(host),
                  onPressed: () {
                    launchUrlString(pluginRepo.repoUrl);
                  },
                ),
              ],
            ),
          ],
        ),
      );
    }
  }
  