import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:watchtower/modules/music/modules/library/user_downloads/download_item.dart';
import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:watchtower/modules/music/provider/download_manager_provider.dart';

class UserDownloadsPage extends HookConsumerWidget {
  static const name = 'user_downloads';
  const UserDownloadsPage({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final downloadQueue = ref.watch(downloadManagerProvider);
    final downloadManagerNotifier = ref.watch(downloadManagerProvider.notifier);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: AutoSizeText(
                  context.l10n.currently_downloading(downloadQueue.length),
                  maxLines: 1,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                ),
                onPressed: downloadQueue.isEmpty
                    ? null
                    : downloadManagerNotifier.clearAll,
                child: Text(context.l10n.cancel_all),
              ),
            ],
          ),
        ),
        Expanded(
          child: SafeArea(
            child: ListView.builder(
              itemCount: downloadQueue.length,
              padding: const EdgeInsets.only(bottom: 200),
              itemBuilder: (context, index) {
                return DownloadItem(
                  task: downloadQueue.elementAt(index),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
