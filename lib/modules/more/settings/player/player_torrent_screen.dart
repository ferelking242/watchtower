import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/modules/more/settings/player/providers/player_prefs_provider.dart';
import 'package:watchtower/modules/more/settings/widgets/settings_subpage_scaffold.dart';

/// Torrent streaming options, mirroring Aniyomi's "Torrent" block.
class PlayerTorrentScreen extends ConsumerWidget {
  const PlayerTorrentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = ref.watch(playerTorrServerUrlProvider);
    final stream = ref.watch(playerTorrentStreamProvider);

    return SettingsSubpageScaffold(
      title: 'Torrent',
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Broken.link),
                title: const Text('Adresse TorrServer'),
                subtitle: Text(
                  url.isEmpty ? 'Non configuré' : url,
                  style: const TextStyle(fontSize: 11),
                ),
                trailing: const Icon(Broken.edit_2),
                onTap: () {
                  final controller = TextEditingController(text: url);
                  showDialog<void>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Adresse TorrServer'),
                      content: TextField(
                        controller: controller,
                        autofocus: true,
                        decoration: const InputDecoration(
                          hintText: 'http://127.0.0.1:8090',
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Annuler'),
                        ),
                        FilledButton(
                          onPressed: () {
                            ref
                                .read(playerTorrServerUrlProvider.notifier)
                                .set(controller.text.trim());
                            Navigator.pop(ctx);
                          },
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                },
              ),
              SwitchListTile(
                secondary: const Icon(Broken.play_circle),
                value: stream,
                title: const Text('Lecture en continu'),
                subtitle: const Text(
                  'Démarre la lecture dès que suffisamment de morceaux sont disponibles',
                  style: TextStyle(fontSize: 11),
                ),
                onChanged: (v) =>
                    ref.read(playerTorrentStreamProvider.notifier).set(v),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
