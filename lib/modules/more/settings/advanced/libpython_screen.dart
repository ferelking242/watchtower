import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:watchtower/services/python/libpython_manager.dart';
import 'package:watchtower/utils/extensions/build_context_extensions.dart';

class LibPythonScreen extends StatefulWidget {
  const LibPythonScreen({super.key});

  @override
  State<LibPythonScreen> createState() => _LibPythonScreenState();
}

class _LibPythonScreenState extends State<LibPythonScreen> {
  final _mgr = LibPythonManager.instance;
  final _installCtrl = TextEditingController();
  final _consoleCtrl = ScrollController();

  String _pythonVersion = '…';
  String _pipVersion = '…';
  String _sitePackagesPath = '…';
  List<PythonPackageInfo> _packages = [];
  Map<String, bool> _zeusDepStatus = {};
  final List<String> _consoleLines = [];

  bool _loadingInfo = true;
  bool _loadingPackages = true;
  bool _loadingZeusDeps = true;
  bool _pipBusy = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _installCtrl.dispose();
    _consoleCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    if (!Platform.isAndroid) {
      setState(() {
        _loadingInfo = false;
        _loadingPackages = false;
        _loadingZeusDeps = false;
      });
      return;
    }

    _mgr.getPythonVersion().then((v) {
      if (mounted) setState(() { _pythonVersion = v; _loadingInfo = false; });
    });
    _mgr.getPipVersion().then((v) {
      if (mounted) setState(() => _pipVersion = v);
    });
    _mgr.sitePackagesDir.then((p) {
      if (mounted) setState(() => _sitePackagesPath = p);
    });
    _refreshPackages();
    _refreshZeusDeps();
  }

  Future<void> _refreshPackages() async {
    if (!Platform.isAndroid) return;
    setState(() => _loadingPackages = true);
    final pkgs = await _mgr.listInstalledPackages();
    if (mounted) setState(() { _packages = pkgs; _loadingPackages = false; });
  }

  Future<void> _refreshZeusDeps() async {
    if (!Platform.isAndroid) return;
    setState(() => _loadingZeusDeps = true);
    final status = await _mgr.checkZeusDeps();
    if (mounted) setState(() { _zeusDepStatus = status; _loadingZeusDeps = false; });
  }

  void _log(String line) {
    if (!mounted) return;
    setState(() {
      _consoleLines.add(line);
      if (_consoleLines.length > 500) _consoleLines.removeAt(0);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_consoleCtrl.hasClients) {
        _consoleCtrl.animateTo(
          _consoleCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _bootstrapPip() async {
    setState(() => _pipBusy = true);
    _log('▶ Bootstrap pip...');
    final result = await _mgr.bootstrapPip();
    for (final line in result.split('\n')) {
      if (line.trim().isNotEmpty) _log(line);
    }
    _log('');
    await _refreshPackages();
    _mgr.getPipVersion().then((v) {
      if (mounted) setState(() => _pipVersion = v);
    });
    if (mounted) setState(() => _pipBusy = false);
  }

  Future<void> _installAllZeusDeps() async {
    setState(() => _pipBusy = true);
    _log('▶ Installation des dépendances ZeusDL...');
    final result = await _mgr.ensureZeusDlDeps(onProgress: (msg) => _log('  $msg'));
    for (final line in result.split('\n')) {
      if (line.trim().isNotEmpty) _log(line);
    }
    _log('');
    await _refreshPackages();
    await _refreshZeusDeps();
    if (mounted) setState(() => _pipBusy = false);
  }

  Future<void> _installSingleDep(String pkg) async {
    setState(() => _pipBusy = true);
    _log('▶ pip install $pkg...');
    final result = await _mgr.installPackage(pkg);
    for (final line in result.split('\n')) {
      if (line.trim().isNotEmpty) _log(line);
    }
    _log('');
    await _refreshPackages();
    await _refreshZeusDeps();
    if (mounted) setState(() => _pipBusy = false);
  }

  Future<void> _installCustomPackage() async {
    final pkg = _installCtrl.text.trim();
    if (pkg.isEmpty) return;
    _installCtrl.clear();
    setState(() => _pipBusy = true);
    _log('▶ pip install $pkg...');
    final result = await _mgr.installPackage(pkg);
    for (final line in result.split('\n')) {
      if (line.trim().isNotEmpty) _log(line);
    }
    _log('');
    await _refreshPackages();
    await _refreshZeusDeps();
    if (mounted) setState(() => _pipBusy = false);
  }

  Future<void> _uninstallPackage(String pkg) async {
    setState(() => _pipBusy = true);
    _log('▶ Désinstallation de $pkg...');
    final result = await _mgr.uninstallPackage(pkg);
    _log(result);
    _log('');
    await _refreshPackages();
    await _refreshZeusDeps();
    if (mounted) setState(() => _pipBusy = false);
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, {bool mono = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: context.secondaryColor,
                    fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: GestureDetector(
              onLongPress: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Copié'),
                        duration: Duration(seconds: 1)));
              },
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: mono ? 'monospace' : null,
                  color: mono ? Theme.of(context).colorScheme.onSurfaceVariant : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (!Platform.isAndroid) {
      return Scaffold(
        appBar: AppBar(title: const Text('LibPython')),
        body: const Center(child: Text('LibPython est disponible sur Android uniquement.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('LibPython'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Rafraîchir',
            onPressed: _pipBusy ? null : _loadAll,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_pipBusy)
            LinearProgressIndicator(
              backgroundColor: cs.surfaceContainerHighest,
              color: cs.primary,
            ),
          Expanded(
            child: ListView(
              children: [
                // ── Section : Runtime ─────────────────────────────────────────
                _sectionHeader('Runtime Python'),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  elevation: 0,
                  color: cs.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: _loadingInfo
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(),
                            ))
                        : Column(
                            children: [
                              _infoRow('Version', _pythonVersion),
                              _infoRow('pip', _pipVersion),
                              _infoRow('site-packages', _sitePackagesPath, mono: true),
                            ],
                          ),
                  ),
                ),
                if (_pipVersion.contains('non installé') || _pipVersion.contains('non disponible'))
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: FilledButton.icon(
                      onPressed: _pipBusy ? null : _bootstrapPip,
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: const Text('Installer pip (ensurepip)'),
                    ),
                  ),

                // ── Section : Dépendances ZeusDL ──────────────────────────────
                _sectionHeader('Dépendances ZeusDL'),
                if (_loadingZeusDeps)
                  const Center(
                      child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator()))
                else ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: LibPythonManager.zeusRequiredPackages.map((pkg) {
                        final ok = _zeusDepStatus[pkg] ?? false;
                        return ActionChip(
                          avatar: Icon(
                            ok ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                            size: 16,
                            color: ok ? Colors.green : cs.error,
                          ),
                          label: Text(pkg, style: const TextStyle(fontSize: 12)),
                          backgroundColor: ok
                              ? Colors.green.withOpacity(0.12)
                              : cs.error.withOpacity(0.1),
                          side: BorderSide(
                            color: ok
                                ? Colors.green.withOpacity(0.4)
                                : cs.error.withOpacity(0.3),
                          ),
                          onPressed: _pipBusy
                              ? null
                              : () => ok
                                  ? _showUninstallDialog(pkg)
                                  : _installSingleDep(pkg),
                          tooltip: ok
                              ? 'Installé — appuyer pour désinstaller'
                              : 'Manquant — appuyer pour installer',
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _pipBusy ? null : _installAllZeusDeps,
                            icon: const Icon(Icons.download_for_offline_rounded, size: 18),
                            label: const Text('Tout installer'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: _pipBusy ? null : _refreshZeusDeps,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Vérifier'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                ],

                // ── Section : Installer un package ────────────────────────────
                _sectionHeader('Installer un package'),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _installCtrl,
                          enabled: !_pipBusy,
                          decoration: const InputDecoration(
                            hintText: 'nom==version (ex: requests, yt-dlp)',
                            border: OutlineInputBorder(),
                            contentPadding:
                                EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            isDense: true,
                          ),
                          style: const TextStyle(fontSize: 13),
                          onSubmitted: (_) => _installCustomPackage(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _pipBusy ? null : _installCustomPackage,
                        style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12)),
                        child: const Text('Installer'),
                      ),
                    ],
                  ),
                ),

                // ── Section : Packages installés ──────────────────────────────
                _sectionHeader(
                    'Packages installés (${_loadingPackages ? "…" : _packages.length})'),
                if (_loadingPackages)
                  const Center(
                      child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator()))
                else if (_packages.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Text(
                      'Aucun package installé.\nUtilisez "Tout installer" pour installer les dépendances ZeusDL.',
                      style: TextStyle(fontSize: 13, color: context.secondaryColor),
                    ),
                  )
                else
                  ..._packages.map((pkg) => _PackageTile(
                        package: pkg,
                        onUninstall: _pipBusy ? null : () => _showUninstallDialog(pkg.name),
                      )),

                // ── Section : Console ─────────────────────────────────────────
                _sectionHeader('Console pip'),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () => setState(() => _consoleLines.clear()),
                        icon: const Icon(Icons.clear_all_rounded, size: 16),
                        label: const Text('Effacer', style: TextStyle(fontSize: 12)),
                      ),
                      const SizedBox(width: 4),
                      TextButton.icon(
                        onPressed: _consoleLines.isEmpty
                            ? null
                            : () {
                                Clipboard.setData(
                                    ClipboardData(text: _consoleLines.join('\n')));
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('Console copiée'),
                                        duration: Duration(seconds: 1)));
                              },
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: const Text('Copier', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: Container(
                    height: 220,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D1117),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: cs.outline.withOpacity(0.25)),
                    ),
                    padding: const EdgeInsets.all(10),
                    child: _consoleLines.isEmpty
                        ? Center(
                            child: Text(
                              'Aucune sortie pour l\'instant.\nInstallez des packages pour voir la sortie pip.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withOpacity(0.35),
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: _consoleCtrl,
                            itemCount: _consoleLines.length,
                            itemBuilder: (_, i) => Text(
                              _consoleLines[i],
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFFD4D4D4),
                                fontFamily: 'monospace',
                                height: 1.4,
                              ),
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showUninstallDialog(String pkg) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Désinstaller'),
        content: Text('Supprimer $pkg de site-packages ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Supprimer',
                  style: TextStyle(color: Theme.of(ctx).colorScheme.error))),
        ],
      ),
    );
    if (confirm == true) await _uninstallPackage(pkg);
  }
}

class _PackageTile extends StatelessWidget {
  final PythonPackageInfo package;
  final VoidCallback? onUninstall;

  const _PackageTile({required this.package, this.onUninstall});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      title: Text(package.name, style: const TextStyle(fontSize: 13)),
      subtitle: Text(package.version,
          style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontFamily: 'monospace')),
      trailing: IconButton(
        icon: Icon(Icons.delete_outline_rounded,
            size: 18, color: Theme.of(context).colorScheme.error.withOpacity(0.7)),
        tooltip: 'Désinstaller',
        onPressed: onUninstall,
      ),
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            package.name[0].toUpperCase(),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ),
      ),
    );
  }
}
