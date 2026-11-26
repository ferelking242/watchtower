import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/modules/music/collections/routes.gr.dart';
import 'package:watchtower/modules/music/components/image/universal_image.dart';
import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:watchtower/modules/music/models/metadata/metadata.dart';
import 'package:watchtower/modules/music/provider/connect/clients.dart';
import 'package:watchtower/modules/music/provider/download_manager_provider.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/core/auth.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/core/user.dart';
import 'package:watchtower/modules/music/provider/sleep_timer_provider.dart';

/// Account drawer of the music hub, in the spirit of Spotify's profile sheet:
/// identity on top, then account, stats, devices, downloads and settings.
///
/// Rendered inside [NamidaInnerDrawer] (same shell as the Discovery drawer),
/// so the swipe gesture and the page slide come from the shared widget.
class MusicHomeDrawer extends ConsumerWidget {
  final VoidCallback onClose;

  const MusicHomeDrawer({super.key, required this.onClose});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final me = ref.watch(metadataPluginUserProvider);
    final authenticated =
        ref.watch(metadataPluginAuthenticatedProvider).asData?.value == true;
    final user = me.asData?.value;

    final connectClients = ref.watch(connectClientsProvider);
    final deviceCount = connectClients.asData?.value.services.length ?? 0;

    final pendingDownloads = ref
        .watch(downloadManagerProvider)
        .where(
          (e) =>
              e.status == DownloadStatus.downloading ||
              e.status == DownloadStatus.queued,
        )
        .length;

    final avatar = user?.images.asUrlString(
      index: 0,
      placeholder: ImagePlaceholder.artist,
    );

    void open(PageRouteInfo route) {
      onClose();
      context.navigateTo(route);
    }

    return Material(
      color: cs.surface,
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ProfileHeader(
              name: user?.name ?? context.l10n.music,
              subtitle: authenticated
                  ? context.l10n.profile
                  : context.l10n.login,
              image: authenticated ? avatar : null,
              onTap: () => open(
                authenticated
                    ? const ProfileRoute()
                    : const SettingsMetadataProviderRoute(),
              ),
            ),
            Divider(
              height: 1,
              thickness: 1,
              color: cs.outlineVariant.withValues(alpha: 0.35),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _MusicDrawerTile(
                    icon: authenticated ? Broken.user : Broken.login,
                    title: authenticated
                        ? context.l10n.account
                        : context.l10n.login,
                    onTap: () => open(const SettingsMetadataProviderRoute()),
                  ),
                  _MusicDrawerTile(
                    icon: Broken.chart_2,
                    title: context.l10n.stats,
                    onTap: () => open(const StatsRoute()),
                  ),
                  _MusicDrawerTile(
                    icon: Broken.speaker,
                    title: context.l10n.devices,
                    trailing: deviceCount > 0 ? '$deviceCount' : null,
                    onTap: () => open(const ConnectRoute()),
                  ),
                  _MusicDrawerTile(
                    icon: Broken.document_download,
                    title: context.l10n.downloads,
                    trailing: pendingDownloads > 0 ? '$pendingDownloads' : null,
                    onTap: () => open(const UserDownloadsRoute()),
                  ),
                  _MusicDrawerTile(
                    icon: Broken.music_library_2,
                    title: context.l10n.library,
                    onTap: () => open(const LibraryRoute()),
                  ),
                  const SizedBox(height: 6),
                  Divider(
                    height: 1,
                    thickness: 1,
                    indent: 20,
                    endIndent: 20,
                    color: cs.outlineVariant.withValues(alpha: 0.25),
                  ),
                  const SizedBox(height: 6),
                  _SleepTimerTile(onClose: onClose),
                  _MusicDrawerTile(
                    icon: Broken.setting_2,
                    title: context.l10n.settings,
                    onTap: () => open(const SettingsRoute()),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
              child: Row(
                children: [
                  Icon(
                    Broken.musicnote,
                    size: 15,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    context.l10n.music,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                      letterSpacing: 0.6,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Profile header ────────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  final String name;
  final String subtitle;
  final String? image;
  final VoidCallback onTap;

  const _ProfileHeader({
    required this.name,
    required this.subtitle,
    required this.image,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 16, 18),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: cs.primary.withValues(alpha: 0.45),
                  width: 1.5,
                ),
              ),
              child: ClipOval(
                child: image != null
                    ? UniversalImage(path: image!, fit: BoxFit.cover)
                    : ColoredBox(
                        color: cs.primaryContainer,
                        child: Icon(
                          Broken.user,
                          size: 26,
                          color: cs.onPrimaryContainer,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Broken.arrow_right_3,
              size: 17,
              color: cs.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tiles ─────────────────────────────────────────────────────────────────────

class _MusicDrawerTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? trailing;
  final VoidCallback? onTap;

  const _MusicDrawerTile({
    required this.icon,
    required this.title,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            child: Row(
              children: [
                Icon(icon, size: 21, color: cs.onSurfaceVariant),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (trailing != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      trailing!,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: cs.primary,
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

// ── Sleep timer ───────────────────────────────────────────────────────────────

class _SleepTimerTile extends ConsumerWidget {
  final VoidCallback onClose;

  const _SleepTimerTile({required this.onClose});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remaining = ref.watch(sleepTimerProvider);

    return _MusicDrawerTile(
      icon: Broken.timer_1,
      title: context.l10n.sleep_timer,
      trailing: remaining == null ? null : '${remaining.inMinutes} min',
      onTap: () {
        onClose();
        _showSleepTimerDialog(context, ref);
      },
    );
  }

  Future<void> _showSleepTimerDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final cs = Theme.of(context).colorScheme;
    final remaining = ref.read(sleepTimerProvider);

    await showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: cs.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Broken.timer_1, size: 20, color: cs.primary),
            const SizedBox(width: 8),
            Text(context.l10n.sleep_timer),
          ],
        ),
        contentPadding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final minutes in const [15, 30, 60, 120])
              _SleepTimerOption(
                label: '$minutes min',
                selected: remaining?.inMinutes == minutes,
                onTap: () {
                  ref
                      .read(sleepTimerProvider.notifier)
                      .setSleepTimer(Duration(minutes: minutes));
                  Navigator.of(dialogContext).pop();
                },
              ),
            const SizedBox(height: 4),
            _SleepTimerOption(
              label: context.l10n.none,
              selected: remaining == null,
              onTap: () {
                ref.read(sleepTimerProvider.notifier).cancelSleepTimer();
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SleepTimerOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SleepTimerOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Material(
        color: selected
            ? cs.primary.withValues(alpha: 0.14)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Icon(
                  selected ? Broken.tick_circle : Broken.clock_1,
                  size: 18,
                  color: selected ? cs.primary : cs.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? cs.primary : cs.onSurface,
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
