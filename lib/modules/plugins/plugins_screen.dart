import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─── Model ────────────────────────────────────────────────────────────────────

class PluginEntry {
  final String id;
  final String name;
  final String author;
  final String category;
  final String description;
  final String version;
  final String iconUrl;
  final Map<String, dynamic> requirements;

  const PluginEntry({
    required this.id,
    required this.name,
    this.author = '',
    this.category = '',
    this.description = '',
    this.version = '',
    this.iconUrl = '',
    this.requirements = const {},
  });

  PluginEntry copyWith({
    String? id,
    String? name,
    String? author,
    String? category,
    String? description,
    String? version,
    String? iconUrl,
    Map<String, dynamic>? requirements,
  }) {
    return PluginEntry(
      id: id ?? this.id,
      name: name ?? this.name,
      author: author ?? this.author,
      category: category ?? this.category,
      description: description ?? this.description,
      version: version ?? this.version,
      iconUrl: iconUrl ?? this.iconUrl,
      requirements: requirements ?? this.requirements,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is PluginEntry && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

// ─── Providers ────────────────────────────────────────────────────────────────

class _PluginsListNotifier extends AsyncNotifier<List<PluginEntry>> {
  @override
  Future<List<PluginEntry>> build() async => [];
}

final pluginsListProvider =
    AsyncNotifierProvider<_PluginsListNotifier, List<PluginEntry>>(
  _PluginsListNotifier.new,
);

class _InstalledPluginsNotifier extends AsyncNotifier<List<PluginEntry>> {
  @override
  Future<List<PluginEntry>> build() async => [];

  Future<void> install(PluginEntry plugin) async {
    final current = state.value ?? [];
    if (current.any((p) => p.id == plugin.id)) return;
    state = AsyncData([...current, plugin]);
  }

  Future<void> uninstall(String pluginId) async {
    final current = state.value ?? [];
    state = AsyncData(current.where((p) => p.id != pluginId).toList());
  }
}

final installedPluginsProvider =
    AsyncNotifierProvider<_InstalledPluginsNotifier, List<PluginEntry>>(
  _InstalledPluginsNotifier.new,
);

// ─── PluginDetailPage ─────────────────────────────────────────────────────────

class PluginDetailPage extends ConsumerWidget {
  final PluginEntry plugin;

  const PluginDetailPage({required this.plugin, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final installedList = ref.watch(installedPluginsProvider).value ?? [];
    final isInstalled = installedList.any((p) => p.id == plugin.id);

    return Scaffold(
      appBar: AppBar(
        title: Text(plugin.name),
        actions: [
          if (!isInstalled)
            IconButton(
              icon: const Icon(Icons.download_rounded),
              onPressed: () =>
                  ref.read(installedPluginsProvider.notifier).install(plugin),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(18),
                ),
                clipBehavior: Clip.antiAlias,
                child: plugin.iconUrl.isNotEmpty
                    ? Image.network(plugin.iconUrl, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                            Icons.extension_rounded,
                            size: 36,
                            color: cs.primary))
                    : Icon(Icons.extension_rounded,
                        size: 36, color: cs.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(plugin.name,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700)),
                    if (plugin.author.isNotEmpty)
                      Text(plugin.author,
                          style: TextStyle(
                              fontSize: 13, color: cs.onSurfaceVariant)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isInstalled
                            ? Colors.green.withValues(alpha: 0.15)
                            : cs.primaryContainer,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        isInstalled ? 'Installé' : 'v${plugin.version}',
                        style: TextStyle(
                            fontSize: 12,
                            color: isInstalled ? Colors.green : cs.primary,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (plugin.description.isNotEmpty) ...[
            Text('Description',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurfaceVariant)),
            const SizedBox(height: 6),
            Text(plugin.description,
                style: TextStyle(fontSize: 14, height: 1.5)),
            const SizedBox(height: 16),
          ],
          if (!isInstalled)
            FilledButton.icon(
              onPressed: () =>
                  ref.read(installedPluginsProvider.notifier).install(plugin),
              icon: const Icon(Icons.download_rounded),
              label: const Text('Installer'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            )
          else
            OutlinedButton.icon(
              onPressed: () => ref
                  .read(installedPluginsProvider.notifier)
                  .uninstall(plugin.id),
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Désinstaller'),
              style: OutlinedButton.styleFrom(
                foregroundColor: cs.error,
                side: BorderSide(color: cs.error.withValues(alpha: 0.5)),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── PluginDetailSheet ────────────────────────────────────────────────────────

class PluginDetailSheet extends ConsumerWidget {
  final PluginEntry plugin;

  const PluginDetailSheet({required this.plugin, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final installedList = ref.watch(installedPluginsProvider).value ?? [];
    final isInstalled = installedList.any((p) => p.id == plugin.id);

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).padding.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                clipBehavior: Clip.antiAlias,
                child: plugin.iconUrl.isNotEmpty
                    ? Image.network(plugin.iconUrl, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                            Icons.extension_rounded,
                            size: 26,
                            color: cs.primary))
                    : Icon(Icons.extension_rounded,
                        size: 26, color: cs.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(plugin.name,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700)),
                    Text(plugin.author.isNotEmpty
                        ? plugin.author
                        : plugin.category,
                        style: TextStyle(
                            fontSize: 12, color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (plugin.description.isNotEmpty)
            Text(plugin.description,
                style: TextStyle(fontSize: 13, height: 1.5)),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: isInstalled
                ? OutlinedButton(
                    onPressed: () => ref
                        .read(installedPluginsProvider.notifier)
                        .uninstall(plugin.id),
                    child: const Text('Désinstaller'),
                  )
                : FilledButton(
                    onPressed: () => ref
                        .read(installedPluginsProvider.notifier)
                        .install(plugin),
                    child: const Text('Installer'),
                  ),
          ),
        ],
      ),
    );
  }
}
