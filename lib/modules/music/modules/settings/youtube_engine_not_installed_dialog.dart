import 'dart:io';

import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:watchtower/modules/music/collections/spotube_icons.dart';
import 'package:watchtower/modules/music/components/form/text_form_field.dart';
import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:watchtower/modules/music/models/database/database.dart';
import 'package:watchtower/modules/music/services/kv_store/kv_store.dart';
import 'package:watchtower/modules/music/utils/platform.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yt_dlp_dart/yt_dlp_dart.dart';

const engineDownloadUrls = {
  YoutubeClientEngine.ytDlp:
      "https://github.com/yt-dlp/yt-dlp?tab=readme-ov-file#installation",
};

class YouTubeEngineNotInstalledDialog extends HookConsumerWidget {
  final YoutubeClientEngine engine;
  const YouTubeEngineNotInstalledDialog({
    super.key,
    required this.engine,
  });

  @override
  Widget build(BuildContext context, ref) {
    final controller = useTextEditingController();
    final formKey = useMemoized(() => GlobalKey<FormBuilderState>(), []);

    return AlertDialog(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(SpotubeIcons.error, color: Colors.red),
          const SizedBox(width: 8),
          Text(
            context.l10n.youtube_engine_not_installed_title(engine.label),
            style: const TextStyle(color: Colors.red),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.youtube_engine_not_installed_message(engine.label),
            ),
            if (engineDownloadUrls[engine] != null) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("${context.l10n.download}:"),
                  TextButton(
                    onPressed: () async {
                      launchUrl(Uri.parse(engineDownloadUrls[engine]!));
                    },
                    child: Text(
                      engineDownloadUrls[engine]!.split("?").first,
                      style: const TextStyle(color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Text(context.l10n.youtube_engine_set_path(engine.label)),
            const SizedBox(height: 8),
            FormBuilder(
              key: formKey,
              child: TextFormBuilderField(
                name: "path",
                controller: controller,
                placeholder: Text(switch (Theme.of(context).platform) {
                  TargetPlatform.macOS => "e.g. /opt/homebrew/bin/yt-dlp",
                  TargetPlatform.windows =>
                    r"e.g. C:\Program Files\yt-dlp\yt-dlp.exe",
                  _ => "e.g. /home/user/.local/bin/yt-dlp",
                }),
              ),
            ),
            if (kIsMacOS || kIsLinux) ...[
              const SizedBox(height: 8),
              Text(context.l10n.youtube_engine_unix_issue_message),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            if (!context.mounted) return;
            Navigator.of(context).pop(false);
          },
          child: Text(context.l10n.cancel),
        ),
        ElevatedButton(
          onPressed: () async {
            if (controller.text.isNotEmpty) {
              if (!await File(controller.text).exists() && context.mounted) {
                formKey.currentState?.fields["path"]
                    ?.invalidate(context.l10n.file_not_found);
                return;
              }
              await KVStoreService.setYoutubeEnginePath(
                engine,
                controller.text,
              );
              if (engine == YoutubeClientEngine.ytDlp) {
                await YtDlp.instance.setBinaryLocation(controller.text);
              }
            }
            if (!context.mounted) return;
            Navigator.of(context).pop(true);
          },
          child: Text(context.l10n.save),
        ),
      ],
    );
  }
}
