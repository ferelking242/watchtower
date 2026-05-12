import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:watchtower/modules/more/about/providers/logs_state.dart';
import 'package:watchtower/utils/log/logger.dart';
import 'package:watchtower/utils/log/log_overlay.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Dedicated Log Settings Screen
// Extracted from AdvancedScreen so it has its own route (/logSettings).
// ─────────────────────────────────────────────────────────────────────────────

class LogSettingsScreen extends ConsumerStatefulWidget {
  const LogSettingsScreen({super.key});

  @override
  ConsumerState<LogSettingsScreen> createState() => _LogSettingsScreenState();
}

class _LogSettingsScreenState extends ConsumerState<LogSettingsScreen> {
  int _logMode = 1;
  bool _logSuppressImages = true;
  bool _logTagExt = true;
  bool _logTagDl = true;
  bool _logTagNet = true;
  bool _logTagZeus = true;
  bool _logTagUi = true;
  bool _logTagManga = false;
  bool _logTagPage = false;
  bool _logTagHls = false;
  bool _logTagInstall = true;
  bool _logTagReader = false;
  bool _logTagWatch = true;
  bool _logTagMaint = true;
  bool _autoShowOnError = false;
  bool _volumeShortcut = false;
  bool _loading = true;

  static const _kBoxName = 'advanced_settings';
  static const _kAutoShowOnError = 'log_auto_show_on_error';
  static const _kVolumeShortcut = 'log_volume_shortcut';

  Future<Box> _openBox() => Hive.openBox(_kBoxName);

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final box = await _openBox();
    if (!mounted) return;
    setState(() {
      _logMode = box.get(kLogMode, defaultValue: 1) as int;
      _logSuppressImages =
          box.get(kLogSuppressImages, defaultValue: true) as bool;
      _logTagExt = box.get(kLogTagExt, defaultValue: true) as bool;
      _logTagDl = box.get(kLogTagDl, defaultValue: true) as bool;
      _logTagNet = box.get(kLogTagNet, defaultValue: true) as bool;
      _logTagZeus = box.get(kLogTagZeus, defaultValue: true) as bool;
      _logTagUi = box.get(kLogTagUi, defaultValue: true) as bool;
      _logTagManga = box.get(kLogTagManga, defaultValue: false) as bool;
      _logTagPage = box.get(kLogTagPage, defaultValue: false) as bool;
      _logTagHls = box.get(kLogTagHls, defaultValue: false) as bool;
      _logTagInstall = box.get(kLogTagInstall, defaultValue: true) as bool;
      _logTagReader = box.get(kLogTagReader, defaultValue: false) as bool;
      _logTagWatch = box.get(kLogTagWatch, defaultValue: true) as bool;
      _logTagMaint = box.get(kLogTagMaint, defaultValue: true) as bool;
      _autoShowOnError =
          box.get(_kAutoShowOnError, defaultValue: false) as bool;
      _volumeShortcut =
          box.get(_kVolumeShortcut, defaultValue: false) as bool;
      _loading = false;
    });
    // Apply persisted shortcuts
    if (_autoShowOnError) LogOverlayController.listenForErrors();
    if (_volumeShortcut) LogOverlayController.installVolumeShortcut();
  }

  Future<void> _save(String key, dynamic value) async {
    final box = await _openBox();
    await box.put(key, value);
    await AppLogger.reloadSettings();
  }

  Future<void> _applyMode(LogMode mode) async {
    final tags = mode.defaultTags;
    setState(() {
      _logMode = mode.index;
      _logTagExt = tags[kLogTagExt]!;
      _logTagDl = tags[kLogTagDl]!;
      _logTagNet = tags[kLogTagNet]!;
      _logTagZeus = tags[kLogTagZeus]!;
      _logTagUi = tags[kLogTagUi]!;
      _logTagManga = tags[kLogTagManga]!;
      _logTagPage = tags[kLogTagPage]!;
      _logTagHls = tags[kLogTagHls]!;
      _logTagInstall = tags[kLogTagInstall]!;
      _logTagReader = tags[kLogTagReader]!;
      _logTagWatch = tags[kLogTagWatch]!;
      _logTagMaint = tags[kLogTagMaint]!;
    });
    final box = await _openBox();
    await box.put(kLogMode, mode.index);
    await box.put(kLogMinLevel, mode.minLevel);
    for (final e in tags.entries) {
      await box.put(e.key, e.value);
    }
    await AppLogger.reloadSettings();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final secondary =
        Theme.of(context).textTheme.bodySmall?.color ??
        cs.onSurface.withOpacity(0.6);
    final logsEnabled = ref.watch(logsStateProvider);
    final selectedMode = LogMode.values[_logMode.clamp(0, 3)];

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Paramètres des logs')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    Widget section(String title) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: cs.primary,
              letterSpacing: 0.3,
            ),
          ),
        );

    Widget toggle({
      required String title,
      required String subtitle,
      required bool value,
      required void Function(bool) onChanged,
      bool danger = false,
      bool disabled = false,
    }) {
      final activeColor = danger ? Colors.red : cs.primary;
      return SwitchListTile(
        dense: true,
        title: Text(
          title,
          style: TextStyle(
            fontSize: 13.5,
            color: disabled ? secondary : null,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 11.5, color: secondary),
        ),
        value: value,
        onChanged: disabled ? null : onChanged,
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return cs.onSurface.withOpacity(0.3);
          }
          if (states.contains(WidgetState.selected)) return Colors.white;
          return null;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return cs.onSurface.withOpacity(0.12);
          }
          if (states.contains(WidgetState.selected)) return activeColor;
          return null;
        }),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres des logs'),
        actions: [
          IconButton(
            tooltip: 'Ouvrir overlay',
            icon: const Icon(Icons.terminal_rounded),
            onPressed: () => LogOverlayController.instance.toggle(),
          ),
        ],
      ),
      body: ListView(
        children: [
          // ── Logs disabled notice ────────────────────────────────────────
          if (!logsEnabled)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: cs.outline.withOpacity(0.25)),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 18, color: cs.onSurface.withOpacity(0.55)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Activez les logs dans À propos > Développeur pour que ces paramètres prennent effet.",
                        style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurface.withOpacity(0.7)),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Overlay shortcuts ───────────────────────────────────────────
          section('Overlay'),
          toggle(
            title: 'Affichage auto sur erreur',
            subtitle:
                "L'overlay s'ouvre automatiquement à chaque entrée ERROR",
            value: _autoShowOnError,
            disabled: !logsEnabled,
            onChanged: (v) async {
              setState(() => _autoShowOnError = v);
              await _save(_kAutoShowOnError, v);
              if (v) LogOverlayController.listenForErrors();
            },
          ),
          toggle(
            title: 'Raccourci touches volume',
            subtitle:
                'Appuyer sur Volume+ ou Volume− bascule l\'overlay (Android)',
            value: _volumeShortcut,
            disabled: !logsEnabled,
            onChanged: (v) async {
              setState(() => _volumeShortcut = v);
              await _save(_kVolumeShortcut, v);
              if (v) LogOverlayController.installVolumeShortcut();
            },
          ),

          // ── Mode ────────────────────────────────────────────────────────
          section('Mode de logging'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: LogMode.values.map((mode) {
                    final selected = _logMode == mode.index;
                    final Color chipColor;
                    switch (mode) {
                      case LogMode.normal:
                        chipColor = Colors.green;
                        break;
                      case LogMode.verbose:
                        chipColor = Colors.blue;
                        break;
                      case LogMode.debug:
                        chipColor = Colors.orange;
                        break;
                      case LogMode.extreme:
                        chipColor = Colors.red;
                        break;
                    }
                    return ChoiceChip(
                      label: Text(
                        mode.displayName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? Colors.white
                              : logsEnabled
                                  ? chipColor
                                  : secondary,
                        ),
                      ),
                      selected: selected,
                      selectedColor: logsEnabled ? chipColor : secondary,
                      backgroundColor: logsEnabled
                          ? chipColor.withOpacity(0.1)
                          : cs.surfaceContainerHighest,
                      side: BorderSide(
                        color: selected
                            ? Colors.transparent
                            : logsEnabled
                                ? chipColor.withOpacity(0.4)
                                : secondary.withOpacity(0.2),
                      ),
                      onSelected: logsEnabled ? (_) => _applyMode(mode) : null,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                Text(
                  selectedMode.description,
                  style: TextStyle(
                    fontSize: 11,
                    color: secondary.withOpacity(0.75),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),

          // ── Options ─────────────────────────────────────────────────────
          section('Options'),
          toggle(
            title: "Supprimer erreurs d'images",
            subtitle: "Ne pas enregistrer les erreurs de logos 404",
            value: _logSuppressImages,
            disabled: !logsEnabled,
            onChanged: (v) {
              setState(() => _logSuppressImages = v);
              _save(kLogSuppressImages, v);
            },
          ),

          // ── Catégories actives ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
            child: Row(
              children: [
                Text(
                  'Catégories actives',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: cs.primary,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'personnalisables',
                    style: TextStyle(
                      fontSize: 10,
                      color: cs.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          toggle(
            title: 'Extensions [EXT]',
            subtitle: 'Installation, mise à jour, erreurs d\'extensions',
            value: _logTagExt,
            disabled: !logsEnabled,
            onChanged: (v) {
              setState(() => _logTagExt = v);
              _save(kLogTagExt, v);
            },
          ),
          toggle(
            title: 'Installation détaillée [INSTALL]',
            subtitle: 'Chaque étape d\'installation/désinstallation',
            value: _logTagInstall,
            disabled: !logsEnabled,
            onChanged: (v) {
              setState(() => _logTagInstall = v);
              _save(kLogTagInstall, v);
            },
          ),
          toggle(
            title: 'Téléchargements [DL]',
            subtitle: 'Progression, reprise, erreurs de téléchargements',
            value: _logTagDl,
            disabled: !logsEnabled,
            onChanged: (v) {
              setState(() => _logTagDl = v);
              _save(kLogTagDl, v);
            },
          ),
          toggle(
            title: 'HLS streaming [HLS]',
            subtitle: 'Segments HLS, manifest, erreurs de stream',
            value: _logTagHls,
            disabled: !logsEnabled,
            onChanged: (v) {
              setState(() => _logTagHls = v);
              _save(kLogTagHls, v);
            },
          ),
          toggle(
            title: 'Réseau [NET]',
            subtitle: 'Requêtes HTTP, redirections, erreurs réseau',
            value: _logTagNet,
            disabled: !logsEnabled,
            onChanged: (v) {
              setState(() => _logTagNet = v);
              _save(kLogTagNet, v);
            },
          ),
          toggle(
            title: 'ZeusDL [ZEUS]',
            subtitle: 'Moteur ZeusDL / yt-dlp – sorties complètes',
            value: _logTagZeus,
            disabled: !logsEnabled,
            onChanged: (v) {
              setState(() => _logTagZeus = v);
              _save(kLogTagZeus, v);
            },
          ),
          toggle(
            title: 'Manga [MANGA]',
            subtitle: 'Chargement série, chapitres, métadonnées',
            value: _logTagManga,
            disabled: !logsEnabled,
            onChanged: (v) {
              setState(() => _logTagManga = v);
              _save(kLogTagManga, v);
            },
          ),
          toggle(
            title: 'Lecteur [READER]',
            subtitle: 'Navigation lecteur, zoom, orientation',
            value: _logTagReader,
            disabled: !logsEnabled,
            onChanged: (v) {
              setState(() => _logTagReader = v);
              _save(kLogTagReader, v);
            },
          ),
          toggle(
            title: 'Pages manga [PAGE]',
            subtitle: '⚡ Chaque page chargée (très verbeux)',
            value: _logTagPage,
            disabled: !logsEnabled,
            danger: true,
            onChanged: (v) {
              setState(() => _logTagPage = v);
              _save(kLogTagPage, v);
            },
          ),
          toggle(
            title: 'Lecture vidéo [WATCH]',
            subtitle: 'Ouverture épisode, buffering, watchdog 60 s',
            value: _logTagWatch,
            disabled: !logsEnabled,
            onChanged: (v) {
              setState(() => _logTagWatch = v);
              _save(kLogTagWatch, v);
            },
          ),
          toggle(
            title: 'Maintenance [MAINT]',
            subtitle:
                'Nettoyage cookies, BDD, réindexation, tâches d\'arrière-plan',
            value: _logTagMaint,
            disabled: !logsEnabled,
            onChanged: (v) {
              setState(() => _logTagMaint = v);
              _save(kLogTagMaint, v);
            },
          ),
          toggle(
            title: 'Interface [UI]',
            subtitle: 'Événements et erreurs d\'interface',
            value: _logTagUi,
            disabled: !logsEnabled,
            onChanged: (v) {
              setState(() => _logTagUi = v);
              _save(kLogTagUi, v);
            },
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
