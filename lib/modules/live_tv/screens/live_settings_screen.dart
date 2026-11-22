import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/modules/live_tv/data/live_favorites_store.dart';
import 'package:watchtower/modules/live_tv/epg/epg_providers.dart';
import 'package:watchtower/modules/live_tv/models/live_provider.dart';
import 'package:watchtower/modules/live_tv/providers/live_providers.dart';
import 'package:watchtower/modules/live_tv/screens/live_catalog_sheet.dart';
import 'package:watchtower/modules/live_tv/screens/live_channels_screen.dart';
import 'package:watchtower/modules/live_tv/screens/live_provider_form_sheet.dart';
import 'package:watchtower/modules/live_tv/widgets/live_common.dart';

/// Live TV settings: providers, guide source, favourites, storage.
///
/// Providers are toggled here but installed from the Marketplace, so this
/// screen never offers a catalogue: it only manages what is already present.
class LiveSettingsScreen extends ConsumerWidget {
  const LiveSettingsScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final providers = ref.watch(liveProvidersProvider);
    final stats = ref.watch(liveFetchStatsProvider);
    final epg = ref.watch(epgProvider);
    final favorites = ref.watch(liveFavoritesProvider);
    final body = ListView(
      padding: const EdgeInsets.only(bottom: 28),
      children: [
        const LiveSectionTitle(
          title: 'Fournisseurs',
          subtitle: 'Activer, désactiver ou ajouter une liste',
        ),
        if (providers.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('Aucun fournisseur installé.'),
          )
        else
          for (final provider in providers)
            _ProviderTile(
              provider: provider,
              stat: stats[provider.id]?.channelCount,
              onOpen: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => LiveChannelsScreen(provider: provider),
                ),
              ),
              onToggle: (value) => ref
                  .read(liveProvidersProvider.notifier)
                  .setEnabled(provider.id, value),
              onRemove: provider.isBuiltin
                  ? null
                  : () => ref
                        .read(liveProvidersProvider.notifier)
                        .remove(provider.id),
            ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _addProvider(context, ref),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Ajouter'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _browseCatalog(context),
                  icon: const Icon(Icons.storefront_rounded, size: 18),
                  label: const Text('Catalogue'),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: OutlinedButton.icon(
            onPressed: () => _checkUpdates(context, ref),
            icon: const Icon(Icons.sync_rounded, size: 18),
            label: const Text('Vérifier les mises à jour'),
          ),
        ),
        const Divider(height: 32),
        const LiveSectionTitle(
          title: 'Guide des programmes',
          subtitle: 'EPG pour « en ce moment » et la grille',
        ),
        _GuideTile(state: epg, onRefresh: _refresh, onClear: _clear),
        const Divider(height: 32),
        const LiveSectionTitle(title: 'Favoris'),
        ListTile(
          leading: const Icon(Icons.star_rounded),
          title: Text('${favorites.length} chaîne(s) en favori'),
          trailing: favorites.isEmpty
              ? null
              : TextButton(
                  onPressed: () =>
                      ref.read(liveFavoritesProvider.notifier).clear(),
                  child: const Text('Tout retirer'),
                ),
        ),
        const Divider(height: 32),
        const LiveSectionTitle(title: 'Stockage'),
        ListTile(
          leading: const Icon(Icons.storage_rounded),
          title: const Text('Guide en cache'),
          subtitle: Text(_storageLabel(epg)),
        ),
      ],
    );
    if (embedded) return body;
    return Scaffold(
      appBar: AppBar(title: const Text('Réglages Live TV')),
      body: body,
    );
  }

  static String _storageLabel(EpgState state) {
    final guide = state.guide;
    if (guide == null) return 'Aucun guide téléchargé';
    final size = guide.toJson().toString().length;
    final mb = (size / (1024 * 1024)).toStringAsFixed(1);
    return '${guide.programmeCount} programmes · ${guide.channels.length} '
        'chaînes · ~$mb Mo';
  }

  Future<void> _browseCatalog(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const LiveCatalogSheet(),
    );
  }

  Future<void> _checkUpdates(BuildContext context, WidgetRef ref) async {
    final updated = await ref
        .read(liveProvidersProvider.notifier)
        .checkForUpdates();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          updated.isEmpty
              ? 'Tous les fournisseurs sont à jour.'
              : 'Mis à jour : ${updated.map((p) => p.name).join(', ')}.',
        ),
      ),
    );
  }

  Future<void> _addProvider(BuildContext context, WidgetRef ref) async {
    final created = await showModalBottomSheet<LiveProvider>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const LiveProviderFormSheet(),
    );
    if (created == null) return;
    await ref.read(liveProvidersProvider.notifier).add(created);
  }

  Future<void> _refresh(BuildContext context, WidgetRef ref) async {
    final state = ref.read(epgProvider);
    if (state.sourceUrl == null) {
      await ref.read(epgProvider.notifier).load(epgSources.first);
    } else {
      await ref.read(epgProvider.notifier).refresh();
    }
    if (!context.mounted) return;
    final error = ref.read(epgProvider).error;
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Guide : $error')));
    }
  }

  Future<void> _clear(BuildContext context, WidgetRef ref) async {
    await ref.read(epgProvider.notifier).clear();
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Guide supprimé.')));
  }
}

class _ProviderTile extends StatelessWidget {
  const _ProviderTile({
    required this.provider,
    required this.stat,
    required this.onOpen,
    required this.onToggle,
    required this.onRemove,
  });

  final LiveProvider provider;
  final int? stat;
  final VoidCallback onOpen;
  final ValueChanged<bool> onToggle;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      value: provider.isEnabled,
      onChanged: onToggle,
      secondary: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.live_tv_rounded),
          if (onRemove != null) ...[
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Supprimer',
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
            ),
          ],
        ],
      ),
      title: InkWell(onTap: onOpen, child: Text(provider.name)),
      subtitle: Text(
        [
          'v${provider.version}',
          if (stat != null && stat! > 0) '$stat chaînes',
          if (provider.isBuiltin) 'intégré',
        ].join(' · '),
      ),
    );
  }
}

class _GuideTile extends StatelessWidget {
  const _GuideTile({
    required this.state,
    required this.onRefresh,
    required this.onClear,
  });

  final EpgState state;
  final Future<void> Function(BuildContext, WidgetRef) onRefresh;
  final Future<void> Function(BuildContext, WidgetRef) onClear;

  @override
  Widget build(BuildContext context) {
    final guide = state.guide;
    return Consumer(
      builder: (context, ref, _) => ListTile(
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Télécharger / rafraîchir',
              onPressed: state.loading ? null : () => onRefresh(context, ref),
              icon: const Icon(Icons.download_rounded),
            ),
            if (guide != null)
              IconButton(
                tooltip: 'Supprimer',
                onPressed: () => onClear(context, ref),
                icon: const Icon(Icons.delete_outline_rounded),
              ),
          ],
        ),
        leading: state.loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.calendar_month_rounded),
        title: Text(guide?.source ?? 'Aucun guide'),
        subtitle: Text(
          state.loading
              ? 'Lecture… ${state.progress} programmes'
              : guide == null
              ? 'Téléchargez un guide pour activer la grille'
              : '${guide.programmeCount} programmes · '
                    'mis à jour ${dayLabel(guide.fetchedAt, DateTime.now())}',
        ),
      ),
    );
  }
}
