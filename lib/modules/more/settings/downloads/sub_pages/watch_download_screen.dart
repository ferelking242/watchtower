import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io'
    if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'package:watchtower/l10n/generated/app_localizations.dart';
import 'package:watchtower/modules/more/settings/downloads/providers/downloads_state_provider.dart';
import 'package:watchtower/modules/more/settings/widgets/settings_subpage_scaffold.dart';
import 'package:watchtower/services/download_manager/download_settings_service.dart';
import 'package:watchtower/services/download_manager/external_downloader_launcher.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/utils/extensions/build_context_extensions.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Watch download settings sub-page
// ─────────────────────────────────────────────────────────────────────────────

class WatchDownloadScreen extends ConsumerWidget {
  const WatchDownloadScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final downloadMode = ref.watch(downloadModeStateProvider);
    final animeConnections = ref.watch(animeConnectionsStateProvider);
    final watchSimultaneous = ref.watch(watchSimultaneousStateProvider);
    final watchOnlyOnWifi = ref.watch(watchOnlyOnWifiStateProvider);
    final autoDownloadNewEpisodes = ref.watch(
      autoDownloadNewEpisodesStateProvider,
    );
    final downloadFillerEpisodes = ref.watch(
      downloadFillerEpisodesStateProvider,
    );
    final anticipatoryDownload = ref.watch(
      anticipatoryDownloadWatchStateProvider,
    );
    final alwaysUseExternal = ref.watch(
      alwaysUseExternalDownloaderStateProvider,
    );
    final preferredExternal = ref.watch(
      preferredExternalDownloaderStateProvider,
    );

    return SettingsSubpageScaffold(
      title: l10n.downloads_watch_title,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Moteur de téléchargement ────────────────────────────────
            _SectionHeader(title: l10n.downloads_engine_section),
            ...DownloadMode.values.map(
              (mode) => _EngineCard(
                mode: mode,
                selected: downloadMode == mode,
                onTap: () =>
                    ref.read(downloadModeStateProvider.notifier).set(mode),
              ),
            ),

            // ── Connexions ──────────────────────────────────────────────
            _SectionHeader(title: l10n.downloads_connections_section),
            _ConnectionsTile(
              label: l10n.downloads_hls_connections,
              subtitle: l10n.downloads_hls_connections_subtitle,
              value: animeConnections,
              icon: Broken.link,
              onChanged: (v) =>
                  ref.read(animeConnectionsStateProvider.notifier).set(v),
              scheme: scheme,
            ),
            _ConnectionsTile(
              label: l10n.downloads_episodes_queue,
              subtitle: l10n.downloads_episodes_queue_subtitle,
              value: watchSimultaneous,
              icon: Broken.note_2,
              onChanged: (v) =>
                  ref.read(watchSimultaneousStateProvider.notifier).set(v),
              scheme: scheme,
            ),

            // ── Comportement ────────────────────────────────────────────
            _SectionHeader(title: l10n.downloads_behavior_section),
            SwitchListTile(
              dense: true,
              secondary: const Icon(Broken.wifi),
              title: Text(l10n.downloads_wifi_only),
              subtitle: Text(
                l10n.downloads_wifi_only_subtitle,
                style: const TextStyle(fontSize: 11),
              ),
              value: watchOnlyOnWifi,
              onChanged: (v) =>
                  ref.read(watchOnlyOnWifiStateProvider.notifier).set(v),
            ),
            SwitchListTile(
              dense: true,
              secondary: const Icon(Broken.magic_star),
              title: Text(l10n.downloads_new_episodes),
              subtitle: Text(
                l10n.downloads_new_episodes_subtitle,
                style: const TextStyle(fontSize: 11),
              ),
              value: autoDownloadNewEpisodes,
              onChanged: (v) => ref
                  .read(autoDownloadNewEpisodesStateProvider.notifier)
                  .set(v),
            ),
            SwitchListTile(
              dense: true,
              secondary: const Icon(Broken.filter),
              title: Text(l10n.downloads_filler),
              subtitle: Text(
                l10n.downloads_filler_subtitle,
                style: const TextStyle(fontSize: 11),
              ),
              value: downloadFillerEpisodes,
              onChanged: (v) =>
                  ref.read(downloadFillerEpisodesStateProvider.notifier).set(v),
            ),
            SwitchListTile(
              dense: true,
              secondary: const Icon(Broken.forward),
              title: Text(l10n.downloads_anticipatory),
              subtitle: Text(
                l10n.downloads_anticipatory_watch_subtitle,
                style: const TextStyle(fontSize: 10),
              ),
              value: anticipatoryDownload,
              onChanged: (v) => ref
                  .read(anticipatoryDownloadWatchStateProvider.notifier)
                  .set(v),
            ),

            // ── Téléchargeur externe ────────────────────────────────────
            _SectionHeader(title: l10n.downloads_external_section),
            SwitchListTile(
              dense: true,
              secondary: const Icon(Broken.export),
              title: Text(l10n.downloads_always_external),
              subtitle: Text(
                l10n.downloads_always_external_subtitle,
                style: const TextStyle(fontSize: 11),
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
        return Broken.document_download;
      case DownloadMode.aria2:
        return Broken.hierarchy;
      case DownloadMode.external:
        return Broken.export;
      case DownloadMode.zeus:
        return Broken.cpu;
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
          color: selected
              ? scheme.primary
              : scheme.outline.withValues(alpha: 0.3),
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
                      ? scheme.primary.withValues(alpha: 0.15)
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
                          mode.label(context.l10n),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: selected ? scheme.primary : scheme.onSurface,
                          ),
                        ),
                        if (mode.isDefault) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              context.l10n.downloads_default_folder,
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
                      mode.description(context.l10n),
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(Broken.tick_circle, color: scheme.primary, size: 20),
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
            color: scheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$value',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: scheme.primary,
            ),
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
                child: Text(
                  context.l10n.cancel,
                  style: TextStyle(color: context.primaryColor),
                ),
              ),
              TextButton(
                onPressed: () {
                  onChanged(currentValue);
                  Navigator.pop(context);
                },
                child: Text(
                  'OK',
                  style: TextStyle(color: context.primaryColor),
                ),
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
        name: '',
        descriptionKey: '',
      ),
    );
    final hasSelection = preferredExternal != null && selected.id.isNotEmpty;
    final noAppName = context.l10n.downloads_no_app;
    final noAppDesc = context.l10n.downloads_no_app_subtitle;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: scheme.outline.withValues(alpha: 0.25)),
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
                        ? scheme.primary.withValues(alpha: 0.12)
                        : scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    hasSelection
                        ? Broken.export
                        : Broken.category,
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
                        context.l10n.downloads_preferred_app,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasSelection ? selected.name : noAppName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: hasSelection
                              ? scheme.onSurface
                              : scheme.onSurface.withValues(alpha: 0.5),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasSelection
                            ? _externalDownloaderDescription(
                                context.l10n,
                                selected.descriptionKey,
                              )
                            : noAppDesc,
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
                Icon(Broken.edit, size: 18, color: scheme.primary),
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
        title: Text(context.l10n.downloads_preferred_app),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              RadioGroup<String?>(
                groupValue: preferredExternal,
                onChanged: (v) {
                  onChanged(null);
                  Navigator.pop(ctx);
                },
                child: RadioListTile<String?>(
                  title: Text(context.l10n.downloads_none_app),
                  value: null,
                ),
              ),
              ...apps.map(
                (app) => _ExternalAppTile(
                  app: app,
                  selected: preferredExternal == app.id,
                  onSelect: () {
                    onChanged(app.id);
                    Navigator.pop(ctx);
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.cancel),
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
  final String descriptionKey;

  const _ExternalDownloaderApp({
    required this.id,
    required this.name,
    required this.descriptionKey,
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
      descriptionKey: 'downloads_ext_adm_desc',
      androidPackage: 'com.dv.adm',
      playStoreUrl: 'https://play.google.com/store/apps/details?id=com.dv.adm',
    ),
    _ExternalDownloaderApp(
      id: '1dm',
      name: '1DM — 1Downloader',
      descriptionKey: 'downloads_ext_1dm_desc',
      androidPackage: 'idm.internet.download.manager',
      playStoreUrl:
          'https://play.google.com/store/apps/details?id=idm.internet.download.manager',
      appStoreUrl:
          'https://apps.apple.com/app/1downloader-download-manager/id1451985776',
    ),
    _ExternalDownloaderApp(
      id: 'fdm',
      name: 'FDM — Free Download Manager',
      descriptionKey: 'downloads_ext_fdm_desc',
      androidPackage: 'org.freedownloadmanager.fdm',
      playStoreUrl:
          'https://play.google.com/store/apps/details?id=org.freedownloadmanager.fdm',
      pcUrl: 'https://www.freedownloadmanager.org/',
    ),
    _ExternalDownloaderApp(
      id: 'idm',
      name: 'IDM — Internet Download Manager',
      descriptionKey: 'downloads_ext_idm_desc',
      pcUrl: 'https://www.internetdownloadmanager.com/',
    ),
    _ExternalDownloaderApp(
      id: 'jdownloader',
      name: 'JDownloader',
      descriptionKey: 'downloads_ext_jdownloader_desc',
      pcUrl: 'https://jdownloader.org/',
    ),
    _ExternalDownloaderApp(
      id: 'motrix',
      name: 'Motrix',
      descriptionKey: 'downloads_ext_motrix_desc',
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
      leading: RadioGroup<bool>(
        groupValue: selected,
        onChanged: (_) => onSelect(),
        child: Radio<bool>(value: true),
      ),
      title: Text(app.name, style: const TextStyle(fontSize: 13)),
      subtitle: Text(
        _externalDownloaderDescription(context.l10n, app.descriptionKey),
        style: const TextStyle(fontSize: 11),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!kIsWeb &&
              Platform.isAndroid &&
              ExternalDownloaderLauncher.packageMap.containsKey(app.id))
            IconButton(
              icon: const Icon(Broken.play, size: 20),
              tooltip: context.l10n.downloads_test_launch(app.name),
              onPressed: () async {
                final ok = await ExternalDownloaderLauncher.launch(
                  url:
                      'https://download.blender.org/peach/bigbuckbunny_movies/BigBuckBunny_320x180.mp4',
                  appId: app.id,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      duration: const Duration(seconds: 2),
                      content: Text(
                        ok
                            ? context.l10n.downloads_launched(app.name)
                            : context.l10n.downloads_launch_failed(app.name),
                      ),
                    ),
                  );
                }
              },
            ),
          if (app.playStoreUrl != null)
            IconButton(
              icon: const Icon(Broken.shop, size: 18),
              tooltip: 'Google Play',
              onPressed: () => launchUrl(Uri.parse(app.playStoreUrl!)),
            ),
          if (app.appStoreUrl != null)
            IconButton(
              icon: const Icon(Broken.shopping_bag, size: 18),
              tooltip: 'App Store',
              onPressed: () => launchUrl(Uri.parse(app.appStoreUrl!)),
            ),
          if (app.pcUrl != null)
            IconButton(
              icon: const Icon(Broken.monitor, size: 18),
              tooltip: context.l10n.downloads_official_site,
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
          icon: const Icon(Broken.minus_cirlce),
        ),
        Container(
          width: 60,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.12),
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
          icon: const Icon(Broken.add_circle),
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

/// Resolves an external-downloader description key to its localised text.
String _externalDownloaderDescription(AppLocalizations l10n, String key) {
  return switch (key) {
    'downloads_ext_adm_desc' => l10n.downloads_ext_adm_desc,
    'downloads_ext_1dm_desc' => l10n.downloads_ext_1dm_desc,
    'downloads_ext_fdm_desc' => l10n.downloads_ext_fdm_desc,
    'downloads_ext_idm_desc' => l10n.downloads_ext_idm_desc,
    'downloads_ext_jdownloader_desc' => l10n.downloads_ext_jdownloader_desc,
    'downloads_ext_motrix_desc' => l10n.downloads_ext_motrix_desc,
    _ => '',
  };
}
