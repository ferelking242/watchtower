import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/modules/more/settings/player/providers/player_state_provider.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/providers/storage_provider.dart';
import 'package:watchtower/services/mpv_config_service.dart';
import 'package:watchtower/utils/extensions/build_context_extensions.dart';

class PlayerAdvancedScreen extends ConsumerStatefulWidget {
  const PlayerAdvancedScreen({super.key});

  @override
  ConsumerState<PlayerAdvancedScreen> createState() =>
      _PlayerAdvancedScreenState();
}

class _PlayerAdvancedScreenState extends ConsumerState<PlayerAdvancedScreen> {
  @override
  Widget build(BuildContext context) {
    final useMpvConfig = ref.watch(useMpvConfigStateProvider);

    return Scaffold(
      appBar: AppBar(
          leading: const BackButton(),title: Text(context.l10n.advanced)),
      body: SingleChildScrollView(
        child: Column(
          children: [
            SwitchListTile(
              value: useMpvConfig,
              title: Text(context.l10n.enable_mpv),
              subtitle: Text(
                context.l10n.mpv_info,
                style: TextStyle(fontSize: 11, color: context.secondaryColor),
              ),
              onChanged: (value) async {
                if (value && !(await _checkMpvConfig(context))) {
                  return;
                }
                ref.read(useMpvConfigStateProvider.notifier).set(value);
              },
            ),
            ListTile(
              onTap: () {
                _checkMpvConfig(context, redownload: true);
              },
              title: Text(context.l10n.mpv_redownload),
              subtitle: Text(
                context.l10n.mpv_redownload_info,
                style: TextStyle(fontSize: 11, color: context.secondaryColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _checkMpvConfig(
    BuildContext context, {
    bool redownload = false,
  }) async {
    final provider = StorageProvider();
    if (!(await provider.requestPermission())) {
      return false;
    }
    final dir = await provider.getMpvDirectory();
    final mpvFile = File('${dir!.path}/mpv.conf');
    final inputFile = File('${dir.path}/input.conf');
    final filesMissing =
        !(await mpvFile.exists()) || !(await inputFile.exists());
    if ((redownload || filesMissing) && context.mounted) {
      final res = await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            content: Text(context.l10n.mpv_download),
            actions: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(context.l10n.cancel),
                  ),
                  const SizedBox(width: 15),
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        await MpvConfigService.install(dir);
                        if (context.mounted) {
                          Navigator.pop(context, "ok");
                        }
                      } catch (error) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(error.toString())),
                          );
                        }
                      }
                    },
                    child: Text(context.l10n.download),
                  ),
                ],
              ),
            ],
          );
        },
      );
      return res != null && res == "ok";
    }
    return context.mounted;
  }
}
