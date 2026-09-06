import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_undraw/flutter_undraw.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:watchtower/modules/music/collections/spotube_icons.dart';
import 'package:watchtower/modules/music/components/button/back_button.dart';
import 'package:watchtower/modules/music/components/inter_scrollbar/inter_scrollbar.dart';
import 'package:watchtower/modules/music/components/titlebar/titlebar.dart';
import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:watchtower/modules/music/provider/logs/logs_provider.dart';
import 'package:watchtower/modules/music/services/logger/logger.dart';

class LogsPage extends HookConsumerWidget {
  static const name = "logs";

  const LogsPage({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final controller = useScrollController();
    final logsQuery = ref.watch(logsProvider);

    return SafeArea(
      bottom: false,
      child: Scaffold(
        appBar: AppBar(
          leading: MusicBackButton(),
          title: Text(context.l10n.logs),
          actions: [
            IconButton(
              icon: const Icon(SpotubeIcons.clipboard),
              onPressed: () async {
                final logsSnapshot = await ref.read(logsProvider.future);
                await Clipboard.setData(ClipboardData(text: logsSnapshot));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(context.l10n.copied_to_clipboard("")),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            ),
            IconButton(
              icon: const Icon(SpotubeIcons.trash),
              onPressed: () async {
                ref.invalidate(logsProvider);
                final logsFile = await AppLogger.getLogsPath();
                await logsFile.writeAsString("");
              },
            ),
          ],
        ),
        body: SafeArea(
          child: switch (logsQuery) {
            AsyncData(:final value) => InterScrollbar(
                controller: controller,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(8.0),
                  controller: controller,
                  child: Card(child: SelectableText(value)),
                ),
              ),
            AsyncError(:final error) => switch (error) {
                StateError() => Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Undraw(
                        illustration: UndrawIllustration.noData,
                        height: 200,
                        width: 200,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      Text(context.l10n.no_logs_found),
                    ],
                  ),
                _ => Center(child: Text(error.toString())),
              },
            _ => const Center(child: CircularProgressIndicator()),
          },
        ),
      ),
    );
  }
}
