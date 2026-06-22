import 'package:flutter/material.dart';
  import 'package:flutter_riverpod/flutter_riverpod.dart';
  import 'package:go_router/go_router.dart';
  import 'package:watchtower/modules/plugins/plugin_launcher_screen.dart';
  import 'package:watchtower/modules/plugins/plugins_screen.dart';

  // ─── PluginDetailScreen ───────────────────────────────────────────────────────

  class PluginDetailScreen extends ConsumerWidget {
    final PluginEntry plugin;
    const PluginDetailScreen({required this.plugin, super.key});

    @override
    Widget build(BuildContext context, WidgetRef ref) {
      final cs = Theme.of(context).colorScheme;
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final installedList = ref.watch(installedPluginsProvider).value ?? [];
      final isInstalled = installedList.any((p) => p.id == plugin.id);

      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0A0A0A) : cs.surface,
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 200,
              pinned: true,
              backgroundColor:
                  isDark ? const Color(0xFF141414) : cs.surfaceContainerLow,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: () => context.pop(),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background:
                    _PluginBanner(plugin: plugin, cs: cs, isDark: isDark),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                plugin.name,
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: cs.onSurface,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              if (plugin.author.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text('par ${plugin.author}',
                                    style: TextStyle(
                                        fontSize: 14,
                                        color: cs.onSurfaceVariant)),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        _VersionBadge(
                            version: plugin.version,
                            installed: isInstalled,
                            cs: cs),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        if (isInstalled) ...[
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () {
                                final installed =
                                    InstalledPlugin.fromEntry(plugin);
                                context.push('/pluginLauncher',
                                    extra: (installed, plugin));
                              },
                              icon: const Icon(Icons.play_arrow_rounded),
                              label: const Text('Ouvrir'),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 50),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton(
                            onPressed: () => ref
                                .read(installedPluginsProvider.notifier)
                                .uninstall(plugin.id),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: cs.error,
                              side: BorderSide(
                                  color: cs.error.withValues(alpha: 0.5)),
                              minimumSize: const Size(50, 50),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            child: const Icon(Icons.delete_outline_rounded),
                          ),
                        ] else
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () => ref
                                  .read(installedPluginsProvider.notifier)
                                  .install(plugin),
                              icon: const Icon(Icons.download_rounded),
                              label: const Text('Installer'),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 50),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    if (plugin.description.isNotEmpty) ...[
                      _SectionLabel(title: 'Description'),
                      const SizedBox(height: 8),
                      Text(plugin.description,
                          style: TextStyle(
                              fontSize: 14,
                              height: 1.6,
                              color: cs.onSurface.withValues(alpha: 0.85))),
                      const SizedBox(height: 24),
                    ],
                    if (plugin.requirements.isNotEmpty) ...[
                      _SectionLabel(title: 'Prérequis'),
                      const SizedBox(height: 8),
                      ...plugin.requirements.entries.map((e) {
                        final data = e.value is Map
                            ? Map<String, dynamic>.from(e.value as Map)
                            : <String, dynamic>{};
                        return _RequirementTile(
                            id: e.key, data: data, cs: cs, isDark: isDark);
                      }),
                      const SizedBox(height: 24),
                    ],
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      );
    }
  }

  // ── Plugin banner ─────────────────────────────────────────────────────────────

  class _PluginBanner extends StatelessWidget {
    final PluginEntry plugin;
    final ColorScheme cs;
    final bool isDark;
    const _PluginBanner(
        {required this.plugin, required this.cs, required this.isDark});

    static const _colors = <String, List<Color>>{
      'downloader': [Color(0xFF1A73E8), Color(0xFF0D47A1)],
      'source': [Color(0xFF388E3C), Color(0xFF1B5E20)],
      'tracker': [Color(0xFF7B1FA2), Color(0xFF4A148C)],
      'utility': [Color(0xFFEF6C00), Color(0xFFBF360C)],
    };

    @override
    Widget build(BuildContext context) {
      final c = _colors[plugin.category] ??
          [const Color(0xFF424242), const Color(0xFF212121)];
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: c,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -30,
              bottom: -30,
              child: Icon(Icons.extension_rounded,
                  size: 180, color: Colors.white.withValues(alpha: 0.07)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(16)),
                    clipBehavior: Clip.antiAlias,
                    child: plugin.iconUrl.isNotEmpty
                        ? Image.network(plugin.iconUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                                Icons.extension_rounded,
                                size: 30,
                                color: Colors.white))
                        : const Icon(Icons.extension_rounded,
                            size: 30, color: Colors.white),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(plugin.name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20)),
                          child: Text(
                            plugin.category.toUpperCase(),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }

  // ── Version badge ─────────────────────────────────────────────────────────────

  class _VersionBadge extends StatelessWidget {
    final String version;
    final bool installed;
    final ColorScheme cs;
    const _VersionBadge(
        {required this.version, required this.installed, required this.cs});

    @override
    Widget build(BuildContext context) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: installed
              ? Colors.green.withValues(alpha: 0.15)
              : cs.primaryContainer.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          installed ? 'Installé' : 'v$version',
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: installed ? Colors.green : cs.primary),
        ),
      );
    }
  }

  // ── Section label ─────────────────────────────────────────────────────────────

  class _SectionLabel extends StatelessWidget {
    final String title;
    const _SectionLabel({required this.title});

    @override
    Widget build(BuildContext context) {
      return Text(title,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              letterSpacing: 0.5));
    }
  }

  // ── Requirement tile ──────────────────────────────────────────────────────────

  class _RequirementTile extends StatelessWidget {
    final String id;
    final Map<String, dynamic> data;
    final ColorScheme cs;
    final bool isDark;
    const _RequirementTile(
        {required this.id,
        required this.data,
        required this.cs,
        required this.isDark});

    @override
    Widget build(BuildContext context) {
      final optional = data['optional'] as bool? ?? false;
      final version = data['version'] as String? ?? '';
      final reason = data['reason'] as String? ?? '';
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF141414) : cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: cs.outlineVariant.withValues(alpha: isDark ? 0.25 : 0.5)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: optional
                    ? cs.surfaceContainerHigh
                    : cs.primaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                optional
                    ? Icons.info_outline_rounded
                    : Icons.warning_amber_rounded,
                size: 18,
                color: optional ? cs.onSurfaceVariant : cs.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(id,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface)),
                      if (version.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text(version,
                            style: TextStyle(
                                fontSize: 12, color: cs.onSurfaceVariant)),
                      ],
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: optional
                              ? cs.surfaceContainerHigh
                              : Colors.orange.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          optional ? 'Optionnel' : 'Requis',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: optional
                                  ? cs.onSurfaceVariant
                                  : Colors.orange),
                        ),
                      ),
                    ],
                  ),
                  if (reason.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(reason,
                        style: TextStyle(
                            fontSize: 12, color: cs.onSurfaceVariant)),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }
  }
  