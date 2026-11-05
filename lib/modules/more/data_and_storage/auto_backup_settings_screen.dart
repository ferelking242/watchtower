import 'dart:async';
import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/modules/more/data_and_storage/providers/auto_backup.dart';
import 'package:watchtower/modules/more/data_and_storage/providers/backup_compression.dart';
import 'package:watchtower/modules/more/data_and_storage/providers/restore.dart';
import 'package:watchtower/modules/more/settings/widgets/settings_subpage_scaffold.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/services/auto_backup_service.dart';
import 'package:watchtower/utils/extensions/build_context_extensions.dart';
import 'package:watchtower/utils/log/logger.dart';

/// Settings page for the automatic, uninstall-surviving backup.
///
/// Shows where the snapshot lives, whether it is enabled, when it last ran,
/// and lets the user trigger a snapshot or restore it. This is the screen the
/// user is pointed to from Settings → Sauvegarde automatique.
class AutoBackupSettingsScreen extends ConsumerStatefulWidget {
  const AutoBackupSettingsScreen({super.key});

  @override
  ConsumerState<AutoBackupSettingsScreen> createState() =>
      _AutoBackupSettingsScreenState();
}

class _AutoBackupSettingsScreenState
    extends ConsumerState<AutoBackupSettingsScreen> {
  bool _enabled = true;
  bool _hasBackup = false;
  DateTime? _lastBackup;
  String? _path;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await AutoBackupService.isEnabled();
    final has = await AutoBackupService.hasBackup();
    final last = await AutoBackupService.lastBackupTime();
    final path = await AutoBackupService.backupDirectoryPath();
    if (!mounted) return;
    setState(() {
      _enabled = enabled;
      _hasBackup = has;
      _lastBackup = last;
      _path = path;
    });
  }

  String _formatDate(DateTime? value) {
    if (value == null) return 'Jamais';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(value.day)}/${two(value.month)}/${value.year} '
        '${two(value.hour)}:${two(value.minute)}';
  }

  Future<void> _backupNow() async {
    setState(() => _busy = true);
    // Explicit user action: never skipped by the automatic freshness guard.
    await AutoBackupService.backupNow(force: true);
    await _load();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sauvegarde effectuée.')),
    );
  }

  Future<void> _restoreNow() async {
    setState(() => _busy = true);
    final ok = await AutoBackupService.restoreNow();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Sauvegarde restaurée. Redémarrez l\'application pour '
                    'recharger la base.'
              : 'Aucune sauvegarde à restaurer.',
        ),
      ),
    );
  }

  List<String> _getBackupFrequencyList(BuildContext context) {
    final l10n = l10nLocalizations(context)!;
    return [
      l10n.off,
      l10n.every_6_hours,
      l10n.every_12_hours,
      l10n.daily,
      l10n.every_2_days,
      l10n.weekly,
    ];
  }

  void _pickBackupFrequency(dynamic l10n) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final list = _getBackupFrequencyList(context);
        return AlertDialog(
          title: Text(l10n.backup_frequency),
          content: SizedBox(
            width: context.width(0.8),
            child: RadioGroup<int>(
              groupValue: ref.read(backupFrequencyStateProvider),
              onChanged: (value) {
                ref.read(backupFrequencyStateProvider.notifier).set(value!);
                Navigator.pop(dialogContext);
              },
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: list.length,
                itemBuilder: (context, index) => RadioListTile<int>(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: index,
                  title: Text(list[index]),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickBackupLocation() async {
    final result = await FilePicker.getDirectoryPath();
    if (result != null) {
      ref.read(autoBackupLocationStateProvider.notifier).set(result);
    }
  }

  Future<void> _restoreFromFile() async {
    final result = await FilePicker.pickFiles(allowMultiple: false);
    if (result == null || !mounted) return;
    ref.watch(
      doRestoreProvider(path: result.files.first.path!, context: context),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = l10nLocalizations(context)!;
    final backupFrequency = ref.watch(backupFrequencyStateProvider);
    final autoBackupLocation = ref.watch(autoBackupLocationStateProvider);
    final compression = ref.watch(backupCompressionLevelProvider);
    return SettingsSubpageScaffold(
      title: 'Sauvegarde automatique',
      showSearch: false,
      leading: IconButton(
        icon: const Icon(Broken.arrow_left_2),
        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        onPressed: () => context.pop(),
      ),
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            children: [
              SwitchListTile(
                value: _enabled,
                title: const Text('Sauvegarde automatique'),
                subtitle: const Text(
                  'Enregistre régulièrement la bibliothèque, les réglages, '
                  'les extensions et le cache dans un dossier qui survit à la '
                  'désinstallation.',
                  style: TextStyle(fontSize: 11),
                ),
                onChanged: (value) async {
                  setState(() => _enabled = value);
                  await AutoBackupService.setEnabled(value);
                  await _load();
                },
              ),
              ListTile(
                title: const Text('Emplacement de la sauvegarde'),
                subtitle: Text(
                  _path ?? 'Indisponible',
                  style: const TextStyle(fontSize: 11),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  tooltip: 'Copier le chemin',
                  onPressed: _path == null
                      ? null
                      : () async {
                          await Clipboard.setData(
                            ClipboardData(text: _path!),
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Chemin copié.'),
                            ),
                          );
                        },
                ),
                onTap: () {
                  if (_path != null) {
                    AppLogger.log(
                      'AutoBackup location: $_path',
                      logLevel: LogLevel.info,
                      tag: LogTag.maintenance,
                    );
                  }
                },
              ),
              ListTile(
                title: const Text('Dernière sauvegarde'),
                subtitle: Text(
                  _formatDate(_lastBackup),
                  style: const TextStyle(fontSize: 11),
                ),
              ),
              ListTile(
                title: const Text('Sauvegarde présente sur le disque'),
                subtitle: Text(
                  _hasBackup ? 'Oui' : 'Non',
                  style: const TextStyle(fontSize: 11),
                ),
              ),
              const Divider(height: 24),
              ListTile(
                onTap: () => _pickBackupFrequency(l10n),
                title: Text(l10n.backup_frequency),
                subtitle: Text(
                  _getBackupFrequencyList(context)[backupFrequency],
                  style: const TextStyle(fontSize: 11),
                ),
              ),
              ListTile(
                title: Text(l10n.compression_level),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.compression_info(DeflateLevel.defaultCompression),
                      style: const TextStyle(fontSize: 11),
                    ),
                    Slider(
                      min: 0,
                      max: 9,
                      divisions: 9,
                      value: compression.toDouble(),
                      label: compression.toString(),
                      onChanged: (value) => ref
                          .read(backupCompressionLevelProvider.notifier)
                          .update(value.round()),
                      onChangeEnd: (value) => ref
                          .read(backupCompressionLevelProvider.notifier)
                          .set(value.round()),
                    ),
                  ],
                ),
              ),
              if (!kIsWeb && !Platform.isIOS)
                ListTile(
                  onTap: () => _pickBackupLocation(),
                  title: Text(l10n.backup_location),
                  subtitle: Text(
                    autoBackupLocation.$2.isEmpty
                        ? autoBackupLocation.$1
                        : autoBackupLocation.$2,
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              const Divider(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Broken.document_download, size: 18),
                        label: const Text('Sauvegarder maintenant'),
                        onPressed: _busy ? null : _backupNow,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Broken.refresh_circle, size: 18),
                        label: const Text('Restaurer'),
                        onPressed: _busy || !_hasBackup ? null : _restoreNow,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Broken.folder_open, size: 18),
                        label: Text(l10n.create_backup),
                        onPressed: _busy
                            ? null
                            : () => context.push('/createBackup'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Broken.cloud_connection, size: 18),
                        label: Text(l10n.restore_backup),
                        onPressed: _busy ? null : () => _restoreFromFile(),
                      ),
                    ),
                  ],
                ),
              ),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
              ListTile(
                title: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: context.secondaryColor,
                    ),
                  ],
                ),
                subtitle: Text(
                  'La sauvegarde contient : bibliothèque, réglages, '
                  'extensions et leurs préférences, catégories, historique, '
                  'téléchargements, boutons personnalisés et le cache '
                  'nécessaire. Elle est réécrite automatiquement au passage '
                  'en arrière-plan et périodiquement.',
                  style: TextStyle(
                    fontSize: 11,
                    color: context.secondaryColor,
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }
}
