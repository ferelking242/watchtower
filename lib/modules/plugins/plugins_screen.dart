import 'dart:convert';
  import 'package:flutter/material.dart';
  import 'package:flutter_riverpod/flutter_riverpod.dart';
  import 'package:go_router/go_router.dart';
  import 'package:http/http.dart' as http;

  // ─── Model ────────────────────────────────────────────────────────────────────

  class PluginEntry {
    final String id;
    final String name;
    final String author;
    final String category;
    final String description;
    final String version;
    final String iconUrl;
    final String uiMethod;
    final Map<String, dynamic> requirements;

    const PluginEntry({
      required this.id,
      required this.name,
      this.author = '',
      this.category = '',
      this.description = '',
      this.version = '',
      this.iconUrl = '',
      this.uiMethod = 'html',
      this.requirements = const {},
    });

    factory PluginEntry.fromJson(Map<String, dynamic> json) {
      // requirements can be a List or a Map depending on the plugin
      Map<String, dynamic> reqs = {};
      final rawReqs = json['requirements'];
      if (rawReqs is Map) {
        reqs = Map<String, dynamic>.from(rawReqs as Map);
      } else if (rawReqs is List) {
        for (final r in rawReqs) {
          if (r is Map && r['id'] != null) {
            reqs[r['id'] as String] = Map<String, dynamic>.from(r as Map)
              ..remove('id');
          }
        }
      }
      final ui = json['ui'] as Map? ?? {};
      final uiMethod = (ui['method'] as String? ?? 'html');
      // Resolve icon URL: may be relative ("assets/icon.png") or absolute
      String iconUrl = json['icon'] as String? ?? '';
      if (iconUrl.isNotEmpty && !iconUrl.startsWith('http')) {
        iconUrl =
            'https://raw.githubusercontent.com/ferelking242/watchtower-extensions/main/plugins/${json['id']}/$iconUrl';
      }
      return PluginEntry(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        author: json['author'] as String? ?? '',
        category: json['category'] as String? ?? '',
        description: (json['longDescription'] ?? json['description'] ?? '') as String,
        version: json['version'] as String? ?? '',
        iconUrl: iconUrl,
        uiMethod: uiMethod,
        requirements: reqs,
      );
    }

    PluginEntry copyWith({
      String? id,
      String? name,
      String? author,
      String? category,
      String? description,
      String? version,
      String? iconUrl,
      String? uiMethod,
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
        uiMethod: uiMethod ?? this.uiMethod,
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

  const _kMarketplaceUrl =
      'https://raw.githubusercontent.com/ferelking242/watchtower-extensions/main/plugins/index.json';

  class _PluginsListNotifier extends AsyncNotifier<List<PluginEntry>> {
    @override
    Future<List<PluginEntry>> build() async {
      try {
        final res = await http.get(Uri.parse(_kMarketplaceUrl));
        if (res.statusCode != 200) return [];
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        final list = json['plugins'] as List? ?? [];
        return list
            .map((e) => PluginEntry.fromJson(e as Map<String, dynamic>))
            .where((p) => p.id.isNotEmpty)
            .toList();
      } catch (_) {
        return [];
      }
    }
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

  // ─── PluginsScreen ────────────────────────────────────────────────────────────

  class PluginsScreen extends ConsumerStatefulWidget {
    const PluginsScreen({super.key});

    @override
    ConsumerState<PluginsScreen> createState() => _PluginsScreenState();
  }

  class _PluginsScreenState extends ConsumerState<PluginsScreen> {
    int _tab = 0;

    @override
    Widget build(BuildContext context) {
      final cs = Theme.of(context).colorScheme;
      final isDark = Theme.of(context).brightness == Brightness.dark;

      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF090909) : cs.surface,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => context.pop(),
          ),
          title: Text(
            'Plugins',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 17,
              color: isDark ? Colors.white : cs.onSurface,
            ),
          ),
          centerTitle: true,
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: _SegmentPicker(
                selected: _tab,
                onChanged: (i) => setState(() => _tab = i),
                isDark: isDark,
                cs: cs,
              ),
            ),
            Expanded(
              child: _tab == 0
                  ? _InstalledTab(cs: cs, isDark: isDark)
                  : _MarketplaceTab(cs: cs, isDark: isDark),
            ),
          ],
        ),
      );
    }
  }

  // ─── Segment picker ───────────────────────────────────────────────────────────

  class _SegmentPicker extends StatelessWidget {
    final int selected;
    final ValueChanged<int> onChanged;
    final bool isDark;
    final ColorScheme cs;

    const _SegmentPicker({
      required this.selected,
      required this.onChanged,
      required this.isDark,
      required this.cs,
    });

    @override
    Widget build(BuildContext context) {
      final bg = isDark ? const Color(0xFF1A1A1A) : cs.surfaceContainerHigh;
      return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
            color: bg, borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            _Seg(
              label: 'Installés',
              icon: Icons.inventory_2_outlined,
              selected: selected == 0,
              onTap: () => onChanged(0),
              cs: cs,
              isDark: isDark,
            ),
            _Seg(
              label: 'Marketplace',
              icon: Icons.storefront_outlined,
              selected: selected == 1,
              onTap: () => onChanged(1),
              cs: cs,
              isDark: isDark,
            ),
          ],
        ),
      );
    }
  }

  class _Seg extends StatelessWidget {
    final String label;
    final IconData icon;
    final bool selected;
    final VoidCallback onTap;
    final ColorScheme cs;
    final bool isDark;

    const _Seg({
      required this.label,
      required this.icon,
      required this.selected,
      required this.onTap,
      required this.cs,
      required this.isDark,
    });

    @override
    Widget build(BuildContext context) {
      final activeBg = isDark ? const Color(0xFF2A2A2A) : cs.surface;
      return Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: selected ? activeBg : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              boxShadow: selected
                  ? [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 6,
                          offset: const Offset(0, 2))
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon,
                    size: 16,
                    color: selected
                        ? cs.onSurface
                        : cs.onSurface.withValues(alpha: 0.45)),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected
                        ? cs.onSurface
                        : cs.onSurface.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  // ─── Installed tab ────────────────────────────────────────────────────────────

  class _InstalledTab extends ConsumerWidget {
    final ColorScheme cs;
    final bool isDark;
    const _InstalledTab({required this.cs, required this.isDark});

    @override
    Widget build(BuildContext context, WidgetRef ref) {
      final installed = ref.watch(installedPluginsProvider).value ?? [];

      if (installed.isEmpty) {
        return _EmptyInstalled(cs: cs, isDark: isDark);
      }

      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: installed.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (ctx, i) => _InstalledCard(
          plugin: installed[i],
          cs: cs,
          isDark: isDark,
        ),
      );
    }
  }

  class _EmptyInstalled extends StatelessWidget {
    final ColorScheme cs;
    final bool isDark;
    const _EmptyInstalled({required this.cs, required this.isDark});

    @override
    Widget build(BuildContext context) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.extension_off_rounded,
                  size: 64, color: cs.onSurface.withValues(alpha: 0.2)),
              const SizedBox(height: 16),
              Text('Aucun plugin installé',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface)),
              const SizedBox(height: 8),
              Text('Explore le Marketplace pour installer des plugins.',
                  style: TextStyle(
                      fontSize: 14, color: cs.onSurfaceVariant),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }
  }

  class _InstalledCard extends ConsumerWidget {
    final PluginEntry plugin;
    final ColorScheme cs;
    final bool isDark;

    const _InstalledCard(
        {required this.plugin, required this.cs, required this.isDark});

    @override
    Widget build(BuildContext context, WidgetRef ref) {
      final cardBg =
          isDark ? const Color(0xFF141414) : cs.surfaceContainerLow;

      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: cs.outlineVariant.withValues(alpha: isDark ? 0.25 : 0.5)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                  color: cs.primaryContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12)),
              clipBehavior: Clip.antiAlias,
              child: plugin.iconUrl.isNotEmpty
                  ? Image.network(plugin.iconUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                          Icons.extension_rounded,
                          size: 24,
                          color: cs.primary))
                  : Icon(Icons.extension_rounded,
                      size: 24, color: cs.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(plugin.name,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                  Text(plugin.author.isNotEmpty
                      ? plugin.author
                      : plugin.category,
                      style: TextStyle(
                          fontSize: 12, color: cs.onSurfaceVariant)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => context.push('/pluginDetail', extra: plugin),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.open_in_new_rounded,
                    size: 18, color: cs.primary),
              ),
            ),
          ],
        ),
      );
    }
  }

  // ─── Marketplace tab ──────────────────────────────────────────────────────────

  class _MarketplaceTab extends ConsumerWidget {
    final ColorScheme cs;
    final bool isDark;
    const _MarketplaceTab({required this.cs, required this.isDark});

    @override
    Widget build(BuildContext context, WidgetRef ref) {
      final plugins = ref.watch(pluginsListProvider);

      return plugins.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, size: 48, color: cs.error),
              const SizedBox(height: 12),
              const Text('Impossible de charger le marketplace',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => ref.refresh(pluginsListProvider),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Réessayer'),
              ),
            ],
          ),
        ),
        data: (list) => list.isEmpty
            ? const Center(child: Text('Aucun plugin disponible'))
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (ctx, i) => _MarketplaceCard(
                  plugin: list[i],
                  cs: cs,
                  isDark: isDark,
                ),
              ),
      );
    }
  }

  class _MarketplaceCard extends ConsumerWidget {
    final PluginEntry plugin;
    final ColorScheme cs;
    final bool isDark;

    const _MarketplaceCard(
        {required this.plugin, required this.cs, required this.isDark});

    @override
    Widget build(BuildContext context, WidgetRef ref) {
      final cardBg =
          isDark ? const Color(0xFF141414) : cs.surfaceContainerLow;
      final installed = ref.watch(installedPluginsProvider).value ?? [];
      final isInstalled = installed.any((p) => p.id == plugin.id);

      return GestureDetector(
        onTap: () => context.push('/pluginDetail', extra: plugin),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color:
                    cs.outlineVariant.withValues(alpha: isDark ? 0.25 : 0.5)),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                    color: cs.primaryContainer.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(14)),
                clipBehavior: Clip.antiAlias,
                child: plugin.iconUrl.isNotEmpty
                    ? Image.network(plugin.iconUrl,
                        fit: BoxFit.cover,
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
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    Text(plugin.author.isNotEmpty
                        ? plugin.author
                        : plugin.category,
                        style: TextStyle(
                            fontSize: 12, color: cs.onSurfaceVariant)),
                    const SizedBox(height: 4),
                    Text(
                      plugin.description.length > 80
                          ? '${plugin.description.substring(0, 80)}…'
                          : plugin.description,
                      style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withValues(alpha: 0.6)),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (isInstalled)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('Installé',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.green)),
                )
              else
                FilledButton(
                  onPressed: () => ref
                      .read(installedPluginsProvider.notifier)
                      .install(plugin),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 34),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    textStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  child: const Text('Installer'),
                ),
            ],
          ),
        ),
      );
    }
  }

  // ─── Legacy detail widgets (kept for backward compat) ─────────────────────────

  class PluginDetailPage extends ConsumerWidget {
    final PluginEntry plugin;
    const PluginDetailPage({required this.plugin, super.key});

    @override
    Widget build(BuildContext context, WidgetRef ref) {
      final cs = Theme.of(context).colorScheme;
      final installedList = ref.watch(installedPluginsProvider).value ?? [];
      final isInstalled = installedList.any((p) => p.id == plugin.id);

      return Scaffold(
        appBar: AppBar(title: Text(plugin.name)),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(plugin.name,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (plugin.description.isNotEmpty)
              Text(plugin.description),
            const SizedBox(height: 20),
            if (!isInstalled)
              FilledButton(
                onPressed: () =>
                    ref.read(installedPluginsProvider.notifier).install(plugin),
                child: const Text('Installer'),
              )
            else
              OutlinedButton(
                onPressed: () => ref
                    .read(installedPluginsProvider.notifier)
                    .uninstall(plugin.id),
                child: const Text('Désinstaller'),
              ),
          ],
        ),
      );
    }
  }

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
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24))),
        padding: EdgeInsets.fromLTRB(
            20, 16, 20, MediaQuery.of(context).padding.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(plugin.name,
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
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
  