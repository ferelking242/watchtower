import 'package:file_picker/file_picker.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:watchtower/modules/music/collections/spotube_icons.dart';
import 'package:watchtower/modules/music/modules/settings/section_card_with_heading.dart';
import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:watchtower/modules/music/provider/user_preferences/user_preferences_provider.dart';
import 'package:watchtower/modules/music/utils/platform.dart';

class SettingsDownloadsSection extends HookConsumerWidget {
  const SettingsDownloadsSection({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final preferencesNotifier = ref.watch(userPreferencesProvider.notifier);
    final preferences = ref.watch(userPreferencesProvider);

    final pickDownloadLocation = useCallback(() async {
      if (kIsMobile || kIsMacOS) {
        final dirStr = await FilePicker.getDirectoryPath(
          initialDirectory: preferences.downloadLocation,
        );
        if (dirStr == null) return;
        preferencesNotifier.setDownloadLocation(dirStr);
      } else {
        final dirStr = await getDirectoryPath(
          initialDirectory: preferences.downloadLocation,
        );
        if (dirStr == null) return;
        preferencesNotifier.setDownloadLocation(dirStr);
      }
    }, [preferences.downloadLocation]);

    return SectionCardWithHeading(
      heading: context.l10n.downloads,
      children: [
        ListTile(
          title: Text(context.l10n.download_location),
          trailing: IconButton(
            style: IconButton.styleFrom(
              side: const BorderSide(),
            ),
            onPressed: pickDownloadLocation,
            icon: const Icon(SpotubeIcons.folder),
          ),
          onTap: pickDownloadLocation,
        ),
      ],
    );
  }
}
