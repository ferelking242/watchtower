import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/modules/music/collections/riverpod_compat.dart';
import 'package:flutter/material.dart';

import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:watchtower/modules/music/models/metadata/metadata.dart';

final replaceDownloadedFileState = StateProvider<bool?>((ref) => null);

class ReplaceDownloadedDialog extends ConsumerWidget {
  final SpotubeTrackObject track;
  const ReplaceDownloadedDialog({required this.track, super.key});

  @override
  Widget build(BuildContext context, ref) {
    final replaceAll = ref.watch(replaceDownloadedFileState);

    return AlertDialog(
      title: Text(context.l10n.track_exists(track.name)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.do_you_want_to_replace),
          const SizedBox(height: 16),
          RadioListTile<bool>(
            title: Text(context.l10n.replace_downloaded_tracks),
            value: true,
            groupValue: replaceAll,
            onChanged: (value) {
              ref.read(replaceDownloadedFileState.notifier).state = value;
            },
          ),
          const SizedBox(height: 8),
          RadioListTile<bool>(
            title: Text(context.l10n.skip_download_tracks),
            value: false,
            groupValue: replaceAll,
            onChanged: (value) {
              ref.read(replaceDownloadedFileState.notifier).state = value;
            },
          ),
        ],
      ),
      actions: [
        OutlinedButton(
          onPressed: replaceAll == true
              ? null
              : () {
                  Navigator.pop(context, false);
                },
          child: Text(context.l10n.skip),
        ),
        FilledButton(
          onPressed: replaceAll == false
              ? null
              : () {
                  Navigator.pop(context, true);
                },
          child: Text(context.l10n.replace),
        ),
      ],
    );
  }
}
