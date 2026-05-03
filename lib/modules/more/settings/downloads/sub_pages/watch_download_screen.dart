import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'package:watchtower/modules/more/settings/downloads/providers/downloads_state_provider.dart';
import 'package:watchtower/services/download_manager/download_settings_service.dart';
import 'package:watchtower/services/download_manager/external_downloader_launcher.dart';
import 'package:watchtower/utils/extensions/build_context_extensions.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Watch download settings sub-page
// ─────────────────────────────────────────────────────────────────────────────

class WatchDownloadScreen extends ConsumerWidget {
  const WatchDownloadScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final downloadMode = ref.watch(downloadModeStateProvider);
    final animeConnections = ref.watch(animeConnectionsStateProvider);
    final watchSimultaneous = ref.watch(watchSimultaneousStateProvider);
    final watchOnlyOnWifi = ref.watch(watchOnlyOnWifiStateProvider);
    final autoDownloadNewEpisodes =
        ref.watch(autoDownloadNewEpisodesStateProvider);
    final downloadFillerEpisodes =
        ref.watch(downloadFillerEpisodesStateProvider);
    final anticipatoryDownload =
        ref.watch(anticipatoryDownloadWatchStateProvider);
    final alwaysUseExternal =
        ref.watch(alwaysUseExternalDownloaderStateProvider);
    final preferredExternal =
        ref.watch(preferredExternalDownloaderStateProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Téléchargements — Watch')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Moteur de téléchargement ────────────────────────────────
            _SectionHeader(title: 'Moteur de téléchargement'),
            ...DownloadMode.values.map(
              (mode) => _EngineCard(
                mode: mode,
                selected: downloadMode == mode,
                onTap: () => ref
                    .read(downloadModeStateProvider.notifier)
                    .set(mode),
              ),
            ),

            // ── Connexions ──────────────────────────────────────────────
            _SectionHeader(title: 'Connexions'),
            _ConnectionsTile(
              label: 'Connexions HLS simultanées',
              subtitle: 'Segments téléchargés en parallèle par épisode',
              value: animeConnections,
              icon: Icons.cable_outlined,
              onChanged: (v) =>
                  ref.read(animeConnectionsStateProvider.notifier).set(v),
              scheme: scheme,
            ),
            _ConnectionsTile(
              label: 'Épisodes simultanés (file)',
              subtitle: 'Nombre d\'épisodes téléchargés en même temps',
              value: watchSimultaneous,
              icon: Icons.queue_outlined,
              onChanged: (v) =>
                  ref.read(watchSimultaneousStateProvider.notifier).set(v),
              scheme: scheme,
            ),

            // ── Comportement ────────────────────────────────────────────
            _SectionHeader(title: 'Comportement'),
            SwitchListTile(
              dense: true,
              secondary: const Icon(Icons.wifi_outlined),
              title: const Text('Wi-Fi uniquement'),
              subtitle: const Text(
                'Télécharger uniquement via Wi-Fi',
                style: TextStyle(fontSize: 11),
              ),
              value: watchOnlyOnWifi,
              onChanged: (v) =>
                  ref.read(watchOnlyOnWifiStateProvider.notifier).set(v),
            ),
            SwitchListTile(
              dense: true,
              secondary: const Icon(Icons.new_releases_outlined),
              title: const Text('Télécharger les nouveaux épisodes'),
              subtitle: const Text(
                'Télécharge automatiquement les nouveaux épisodes disponibles',
                style: TextStyle(fontSize: 11),
              ),
              value: autoDownloadNewEpisodes,
              onChanged: (v) => ref
                  .read(autoDownloadNewEpisodesStateProvider.notifier)
                  .set(v),
            ),
            SwitchListTile(
              dense: true,
              secondary: const Icon(Icons.filter_list_outlined),
              title: const Text('Autoriser les épisodes filler'),
              subtitle: const Text(
                'Inclure les épisodes filler dans les téléchargements automatiques',
                style: TextStyle(fontSize: 11),
              ),
              value: downloadFillerEpisodes,
              onChanged: (v) => ref
                  .read(downloadFillerEpisodesStateProvider.notifier)
                  .set(v),
            ),
            SwitchListTile(
              dense: true,
              secondary: const Icon(Icons.fast_forward_outlined),
              title: const Text('Téléchargement anticipé'),
              subtitle: const Text(
                'Pré-télécharge pendant le visionnage si les 2 éps suivants sont disponibles',
                style: TextStyle(fontSize: 10),
              ),
              value: anticipatoryDownload,
              onChanged: (v) => ref
                  .read(anticipatoryDownloadWatchStateProvider.notifier)
                  .set(v),
            ),

            // ── Téléchargeur externe ────────────────────────────────────
            _SectionHeader(title: 'Téléchargeur externe'),
            SwitchListTile(
              dense: true,
              secondary: const Icon(Icons.open_in_new_outlined),
              title: const Text('Toujours utiliser un téléchargeur externe'),
              subtitle: const Text(
                'Délègue chaque téléchargement à l\'app externe choisie ci-dessous',
                style: TextStyle(fontSize: 11),
              ),
              value: alwaysUseExternal,
              onChanged: (v) => ref
                  .read(alwaysUseExternalDownloaderStateProvider.notifier)
                  .set(v),
            ),
            _ExternalDownloaderCard(
              preferredExternal: preferredExternal,
              scheme: scheme,
              onChanged: (v) => ref
                  .read(preferredExternalDownloaderStateProvider.notifier)
                  .set(v),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Engine card
// ─────────────────────────────────────────────────────────────────────────────

class _EngineCard extends StatelessWidget {
  final DownloadMode mode;
  final bool selected;
  final VoidCallback onTap;

  const _EngineCard({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  IconData get _icon {
    switch (mode) {
      case DownloadMode.internalDownloader:
        return Icons.download_outlined;
      case DownloadMode.zeusDl:
        return Icons.bolt_outlined;
      case DownloadMode.aria2:
        return Icons.account_tree_outlined;
      case DownloadMode.external:
        return Icons.open_in_new_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: selected ? 2 : 0,
      margin: const EdgeInsets.symmetric(vertical: 3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: selected ? scheme.primary : scheme.outline.withOpacity(0.3),
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: selected
                      ? scheme.primary.withOpacity(0.15)
                      : scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _icon,
                  color: selected ? scheme.primary : scheme.onSurfaceVariant,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          mode.label,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: selected
                                ? scheme.primary
                                : scheme.onSurface,
                          ),
                        ),
                        if (mode.isDefault) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: scheme.primary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Défaut',
                              style: TextStyle(
                                fontSize: 9,
                                color: scheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      mode.description,
                      style: TextStyle(
                          fontSize: 11, color: scheme.onSurfaceVariant),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle, color: scheme.primary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Connections tile
// ─────────────────────────────────────────────────────────────────────────────

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
    return ListTile(
      leading: Icon(icon, color: scheme.primary),
      title: Text(label, style: const TextStyle(fontSize: 13)),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
      ),
      trailing: GestureDetector(
        onTap: () => _showPicker(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: scheme.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$value',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: scheme.primary),
          ),
        ),
      ),
      onTap: () => _showPicker(context),
    );
  }

  void _showPicker(BuildContext context) {
    int currentValue = value;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(label),
        content: StatefulBuilder(
          builder: (context, setState) => SizedBox(
            height: 180,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _NumberPickerSimple(
                  value: currentValue,
                  min: 1,
                  max: 16,
                  onChanged: (v) => setState(() => currentValue = v),
                ),
              ],
            ),
          ),
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Annuler',
                    style: TextStyle(color: context.primaryColor)),
              ),
              TextButton(
                onPressed: () {
                  onChanged(currentValue);
                  Navigator.pop(context);
                },
                child: Text('OK',
                    style: TextStyle(color: context.primaryColor)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// External downloader card
// ─────────────────────────────────────────────────────────────────────────────

class _ExternalDownloaderCard extends StatelessWidget {
  final String? preferredExternal;
  final ColorScheme scheme;
  final void Function(String?) onChanged;

  const _ExternalDownloaderCard({
    required this.preferredExternal,
    required this.scheme,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selected = _ExternalDownloaderRegistry.all.firstWhere(
      (a) => a.id == preferredExternal,
      orElse: () => const _ExternalDownloaderApp(
        id: '',
        name: 'Aucune app sélectionnée',
        description: 'L\'application demandera à chaque téléchargement.',
      ),
    );
    final hasSelection =
        preferredExternal != null && selected.id.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: scheme.outline.withOpacity(0.25)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _showPicker(context),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: hasSelection
                        ? scheme.primary.withOpacity(0.12)
                        : scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    hasSelection
                        ? Icons.open_in_new_rounded
                        : Icons.apps_outlined,
                    color: hasSelection
                        ? scheme.primary
                        : scheme.onSurfaceVariant,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'App de téléchargement préférée',
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        selected.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: hasSelection
                              ? scheme.onSurface
                              : scheme.onSurface.withOpacity(0.5),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        selected.description,
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSurfaceVariant,
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.edit_outlined, size: 18, color: scheme.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    final apps = _ExternalDownloaderRegistry.all;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('App de téléchargement préférée'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              RadioListTile<String?>(
                title: const Text('Aucune'),
                value: null,
                groupValue: preferredExternal,
                onChanged: (v) {
                  onChanged(null);
                  Navigator.pop(ctx);
                },
              ),
              ...apps.map((app) => _ExternalAppTile(
                    app: app,
                    selected: preferredExternal == app.id,
                    onSelect: () {
                      onChanged(app.id);
                      Navigator.pop(ctx);
                    },
                  )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
        ],
      ),
    );
  }
}

class _ExternalDownloaderApp {
  final String id;
  final String name;
  final String? androidPackage;
  final String? playStoreUrl;
  final String? appStoreUrl;
  final String? pcUrl;
  final String description;

  const _ExternalDownloaderApp({
    required this.id,
    required this.name,
    required this.description,
    this.androidPackage,
    this.playStoreUrl,
    this.appStoreUrl,
    this.pcUrl,
  });
}

class _ExternalDownloaderRegistry {
  static const all = [
    _ExternalDownloaderApp(
      id: 'adm',
      name: 'ADM — Advanced Download Manager',
      description: 'Gestionnaire de téléchargement multi-thread pour Android.',
      androidPackage: 'com.dv.adm',
      playStoreUrl:
          'https://play.google.com/store/apps/details?id=com.dv.adm',
    ),
    _ExternalDownloaderApp(
      id: '1dm',
      name: '1DM — 1Downloader',
      description:
          'Téléchargeur rapide avec support HLS et DASH pour Android.',
      androidPackage: 'idm.internet.download.manager',
      playStoreUrl:
          'https://play.google.com/store/apps/details?id=idm.internet.download.manager',
      appStoreUrl:
          'https://apps.apple.com/app/1downloader-download-manager/id1451985776',
    ),
    _ExternalDownloaderApp(
      id: 'fdm',
      name: 'FDM — Free Download Manager',
      description: 'Téléchargeur multiplateforme gratuit et open-source.',
      androidPackage: 'org.freedownloadmanager.fdm',
      playStoreUrl:
          'https://play.google.com/store/apps/details?id=org.freedownloadmanager.fdm',
      pcUrl: 'https://www.freedownloadmanager.org/',
    ),
    _ExternalDownloaderApp(
      id: 'idm',
      name: 'IDM — Internet Download Manager',
      description: 'Téléchargeur haute vitesse avec reprise (Windows).',
      pcUrl: 'https://www.internetdownloadmanager.com/',
    ),
    _ExternalDownloaderApp(
      id: 'jdownloader',
      name: 'JDownloader',
      description: 'Téléchargeur open-source multiplateforme très populaire.',
      pcUrl: 'https://jdownloader.org/',
    ),
    _ExternalDownloaderApp(
      id: 'motrix',
      name: 'Motrix',
      description: 'Téléchargeur Aria2 open-source avec interface moderne.',
      pcUrl: 'https://motrix.app/',
    ),
  ];
}

class _ExternalAppTile extends StatelessWidget {
  final _ExternalDownloaderApp app;
  final bool selected;
  final VoidCallback onSelect;

  const _ExternalAppTile({
    required this.app,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Radio<bool>(
        value: true,
        groupValue: selected,
        onChanged: (_) => onSelect(),
      ),
      title: Text(app.name, style: const TextStyle(fontSize: 13)),
      subtitle: Text(app.description, style: const TextStyle(fontSize: 11)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (Platform.isAndroid &&
              ExternalDownloaderLauncher.packageMap.containsKey(app.id))
            IconButton(
              icon: const Icon(Icons.play_arrow_rounded, size: 20),
              tooltip: 'Tester (lance ${app.name})',
              onPressed: () async {
                final ok = await ExternalDownloaderLauncher.launch(
                  url:
                      'https://download.blender.org/peach/bigbuckbunny_movies/BigBuckBunny_320x180.mp4',
                  appId: app.id,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    duration: const Duration(seconds: 2),
                    content: Text(ok
                        ? '${app.name} lancé via intent'
                        : 'Échec du lancement de ${app.name} (app installée ?)'),
                  ));
                }
              },
            ),
          if (app.playStoreUrl != null)
            IconButton(
              icon: const Icon(Icons.android_outlined, size: 18),
              tooltip: 'Google Play',
              onPressed: () => launchUrl(Uri.parse(app.playStoreUrl!)),
            ),
          if (app.appStoreUrl != null)
            IconButton(
              icon: const Icon(Icons.apple_outlined, size: 18),
              tooltip: 'App Store',
              onPressed: () => launchUrl(Uri.parse(app.appStoreUrl!)),
            ),
          if (app.pcUrl != null)
            IconButton(
              icon: const Icon(Icons.computer_outlined, size: 18),
              tooltip: 'Site officiel',
              onPressed: () => launchUrl(Uri.parse(app.pcUrl!)),
            ),
        ],
      ),
      onTap: onSelect,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Minimal number picker (no external package needed — inline spinner)
// ─────────────────────────────────────────────────────────────────────────────

class _NumberPickerSimple extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final void Function(int) onChanged;

  const _NumberPickerSimple({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: value > min ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove_circle_outline),
        ),
        Container(
          width: 60,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: scheme.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            '$value',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: scheme.primary,
            ),
          ),
        ),
        IconButton(
          onPressed: value < max ? () => onChanged(value + 1) : null,
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section header
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 6),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
