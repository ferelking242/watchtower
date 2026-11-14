import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:watchtower/modules/music/components/button/back_button.dart';
import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:watchtower/modules/music/hooks/controllers/use_package_info.dart';

class AboutPage extends HookConsumerWidget {
  static const name = "about";
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final packageInfo = usePackageInfo();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = context.l10n;

    return SafeArea(
      bottom: false,
      child: Scaffold(
        appBar: AppBar(
          leading: const MusicBackButton(),
          title: Text(l10n.about),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              const SizedBox(height: 24),
              CircleAvatar(
                radius: 50,
                backgroundColor: cs.primaryContainer,
                child: Icon(
                  Icons.music_note_rounded,
                  size: 56,
                  color: cs.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.music,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.integrated_in_watchtower,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              _AboutRow(label: l10n.version, value: Text('v${packageInfo.version}')),
              _AboutRow(
                label: l10n.build_number,
                value: Text(packageInfo.buildNumber.replaceAll('.', ' ')),
              ),
              const SizedBox(height: 24),
              Text(
                l10n.made_with,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
              Text(
                l10n.copyright(DateTime.now().year),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  final String label;
  final Widget value;

  const _AboutRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 4),
          const Text(':'),
          const SizedBox(width: 8),
          Expanded(child: value),
        ],
      ),
    );
  }
}
