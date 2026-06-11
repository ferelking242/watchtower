import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';

import 'plugins_screen.dart' show InstalledPlugin, PluginEntry;

// ─── Plugin Launcher (full-screen) ───────────────────────────────────────────

class PluginLauncherScreen extends StatefulWidget {
  final InstalledPlugin installed;
  final PluginEntry meta;
  const PluginLauncherScreen({
    required this.installed,
    required this.meta,
    super.key,
  });

  @override
  State<PluginLauncherScreen> createState() => _PluginLauncherScreenState();
}

class _PluginLauncherScreenState extends State<PluginLauncherScreen> {
  final _urlController = TextEditingController();
  final List<_DownloadItem> _downloads = [];
  bool _running = false;

  bool get _isDownloader =>
      widget.meta.category == 'downloader' ||
      widget.meta.runtimeTypes.contains('downloader') ||
      widget.meta.commandScopes.contains('download');

  String get _pluginName =>
      widget.meta.name.isNotEmpty ? widget.meta.name : widget.installed.id;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  // ── Core download logic ────────────────────────────────────────────────────

  Future<void> _startDownload() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    final item = _DownloadItem(url: url);
    setState(() {
      _downloads.insert(0, item);
      _urlController.clear();
      _running = true;
    });

    try {
      final supportDir = await getApplicationSupportDirectory();
      final zeusBin = File('${supportDir.path}/binaries/zeusdl');
      if (!await zeusBin.exists()) {
        _finish(item, 'ZeusDL non installé — Marketplace → Binaires', error: true);
        return;
      }
      setState(() => item.status = 'Démarrage…');

      final proc = await Process.start(zeusBin.path, [url]);
      proc.stdout.listen((bytes) {
        final line = String.fromCharCodes(bytes).trim();
        if (line.isNotEmpty && mounted) setState(() => item.status = line);
      });
      proc.stderr.listen((bytes) {
        final line = String.fromCharCodes(bytes).trim();
        if (line.isNotEmpty && mounted) setState(() => item.status = line);
      });

      final code = await proc.exitCode;
      if (!mounted) return;
      _finish(item, code == 0 ? 'Terminé ✓' : 'Terminé (code $code)', error: code != 0);
    } catch (e) {
      if (!mounted) return;
      _finish(item, 'Erreur : $e', error: true);
    }
  }

  void _finish(_DownloadItem item, String status, {bool error = false}) {
    setState(() {
      item.status = status;
      item.isDone = true;
      item.isError = error;
      _running = false;
    });
  }

  // ── Shortcut dialog ────────────────────────────────────────────────────────

  void _showShortcutDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(children: [
            Icon(Icons.add_to_home_screen_rounded, color: cs.primary, size: 22),
            const SizedBox(width: 10),
            const Text('Créer un raccourci'),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Ajoutez "$_pluginName" sur votre écran d\'accueil :', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
            const SizedBox(height: 14),
            _Step(number: '1', text: 'Maintenez l\'icône Watchtower sur l\'écran d\'accueil'),
            _Step(number: '2', text: 'Appuyez sur "Raccourcis"'),
            _Step(number: '3', text: 'Sélectionnez "$_pluginName"'),
            _Step(number: '4', text: 'Glissez-le sur l\'écran d\'accueil'),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Compris')),
          ],
        );
      },
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          color: cs.onSurface,
          onPressed: () => context.pop(),
        ),
        title: Row(children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(7),
            ),
            child: widget.meta.iconUrl.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: Image.network(
                      widget.meta.iconUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Icon(Icons.extension_rounded, size: 16, color: cs.onPrimaryContainer),
                    ),
                  )
                : Icon(Icons.extension_rounded, size: 16, color: cs.onPrimaryContainer),
          ),
          const SizedBox(width: 10),
          Text(_pluginName,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          if (widget.meta.category.isNotEmpty) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(widget.meta.category,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: cs.onPrimaryContainer)),
            ),
          ],
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_to_home_screen_rounded),
            color: cs.onSurfaceVariant,
            tooltip: 'Créer raccourci',
            onPressed: _showShortcutDialog,
          ),
        ],
      ),
      body: _isDownloader ? _buildDownloaderUI(cs, theme) : _buildInfoUI(cs, theme),
    );
  }

  // ── Downloader UI ──────────────────────────────────────────────────────────

  Widget _buildDownloaderUI(ColorScheme cs, ThemeData theme) {
    return Column(children: [
      // ── Input bar ─────────────────────────────────────────────────────────
      Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          border: Border(bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.4))),
        ),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _urlController,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.go,
              onSubmitted: (_) => _startDownload(),
              style: TextStyle(color: cs.onSurface, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Collez un lien à télécharger…',
                hintStyle: TextStyle(color: cs.onSurface.withValues(alpha: 0.35), fontSize: 14),
                filled: true,
                fillColor: cs.surfaceContainerHigh,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: Icon(Icons.link_rounded, color: cs.onSurfaceVariant, size: 18),
                suffixIcon: IconButton(
                  icon: Icon(Icons.content_paste_rounded, color: cs.primary, size: 18),
                  tooltip: 'Coller',
                  onPressed: () async {
                    final d = await Clipboard.getData('text/plain');
                    if (d?.text != null) setState(() => _urlController.text = d!.text!);
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 46,
            child: FilledButton(
              onPressed: _running ? null : _startDownload,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _running
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: cs.onPrimary),
                    )
                  : const Text('Lancer', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ),

      // ── History ───────────────────────────────────────────────────────────
      Expanded(
        child: _downloads.isEmpty
            ? Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.download_for_offline_rounded,
                      size: 72, color: cs.onSurface.withValues(alpha: 0.1)),
                  const SizedBox(height: 16),
                  Text('Collez un lien pour démarrer',
                      style: TextStyle(
                          fontSize: 14,
                          color: cs.onSurface.withValues(alpha: 0.35))),
                ]),
              )
            : ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _downloads.length,
                separatorBuilder: (_, __) => Divider(
                  indent: 70,
                  height: 1,
                  color: cs.outlineVariant.withValues(alpha: 0.3),
                ),
                itemBuilder: (_, i) {
                  final dl = _downloads[i];
                  return ListTile(
                    leading: _StatusIcon(item: dl, cs: cs),
                    title: Text(
                      dl.url,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      dl.status,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: dl.isError ? cs.error : cs.onSurfaceVariant,
                      ),
                    ),
                    trailing: dl.isDone
                        ? null
                        : SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: cs.primary),
                          ),
                  );
                },
              ),
      ),
    ]);
  }

  // ── Info UI (non-downloader) ───────────────────────────────────────────────

  Widget _buildInfoUI(ColorScheme cs, ThemeData theme) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      if (widget.meta.description.isNotEmpty)
        Card(
          elevation: 0,
          color: cs.surfaceContainerLow,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('À propos',
                  style: theme.textTheme.labelLarge?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 8),
              Text(widget.meta.description, style: TextStyle(color: cs.onSurface, height: 1.5)),
            ]),
          ),
        ),
      if (widget.meta.runtimeTypes.isNotEmpty) ...[
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          color: cs.surfaceContainerLow,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Fonctionnalités',
                  style: theme.textTheme.labelLarge?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 10),
              ...widget.meta.runtimeTypes.map((r) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Icon(Icons.check_circle_rounded, size: 16, color: cs.primary),
                  const SizedBox(width: 10),
                  Text(r, style: TextStyle(color: cs.onSurface)),
                ]),
              )),
            ]),
          ),
        ),
      ],
      const SizedBox(height: 16),
      Text(
        'Ce plugin est actif et s\'intègre automatiquement aux fonctions de Watchtower.',
        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
        textAlign: TextAlign.center,
      ),
    ]);
  }
}

// ─── Status icon ──────────────────────────────────────────────────────────────

class _StatusIcon extends StatelessWidget {
  final _DownloadItem item;
  final ColorScheme cs;
  const _StatusIcon({required this.item, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: item.isError
            ? cs.errorContainer
            : item.isDone
                ? cs.primaryContainer
                : cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
      ),
      child: item.isDone
          ? Icon(
              item.isError ? Icons.error_rounded : Icons.check_rounded,
              color: item.isError ? cs.onErrorContainer : cs.onPrimaryContainer,
              size: 20,
            )
          : const Padding(
              padding: EdgeInsets.all(10),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
    );
  }
}

// ─── Download item model ──────────────────────────────────────────────────────

class _DownloadItem {
  final String url;
  String status;
  bool isDone;
  bool isError;

  _DownloadItem({
    required this.url,
    this.status = 'En attente…',
    this.isDone = false,
    this.isError = false,
  });
}

// ─── Shortcut step row ────────────────────────────────────────────────────────

class _Step extends StatelessWidget {
  final String number;
  final String text;
  const _Step({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(color: cs.primaryContainer, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text(number,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w800, color: cs.onPrimaryContainer)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: cs.onSurface, height: 1.4))),
      ]),
    );
  }
}
