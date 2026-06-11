import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';

import 'plugins_screen.dart' show installedPluginsProvider, InstalledPlugin, PluginEntry;

// ─── Full-screen Play Store style detail page ─────────────────────────────────

class PluginDetailScreen extends ConsumerStatefulWidget {
  final PluginEntry plugin;
  const PluginDetailScreen({required this.plugin, super.key});

  @override
  ConsumerState<PluginDetailScreen> createState() => _PluginDetailScreenState();
}

class _PluginDetailScreenState extends ConsumerState<PluginDetailScreen> {
  bool _installing = false;

  PluginEntry get _p => widget.plugin;

  String _clean(String s) => s
      .replaceAllMapped(RegExp(r'\*\*(.*?)\*\*', dotAll: true), (m) => m.group(1)!)
      .replaceAllMapped(RegExp(r'\*(.*?)\*', dotAll: true), (m) => m.group(1)!)
      .replaceAll(RegExp(r'#{1,6}\s?'), '')
      .trim();

  Future<void> _install() async {
    setState(() => _installing = true);
    try {
      await ref.read(installedPluginsProvider.notifier).install(_p);
    } finally {
      if (mounted) setState(() => _installing = false);
    }
  }

  InstalledPlugin? _findInstalled(List<InstalledPlugin>? list) {
    if (list == null) return null;
    try {
      return list.firstWhere((i) => i.id == _p.id);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final installedAsync = ref.watch(installedPluginsProvider);
    final installed = _findInstalled(installedAsync.value);

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.more_vert_rounded), onPressed: () {}),
        ],
      ),
      body: Skeletonizer(
        enabled: installedAsync.isLoading,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // ── Header ─────────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PluginCardIcon(url: _p.iconUrl, cs: cs, size: 72, rounded: 16),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _p.name.isNotEmpty ? _p.name : 'Plugin',
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            height: 1.25,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _p.author.isNotEmpty ? _p.author : 'Watchtower',
                          style: TextStyle(
                            fontSize: 14,
                            color: cs.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _p.category,
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Action buttons ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: installed != null
                  ? Row(children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () =>
                              ref.read(installedPluginsProvider.notifier).uninstall(_p.id),
                          style: OutlinedButton.styleFrom(
                            shape: const StadiumBorder(),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                          child: const Text('Désinstaller'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed: () =>
                              ref.read(installedPluginsProvider.notifier).toggle(_p.id),
                          style: FilledButton.styleFrom(
                            shape: const StadiumBorder(),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                          child: Text(installed.enabled ? 'Désactiver' : 'Activer'),
                        ),
                      ),
                    ])
                  : SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _installing ? null : _install,
                        style: FilledButton.styleFrom(
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _installing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2.5),
                              )
                            : const Text(
                                'Installer',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                              ),
                      ),
                    ),
            ),

            // ── Info chips ────────────────────────────────────────────────────
            SizedBox(
              height: 76,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _InfoChip(icon: Icons.tag_rounded, label: 'Version', value: _p.version),
                  _InfoChip(icon: Icons.category_rounded, label: 'Catégorie', value: _p.category),
                  if (_p.rating > 0)
                    _InfoChip(
                      icon: Icons.star_rounded,
                      label: 'Note',
                      value: '${_p.rating.toStringAsFixed(1)} ★',
                    ),
                  if (_p.downloadCount > 0)
                    _InfoChip(
                      icon: Icons.download_rounded,
                      label: 'Téléchargements',
                      value: _p.downloadCount.toString(),
                    ),
                ],
              ),
            ),

            Divider(
              indent: 16,
              endIndent: 16,
              color: cs.outlineVariant.withValues(alpha: 0.5),
            ),

            // ── Description ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                'À propos de cette application',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Text(
                _clean(
                  _p.longDescription.isNotEmpty ? _p.longDescription : _p.description,
                ),
                style: TextStyle(
                  fontSize: 14,
                  color: cs.onSurface.withValues(alpha: 0.85),
                  height: 1.6,
                ),
              ),
            ),

            // ── Requirements ──────────────────────────────────────────────────
            if (_p.requirements.isNotEmpty) ...[
              Divider(
                indent: 16,
                endIndent: 16,
                color: cs.outlineVariant.withValues(alpha: 0.5),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Prérequis',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
              ),
              ..._p.requirements.entries.map((e) {
                final req = e.value as Map?;
                final optional = req?['optional'] as bool? ?? false;
                final version = req?['version'] as String? ?? '';
                final reason = req?['reason'] as String? ?? '';
                return ListTile(
                  dense: true,
                  leading: Icon(
                    optional ? Icons.extension_outlined : Icons.extension_rounded,
                    color: optional ? cs.onSurfaceVariant : cs.primary,
                    size: 20,
                  ),
                  title: Row(children: [
                    Text(
                      e.key,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    if (version.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          version,
                          style: TextStyle(fontSize: 9, color: cs.onPrimaryContainer),
                        ),
                      ),
                    ],
                    if (optional) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'optionnel',
                          style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ]),
                  subtitle: reason.isNotEmpty
                      ? Text(
                          reason,
                          style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                        )
                      : null,
                );
              }),
            ],

            // ── Tags ──────────────────────────────────────────────────────────
            if (_p.tags.isNotEmpty) ...[
              Divider(
                indent: 16,
                endIndent: 16,
                color: cs.outlineVariant.withValues(alpha: 0.5),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Tags',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _p.tags
                      .map((t) => Chip(
                            label: Text(t, style: const TextStyle(fontSize: 12)),
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                          ))
                      .toList(),
                ),
              ),
            ],

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ─── Shared plugin icon widget — handles SVG + regular + fallback ─────────────

class PluginCardIcon extends StatelessWidget {
  final String url;
  final ColorScheme cs;
  final double size;
  final double rounded;

  const PluginCardIcon({
    required this.url,
    required this.cs,
    required this.size,
    this.rounded = 5,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    Widget inner;
    if (url.isEmpty) {
      inner = Icon(
        Icons.extension_rounded,
        size: size * 0.55,
        color: cs.onSurfaceVariant,
      );
    } else if (url.endsWith('.svg')) {
      inner = SvgPicture.network(
        url,
        fit: BoxFit.contain,
        width: size * 0.7,
        height: size * 0.7,
        placeholderBuilder: (_) => Icon(
          Icons.extension_rounded,
          size: size * 0.55,
          color: cs.onSurfaceVariant,
        ),
      );
    } else {
      inner = Image.network(
        url,
        fit: BoxFit.contain,
        width: size * 0.7,
        height: size * 0.7,
        errorBuilder: (_, __, ___) => Icon(
          Icons.extension_rounded,
          size: size * 0.55,
          color: cs.onSurfaceVariant,
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).secondaryHeaderColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(rounded),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(rounded),
        child: Center(child: inner),
      ),
    );
  }
}

// ─── Info chip ────────────────────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoChip({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(right: 16),
      width: 80,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: cs.onSurface),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Divider(color: cs.outlineVariant.withValues(alpha: 0.5), height: 10),
          Icon(icon, size: 14, color: cs.onSurfaceVariant),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
