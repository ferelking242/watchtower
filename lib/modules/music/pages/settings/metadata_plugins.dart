import 'package:collection/collection.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:watchtower/modules/music/collections/spotube_icons.dart';
import 'package:watchtower/modules/music/components/form/text_form_field.dart';
import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:watchtower/modules/music/models/metadata/metadata.dart';
import 'package:watchtower/modules/music/modules/metadata_plugins/installed_plugin.dart';
import 'package:watchtower/modules/music/modules/metadata_plugins/plugin_repository.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/core/repositories.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/metadata_plugin_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/utils/common.dart';
import 'package:watchtower/modules/music/services/logger/logger.dart';
import 'package:watchtower/modules/music/utils/platform.dart';
import 'package:very_good_infinite_list/very_good_infinite_list.dart';
import 'package:sliver_tools/sliver_tools.dart';

class SettingsMetadataProviderPage extends HookConsumerWidget {
  const SettingsMetadataProviderPage({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final tabState = useState<int>(0);
    final formKey = useMemoized(() => GlobalKey<FormBuilderState>(), []);
    final theme = Theme.of(context);

    final plugins = ref.watch(metadataPluginsProvider);
    final pluginsNotifier = ref.watch(metadataPluginsProvider.notifier);

    final pluginReposSnapshot = ref.watch(metadataPluginRepositoriesProvider);
    final pluginReposNotifier =
        ref.watch(metadataPluginRepositoriesProvider.notifier);

    final pluginRepos = useMemoized(
      () {
        final installedPluginIds = plugins.asData?.value.plugins
                .map((e) => e.repository)
                .nonNulls
                .toList() ??
            [];
        final pluginRepos = pluginReposSnapshot.asData?.value.items ?? [];
        if (installedPluginIds.isEmpty) return pluginRepos;
        final availablePlugins = pluginRepos
            .whereNot((repo) => installedPluginIds.contains(repo.repoUrl))
            .toList();
        if (tabState.value != 0) {
          return availablePlugins.where((d) {
            return d.topics.contains(
              tabState.value == 1
                  ? "spotube-metadata-plugin"
                  : "spotube-audio-source-plugin",
            );
          }).toList();
        }
        return availablePlugins;
      },
      [
        plugins.asData?.value.plugins,
        pluginReposSnapshot.asData?.value,
        tabState.value,
      ],
    );

    final installedPlugins = useMemoized<List<PluginConfiguration>?>(() {
      if (tabState.value == 0) return plugins.asData?.value.plugins;
      return plugins.asData?.value.plugins.where((d) {
        return d.abilities.contains(
          tabState.value == 1
              ? PluginAbilities.metadata
              : PluginAbilities.audioSource,
        );
      }).toList();
    }, [tabState.value, plugins.asData?.value]);

    return SafeArea(
      bottom: false,
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.plugins),
        ),
        body: Padding(
          padding: const EdgeInsets.all(8),
          child: CustomScrollView(
            slivers: [
              // URL install + file install
              SliverToBoxAdapter(
                child: Row(
                  spacing: 8,
                  children: [
                    Expanded(
                      child: FormBuilder(
                        key: formKey,
                        child: TextFormBuilderField(
                          name: "plugin_url",
                          validator: FormBuilderValidators.url(
                              protocols: ["http", "https"]),
                          placeholder:
                              Text(context.l10n.paste_plugin_download_url),
                        ),
                      ),
                    ),
                    HookBuilder(builder: (context) {
                      final isLoading = useState(false);
                      return IconButton(
                        style: IconButton.styleFrom(
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                        icon: isLoading.value
                            ? const SizedBox.square(
                                dimension: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              )
                            : const Icon(SpotubeIcons.download),
                        onPressed: isLoading.value
                            ? null
                            : () async {
                                try {
                                  if (formKey.currentState
                                          ?.saveAndValidate() ??
                                      false) {
                                    final url = formKey.currentState
                                        ?.fields["plugin_url"]
                                        ?.value as String;
                                    if (url.isNotEmpty) {
                                      isLoading.value = true;
                                      final pluginConfig =
                                          await pluginsNotifier
                                              .downloadAndCachePlugin(url);
                                      await pluginsNotifier
                                          .addPlugin(pluginConfig);
                                      formKey.currentState
                                          ?.fields["plugin_url"]
                                          ?.reset();
                                    }
                                  }
                                } catch (e, stackTrace) {
                                  AppLogger.reportError(e, stackTrace);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(SnackBar(
                                      content: Text(
                                        context.l10n
                                            .failed_to_add_plugin_error(
                                                e.toString()),
                                      ),
                                      backgroundColor:
                                          theme.colorScheme.error,
                                    ));
                                  }
                                } finally {
                                  isLoading.value = false;
                                }
                              },
                      );
                    }),
                    IconButton.filled(
                      icon: const Icon(SpotubeIcons.upload),
                      onPressed: () async {
                        Uint8List bytes;
                        if (kIsFlatpak) {
                          final result = await openFile(
                            acceptedTypeGroups: [
                              const XTypeGroup(
                                label: 'Spotube Metadata Plugin',
                                extensions: ['smplug'],
                              ),
                            ],
                          );
                          if (result == null) return;
                          bytes = await result.readAsBytes();
                        } else {
                          final result = await FilePicker.pickFiles(
                            type:
                                kIsAndroid ? FileType.any : FileType.custom,
                            allowedExtensions:
                                kIsAndroid ? [] : ["smplug"],
                            withData: true,
                          );
                          if (result == null) return;
                          final file = result.files.first;
                          if (file.bytes == null) return;
                          bytes = file.bytes!;
                        }
                        final pluginConfig = await pluginsNotifier
                            .extractPluginArchive(bytes);
                        await pluginsNotifier.addPlugin(pluginConfig);
                      },
                    ),
                  ],
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),

              // Tab filter chips
              SliverToBoxAdapter(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final (i, label)
                          in ["All", "Metadata", "Audio Source"].indexed) ...[
                        FilterChip(
                          label: Text(label),
                          selected: tabState.value == i,
                          onSelected: (_) => tabState.value = i,
                          showCheckmark: false,
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),

              // Installed heading
              if (plugins.asData?.value.plugins.isNotEmpty ?? false)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        Text(
                          context.l10n.installed,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(child: Divider()),
                      ],
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),

              SliverList.separated(
                itemCount: installedPlugins?.length ?? 0,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final plugin = installedPlugins![index];
                  final isDefaultMetadata =
                      plugins.asData!.value.defaultMetadataPluginConfig
                              ?.slug ==
                          plugin.slug;
                  final isDefaultAudioSource = plugins.asData!.value
                          .defaultAudioSourcePluginConfig?.slug ==
                      plugin.slug;
                  return MetadataInstalledPluginItem(
                    plugin: plugin,
                    isDefaultMetadata: isDefaultMetadata,
                    isDefaultAudioSource: isDefaultAudioSource,
                  );
                },
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),

              // Available plugins heading
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      Text(
                        context.l10n.available_plugins,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(child: Divider()),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),

              SliverInfiniteList(
                isLoading: pluginReposSnapshot.isLoading &&
                    !pluginReposSnapshot.isLoadingNextPage,
                itemCount: pluginRepos.length,
                onFetchData: pluginReposNotifier.fetchMore,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                loadingBuilder: (context) {
                  return Skeletonizer(enabled: true,
                    child: MetadataPluginRepositoryItem(
                      pluginRepo: MetadataPluginRepository(
                        name: "Loading...",
                        description: "Loading...",
                        repoUrl: "",
                        owner: "",
                        topics: [],
                      ),
                    ),
                  );
                },
                itemBuilder: (context, index) {
                  return MetadataPluginRepositoryItem(
                    pluginRepo: pluginRepos[index],
                  );
                },
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),

              // Disclaimer card
              SliverCrossAxisConstrained(
                maxCrossAxisExtent: 720,
                child: SliverFillRemaining(
                  hasScrollBody: false,
                  child: Container(
                    alignment: Alignment.bottomCenter,
                    margin: const EdgeInsets.only(bottom: 20),
                    child: SafeArea(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(SpotubeIcons.warning,
                                      size: 16,
                                      color: theme.colorScheme.error),
                                  const SizedBox(width: 8),
                                  Text(
                                    context.l10n.disclaimer,
                                    style: theme.textTheme.titleSmall
                                        ?.copyWith(
                                            fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                context.l10n.third_party_plugin_dmca_notice,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color:
                                      theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
