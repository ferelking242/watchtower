import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:watchtower/modules/browse/marketplace_palette.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/modules/more/widgets/binaries_section.dart';
import 'package:watchtower/providers/storage_provider.dart';
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
      final mpv = await OnboardingDependencyService.isInstalled(
        OnboardingDependencyId.mpv,
      );
      if (mounted) {
        setState(() {
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
        throw MpvConfigException(context.l10n.plugins_mpv_config_exception);
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
    final l10n = context.l10n;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.plugins_ffmpeg_title),
        content: Text(l10n.plugins_ffmpeg_info),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.plugins_action_close),
          ),
        ],
      ),
    );
  }

  /// Section header matching the catalogue shelves: accent square, title,
  /// and the same type scale, so the Plugins tab reads as part of the
  /// Marketplace instead of a differently-styled list.
  Widget _sectionHeader(String title, IconData icon) {
    final palette = MarketplacePalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: palette.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: palette.accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.text,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
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
    final palette = MarketplacePalette.of(context);
    final accent = color ?? palette.accent;
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 5, 14, 5),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accent.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, color: accent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.text,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: palette.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing,
        ],
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
    return OutlinedButton(onPressed: onPressed, child: Text(action));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionHeader(l10n.plugins_section_builtin, Icons.extension_rounded),
          _card(
            icon: Icons.folder_open_rounded,
            title: l10n.plugins_nfile_title,
            description: l10n.plugins_nfile_description,
            trailing: OutlinedButton(
              onPressed: () => context.push('/nfileHome'),
              child: Text(l10n.plugins_action_open),
            ),
            color: Colors.orange,
          ),
          _card(
            icon: Icons.video_library_rounded,
            title: l10n.plugins_smart_library_title,
            description: l10n.plugins_smart_library_description,
            trailing: OutlinedButton(
              onPressed: () => context.push('/smartLibrary'),
              child: Text(l10n.plugins_action_open),
            ),
            color: Colors.indigo,
          ),
          _sectionHeader(l10n.plugins_section_engines, Icons.memory_rounded),
          _card(
            icon: Icons.movie_filter_rounded,
            title: l10n.plugins_ffmpeg_title,
            description: l10n.plugins_ffmpeg_bundled,
            trailing: OutlinedButton(
              onPressed: _showFfmpegInfo,
              child: Text(l10n.plugins_action_info),
            ),
            color: Colors.deepOrange,
          ),
          _card(
            icon: Icons.play_circle_outline_rounded,
            title: l10n.plugins_mpv_title,
            description: l10n.plugins_mpv_description,
            trailing: _statusButton(
              installed: _mpvInstalled,
              action: l10n.plugins_action_install,
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
