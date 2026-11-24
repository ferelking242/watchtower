import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/modules/more/settings/widgets/settings_subpage_scaffold.dart';
import 'package:watchtower/modules/music/components/button/back_button.dart';
import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:watchtower/modules/music/provider/logs/logs_provider.dart';
import 'package:watchtower/modules/music/services/logger/logger.dart';

class LogsPage extends HookConsumerWidget {
  static const name = "logs";

  const LogsPage({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final logsQuery = ref.watch(logsProvider);
    final cs = Theme.of(context).colorScheme;

    return SettingsSubpageScaffold(
      title: context.l10n.logs,
      showSearch: false,
      leading: const MusicBackButton(),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Broken.document_text, size: 20),
            tooltip: context.l10n.copy_to_clipboard,
            onPressed: () async {
              final snapshot = await ref.read(logsProvider.future);
              await Clipboard.setData(ClipboardData(text: snapshot));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(context.l10n.copied_to_clipboard('')),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Broken.trash, size: 20),
            tooltip: context.l10n.delete,
            onPressed: () async {
              ref.invalidate(logsProvider);
              final logsFile = await AppLogger.getLogsPath();
              await logsFile.writeAsString("");
            },
          ),
        ],
      ),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            child: switch (logsQuery) {
              AsyncData(:final value) =>
                value.trim().isEmpty
                    ? _LogsEmpty(message: context.l10n.no_logs_found)
                    : SelectableText(
                        value,
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.45,
                          fontFamily: 'monospace',
                          color: cs.onSurfaceVariant,
                        ),
                      ),
              AsyncError(:final error) => _LogsEmpty(
                message: error is StateError
                    ? context.l10n.no_logs_found
                    : error.toString(),
              ),
              _ => const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              ),
            },
          ),
        ),
      ],
    );
  }
}

class _LogsEmpty extends StatelessWidget {
  const _LogsEmpty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
      child: Column(
        children: [
          Icon(
            Broken.document_text,
            size: 34,
            color: cs.onSurfaceVariant.withValues(alpha: .5),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
