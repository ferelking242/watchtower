import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:watchtower/modules/music/collections/spotube_icons.dart';
import 'package:watchtower/modules/music/models/metadata/metadata.dart';
import 'package:watchtower/modules/music/modules/settings/section_card_with_heading.dart';
import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/core/auth.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/metadata_plugin_provider.dart';
import 'package:watchtower/modules/music/provider/scrobbler/scrobbler.dart';

class SettingsAccountSection extends ConsumerWidget {
  const SettingsAccountSection({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final scrobbler = ref.watch(scrobblerProvider);
    final pluginsState = ref.watch(metadataPluginsProvider);
    final metadataPlugin = ref.watch(metadataPluginProvider);
    final isAuthSnap = ref.watch(metadataPluginAuthenticatedProvider);
    final theme = Theme.of(context);

    final defaultMetadata =
        pluginsState.asData?.value.defaultMetadataPluginConfig;
    final requiresAuth =
        defaultMetadata?.abilities.contains(PluginAbilities.authentication) ==
            true;
    final isAuthenticated = isAuthSnap.asData?.value == true;

    return SectionCardWithHeading(
      heading: context.l10n.account,
      children: [
        // ─── Spotify / metadata-plugin login ────────────────────────────
        ListTile(
          leading: const Icon(SpotubeIcons.music),
          title: const Text('Spotify'),
          subtitle: Text(
            requiresAuth
                ? isAuthenticated
                    ? 'Connected'
                    : 'Tap to log in'
                : 'Install a Spotify plugin from Extensions',
            style: theme.textTheme.bodySmall?.copyWith(
              color: requiresAuth && isAuthenticated
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          trailing: requiresAuth
              ? isAuthenticated
                  ? FilledButton.tonal(
                      style: FilledButton.styleFrom(
                        foregroundColor: theme.colorScheme.error,
                        backgroundColor: theme.colorScheme.errorContainer,
                      ),
                      onPressed: () async {
                        await metadataPlugin.asData?.value?.auth.logout();
                      },
                      child: Text(context.l10n.disconnect),
                    )
                  : FilledButton.icon(
                      onPressed: metadataPlugin.asData?.value != null
                          ? () async {
                              await metadataPlugin.asData!.value!.auth
                                  .authenticate();
                            }
                          : null,
                      icon: metadataPlugin.isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(SpotubeIcons.login, size: 18),
                      label: Text(context.l10n.login),
                    )
              : null,
        ),

        // ─── Last.fm scrobbler ───────────────────────────────────────────
        scrobbler.asData?.value == null
            ? ListTile(
                leading: const Icon(SpotubeIcons.lastFm),
                title: const Text('Last.fm'),
                subtitle: Text(
                  context.l10n.scrobble_to_lastfm,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                trailing: OutlinedButton(
                  onPressed: () {/* navigates to lastfm login */},
                  child: Text(context.l10n.connect),
                ),
              )
            : ListTile(
                leading: const Icon(SpotubeIcons.lastFm),
                title: Text(context.l10n.disconnect_lastfm),
                subtitle: Text(
                  'Connected',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                trailing: FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                    backgroundColor: theme.colorScheme.errorContainer,
                  ),
                  onPressed: () {
                    ref.read(scrobblerProvider.notifier).logout();
                  },
                  child: Text(context.l10n.disconnect),
                ),
              ),
      ],
    );
  }
}
