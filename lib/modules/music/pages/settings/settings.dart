import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/modules/more/settings/widgets/settings_subpage_scaffold.dart';
import 'package:watchtower/modules/music/components/button/back_button.dart';
import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:watchtower/modules/music/pages/settings/sections/about.dart';
import 'package:watchtower/modules/music/pages/settings/sections/accounts.dart';
import 'package:watchtower/modules/music/pages/settings/sections/appearance.dart';
import 'package:watchtower/modules/music/pages/settings/sections/desktop.dart';
import 'package:watchtower/modules/music/pages/settings/sections/downloads.dart';
import 'package:watchtower/modules/music/pages/settings/sections/language_region.dart';
import 'package:watchtower/modules/music/pages/settings/sections/playback.dart';
import 'package:watchtower/modules/music/provider/user_preferences/user_preferences_provider.dart';
import 'package:watchtower/modules/music/utils/platform.dart';

/// A music settings block plus the words that should find it.
class _MusicSettingsSection {
  final Widget child;
  final List<String> keywords;

  const _MusicSettingsSection(this.child, this.keywords);

  bool matches(String query) =>
      keywords.any((keyword) => keyword.contains(query));
}

class SettingsPage extends HookConsumerWidget {
  static const name = "settings";
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final query = useState<String>('');
    final preferencesNotifier = ref.watch(userPreferencesProvider.notifier);
    final theme = Theme.of(context);
    final l10n = context.l10n;

    final sections = <_MusicSettingsSection>[
      _MusicSettingsSection(const SettingsAccountSection(), [
        l10n.account,
        l10n.plugins,
        l10n.scrobbling,
        l10n.audio_scrobblers,
        'plugin',
        'compte',
        'lastfm',
        'last.fm',
        'scrobble',
        'auth',
        'login',
        'connexion',
      ]),
      _MusicSettingsSection(const SettingsLanguageRegionSection(), [
        l10n.language_region,
        l10n.language,
        l10n.market_place_region,
        'langue',
        'language',
        'locale',
        'région',
        'region',
        'marché',
        'market',
      ]),
      _MusicSettingsSection(const SettingsAppearanceSection(), [
        l10n.appearance,
        l10n.layout_mode,
        'apparence',
        'layout',
        'affichage',
        'display',
        'compact',
        'extended',
      ]),
      _MusicSettingsSection(const SettingsPlaybackSection(), [
        l10n.playback,
        l10n.youtube_engine,
        l10n.cache_music,
        l10n.normalize_audio,
        l10n.endless_playback,
        l10n.enable_connect,
        l10n.blacklist,
        l10n.streaming_music_format,
        l10n.streaming_music_quality,
        'lecture',
        'audio',
        'moteur',
        'engine',
        'cache',
        'normalisation',
        'blacklist',
        'connect',
      ]),
      _MusicSettingsSection(const SettingsDownloadsSection(), [
        l10n.downloads,
        l10n.download_location,
        'téléchargement',
        'download',
        'dossier',
        'folder',
      ]),
      if (kIsDesktop)
        _MusicSettingsSection(const SettingsDesktopSection(), [
          l10n.desktop,
          l10n.close_behavior,
          l10n.show_tray_icon,
          l10n.use_system_title_bar,
          l10n.discord_rich_presence,
          'bureau',
          'desktop',
          'tray',
          'discord',
        ]),
      _MusicSettingsSection(const SettingsAboutSection(), [
        l10n.about,
        l10n.check_for_updates,
        'à propos',
        'about',
        'version',
        'mise à jour',
        'update',
      ]),
    ];

    final q = query.value.trim().toLowerCase();
    final visible = q.isEmpty
        ? sections
        : sections.where((section) => section.matches(q)).toList();

    return SettingsSubpageScaffold(
      title: l10n.settings,
      searchHint: l10n.search,
      onSearchChanged: (value) => query.value = value,
      // The music module lives in its own nested router, so the back action has
      // to pop that stack instead of go_router's.
      leading: const MusicBackButton(),
      slivers: [
        if (visible.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Broken.search_normal,
                      size: 42,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.nothing_found,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else ...[
          for (final section in visible)
            SliverToBoxAdapter(child: section.child),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Center(
                child: FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                    backgroundColor: theme.colorScheme.errorContainer,
                  ),
                  onPressed: preferencesNotifier.reset,
                  child: Text(l10n.restore_defaults),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
