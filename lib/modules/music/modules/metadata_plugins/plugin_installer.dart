import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:watchtower/modules/music/collections/music_icons.dart';
import 'package:watchtower/modules/music/components/form/text_form_field.dart';
import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/metadata_plugin_provider.dart';
import 'package:watchtower/modules/music/services/logger/logger.dart';
import 'package:watchtower/modules/music/utils/platform.dart';

/// Manual music-plugin installer: paste a `.smplug` download URL or pick a
/// `.smplug` file from disk.
///
/// Lives in the Watchtower Extension Marketplace (Music tab) — the single
/// entry point for installing extensions — and is reused anywhere a manual
/// install shortcut is useful. The installed-plugins list itself stays in the
/// music module's plugin settings screen.
class MusicPluginInstaller extends HookConsumerWidget {
  const MusicPluginInstaller({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final formKey = useMemoized(() => GlobalKey<FormBuilderState>(), []);
    final isLoading = useState(false);
    final pluginsNotifier = ref.watch(metadataPluginsProvider.notifier);
    final theme = Theme.of(context);

    Future<void> installFromUrl() async {
      try {
        if (formKey.currentState?.saveAndValidate() ?? false) {
          final url = formKey.currentState?.fields["plugin_url"]?.value as String;
          if (url.isNotEmpty) {
            isLoading.value = true;
            final pluginConfig =
                await pluginsNotifier.downloadAndCachePlugin(url);
            await pluginsNotifier.addPlugin(pluginConfig);
            formKey.currentState?.fields["plugin_url"]?.reset();
          }
        }
      } catch (e, stackTrace) {
        AppLogger.reportError(e, stackTrace);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.l10n.failed_to_add_plugin_error(e.toString()),
              ),
              backgroundColor: theme.colorScheme.error,
            ),
          );
        }
      } finally {
        isLoading.value = false;
      }
    }

    Future<void> installFromFile() async {
      try {
        Uint8List bytes;
        if (kIsFlatpak) {
          final result = await openFile(
            acceptedTypeGroups: [
              XTypeGroup(
                label: context.l10n.music_plugin,
                extensions: const ['smplug'],
              ),
            ],
          );
          if (result == null) return;
          bytes = await result.readAsBytes();
        } else {
          final result = await FilePicker.pickFiles(
            type: kIsAndroid ? FileType.any : FileType.custom,
            allowedExtensions: kIsAndroid ? [] : ["smplug"],
            withData: true,
          );
          if (result == null) return;
          final file = result.files.first;
          if (file.bytes == null) return;
          bytes = file.bytes!;
        }
        final pluginConfig = await pluginsNotifier.extractPluginArchive(bytes);
        await pluginsNotifier.addPlugin(pluginConfig);
      } catch (e, stackTrace) {
        AppLogger.reportError(e, stackTrace);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.l10n.failed_to_add_plugin_error(e.toString()),
              ),
              backgroundColor: theme.colorScheme.error,
            ),
          );
        }
      }
    }

    return Row(
      spacing: 8,
      children: [
        Expanded(
          child: FormBuilder(
            key: formKey,
            child: TextFormBuilderField(
              name: "plugin_url",
              validator:
                  FormBuilderValidators.url(protocols: ["http", "https"]),
              placeholder: Text(context.l10n.paste_plugin_download_url),
            ),
          ),
        ),
        IconButton(
          style: IconButton.styleFrom(
            side: BorderSide(color: theme.colorScheme.outline),
          ),
          tooltip: context.l10n.install,
          icon: isLoading.value
              ? const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(MusicIcons.download),
          onPressed: isLoading.value ? null : installFromUrl,
        ),
        IconButton.filled(
          tooltip: context.l10n.upload_plugin_from_file,
          icon: const Icon(MusicIcons.upload),
          onPressed: installFromFile,
        ),
      ],
    );
  }
}
