import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/modules/live_tv/data/live_provider_store.dart';
import 'package:watchtower/modules/live_tv/models/live_provider.dart';
import 'package:watchtower/modules/live_tv/providers/live_providers.dart';
import 'package:watchtower/modules/live_tv/screens/live_channels_screen.dart';
import 'package:watchtower/modules/live_tv/screens/live_catalog_sheet.dart';
import 'package:watchtower/modules/live_tv/screens/live_provider_form_sheet.dart';

/// Live TV home: the installed providers, the way Browse lists extensions.
///
/// This is the surface the "film et série" hub button opens. It shows providers
/// rather than channels so the page stays fast: a playlist is only downloaded
/// when a provider is opened.
class LiveTvScreen extends ConsumerWidget {
  const LiveTvScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final providers = ref.watch(liveProvidersProvider);
    final stats = ref.watch(liveFetchStatsProvider);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.media_live_tv),
        actions: [
          IconButton(
            tooltip: 'Vérifier les mises à jour',
            onPressed: () => _checkUpdates(context, ref),
            icon: const Icon(Broken.refresh),
          ),
          IconButton(
            tooltip: 'Parcourir le catalogue',
            onPressed: () => _browseCatalog(context),
            icon: const Icon(Broken.category),
          ),
          IconButton(
            tooltip: 'Ajouter un fournisseur',
            onPressed: () => _addProvider(context, ref),
            icon: const Icon(Broken.add),
          ),
        ],
      ),
      body: providers.isEmpty
          ? _EmptyState(onAdd: () => _addProvider(context, ref))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              itemCount: providers.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) => _ProviderCard(
                provider: providers[index],
                stat: stats[providers[index].id],
                onTap: () => _openProvider(context, providers[index]),
                onToggle: (enabled) => ref
                    .read(liveProvidersProvider.notifier)
                    .setEnabled(providers[index].id, enabled),
                onRemove: () => _removeProvider(context, ref, providers[index]),
              ),
            ),
    );
  }

  void _openProvider(BuildContext context, LiveProvider provider) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LiveChannelsScreen(provider: provider),
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
    if (!context.mounted) return;
    _toast(context, '« ${created.name} » ajouté.');
  }

  Future<void> _browseCatalog(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const LiveCatalogSheet(),
    );
  }

  Future<void> _removeProvider(
    BuildContext context,
    WidgetRef ref,
    LiveProvider provider,
  ) async {
    if (provider.isBuiltin) {
      _toast(context, 'Un fournisseur intégré se désactive, il ne se supprime pas.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer ce fournisseur ?'),
        content: Text(provider.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(liveProvidersProvider.notifier).remove(provider.id);
    if (!context.mounted) return;
    _toast(context, '« ${provider.name} » supprimé.');
  }

  Future<void> _checkUpdates(BuildContext context, WidgetRef ref) async {
    final updated = await ref
        .read(liveProvidersProvider.notifier)
        .checkForUpdates();
    if (!context.mounted) return;
    _toast(
      context,
      updated.isEmpty
          ? 'Tous les fournisseurs sont à jour.'
          : 'Mis à jour : ${updated.map((p) => p.name).join(', ')}.',
    );
  }

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ProviderCard extends StatelessWidget {
  const _ProviderCard({
    required this.provider,
    required this.stat,
    required this.onTap,
    required this.onToggle,
    required this.onRemove,
  });

  final LiveProvider provider;
  final LiveFetchStat? stat;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: provider.isEnabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          child: Row(
            children: [
              _ProviderAvatar(provider: provider),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            provider.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (provider.isBuiltin)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: _Badge(
                              label: 'intégré',
                              color: theme.colorScheme.primary,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _subtitle(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(value: provider.isEnabled, onChanged: onToggle),
              IconButton(
                tooltip: provider.isBuiltin
                    ? 'Fournisseur intégré'
                    : 'Supprimer',
                onPressed: provider.isBuiltin ? null : onRemove,
                icon: Icon(
                  Broken.trash,
                  size: 20,
                  color: provider.isBuiltin
                      ? theme.disabledColor
                      : theme.colorScheme.error,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _subtitle() {
    final parts = <String>['v${provider.version}'];
    final count = stat?.channelCount;
    if (count != null && count > 0) {
      parts.add('$count chaînes');
    }
    final description = provider.description;
    if (description != null && description.isNotEmpty) {
      return '${parts.join(' · ')}\n$description';
    }
    return parts.join(' · ');
  }
}

class _ProviderAvatar extends StatelessWidget {
  const _ProviderAvatar({required this.provider});

  final LiveProvider provider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = switch (provider.kind) {
      LiveProviderKind.m3u => Broken.video_play,
      LiveProviderKind.xtream => Broken.lock,
      LiveProviderKind.json => Broken.document_text,
      LiveProviderKind.bundled => Broken.folder,
    };
    final url = provider.iconUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 46,
        height: 46,
        child: url != null && url.isNotEmpty
            ? Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _fallback(theme, icon),
              )
            : _fallback(theme, icon),
      ),
    );
  }

  Widget _fallback(ThemeData theme, IconData icon) {
    return ColoredBox(
      color: theme.colorScheme.primaryContainer,
      child: Icon(icon, color: theme.colorScheme.onPrimaryContainer, size: 24),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Broken.video_play, size: 56, color: theme.disabledColor),
            const SizedBox(height: 18),
            Text(
              'Aucun fournisseur actif',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Activez un fournisseur intégré, installez-en un depuis le '
              'catalogue, ou ajoutez le vôtre.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Broken.add),
              label: const Text('Ajouter un fournisseur'),
            ),
          ],
        ),
      ),
    );
  }
}
