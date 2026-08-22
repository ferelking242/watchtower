import 'package:flutter/material.dart';
import 'package:watchtower/modules/music/components/links/anchor_button.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:version/version.dart';

class RootAppUpdateDialog extends StatelessWidget {
  final Version? version;
  final int? nightlyBuildNum;

  const RootAppUpdateDialog({super.key, this.version}) : nightlyBuildNum = null;
  const RootAppUpdateDialog.nightly({super.key, required this.nightlyBuildNum})
      : version = null;

  @override
  Widget build(BuildContext context) {
    // Téléchargements Watchtower (plus de lien vers spotube.krtirtho.dev)
    const url = "https://github.com/ferelking242/watchtower/releases/latest";
    const nightlyUrl = "https://github.com/ferelking242/watchtower/releases";
    return AlertDialog(
      title: const Text("Watchtower — mise à jour disponible"),
      actions: [
        FilledButton(
          child: Text(context.l10n.download_now),
          onPressed: () => launchUrlString(
            nightlyBuildNum != null ? nightlyUrl : url,
            mode: LaunchMode.externalApplication,
          ),
        ),
      ],
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            nightlyBuildNum != null
                ? "Watchtower Nightly ($nightlyBuildNum) est sortie"
                : "Watchtower v${version!} est sortie",
          ),
          if (nightlyBuildNum == null)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(context.l10n.read_the_latest),
                AnchorButton(
                  context.l10n.release_notes,
                  style: const TextStyle(color: Colors.blue),
                  onTap: () => launchUrlString(
                    url,
                    mode: LaunchMode.externalApplication,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
