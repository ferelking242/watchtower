import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:watchtower/modules/music/collections/assets.gen.dart';
import 'package:watchtower/modules/music/collections/env.dart';
import 'package:watchtower/modules/music/components/button/back_button.dart';
import 'package:watchtower/modules/music/components/image/universal_image.dart';
import 'package:watchtower/modules/music/components/links/hyper_link.dart';
import 'package:watchtower/modules/music/components/titlebar/titlebar.dart';
import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:watchtower/modules/music/hooks/controllers/use_package_info.dart';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

final _licenseProvider = FutureProvider<String>((ref) async {
  return await rootBundle.loadString("LICENSE");
});

class AboutSpotubePage extends HookConsumerWidget {
  static const name = "about";

  const AboutSpotubePage({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final packageInfo = usePackageInfo();
    final license = ref.watch(_licenseProvider);
    final theme = Theme.of(context);

    Widget buildRow(String label, Widget value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 95,
              child: Text(label,
                  style: theme.textTheme.bodyMedium!
                      .copyWith(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 4),
            const Text(":"),
            const SizedBox(width: 8),
            Expanded(child: value),
          ],
        ),
      );
    }

    return SafeArea(
      bottom: false,
      child: Scaffold(
        appBar: AppBar(
          leading: const MusicBackButton(),
          title: Text(context.l10n.about_spotube),
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: [
                Assets.branding.spotubeLogoPng.image(
                  height: 200,
                  width: 200,
                ),
                Center(
                  child: Column(
                    children: [
                      Text(context.l10n.spotube_description),
                      const SizedBox(height: 20),
                      buildRow(
                        context.l10n.founder,
                        Hyperlink(
                          context.l10n.kingkor_roy_tirtho,
                          "https://github.com/KRTirtho",
                        ),
                      ),
                      buildRow(
                        context.l10n.version,
                        Text("v${packageInfo.version}"),
                      ),
                      buildRow(
                        context.l10n.channel,
                        Text(Env.releaseChannel.name),
                      ),
                      buildRow(
                        context.l10n.build_number,
                        Text(packageInfo.buildNumber.replaceAll(".", " ")),
                      ),
                      buildRow(
                        "Website",
                        const Hyperlink(
                          "spotube.krtirtho.dev",
                          "https://spotube.krtirtho.dev",
                        ),
                      ),
                      buildRow(
                        context.l10n.repository,
                        const Hyperlink(
                          "github.com/KRTirtho/spotube",
                          "https://github.com/KRTirtho/spotube",
                        ),
                      ),
                      buildRow(
                        context.l10n.license,
                        const Hyperlink(
                          "BSD-4-Clause",
                          "https://raw.githubusercontent.com/KRTirtho/spotube/master/LICENSE",
                        ),
                      ),
                      buildRow(
                        context.l10n.bug_issues,
                        const Hyperlink(
                          "Discord#chat",
                          "https://discord.gg/uJ94vxB6vg",
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => launchUrl(
                      Uri.parse("https://discord.gg/uJ94vxB6vg"),
                      mode: LaunchMode.externalApplication,
                    ),
                    child: const UniversalImage(
                      path:
                          "https://discord.com/api/guilds/1012234096237350943/widget.png?style=banner2",
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  context.l10n.made_with,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall!,
                ),
                Text(
                  context.l10n.copyright(DateTime.now().year),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall!,
                ),
                const SizedBox(height: 20),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 750),
                  child: SafeArea(
                    child: license.when(
                      data: (data) {
                        return Text(data,
                            style: theme.textTheme.bodySmall!);
                      },
                      loading: () {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      },
                      error: (e, s) {
                        return Text(e.toString(),
                            style: theme.textTheme.bodySmall!);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
