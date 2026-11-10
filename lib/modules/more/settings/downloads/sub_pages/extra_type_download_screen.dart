import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/modules/more/settings/downloads/providers/downloads_state_provider.dart';
import 'package:watchtower/modules/more/settings/widgets/settings_subpage_scaffold.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Music / Game download settings sub-pages
//
// Both types share the same knobs (connections, queue slots, Wi-Fi only) and
// the same internal downloader as Manga/Novel, so one parametrised screen backs
// both entries instead of two near-identical copies.
// ─────────────────────────────────────────────────────────────────────────────

class MusicDownloadScreen extends StatelessWidget {
  const MusicDownloadScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const _ExtraTypeDownloadScreen(type: _ExtraType.music);
}

class GameDownloadScreen extends StatelessWidget {
  const GameDownloadScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const _ExtraTypeDownloadScreen(type: _ExtraType.game);
}

enum _ExtraType { music, game }

class _ExtraTypeDownloadScreen extends ConsumerWidget {
  final _ExtraType type;

  const _ExtraTypeDownloadScreen({required this.type});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final isMusic = type == _ExtraType.music;
    final title = isMusic ? 'Téléchargements — Musique' : 'Téléchargements — Jeu';
    final connections = isMusic
        ? ref.watch(musicConnectionsStateProvider)
        : ref.watch(gameConnectionsStateProvider);
    final simultaneous = isMusic
        ? ref.watch(musicSimultaneousStateProvider)
        : ref.watch(gameSimultaneousStateProvider);
    final onlyOnWifi = isMusic
        ? ref.watch(musicOnlyOnWifiStateProvider)
        : ref.watch(gameOnlyOnWifiStateProvider);

    return SettingsSubpageScaffold(
      title: title,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: scheme.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(
                    isMusic ? Broken.music : Broken.game,
                    color: scheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isMusic
                          ? 'La Musique utilise le téléchargeur interne via '
                                'l\'extension source.'
                          : 'Le Jeu utilise le téléchargeur interne via '
                                'l\'extension source.',
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            _SectionHeader(title: 'Connexions'),
            _ConnectionsTile(
              label: 'Connexions simultanées',
              subtitle: 'Connexions parallèles par téléchargement',
              value: connections,
              icon: Broken.document_download,
              onChanged: (v) => isMusic
                  ? ref.read(musicConnectionsStateProvider.notifier).set(v)
                  : ref.read(gameConnectionsStateProvider.notifier).set(v),
              scheme: scheme,
            ),
            _ConnectionsTile(
              label: 'Téléchargements simultanés (file)',
              subtitle: 'Nombre d\'éléments téléchargés en même temps',
              value: simultaneous,
              icon: Broken.note_2,
              onChanged: (v) => isMusic
                  ? ref.read(musicSimultaneousStateProvider.notifier).set(v)
                  : ref.read(gameSimultaneousStateProvider.notifier).set(v),
              scheme: scheme,
            ),

            _SectionHeader(title: 'Comportement'),
            SwitchListTile(
              dense: true,
              secondary: const Icon(Broken.wifi),
              title: const Text('Wi-Fi uniquement'),
              subtitle: const Text(
                'Télécharger uniquement via Wi-Fi',
                style: TextStyle(fontSize: 11),
              ),
              value: onlyOnWifi,
              onChanged: (v) => isMusic
                  ? ref.read(musicOnlyOnWifiStateProvider.notifier).set(v)
                  : ref.read(gameOnlyOnWifiStateProvider.notifier).set(v),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: scheme.primary,
        ),
      ),
    );
  }
}

class _ConnectionsTile extends StatelessWidget {
  final String label;
  final String subtitle;
  final int value;
  final IconData icon;
  final void Function(int) onChanged;
  final ColorScheme scheme;

  const _ConnectionsTile({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.icon,
    required this.onChanged,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          _StepButton(
            icon: Icons.remove,
            enabled: value > 1,
            color: scheme.primary,
            onTap: value > 1 ? () => onChanged(value - 1) : null,
          ),
          SizedBox(
            width: 28,
            child: Center(
              child: Text(
                '$value',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
            ),
          ),
          _StepButton(
            icon: Icons.add,
            enabled: value < 10,
            color: scheme.primary,
            onTap: value < 10 ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final Color color;
  final VoidCallback? onTap;

  const _StepButton({
    required this.icon,
    required this.enabled,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: enabled ? color.withValues(alpha: 0.15) : Colors.transparent,
          border: Border.all(
            color: enabled
                ? color.withValues(alpha: 0.5)
                : scheme.outlineVariant,
            width: 1,
          ),
        ),
        child: Icon(
          icon,
          size: 16,
          color: enabled
              ? color
              : scheme.onSurfaceVariant.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}
