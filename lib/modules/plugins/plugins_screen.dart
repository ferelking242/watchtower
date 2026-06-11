import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

// ─── Constants ──────────────────────────────────────────────────────────────

const _kPluginsJsonUrl =
    'https://raw.githubusercontent.com/ferelking242/watchtower-extensions/main/plugins/index.json';

const _bg    = Color(0xFF0E0E0E);
const _card  = Color(0xFF1A1A1A);
const _card2 = Color(0xFF242424);
const _teal  = Color(0xFF1DB954);
const _grey  = Color(0xFF9E9E9E);
const _sheetBg = Color(0xFF1C1C1C);
const _border  = Color(0xFF2A2A2A);

// ─── Data models ────────────────────────────────────────────────────────────

class PluginEntry {
  final String id;
  final String name;
  final String description;
  final String longDescription;
  final String version;
  final String author;
  final String iconUrl;
  final String banner;
  final String category;
  final List<String> runtimeTypes;
  final List<String> tags;
  final List<String> screenshots;
  final int downloadCount;
  final double rating;
  final bool featured;
  final String publishedAt;
  final Map<String, dynamic> requirements;
  final List<String> commandScopes;
  final List<String> networkAccess;
  final Map<String, dynamic>? userConfig;
  final String schemaVersion;

  const PluginEntry({
    required this.id,
    required this.name,
    required this.description,
    required this.longDescription,
    required this.version,
    required this.author,
    required this.iconUrl,
    required this.banner,
    required this.category,
    required this.runtimeTypes,
    required this.tags,
    required this.screenshots,
    required this.downloadCount,
    required this.rating,
    required this.featured,
    required this.publishedAt,
    required this.requirements,
    required this.commandScopes,
    required this.networkAccess,
    this.userConfig,
    required this.schemaVersion,
  });

  factory PluginEntry.fromJson(Map<String, dynamic> j) => PluginEntry(
    id:              j['id'] as String? ?? '',
    name:            j['name'] as String? ?? '',
    description:     j['description'] as String? ?? '',
    longDescription: j['longDescription'] as String? ?? '',
    version:         j['version'] as String? ?? '0.0.0',
    author:          j['author'] as String? ?? '',
    iconUrl:         (j['icon'] ?? j['iconUrl']) as String? ?? '',
    banner:          j['banner'] as String? ?? '',
    category:        j['category'] as String? ?? 'utility',
    runtimeTypes:    (j['runtimeTypes'] as List?)?.cast<String>() ?? [],
    tags:            (j['tags'] as List?)?.cast<String>() ?? [],
    screenshots:     (j['screenshots'] as List?)?.cast<String>() ?? [],
    downloadCount:   j['downloadCount'] as int? ?? 0,
    rating:          ((j['rating'] as num?) ?? 0.0).toDouble(),
    featured:        j['featured'] as bool? ?? false,
    publishedAt:     j['publishedAt'] as String? ?? '',
    requirements:    (j['requirements'] is Map)
        ? (j['requirements'] as Map).cast<String, dynamic>()
        : (j['requirements'] is List)
            ? { for (final e in (j['requirements'] as List)) if (e is Map && e['id'] != null) (e['id'] as String): e }
            : {},
    commandScopes:   (j['commandScopes'] as List?)
        ?.map((e) => e is Map ? (e['command'] as String? ?? e.toString()) : e.toString())
        .toList() ?? [],
    networkAccess:   (j['networkAccess'] is List)
        ? (j['networkAccess'] as List).cast<String>()
        : (j['networkAccess'] is Map)
            ? ((j['networkAccess'] as Map)['allowedDomains'] as List?)?.cast<String>() ?? []
            : [],
    userConfig:      (j['userConfig'] as Map?)?.cast<String, dynamic>(),
    schemaVersion:   j['schemaVersion'] as String? ?? '1',
  );
}

// ─── Installed plugins state ─────────────────────────────────────────────────

class InstalledPlugin {
  final String id;
  final String version;
  final bool enabled;
  final String installedAt;

  const InstalledPlugin({
    required this.id,
    required this.version,
    required this.enabled,
    required this.installedAt,
  });

  InstalledPlugin copyWith({bool? enabled, String? version}) => InstalledPlugin(
    id: id,
    version: version ?? this.version,
    enabled: enabled ?? this.enabled,
    installedAt: installedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'version': version, 'enabled': enabled, 'installedAt': installedAt,
  };

  factory InstalledPlugin.fromJson(Map<String, dynamic> j) => InstalledPlugin(
    id:          j['id'] as String,
    version:     j['version'] as String,
    enabled:     j['enabled'] as bool? ?? true,
    installedAt: j['installedAt'] as String,
  );
}

// ─── Providers ───────────────────────────────────────────────────────────────

final pluginsListProvider = FutureProvider.autoDispose<List<PluginEntry>>((ref) async {
  final bust = Uri.parse('$_kPluginsJsonUrl?_=${DateTime.now().millisecondsSinceEpoch}');
  final r = await http.get(bust, headers: {'Cache-Control': 'no-cache'});
  if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
  final _decoded = jsonDecode(utf8.decode(r.bodyBytes));
  final list = _decoded is List ? _decoded as List : (_decoded as Map<String, dynamic>)['plugins'] as List? ?? [];
  return list.map((e) => PluginEntry.fromJson(e as Map<String, dynamic>)).toList();
});

class InstalledPluginsNotifier extends AsyncNotifier<List<InstalledPlugin>> {
  static Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/installed_plugins.json');
  }

  @override
  Future<List<InstalledPlugin>> build() async {
    try {
      final f = await _file();
      if (!await f.exists()) return [];
      final raw = jsonDecode(await f.readAsString()) as List;
      return raw.map((e) => InstalledPlugin.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _save(List<InstalledPlugin> list) async {
    final f = await _file();
    await f.writeAsString(jsonEncode(list.map((e) => e.toJson()).toList()));
  }

  Future<void> install(PluginEntry plugin) async {
    final current = state.value ?? [];
    if (current.any((p) => p.id == plugin.id)) return;
    final updated = [
      ...current,
      InstalledPlugin(
        id: plugin.id,
        version: plugin.version,
        enabled: true,
        installedAt: DateTime.now().toIso8601String(),
      ),
    ];
    state = AsyncData(updated);
    await _save(updated);
  }

  Future<void> uninstall(String id) async {
    final current = state.value ?? [];
    final updated = current.where((p) => p.id != id).toList();
    state = AsyncData(updated);
    await _save(updated);
  }

  Future<void> toggle(String id) async {
    final current = state.value ?? [];
    final updated = current.map((p) => p.id == id ? p.copyWith(enabled: !p.enabled) : p).toList();
    state = AsyncData(updated);
    await _save(updated);
  }

  Future<void> updateVersion(String id, String newVersion) async {
    final current = state.value ?? [];
    final updated = current.map((p) => p.id == id ? p.copyWith(version: newVersion) : p).toList();
    state = AsyncData(updated);
    await _save(updated);
  }
}

final installedPluginsProvider =
    AsyncNotifierProvider<InstalledPluginsNotifier, List<InstalledPlugin>>(
        InstalledPluginsNotifier.new);

// ─── Android home-screen shortcut helper ─────────────────────────────────────

const _shortcutChannel = MethodChannel('com.watchtower.app.shortcuts');

Future<void> _pinToHomeScreen(BuildContext ctx, String id, String label) async {
  try {
    final supported =
        await _shortcutChannel.invokeMethod<bool>('isSupported') ?? false;
    if (!supported) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('Raccourcis non supportés par ce launcher')),
        );
      }
      return;
    }
    await _shortcutChannel.invokeMethod<void>('pinShortcut', {'id': id, 'label': label});
    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(content: Text('Raccourci "$label" ajouté à l\'écran d\'accueil')),
      );
    }
  } catch (e) {
    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(content: Text('Erreur : $e')),
      );
    }
  }
}

// ─── Markdown stripper ────────────────────────────────────────────────────────

String _stripMd(String s) => s
  .replaceAllMapped(RegExp(r'\*\*(.*?)\*\*', dotAll: true), (m) => m.group(1)!)
  .replaceAllMapped(RegExp(r'\*(.*?)\*', dotAll: true), (m) => m.group(1)!)
  .replaceAllMapped(RegExp(r'`(.*?)`'), (m) => m.group(1)!);

// ─── Main screen ─────────────────────────────────────────────────────────────

class PluginsScreen extends ConsumerStatefulWidget {
  const PluginsScreen({super.key});

  @override
  ConsumerState<PluginsScreen> createState() => _PluginsScreenState();
}

class _PluginsScreenState extends ConsumerState<PluginsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _searchCtrl = TextEditingController();
  bool _searchOpen = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() { if (mounted) setState(() {}); });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(),
      body: Column(children: [
        if (_searchOpen) _SearchBar(
          ctrl: _searchCtrl,
          onChanged: (v) => setState(() => _query = v.toLowerCase()),
          onClose: () => setState(() { _searchOpen = false; _query = ''; _searchCtrl.clear(); }),
        ),
        _TabStrip(controller: _tabs),
        const SizedBox(height: 1),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _BrowseTab(query: _query),
              _InstalledTab(),
            ],
          ),
        ),
      ]),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: _bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      title: Text(
        'Plugins',
        style: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
      actions: [
        IconButton(
          onPressed: () => setState(() { _searchOpen = !_searchOpen; if (!_searchOpen) { _query = ''; _searchCtrl.clear(); } }),
          icon: Icon(_searchOpen ? Icons.search_off_rounded : Icons.search_rounded, color: _grey),
          tooltip: 'Rechercher',
        ),
        IconButton(
          onPressed: () => ref.invalidate(pluginsListProvider),
          icon: const Icon(Icons.refresh_rounded, color: _grey),
          tooltip: 'Actualiser',
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

// ─── Tab strip ────────────────────────────────────────────────────────────────

class _TabStrip extends StatelessWidget {
  final TabController controller;
  const _TabStrip({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bg,
      child: TabBar(
        controller: controller,
        indicatorColor: _teal,
        indicatorWeight: 2.5,
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: _teal,
        unselectedLabelColor: _grey,
        dividerColor: _border,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        tabs: const [
          Tab(text: 'Parcourir'),
          Tab(text: 'Installés'),
        ],
      ),
    );
  }
}

// ─── Search bar ───────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController ctrl;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;
  const _SearchBar({required this.ctrl, required this.onChanged, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bg,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
      child: TextField(
        controller: ctrl,
        autofocus: true,
        onChanged: onChanged,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        cursorColor: _teal,
        decoration: InputDecoration(
          hintText: 'Rechercher un plugin…',
          hintStyle: const TextStyle(color: _grey, fontSize: 14),
          prefixIcon: const Icon(Icons.search_rounded, color: _grey, size: 18),
          suffixIcon: IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, color: _grey, size: 18),
          ),
          filled: true,
          fillColor: _card,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

// ─── Browse tab ───────────────────────────────────────────────────────────────

class _BrowseTab extends ConsumerWidget {
  final String query;
  const _BrowseTab({required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncPlugins = ref.watch(pluginsListProvider);

    return asyncPlugins.when(
      loading: () => const _PluginsSkeleton(),
      error: (e, _) => _ErrorState(error: e.toString(), onRetry: () => ref.invalidate(pluginsListProvider)),
      data: (plugins) {
        final filtered = query.isEmpty
            ? plugins
            : plugins.where((p) =>
                p.name.toLowerCase().contains(query) ||
                p.description.toLowerCase().contains(query) ||
                p.author.toLowerCase().contains(query) ||
                p.tags.any((t) => t.toLowerCase().contains(query))).toList();

        final featured = filtered.where((p) => p.featured).toList();
        final rest     = filtered.where((p) => !p.featured).toList();

        if (filtered.isEmpty) return _EmptySearch(query: query);

        return ListView(
          padding: const EdgeInsets.only(bottom: 100),
          children: [
            if (featured.isNotEmpty && query.isEmpty) ...[
              _SectionHeader(
                icon: Icons.auto_awesome_rounded,
                label: 'À la une',
                iconColor: const Color(0xFFFFD700),
              ),
              ...featured.map((p) => _PluginCard(plugin: p, featured: true)),
              _SectionHeader(
                icon: Icons.grid_view_rounded,
                label: 'Tous les plugins (${rest.length})',
                iconColor: _teal,
              ),
            ],
            ...rest.map((p) => _PluginCard(plugin: p)),
            if (featured.isEmpty && rest.isEmpty && query.isNotEmpty)
              _EmptySearch(query: query),
          ],
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;
  const _SectionHeader({required this.icon, required this.label, required this.iconColor});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
    child: Row(children: [
      Icon(icon, size: 15, color: iconColor),
      const SizedBox(width: 6),
      Text(label.toUpperCase(),
        style: const TextStyle(
          fontSize: 11, fontWeight: FontWeight.w800,
          color: _grey, letterSpacing: 0.9)),
    ]),
  );
}

// ─── Plugin card (Play Store style) ──────────────────────────────────────────

class _PluginCard extends ConsumerWidget {
  final PluginEntry plugin;
  final bool featured;
  const _PluginCard({required this.plugin, this.featured = false});

  static bool _newerVersion(String remote, String local) {
    final parse = (String v) => v.replaceAll(RegExp(r'[^0-9.]'), '').split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final r = parse(remote), l = parse(local);
    for (var i = 0; i < r.length && i < l.length; i++) {
      if (r[i] > l[i]) return true;
      if (r[i] < l[i]) return false;
    }
    return r.length > l.length;
  }

  void _openDetail(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PluginDetailPage(plugin: plugin),
    ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final installed = ref.watch(installedPluginsProvider).value ?? [];
    final isInstalled = installed.any((p) => p.id == plugin.id);
    final installedEntry = isInstalled ? installed.firstWhere((p) => p.id == plugin.id) : null;
    final hasUpdate = installedEntry != null && _newerVersion(plugin.version, installedEntry.version);

    return GestureDetector(
      onTap: () => _openDetail(context),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: featured ? _teal.withOpacity(0.35) : _border,
            width: featured ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PluginIcon(url: plugin.iconUrl, size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plugin.name,
                        style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white,
                        ),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        plugin.author.isNotEmpty ? plugin.author : plugin.category,
                        style: TextStyle(
                          fontSize: 12, color: _grey.withOpacity(0.75),
                        ),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _PluginActionButton(
                  isInstalled: isInstalled,
                  hasUpdate: hasUpdate,
                  plugin: plugin,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _stripMd(plugin.description),
              style: const TextStyle(fontSize: 13, color: _grey, height: 1.45),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _TagChip(label: 'v${plugin.version}'),
                _TagChip(label: plugin.category),
                if (hasUpdate) _TagChip(label: '↑ màj', color: Colors.orange.shade400),
                if (plugin.requirements.isNotEmpty)
                  _TagChip(label: plugin.requirements.keys.first, color: _teal),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  final Color? color;
  const _TagChip({required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final fg = color ?? _grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fg.withOpacity(0.45)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: fg),
      ),
    );
  }
}

// Action button (download / update / installed indicator)
class _PluginActionButton extends ConsumerStatefulWidget {
  final bool isInstalled;
  final bool hasUpdate;
  final PluginEntry plugin;
  const _PluginActionButton({
    required this.isInstalled,
    required this.hasUpdate,
    required this.plugin,
  });

  @override
  ConsumerState<_PluginActionButton> createState() => _PluginActionButtonState();
}

class _PluginActionButtonState extends ConsumerState<_PluginActionButton> {
  bool _busy = false;

  Future<void> _install() async {
    if (_busy || widget.isInstalled) return;
    setState(() => _busy = true);

    try {
      if (widget.plugin.requirements.isNotEmpty) {
        final supportDir = await getApplicationSupportDirectory();
        final binPath = '${supportDir.path}/binaries';
        final missing = <String>[];
        for (final entry in widget.plugin.requirements.entries) {
          final reqMap = entry.value as Map?;
          final isOptional = reqMap?['optional'] == true;
          if (isOptional) continue;
          final binName = entry.key == 'aria2' ? 'aria2c' : entry.key;
          final f = File('$binPath/$binName');
          if (!f.existsSync() || f.lengthSync() == 0) {
            missing.add(entry.key);
          }
        }
        if (missing.isNotEmpty && mounted) {
          setState(() => _busy = false);
          final proceed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: _card,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              title: const Text('Dépendances manquantes',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${widget.plugin.name} nécessite :',
                      style: const TextStyle(color: _grey, fontSize: 13)),
                  const SizedBox(height: 10),
                  ...missing.map((r) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(children: [
                      const Icon(Icons.memory_rounded, size: 14, color: _teal),
                      const SizedBox(width: 6),
                      Text(r, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                    ]),
                  )),
                  const SizedBox(height: 10),
                  const Text('Installez-les depuis Marketplace → Binaires.',
                      style: TextStyle(color: _grey, fontSize: 12)),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Annuler', style: TextStyle(color: _grey)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Installer quand même', style: TextStyle(color: _teal)),
                ),
              ],
            ),
          );
          if (proceed != true) return;
          setState(() => _busy = true);
        }
      }

      if (!mounted) return;
      await ref.read(installedPluginsProvider.notifier).install(widget.plugin);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: _card,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Row(children: [
            const Icon(Icons.check_circle_rounded, color: _teal, size: 16),
            const SizedBox(width: 8),
            Text('${widget.plugin.name} installé', style: const TextStyle(color: Colors.white, fontSize: 13)),
          ]),
          duration: const Duration(seconds: 2),
        ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_busy) {
      return Container(
        width: 36, height: 36, padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(color: _card2, borderRadius: BorderRadius.circular(10)),
        child: const CircularProgressIndicator(strokeWidth: 2.2, color: _teal),
      );
    }
    if (widget.isInstalled && !widget.hasUpdate) {
      return Container(
        width: 36, height: 36, alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _teal.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _teal.withOpacity(0.35)),
        ),
        child: const Icon(Icons.check_rounded, size: 18, color: _teal),
      );
    }
    return GestureDetector(
      onTap: _install,
      child: Container(
        width: 36, height: 36, alignment: Alignment.center,
        decoration: BoxDecoration(
          color: widget.hasUpdate
              ? Colors.orange.shade700.withOpacity(0.15)
              : _card2,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          widget.hasUpdate ? Icons.system_update_alt_rounded : Icons.download_rounded,
          size: 20,
          color: widget.hasUpdate ? Colors.orange.shade400 : _grey,
        ),
      ),
    );
  }
}

// ─── Small widgets ────────────────────────────────────────────────────────────

class _PluginIcon extends StatelessWidget {
  final String url;
  final double size;
  const _PluginIcon({required this.url, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: _card2,
        borderRadius: BorderRadius.circular(size * 0.22),
        border: Border.all(color: _border),
      ),
      clipBehavior: Clip.antiAlias,
      child: url.isNotEmpty
          ? Image.network(url, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _FallbackIcon(size: size))
          : _FallbackIcon(size: size),
    );
  }
}

class _FallbackIcon extends StatelessWidget {
  final double size;
  const _FallbackIcon({required this.size});
  @override
  Widget build(BuildContext context) => Center(
    child: Icon(Icons.extension_rounded, size: size * 0.45, color: _grey),
  );
}

class _CategoryPill extends StatelessWidget {
  final String category;
  const _CategoryPill({required this.category});

  static const _colors = {
    'downloader': Color(0xFF7C3AED),
    'utility':    Color(0xFF0891B2),
    'media':      Color(0xFF059669),
    'tools':      Color(0xFFD97706),
    'theme':      Color(0xFFDB2777),
  };

  static const _icons = {
    'downloader': Icons.download_rounded,
    'utility':    Icons.build_rounded,
    'media':      Icons.movie_rounded,
    'tools':      Icons.construction_rounded,
    'theme':      Icons.palette_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final color = _colors[category] ?? const Color(0xFF6B7280);
    final icon  = _icons[category]  ?? Icons.extension_rounded;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 10, color: color),
        const SizedBox(width: 4),
        Text(category, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}

// ─── Plugin detail – full screen page ────────────────────────────────────────

class PluginDetailPage extends ConsumerStatefulWidget {
  final PluginEntry plugin;
  const PluginDetailPage({required this.plugin, super.key});

  @override
  ConsumerState<PluginDetailPage> createState() => _PluginDetailPageState();
}

class _PluginDetailPageState extends ConsumerState<PluginDetailPage> {
  bool _installing = false;
  bool _descExpanded = false;

  PluginEntry get p => widget.plugin;

  static String _fmtDownloads(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000)    return '${(n / 1000).toStringAsFixed(0)}K';
    return n.toString();
  }

  Future<void> _install() async {
    if (_installing) return;
    setState(() => _installing = true);
    try {
      await ref.read(installedPluginsProvider.notifier).install(p);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: _card,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Row(children: [
            const Icon(Icons.check_circle_rounded, color: _teal, size: 16),
            const SizedBox(width: 8),
            Text('${p.name} installé', style: const TextStyle(color: Colors.white, fontSize: 13)),
          ]),
          duration: const Duration(seconds: 2),
        ));
      }
    } finally {
      if (mounted) setState(() => _installing = false);
    }
  }

  Future<void> _uninstall() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        title: const Text('Désinstaller', style: TextStyle(color: Colors.white)),
        content: Text('Supprimer "${p.name}" ?', style: const TextStyle(color: _grey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Désinstaller'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(installedPluginsProvider.notifier).uninstall(p.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final installed = ref.watch(installedPluginsProvider).value ?? [];
    final isInstalled = installed.any((ip) => ip.id == p.id);
    final desc = _stripMd(p.longDescription.isNotEmpty ? p.longDescription : p.description);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(p.name,
          style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white),
          maxLines: 1, overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (isInstalled)
            IconButton(
              icon: Icon(Icons.delete_outline_rounded, color: Colors.red.shade400),
              onPressed: _uninstall,
              tooltip: 'Désinstaller',
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        children: [
          // ── Header ─────────────────────────────────────────────────────
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            _PluginIcon(url: p.iconUrl, size: 80),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.name,
                  style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                if (p.author.isNotEmpty)
                  Text(p.author, style: const TextStyle(fontSize: 13, color: _grey)),
                const SizedBox(height: 8),
                Row(children: [
                  _CategoryPill(category: p.category),
                  const SizedBox(width: 6),
                  Text('v${p.version}', style: const TextStyle(fontSize: 11, color: _grey, fontWeight: FontWeight.w600)),
                ]),
              ]),
            ),
          ]),

          const SizedBox(height: 20),

          // ── Install button ─────────────────────────────────────────────
          isInstalled
              ? OutlinedButton.icon(
                  onPressed: _uninstall,
                  icon: const Icon(Icons.delete_outline_rounded, size: 16),
                  label: const Text('Désinstaller'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade400,
                    side: BorderSide(color: Colors.red.shade900),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                )
              : FilledButton.icon(
                  onPressed: _installing ? null : _install,
                  icon: _installing
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.download_rounded, size: 16),
                  label: Text(_installing ? 'Installation…' : 'Installer ${p.name}'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _teal,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),

          const SizedBox(height: 20),
          const Divider(color: _border, height: 1),
          const SizedBox(height: 20),

          // ── Stats ──────────────────────────────────────────────────────
          Row(children: [
            _StatItem(value: _fmtDownloads(p.downloadCount), label: 'Téléch.', icon: Icons.download_rounded),
            const SizedBox(width: 10),
            _StatItem(value: p.rating > 0 ? p.rating.toStringAsFixed(1) : '—', label: 'Note', icon: Icons.star_rounded, iconColor: const Color(0xFFFFD700)),
            const SizedBox(width: 10),
            _StatItem(value: p.publishedAt.isNotEmpty ? p.publishedAt.substring(0, 10) : '—', label: 'Publié', icon: Icons.calendar_today_rounded),
          ]),

          const SizedBox(height: 20),

          // ── Description ────────────────────────────────────────────────
          if (desc.isNotEmpty) ...[
            _SectionLabel(label: 'Description', icon: Icons.info_outline_rounded),
            const SizedBox(height: 10),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 200),
              crossFadeState: _descExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              firstChild: Text(desc,
                style: const TextStyle(fontSize: 13.5, color: Color(0xFFCCCCCC), height: 1.6),
                maxLines: 5, overflow: TextOverflow.ellipsis),
              secondChild: Text(desc,
                style: const TextStyle(fontSize: 13.5, color: Color(0xFFCCCCCC), height: 1.6)),
            ),
            if (desc.length > 200) ...[
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => setState(() => _descExpanded = !_descExpanded),
                child: Text(
                  _descExpanded ? 'Voir moins' : 'Voir plus',
                  style: const TextStyle(fontSize: 12, color: _teal, fontWeight: FontWeight.w600),
                ),
              ),
            ],
            const SizedBox(height: 20),
          ],

          // ── Tags ───────────────────────────────────────────────────────
          if (p.tags.isNotEmpty) ...[
            Wrap(spacing: 6, runSpacing: 6,
              children: p.tags.map((t) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: _card2,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _border),
                ),
                child: Text(t, style: const TextStyle(fontSize: 11, color: _grey, fontWeight: FontWeight.w600)),
              )).toList(),
            ),
            const SizedBox(height: 20),
          ],

          // ── Screenshots ────────────────────────────────────────────────
          if (p.screenshots.isNotEmpty) ...[
            _SectionLabel(label: 'Captures d\'écran', icon: Icons.photo_library_outlined),
            const SizedBox(height: 10),
            SizedBox(
              height: 160,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: p.screenshots.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(p.screenshots[i],
                    height: 160, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 100, height: 160,
                      color: _card2,
                      child: const Icon(Icons.broken_image_rounded, color: _grey),
                    )),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // ── Requirements ───────────────────────────────────────────────
          if (p.requirements.isNotEmpty) ...[
            _DetailSection(
              icon: Icons.terminal_rounded,
              label: 'Dépendances',
              child: Column(
                children: p.requirements.entries.map((e) {
                  final meta = e.value as Map? ?? {};
                  final isOptional = meta['optional'] == true;
                  return _DepRow(
                    name: e.key,
                    version: meta['version'] as String? ?? '*',
                    required: !isOptional,
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Permissions ─────────────────────────────────────────────────
          if (p.commandScopes.isNotEmpty || p.networkAccess.isNotEmpty) ...[
            _DetailSection(
              icon: Icons.shield_rounded,
              label: 'Permissions',
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (p.commandScopes.isNotEmpty)
                  _PermRow(icon: Icons.terminal_rounded, label: 'Commandes système', values: p.commandScopes),
                if (p.networkAccess.isNotEmpty)
                  _PermRow(icon: Icons.wifi_rounded, label: 'Accès réseau', values: p.networkAccess),
              ]),
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final IconData icon;
  const _SectionLabel({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 14, color: _teal),
    const SizedBox(width: 6),
    Text(label.toUpperCase(),
      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: _grey, letterSpacing: 0.8)),
  ]);
}

// Keep PluginDetailSheet as alias for backward compatibility
typedef PluginDetailSheet = PluginDetailPage;

class _StatItem extends StatelessWidget {
  final String value, label;
  final IconData icon;
  final Color iconColor;
  const _StatItem({required this.value, required this.label, required this.icon, this.iconColor = _grey});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: _card2, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 14, color: iconColor),
        const SizedBox(height: 5),
        Text(value, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Colors.white)),
        Text(label, style: const TextStyle(fontSize: 10, color: _grey)),
      ]),
    ),
  );
}

class _DetailSection extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget child;
  const _DetailSection({required this.icon, required this.label, required this.child});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: _card2, borderRadius: BorderRadius.circular(14), border: Border.all(color: _border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 14, color: _teal),
        const SizedBox(width: 6),
        Text(label.toUpperCase(),
          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: _grey, letterSpacing: 0.8)),
      ]),
      const SizedBox(height: 12),
      child,
    ]),
  );
}

class _DepRow extends StatelessWidget {
  final String name, version;
  final bool required;
  const _DepRow({required this.name, required this.version, required this.required});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Icon(Icons.circle, size: 5, color: required ? _teal : _grey),
      const SizedBox(width: 8),
      Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
      const SizedBox(width: 6),
      Text(version, style: const TextStyle(fontSize: 12, color: _grey)),
      const Spacer(),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: required ? _teal.withOpacity(0.1) : _card,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: required ? _teal.withOpacity(0.4) : _border),
        ),
        child: Text(required ? 'Requis' : 'Optionnel',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: required ? _teal : _grey)),
      ),
    ]),
  );
}

class _PermRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final List<String> values;
  const _PermRow({required this.icon, required this.label, required this.values});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 14, color: _grey),
      const SizedBox(width: 8),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 12, color: _grey)),
          const SizedBox(height: 4),
          Wrap(spacing: 5, runSpacing: 4,
            children: values.map((v) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(6), border: Border.all(color: _border)),
              child: Text(v, style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
            )).toList(),
          ),
        ]),
      ),
    ]),
  );
}

// ─── Installed tab ────────────────────────────────────────────────────────────

class _InstalledTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncInstalled = ref.watch(installedPluginsProvider);
    final asyncPlugins   = ref.watch(pluginsListProvider);

    return asyncInstalled.when(
      loading: () => const Center(child: CircularProgressIndicator(color: _teal)),
      error: (e, _) => _ErrorState(error: e.toString(), onRetry: () => ref.invalidate(installedPluginsProvider)),
      data: (installed) {
        if (installed.isEmpty) return const _EmptyInstalled();

        final catalogue = asyncPlugins.value ?? [];
        final withUpdates = installed.where((i) {
          final remote = catalogue.firstWhere((p) => p.id == i.id, orElse: () => PluginEntry(
            id: '', name: '', description: '', longDescription: '', version: '0',
            author: '', iconUrl: '', banner: '', category: '', runtimeTypes: [],
            tags: [], screenshots: [], downloadCount: 0, rating: 0, featured: false,
            publishedAt: '', requirements: {}, commandScopes: [], networkAccess: [], schemaVersion: '2',
          ));
          return _PluginCard._newerVersion(remote.version, i.version);
        }).length;

        return Column(children: [
          if (withUpdates > 0)
            _UpdateAllBanner(count: withUpdates, installed: installed, catalogue: catalogue),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 100),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Text('${installed.length} plugin${installed.length > 1 ? "s" : ""} installé${installed.length > 1 ? "s" : ""}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _grey, letterSpacing: 0.5)),
                ),
                ...installed.map((i) {
                  final meta = catalogue.firstWhere((p) => p.id == i.id, orElse: () => PluginEntry(
                    id: i.id, name: i.id, description: '', longDescription: '', version: i.version,
                    author: '', iconUrl: '', banner: '', category: 'utility', runtimeTypes: [],
                    tags: [], screenshots: [], downloadCount: 0, rating: 0, featured: false,
                    publishedAt: '', requirements: {}, commandScopes: [], networkAccess: [], schemaVersion: '2',
                  ));
                  return _InstalledPluginRow(installed: i, meta: meta);
                }),
              ],
            ),
          ),
        ]);
      },
    );
  }
}

class _UpdateAllBanner extends ConsumerWidget {
  final int count;
  final List<InstalledPlugin> installed;
  final List<PluginEntry> catalogue;
  const _UpdateAllBanner({required this.count, required this.installed, required this.catalogue});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
    margin: const EdgeInsets.fromLTRB(14, 12, 14, 4),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.orange.shade900.withOpacity(0.15),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.orange.shade800.withOpacity(0.4)),
    ),
    child: Row(children: [
      Icon(Icons.system_update_rounded, size: 18, color: Colors.orange.shade400),
      const SizedBox(width: 10),
      Expanded(
        child: Text('$count mise${count > 1 ? "s" : ""} à jour disponible${count > 1 ? "s" : ""}',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.orange.shade300)),
      ),
      GestureDetector(
        onTap: () async {
          for (final i in installed) {
            final remote = catalogue.firstWhere((p) => p.id == i.id, orElse: () => PluginEntry(
              id: '', name: '', description: '', longDescription: '', version: '0',
              author: '', iconUrl: '', banner: '', category: '', runtimeTypes: [],
              tags: [], screenshots: [], downloadCount: 0, rating: 0, featured: false,
              publishedAt: '', requirements: {}, commandScopes: [], networkAccess: [], schemaVersion: '2',
            ));
            if (_PluginCard._newerVersion(remote.version, i.version)) {
              await ref.read(installedPluginsProvider.notifier).updateVersion(i.id, remote.version);
            }
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(color: Colors.orange.shade700, borderRadius: BorderRadius.circular(8)),
          child: const Text('Tout màj', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
        ),
      ),
    ]),
  );
}

// ─── Installed row (Play Store style) ────────────────────────────────────────

class _InstalledPluginRow extends ConsumerWidget {
  final InstalledPlugin installed;
  final PluginEntry meta;
  const _InstalledPluginRow({required this.installed, required this.meta});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasUpdate = _PluginCard._newerVersion(meta.version, installed.version);

    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PluginDetailPage(plugin: meta),
      )),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PluginIcon(url: meta.iconUrl, size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(
                        child: Text(meta.name.isNotEmpty ? meta.name : installed.id,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      if (hasUpdate)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade700.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('MAJ', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.orange.shade400)),
                        ),
                    ]),
                    const SizedBox(height: 2),
                    Text(
                      meta.author.isNotEmpty ? meta.author : meta.category,
                      style: TextStyle(fontSize: 12, color: _grey.withOpacity(0.75)),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                  ]),
                ),
                const SizedBox(width: 8),
                // Enable/disable toggle
                _EnableToggle(id: installed.id, enabled: installed.enabled),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _stripMd(meta.description),
              style: const TextStyle(fontSize: 13, color: _grey, height: 1.4),
              maxLines: 2, overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(children: [
              _TagChip(label: 'v${installed.version}'),
              const SizedBox(width: 6),
              _TagChip(label: meta.category),
              const Spacer(),
              // Home-screen shortcut button (Android only)
              if (Platform.isAndroid) ...[
                GestureDetector(
                  onTap: () => _pinToHomeScreen(
                    context,
                    installed.id,
                    meta.name.isNotEmpty ? meta.name : installed.id,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.withOpacity(0.13),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.deepPurple.withOpacity(0.30)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.add_to_home_screen_rounded, size: 14, color: Colors.deepPurple.shade300),
                      const SizedBox(width: 4),
                      Text('Accueil', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.deepPurple.shade300)),
                    ]),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              // Launch button
              GestureDetector(
                onTap: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => _LaunchPluginSheet(installed: installed, meta: meta),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _teal.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _teal.withOpacity(0.35)),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.play_arrow_rounded, size: 14, color: _teal),
                    SizedBox(width: 4),
                    Text('Lancer', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _teal)),
                  ]),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _EnableToggle extends ConsumerWidget {
  final String id;
  final bool enabled;
  const _EnableToggle({required this.id, required this.enabled});

  @override
  Widget build(BuildContext context, WidgetRef ref) => GestureDetector(
    onTap: () {
      HapticFeedback.lightImpact();
      ref.read(installedPluginsProvider.notifier).toggle(id);
    },
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 42, height: 24,
      decoration: BoxDecoration(
        color: enabled ? _teal : const Color(0xFF3A3A3A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 200),
        alignment: enabled ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 18, height: 18, margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 4)],
          ),
        ),
      ),
    ),
  );
}

// ─── Empty & error states ─────────────────────────────────────────────────────

class _EmptyInstalled extends StatelessWidget {
  const _EmptyInstalled();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(color: _card, shape: BoxShape.circle, border: Border.all(color: _border)),
          child: const Icon(Icons.extension_off_rounded, size: 36, color: _grey),
        ),
        const SizedBox(height: 20),
        const Text('Aucun plugin installé',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white)),
        const SizedBox(height: 8),
        const Text('Parcourez le catalogue et installez\ndes plugins pour enrichir Watchtower.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: _grey, height: 1.5)),
      ]),
    ),
  );
}

class _EmptySearch extends StatelessWidget {
  final String query;
  const _EmptySearch({required this.query});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.search_off_rounded, size: 42, color: _grey),
        const SizedBox(height: 14),
        Text('Aucun résultat pour "$query"',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
      ]),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.cloud_off_rounded, size: 42, color: _grey),
        const SizedBox(height: 14),
        const Text('Impossible de charger les plugins',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
        const SizedBox(height: 8),
        Text(error, textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: _grey), maxLines: 3),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('Réessayer'),
          style: FilledButton.styleFrom(backgroundColor: _teal),
        ),
      ]),
    ),
  );
}

// ─── Skeleton loading ─────────────────────────────────────────────────────────

class _PluginsSkeleton extends StatefulWidget {
  const _PluginsSkeleton();

  @override
  State<_PluginsSkeleton> createState() => _PluginsSkeletonState();
}

class _PluginsSkeletonState extends State<_PluginsSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Widget _bone({double width = double.infinity, double height = 13, double radius = 7}) =>
    AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: width, height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          color: Color.lerp(const Color(0xFF1E1E1E), const Color(0xFF2D2D2D), _anim.value),
        ),
      ),
    );

  @override
  Widget build(BuildContext context) => ListView.builder(
    padding: const EdgeInsets.only(top: 14, bottom: 60),
    itemCount: 6,
    itemBuilder: (_, __) => Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _bone(width: 48, height: 48, radius: 12),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _bone(height: 14, radius: 7),
            const SizedBox(height: 6),
            _bone(width: 120, height: 11, radius: 6),
          ])),
          const SizedBox(width: 8),
          _bone(width: 36, height: 36, radius: 10),
        ]),
        const SizedBox(height: 10),
        _bone(height: 11, radius: 6),
        const SizedBox(height: 5),
        _bone(width: 200, height: 11, radius: 6),
        const SizedBox(height: 8),
        Row(children: [_bone(width: 60, height: 22, radius: 6), const SizedBox(width: 6), _bone(width: 60, height: 22, radius: 6)]),
      ]),
    ),
  );
}

// ─── Launch plugin sheet ──────────────────────────────────────────────────────

class _LaunchPluginSheet extends StatefulWidget {
  final InstalledPlugin installed;
  final PluginEntry meta;
  const _LaunchPluginSheet({required this.installed, required this.meta});

  @override
  State<_LaunchPluginSheet> createState() => _LaunchPluginSheetState();
}

class _LaunchPluginSheetState extends State<_LaunchPluginSheet> {
  final _urlController = TextEditingController();
  bool _running = false;
  String? _result;

  bool get _isDownloader =>
      widget.meta.category == 'downloader' ||
      widget.meta.runtimeTypes.contains('downloader') ||
      widget.meta.commandScopes.contains('download');

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;
    setState(() { _running = true; _result = null; });
    try {
      final supportDir = await getApplicationSupportDirectory();
      final zeusBin = File('${supportDir.path}/binaries/zeusdl');
      if (!await zeusBin.exists() || await zeusBin.length() == 0) {
        setState(() { _running = false; _result = 'Erreur : ZeusDL non installé. Allez dans Marketplace → Binaires.'; });
        return;
      }
      final proc = await Process.start(zeusBin.path, [url]);
      final exitCode = await proc.exitCode;
      if (!mounted) return;
      setState(() {
        _running = false;
        _result = exitCode == 0 ? 'Téléchargement lancé ✓' : 'Terminé avec code $exitCode';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _running = false; _result = 'Erreur : $e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDownloader = _isDownloader;
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, sc) => Container(
        decoration: const BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(children: [
          const SizedBox(height: 10),
          Container(width: 36, height: 4, decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(2))),
          Expanded(
            child: ListView(controller: sc, padding: const EdgeInsets.fromLTRB(20, 18, 20, 32), children: [
              Row(children: [
                _PluginIcon(url: widget.meta.iconUrl, size: 46),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.meta.name.isNotEmpty ? widget.meta.name : widget.installed.id,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                  Text(widget.meta.category.isNotEmpty ? widget.meta.category : 'Plugin',
                      style: const TextStyle(fontSize: 12, color: _teal)),
                ])),
              ]),
              const SizedBox(height: 20),
              if (isDownloader) ...[
                const Text('URL à télécharger',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _grey)),
                const SizedBox(height: 8),
                TextField(
                  controller: _urlController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'https://…',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                    filled: true,
                    fillColor: _card2,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: _border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: _border),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                      borderSide: BorderSide(color: _teal),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: _running ? null : _run,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: _running ? _card2 : _teal,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: _running
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: _teal))
                        : const Text('Démarrer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: _card2, borderRadius: BorderRadius.circular(14)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Fonctionnalités', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                    const SizedBox(height: 10),
                    if (widget.meta.runtimeTypes.isNotEmpty)
                      ...widget.meta.runtimeTypes.map((r) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(children: [
                          const Icon(Icons.check_circle_outline_rounded, size: 14, color: _teal),
                          const SizedBox(width: 8),
                          Text(r, style: const TextStyle(color: _grey, fontSize: 13)),
                        ]),
                      ))
                    else
                      const Text('Ce plugin est actif et fonctionne en arrière-plan.',
                          style: TextStyle(color: _grey, fontSize: 13)),
                  ]),
                ),
              ],
              if (_result != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _result!.startsWith('Erreur')
                        ? Colors.red.withOpacity(0.12)
                        : _teal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _result!.startsWith('Erreur')
                          ? Colors.red.withOpacity(0.35)
                          : _teal.withOpacity(0.3),
                    ),
                  ),
                  child: Text(_result!, style: TextStyle(
                    color: _result!.startsWith('Erreur') ? Colors.red.shade300 : _teal,
                    fontSize: 13,
                  )),
                ),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}
