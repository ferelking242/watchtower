import 'package:flutter/material.dart';
    import 'package:watchtower/modules/music/components/button/back_button.dart';
    import 'package:watchtower/modules/music/extensions/context.dart';
    import 'package:watchtower/modules/music/hooks/controllers/use_package_info.dart';
    import 'package:hooks_riverpod/hooks_riverpod.dart';

    class AboutSpotubePage extends HookConsumerWidget {
    static const name = "about";
    const AboutSpotubePage({super.key});

    @override
    Widget build(BuildContext context, ref) {
      final packageInfo = usePackageInfo();
      final theme = Theme.of(context);
      final colorScheme = theme.colorScheme;

      Widget buildRow(String label, Widget value) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              SizedBox(width: 120, child: Text(label, style: theme.textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.bold))),
              const SizedBox(width: 4), const Text(':'), const SizedBox(width: 8),
              Expanded(child: value),
            ],
          ),
        );
      }

      return SafeArea(
        bottom: false,
        child: Scaffold(
          appBar: AppBar(leading: MusicBackButton(), title: const Text('Music Hub')),
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  Container(
                    width: 100, height: 100,
                    decoration: BoxDecoration(color: colorScheme.primaryContainer, shape: BoxShape.circle),
                    child: Icon(Icons.music_note_rounded, size: 56, color: colorScheme.primary),
                  ),
                  const SizedBox(height: 16),
                  Text('Music Hub', style: theme.textTheme.headlineSmall!.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Intégré dans Watchtower', style: theme.textTheme.bodyMedium!.copyWith(color: colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 24),
                  buildRow(context.l10n.version, Text('v${packageInfo.version}')),
                  buildRow(context.l10n.build_number, Text(packageInfo.buildNumber.replaceAll('.', ' '))),
                  const SizedBox(height: 24),
                  Text(context.l10n.made_with, textAlign: TextAlign.center, style: theme.textTheme.bodySmall!),
                  Text(context.l10n.copyright(DateTime.now().year), textAlign: TextAlign.center, style: theme.textTheme.bodySmall!),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      );
    }
    }
    