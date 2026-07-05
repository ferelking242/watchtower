
    import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';

    import 'package:flutter/foundation.dart';
    import 'package:flutter/material.dart';
    import 'package:go_router/go_router.dart';
    import 'package:watchtower/modules/more/widgets/list_tile_widget.dart';
    import 'package:watchtower/providers/l10n_providers.dart';

    class SettingsScreen extends StatelessWidget {
    const SettingsScreen({super.key});

    @override
    Widget build(BuildContext context) {
      final l10n = l10nLocalizations(context);
      return Scaffold(
        appBar: AppBar(title: Text(l10n!.settings)),
        body: SingleChildScrollView(
          child: Column(
            children: [
              ListTileWidget(
                title: l10n.general,
                icon: Icons.settings,
                onTap: () => context.push('/general'),
              ),
              ListTileWidget(
                title: l10n.appearance,
                icon: Icons.color_lens_rounded,
                onTap: () => context.push('/appearance'),
              ),
              ListTileWidget(
                title: 'Lecteur Manga',
                icon: Icons.chrome_reader_mode_rounded,
                onTap: () => context.push('/readerMode'),
              ),
              ListTileWidget(
                title: 'Lecteur Vidéo',
                icon: Icons.play_circle_outline_outlined,
                onTap: () => context.push('/playerOverview'),
              ),
              ListTileWidget(
                title: l10n.downloads,
                icon: Icons.download_outlined,
                onTap: () => context.push('/downloads'),
              ),
              ListTileWidget(
                title: l10n.tracking,
                icon: Icons.sync_outlined,
                onTap: () => context.push('/track'),
              ),
              ListTileWidget(
                title: l10n.syncing,
                icon: Icons.cloud_sync_outlined,
                onTap: () => context.push('/sync'),
              ),
              ListTileWidget(
                title: l10n.browse,
                icon: Icons.explore_rounded,
                onTap: () => context.push('/browseS'),
              ),
              if (kIsWeb || !Platform.isLinux)
                ListTileWidget(
                  title: l10n.security,
                  icon: Icons.security_rounded,
                  onTap: () => context.push('/security'),
                ),
              ListTileWidget(
                title: "Sources Locales",
                icon: Icons.folder_open_rounded,
                onTap: () => context.push('/localSources'),
              ),
              ListTileWidget(
                title: "Avancé",
                icon: Icons.tune_rounded,
                onTap: () => context.push('/advanced'),
              ),
              // Music Hub settings — open music hub which contains the settings
              ListTileWidget(
                title: 'Music Hub',
                icon: Icons.music_note_rounded,
                onTap: () => context.push('/MusicLibrary'),
              ),
              if (kIsWeb)
                ListTileWidget(
                  title: 'Connexion Distante',
                  icon: Icons.link_rounded,
                  onTap: () => context.push('/remoteSetup'),
                )
              else
                ListTileWidget(
                  title: 'Mode Distant',
                  icon: Icons.wifi_tethering_rounded,
                  onTap: () => context.push('/remoteMode'),
                ),
              ListTileWidget(
                title: l10n.about,
                icon: Icons.info_outline,
                onTap: () => context.push('/about'),
              ),
            ],
          ),
        ),
      );
    }
    }
    