import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/modules/live_tv/models/live_provider.dart';
import 'package:watchtower/modules/live_tv/providers/live_providers.dart';

/// The Live TV catalogue: providers published by the extension repository.
///
/// The same catalogue the Marketplace's Live tab shows, reachable from inside
/// the Live TV module. Installing here writes a provider record; it never
/// downloads code, because a provider is data (a playlist URL or a bundled
/// asset path).
class LiveCatalogSheet extends ConsumerWidget {
  const LiveCatalogSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(liveCatalogProvider);
    final installed = {
      for (final provider in ref.watch(liveProvidersProvider)) provider.id,
    };

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Broken.category, size: 20),
                const SizedBox(width: 10),
                Text(
                  'Catalogue Live TV',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => ref.invalidate(liveCatalogProvider),
                  icon: const Icon(Broken.refresh, size: 20),
                  tooltip: 'Actualiser',
                ),
              ],
            ),
            const SizedBox(height: 4),
            Flexible(
              child: catalog.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => _CatalogError(
                  message: '$error',
                  onRetry: () => ref.invalidate(liveCatalogProvider),
                ),
                data: (entries) {
                  if (entries.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text('Aucun fournisseur publié pour le moment.'),
                      ),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: entries.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      final isInstalled = installed.contains(entry.id);
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: _EntryAvatar(entry: entry),
                        title: Text(entry.name),
                        subtitle: Text(
                          entry.description?.isNotEmpty == true
                              ? entry.description!
                              : 'v${entry.version}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: isInstalled
                            ? const Icon(Broken.tick_circle, size: 20)
                            : FilledButton(
                                onPressed: () => _install(
                                  context,
                                  ref,
                                  entry,
                                ),
                                child: const Text('Installer'),
                              ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _install(
    BuildContext context,
    WidgetRef ref,
    LiveProviderCatalogEntry entry,
  ) async {
    await ref.read(liveProvidersProvider.notifier).install(entry);
    if (!context.mounted) return;
    Navigator.of(context).maybePop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('« ${entry.name} » installé.')),
    );
  }
}

class _EntryAvatar extends StatelessWidget {
  const _EntryAvatar({required this.entry});

  final LiveProviderCatalogEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = switch (entry.kind) {
      LiveProviderKind.m3u => Broken.video_play,
      LiveProviderKind.xtream => Broken.lock,
      LiveProviderKind.json => Broken.document_text,
      LiveProviderKind.bundled => Broken.folder,
    };
    final url = entry.iconUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 40,
        height: 40,
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

  Widget _fallback(ThemeData theme, IconData icon) => ColoredBox(
    color: theme.colorScheme.primaryContainer,
    child: Icon(icon, color: theme.colorScheme.onPrimaryContainer, size: 20),
  );
}

class _CatalogError extends StatelessWidget {
  const _CatalogError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Broken.wifi_square, size: 36),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Broken.refresh),
            label: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }
}
