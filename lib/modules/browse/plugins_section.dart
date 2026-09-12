import 'package:flutter/material.dart';
import 'package:watchtower/modules/more/widgets/binaries_section.dart';
import 'package:watchtower/providers/storage_provider.dart';
import 'package:watchtower/services/download_manager/m3u8/ffmpeg_binary_manager.dart';
import 'package:watchtower/services/mpv_config_service.dart';
import 'package:watchtower/services/onboarding_dependency_service.dart';

/// Marketplace entry point for app-side plugins and runtimes.
///
/// The onboarding flow deliberately does not install large or optional
/// components. They live here so they can be installed, retried, or skipped
/// after the app is usable.
class PluginsSection extends StatefulWidget {
  const PluginsSection({super.key});

  @override
  State<PluginsSection> createState() => _PluginsSectionState();
}

class _PluginsSectionState extends State<PluginsSection> {
  bool? _ffmpegInstalled;
  bool? _mpvInstalled;
  bool _mpvBusy = false;
  String? _mpvError;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final ffmpeg = await FfmpegBinaryManager.instance.isInstalled();
      final mpv = await OnboardingDependencyService.isInstalled(
        OnboardingDependencyId.mpv,
      );
      if (mounted) {
        setState(() {
          _ffmpegInstalled = ffmpeg;
          _mpvInstalled = mpv;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _mpvError = error.toString());
    }
  }

  Future<void> _installMpv() async {
    if (_mpvBusy) return;
    setState(() {
      _mpvBusy = true;
      _mpvError = null;
    });
    try {
      final directory = await StorageProvider().getMpvDirectory();
      if (directory == null) {
        throw const MpvConfigException(
          'Le dossier de configuration MPV est indisponible.',
        );
      }
      await MpvConfigService.install(directory);
      if (mounted) setState(() => _mpvInstalled = true);
    } catch (error) {
      if (mounted) setState(() => _mpvError = error.toString());
    } finally {
      if (mounted) setState(() => _mpvBusy = false);
    }
  }

  void _showFfmpegInfo() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('FFmpeg runtime'),
        content: const Text(
          'FFmpeg sert uniquement à muxer les fragments HLS TS/fMP4 en '
          'fichier lisible. Il ne télécharge ni le lecteur ni MPV.\n\n'
          'Si aucun exécutable vérifié n’est installé, Watchtower utilise '
          'automatiquement la concaténation directe des fragments. La lecture '
          'en ligne ne dépend donc pas de ce plugin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Widget _card({
    required IconData icon,
    required String title,
    required String description,
    required Widget trailing,
    Color? color,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final accent = color ?? scheme.primary;
    return Card(
      margin: const EdgeInsets.fromLTRB(14, 6, 14, 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: accent, size: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing,
          ],
        ),
      ),
    );
  }

  Widget _statusButton({
    required bool? installed,
    required String action,
    required VoidCallback? onPressed,
    bool busy = false,
  }) {
    if (busy) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    if (installed == true) {
      return const Icon(Icons.check_circle_rounded, color: Colors.green);
    }
    return OutlinedButton(
      onPressed: onPressed,
      child: Text(action),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              'Plugins',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          _card(
            icon: Icons.movie_filter_rounded,
            title: 'FFmpeg runtime',
            description: _ffmpegInstalled == true
                ? 'Exécutable vérifié disponible pour les fichiers HLS.'
                : 'Optionnel : la concaténation directe reste utilisée automatiquement.',
            trailing: _statusButton(
              installed: _ffmpegInstalled,
              action: 'Info',
              onPressed: _showFfmpegInfo,
            ),
            color: Colors.deepOrange,
          ),
          _card(
            icon: Icons.play_circle_outline_rounded,
            title: 'Configuration MPV',
            description: 'Télécharge uniquement mpv.conf, input.conf et les scripts.',
            trailing: _statusButton(
              installed: _mpvInstalled,
              action: 'Installer',
              onPressed: _installMpv,
              busy: _mpvBusy,
            ),
            color: Colors.blue,
          ),
          if (_mpvError != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
              child: Text(
                _mpvError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 10),
          const BinariesSection(),
        ],
      ),
    );
  }
}