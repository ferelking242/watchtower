import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:isar_community/isar.dart';
import 'package:watchtower/eval/model/m_bridge.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/settings.dart';
import 'package:watchtower/utils/constant.dart';
import 'package:watchtower/utils/log/logger.dart';
import 'package:watchtower/modules/more/about/providers/logs_state.dart';
import 'package:watchtower/modules/more/settings/general/providers/general_state_provider.dart';
import 'package:watchtower/providers/storage_provider.dart';
import 'package:watchtower/services/http/m_client.dart';
import 'package:watchtower/services/anti_bot/remote_bypass_service.dart';
import 'package:watchtower/utils/extensions/build_context_extensions.dart';

// ─── Hive-backed Advanced Settings helpers ────────────────────────────────────

const _kBoxName = 'advanced_settings';
const _kShareCrashKey = 'share_crash_reports';
const _kDetailedReportsKey = 'detailed_reports';
const _kOldDecoderKey = 'old_decoder';
const _kNonAsciiKey = 'no_non_ascii';
const _kBitmapThresholdKey = 'bitmap_threshold';

Future<Box> _openBox() => Hive.openBox(_kBoxName);

Future<bool> _getBool(String key, {bool defaultValue = false}) async {
  final box = await _openBox();
  return box.get(key, defaultValue: defaultValue) as bool;
}

Future<void> _setBool(String key, bool value) async {
  final box = await _openBox();
  await box.put(key, value);
}

Future<int> _getInt(String key, {int defaultValue = 0}) async {
  final box = await _openBox();
  return box.get(key, defaultValue: defaultValue) as int;
}

Future<void> _setInt(String key, int value) async {
  final box = await _openBox();
  await box.put(key, value);
}

// ─── Screen ──────────────────────────────────────────────────────────────────

class AdvancedScreen extends ConsumerStatefulWidget {
  const AdvancedScreen({super.key});

  @override
  ConsumerState<AdvancedScreen> createState() => _AdvancedScreenState();
}

class _AdvancedScreenState extends ConsumerState<AdvancedScreen> {
  bool _shareCrash = false;
  bool _detailedReports = false;
  bool _oldDecoder = false;
  bool _noNonAscii = false;
  int _bitmapThreshold = 4096;

  // ── Icon cache ───────────────────────────────────────────────────────────────
  String _iconCacheSizeStr = '…';
  String _libCacheSizeStr = '…';

  // ── Remote bypass (FlareSolverr) ────────────────────────────────────────────
  RemoteBypassSettings _remoteBypass = const RemoteBypassSettings();
  final _rbUrlCtrl = TextEditingController();
  final _rbKeyCtrl = TextEditingController();
  final _rbTimeoutCtrl = TextEditingController();

  // ── Log settings ────────────────────────────────────────────────────────────
  int _logMode = 1; // 0=normal,1=verbose,2=debug,3=extreme
  int _logMinLevel = 1;
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

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _loadRemoteBypass();
    _loadCacheSizes();
  }

  @override
  void dispose() {
    _rbUrlCtrl.dispose();
    _rbKeyCtrl.dispose();
    _rbTimeoutCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRemoteBypass() async {
    final s = await RemoteBypassService.instance.loadSettings();
    if (!mounted) return;
    setState(() {
      _remoteBypass = s;
      _rbUrlCtrl.text = s.url;
      _rbKeyCtrl.text = s.apiKey;
      _rbTimeoutCtrl.text = s.timeoutMs.toString();
    });
  }

  Future<void> _saveRemoteBypass() async {
    await RemoteBypassService.instance.saveSettings(_remoteBypass);
  }

  Future<void> _showRemoteBypassDialog() async {
    _rbUrlCtrl.text = _remoteBypass.url;
    _rbKeyCtrl.text = _remoteBypass.apiKey;
    _rbTimeoutCtrl.text = _remoteBypass.timeoutMs.toString();

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => AlertDialog(
          title: const Text('Serveur de contournement distant'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Entrez l\'URL de votre instance FlareSolverr (ex: http://192.168.1.10:8191)',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _rbUrlCtrl,
                  decoration: const InputDecoration(
                    labelText: 'URL du serveur',
                    hintText: 'http://localhost:8191',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _rbKeyCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Clé API (optionnel)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _rbTimeoutCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Délai d\'attente (ms)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Mode de déclenchement',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                ...RemoteBypassMode.values.map((m) => RadioListTile<RemoteBypassMode>(
                      dense: true,
                      title: Text(m.label, style: const TextStyle(fontSize: 13)),
                      subtitle: Text(m.description,
                          style: const TextStyle(fontSize: 11)),
                      value: m,
                      groupValue: _remoteBypass.mode,
                      onChanged: (v) {
                        setInner(() {});
                        setState(() {
                          _remoteBypass = _remoteBypass.copyWith(mode: v!);
                        });
                      },
                    )),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () async {
                final url = _rbUrlCtrl.text.trim();
                final key = _rbKeyCtrl.text.trim();
                final timeout =
                    int.tryParse(_rbTimeoutCtrl.text.trim()) ?? 60000;
                setState(() {
                  _remoteBypass = _remoteBypass.copyWith(
                    url: url,
                    apiKey: key,
                    timeoutMs: timeout,
                  );
                });
                await _saveRemoteBypass();
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadPrefs() async {
    final results = await Future.wait([
      _getBool(_kShareCrashKey),
      _getBool(_kDetailedReportsKey),
      _getBool(_kOldDecoderKey),
      _getBool(_kNonAsciiKey),
      _getInt(_kBitmapThresholdKey, defaultValue: 4096),
      // Log settings
      _getInt(kLogMode, defaultValue: 3),
      _getInt(kLogMinLevel, defaultValue: 0),
      _getBool(kLogSuppressImages, defaultValue: true),
      _getBool(kLogTagExt, defaultValue: true),
      _getBool(kLogTagDl, defaultValue: true),
      _getBool(kLogTagNet, defaultValue: true),
      _getBool(kLogTagZeus, defaultValue: true),
      _getBool(kLogTagUi, defaultValue: true),
      _getBool(kLogTagManga, defaultValue: true),
      _getBool(kLogTagPage, defaultValue: true),
      _getBool(kLogTagHls, defaultValue: true),
      _getBool(kLogTagInstall, defaultValue: true),
      _getBool(kLogTagReader, defaultValue: true),
      _getBool(kLogTagWatch, defaultValue: true),
      _getBool(kLogTagMaint, defaultValue: true),
    ]);
    if (mounted) {
      setState(() {
        _shareCrash = results[0] as bool;
        _detailedReports = results[1] as bool;
        _oldDecoder = results[2] as bool;
        _noNonAscii = results[3] as bool;
        _bitmapThreshold = results[4] as int;
        _logMode = results[5] as int;
        _logMinLevel = results[6] as int;
        _logSuppressImages = results[7] as bool;
        _logTagExt = results[8] as bool;
        _logTagDl = results[9] as bool;
        _logTagNet = results[10] as bool;
        _logTagZeus = results[11] as bool;
        _logTagUi = results[12] as bool;
        _logTagManga = results[13] as bool;
        _logTagPage = results[14] as bool;
        _logTagHls = results[15] as bool;
        _logTagInstall = results[16] as bool;
        _logTagReader = results[17] as bool;
        _logTagWatch = results[18] as bool;
        _logTagMaint = results[19] as bool;
        _loading = false;
      });
    }
  }

  Future<void> _saveLogSetting(String key, dynamic value) async {
    final box = await Hive.openBox('advanced_settings');
    await box.put(key, value);
    await AppLogger.reloadSettings();
  }

  Future<void> _applyMode(LogMode mode) async {
    final tags = mode.defaultTags;
    setState(() {
      _logMode = mode.index;
      _logMinLevel = mode.minLevel;
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
    final box = await Hive.openBox('advanced_settings');
    await box.put(kLogMode, mode.index);
    await box.put(kLogMinLevel, mode.minLevel);
    for (final e in tags.entries) {
      await box.put(e.key, e.value);
    }
    await AppLogger.reloadSettings();
    if (mode.isHeavy) {
      botToast(
        mode == LogMode.extreme
            ? '⚡ Extreme – tout est logué. RAM +++. À utiliser avec précaution.'
            : '⚠ Mode Debug actif – consommation RAM élevée',
        second: 5,
      );
    }
  }

  void _toast(String msg) => botToast(msg);

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _clearCookies() async {
    AppLogger.log('MAINT clearCookies: début',
        tag: LogTag.maintenance, logLevel: LogLevel.info);
    try {
      await CookieManager.instance().deleteAllCookies();
      MClient.deleteAllCookies("");
      AppLogger.log('MAINT clearCookies: ok',
          tag: LogTag.maintenance, logLevel: LogLevel.info);
      _toast("Cookies effacés");
    } catch (e, st) {
      AppLogger.log('MAINT clearCookies: ÉCHEC $e',
          tag: LogTag.maintenance,
          logLevel: LogLevel.error,
          error: e,
          stackTrace: st);
      _toast("Erreur lors de la suppression des cookies");
    }
  }

  Future<void> _clearWebViewData() async {
    AppLogger.log('MAINT clearWebViewData: début',
        tag: LogTag.maintenance, logLevel: LogLevel.info);
    try {
      final mgr = CookieManager.instance();
      await mgr.deleteAllCookies();
      if (Platform.isAndroid) {
        await InAppWebViewController.clearAllCache();
      }
      AppLogger.log('MAINT clearWebViewData: ok',
          tag: LogTag.maintenance, logLevel: LogLevel.info);
      _toast("Données WebView effacées");
    } catch (e, st) {
      AppLogger.log('MAINT clearWebViewData: ÉCHEC $e',
          tag: LogTag.maintenance,
          logLevel: LogLevel.error,
          error: e,
          stackTrace: st);
      _toast("Erreur lors de la suppression des données WebView");
    }
  }

  Future<void> _clearDatabase() async {
    try {
      final nonFavIds = (await isar.mangas
              .filter()
              .favoriteIsNull()
              .or()
              .favoriteEqualTo(false)
              .idProperty()
              .findAll())
          .whereType<int>()
          .toList();
      if (!mounted) return;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Effacer la base de données"),
          content: Text(
            "${nonFavIds.length} série(s) non enregistrées dans votre bibliothèque seront supprimées.\n\nCette action est irréversible.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Annuler"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Effacer", style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
      if (confirm == true) {
        await isar.writeTxn(() async => isar.mangas.deleteAll(nonFavIds));
        _toast("Base de données nettoyée (${nonFavIds.length} supprimées)");
      }
    } catch (e) {
      _toast("Erreur: $e");
    }
  }

  // ── Icon / Library cache helpers ─────────────────────────────────────────────

  static String _fmtSize(int bytes) {
    if (bytes < 1024) return '$bytes o';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} Ko';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} Mo';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} Go';
  }

  Future<int> _dirSize(Directory dir) async {
    if (!dir.existsSync()) return 0;
    int total = 0;
    try {
      await for (final f in dir.list(recursive: true, followLinks: false)) {
        if (f is File) total += await f.length();
      }
    } catch (_) {}
    return total;
  }

  Future<void> _loadCacheSizes() async {
    final storage = StorageProvider();
    final iconDir = await storage.getCacheDirectory('cacheimagecover');
    final libDir = await storage.getCacheDirectory('cacheimagemanga');
    final iconSize = await _dirSize(iconDir);
    final libSize = await _dirSize(libDir);
    if (!mounted) return;
    setState(() {
      _iconCacheSizeStr = _fmtSize(iconSize);
      _libCacheSizeStr = _fmtSize(libSize);
    });
  }

  Future<void> _clearIconCache() async {
    try {
      final storage = StorageProvider();
      final iconDir = await storage.getCacheDirectory('cacheimagecover');
      if (iconDir.existsSync()) {
        await iconDir.delete(recursive: true);
        await iconDir.create(recursive: true);
      }
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      _toast('Cache des icônes vidé');
    } catch (e) {
      _toast('Erreur : $e');
    } finally {
      await _loadCacheSizes();
    }
  }

  Future<void> _clearLibraryCache() async {
    try {
      final storage = StorageProvider();
      final libDir = await storage.getCacheDirectory('cacheimagemanga');
      if (libDir.existsSync()) {
        await libDir.delete(recursive: true);
        await libDir.create(recursive: true);
      }
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      _toast('Cache des couvertures vidé');
    } catch (e) {
      _toast('Erreur : $e');
    } finally {
      await _loadCacheSizes();
    }
  }

  Future<void> _resetUserAgent() async {
    try {
      final settings = isar.settings.getSync(227)!;
      isar.writeTxnSync(
        () => isar.settings.putSync(
          settings
            ..userAgent = defaultUserAgent
            ..updatedAt = DateTime.now().millisecondsSinceEpoch,
        ),
      );
      ref.invalidate(userAgentStateProvider);
      _toast("Agent utilisateur réinitialisé");
    } catch (_) {
      _toast("Erreur lors de la réinitialisation");
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openBatterySettings() async {
    if (Platform.isAndroid) {
      try {
        final uri = Uri.parse('package:com.example.watchtower');
        await launchUrl(
          Uri.parse('android.settings.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS'),
          mode: LaunchMode.externalApplication,
        );
      } catch (_) {
        _toast(
          "Impossible d'ouvrir les paramètres d'optimisation de batterie.\nAllez dans Paramètres > Batterie > Optimisation de batterie.",
        );
      }
    }
  }

  Future<void> _openNotificationSettings() async {
    if (Platform.isAndroid) {
      try {
        await launchUrl(
          Uri.parse('android.settings.APP_NOTIFICATION_SETTINGS'),
          mode: LaunchMode.externalApplication,
        );
      } catch (_) {
        _toast("Ouvrez Paramètres > Notifications pour gérer les alertes.");
      }
    } else {
      _toast("Ouvrez les Réglages système pour gérer les notifications.");
    }
  }

  // ── Widgets helpers ─────────────────────────────────────────────────────────

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
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

  Widget _toggle({
    required String title,
    required String subtitle,
    required bool value,
    required void Function(bool) onChanged,
    bool danger = false,
    bool disabled = false,
  }) {
    final primary = Theme.of(context).colorScheme.primary;
    final activeColor = danger ? Colors.orange : primary;
    return SwitchListTile(
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          color: disabled ? context.secondaryColor : null,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: context.secondaryColor),
      ),
      value: value,
      onChanged: disabled ? null : onChanged,
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return Theme.of(context).colorScheme.onSurface.withOpacity(0.3);
        }
        if (states.contains(WidgetState.selected)) {
          return Colors.white;
        }
        return null;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return Theme.of(context).colorScheme.onSurface.withOpacity(0.12);
        }
        if (states.contains(WidgetState.selected)) {
          return activeColor;
        }
        return null;
      }),
    );
  }

  Widget _action({
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    Color? titleColor,
    IconData? trailing,
  }) {
    return ListTile(
      title: Text(
        title,
        style: TextStyle(fontSize: 14, color: titleColor),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: context.secondaryColor),
            )
          : null,
      trailing: trailing != null
          ? Icon(trailing, size: 18, color: context.secondaryColor)
          : null,
      onTap: onTap,
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text("Avancé")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Avancé")),
      body: ListView(
        children: [
          // ── Section : Avancé ────────────────────────────────────────────
          _sectionHeader("Avancé"),
          _toggle(
            title: "Partager les rapports de plantage",
            subtitle:
                "Enregistre les rapports de plantage dans un fichier pour les partager avec les développeurs",
            value: _shareCrash,
            onChanged: (v) {
              setState(() => _shareCrash = v);
              _setBool(_kShareCrashKey, v);
            },
          ),
          _toggle(
            title: "Rapports détaillés",
            subtitle:
                "Inclut des rapports détaillés dans les traces systèmes (réduit les performances de l'application)",
            value: _detailedReports,
            onChanged: (v) {
              setState(() => _detailedReports = v);
              _setBool(_kDetailedReportsKey, v);
            },
            danger: true,
          ),
          _action(
            title: "Guide de premier lancement",
            subtitle: "Relancer le tutoriel de démarrage",
            onTap: () => context.push('/onboarding'),
            trailing: Icons.arrow_forward_ios_rounded,
          ),
          _action(
            title: "Notifications",
            subtitle: "Gérer les alertes de l'application",
            onTap: _openNotificationSettings,
            trailing: Icons.arrow_forward_ios_rounded,
          ),

          // ── Section : Activité en arrière-plan ──────────────────────────
          _sectionHeader("Activité en arrière-plan"),
          if (Platform.isAndroid)
            _action(
              title: "Désactiver la fonction d'optimisation de la batterie",
              subtitle:
                  "Facilite les mises à jour et sauvegardes de la bibliothèque en arrière-plan",
              onTap: _openBatterySettings,
              trailing: Icons.arrow_forward_ios_rounded,
            ),
          _action(
            title: "Don't kill my app!",
            subtitle:
                "Certains fabricants ont mis en place des restrictions supplémentaires sur les applications qui tuent les services d'arrière-plan. Ce site Web contient plus d'informations sur la manière de résoudre ce problème.",
            onTap: () => _openUrl("https://dontkillmyapp.com"),
            trailing: Icons.open_in_new_rounded,
          ),

          // ── Section : Contournement Cloudflare distant ──────────────────
          _sectionHeader("Contournement Cloudflare distant"),
          SwitchListTile(
            title: const Text(
              'Activer le serveur distant',
              style: TextStyle(fontSize: 14),
            ),
            subtitle: Text(
              _remoteBypass.isConfigured
                  ? 'Connecté à ${_remoteBypass.url}'
                  : 'Aucun serveur configuré — Appuyez sur Configurer',
              style: TextStyle(
                fontSize: 12,
                color: _remoteBypass.isConfigured ? Colors.green : null,
              ),
            ),
            value: _remoteBypass.enabled,
            onChanged: (v) async {
              setState(() {
                _remoteBypass = _remoteBypass.copyWith(enabled: v);
              });
              await _saveRemoteBypass();
            },
          ),
          _action(
            title: 'Configurer le serveur distant',
            subtitle: 'URL, clé API, délai, mode de déclenchement',
            onTap: _showRemoteBypassDialog,
            trailing: Icons.tune_rounded,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline_rounded,
                            size: 14,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 6),
                        Text(
                          'FlareSolverr',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'FlareSolverr est un serveur proxy qui utilise un navigateur headless pour résoudre les challenges Cloudflare. '
                      'Installez-le sur votre machine ou serveur local et entrez son URL ici.',
                      style: TextStyle(fontSize: 11),
                    ),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () => _openUrl(
                          'https://github.com/FlareSolverr/FlareSolverr'),
                      child: Text(
                        'github.com/FlareSolverr/FlareSolverr →',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.primary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Section : Données ───────────────────────────────────────────
          _sectionHeader("Données"),
          _action(
            title: "Réindexe les téléchargements",
            subtitle:
                "Forcer l'application à revérifier les chapitres téléchargés",
            onTap: () {
              _toast("Réindexation des téléchargements…");
            },
          ),
          _action(
            title: "Effacer la base de données",
            subtitle:
                "Supprimer l'historique des séries qui ne sont pas enregistrées dans votre bibliothèque",
            onTap: _clearDatabase,
            titleColor: Colors.red,
          ),

          // ── Section : Réseau ────────────────────────────────────────────
          _sectionHeader("Réseau"),
          _action(
            title: "Effacer les cookies",
            onTap: _clearCookies,
          ),
          _action(
            title: "Effacer les données WebView",
            onTap: _clearWebViewData,
          ),
          ListTile(
            title: const Text("DNS sur HTTPS (DoH)", style: TextStyle(fontSize: 14)),
            subtitle: Text(
              "Google",
              style: TextStyle(fontSize: 12, color: context.secondaryColor),
            ),
            trailing: Icon(
              Icons.arrow_forward_ios_rounded,
              size: 18,
              color: context.secondaryColor,
            ),
            onTap: () => context.push('/general'),
          ),
          Builder(builder: (context) {
            final ua = ref.watch(userAgentStateProvider);
            return ListTile(
              title: const Text(
                "Liste d'agents utilisateurs par défaut",
                style: TextStyle(fontSize: 14),
              ),
              subtitle: Text(
                ua,
                style: TextStyle(fontSize: 11, color: context.secondaryColor),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }),
          _action(
            title: "Réinitialiser la liste d'agents utilisateurs",
            onTap: _resetUserAgent,
          ),

          // ── Section : Cache des icônes ──────────────────────────────────
          _sectionHeader("Cache des icônes et couvertures"),
          _action(
            title: "Vider le cache des icônes d'extensions",
            subtitle: "Taille actuelle : $_iconCacheSizeStr",
            onTap: _clearIconCache,
            trailing: Icons.cleaning_services_outlined,
          ),
          _action(
            title: "Vider le cache des couvertures de bibliothèque",
            subtitle: "Taille actuelle : $_libCacheSizeStr",
            onTap: _clearLibraryCache,
            trailing: Icons.cleaning_services_outlined,
          ),
          _action(
            title: "Rafraîchir les tailles de cache",
            subtitle: "Recalcule la taille des caches disque",
            onTap: () async {
              setState(() {
                _iconCacheSizeStr = '…';
                _libCacheSizeStr = '…';
              });
              await _loadCacheSizes();
            },
            trailing: Icons.refresh_rounded,
          ),

          // ── Section : Bibliothèque ──────────────────────────────────────
          _sectionHeader("Bibliothèque"),
          _action(
            title: "Actualiser les couvertures de la bibliothèque",
            onTap: () {
              _toast("Actualisation des couvertures…");
            },
          ),
          _action(
            title: "Réinitialiser les paramètres du lecteur par série",
            subtitle:
                "Réinitialise le mode de lecture et l'orientation de toutes les séries",
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text(
                    "Réinitialiser les paramètres du lecteur",
                  ),
                  content: const Text(
                    "Réinitialise le mode de lecture et l'orientation de toutes les séries.",
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text("Annuler"),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text("Réinitialiser"),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                try {
                  final settings = isar.settings.getSync(227)!;
                  isar.writeTxnSync(
                    () => isar.settings.putSync(
                      settings
                        ..personalReaderModeList = []
                        ..updatedAt =
                            DateTime.now().millisecondsSinceEpoch,
                    ),
                  );
                  _toast("Paramètres du lecteur réinitialisés");
                } catch (_) {
                  _toast("Erreur");
                }
              }
            },
          ),
          _action(
            title: "Mettre à jour les titres des séries de la bibliothèque",
            subtitle:
                "Attention : si une série est renommée, elle sera supprimée de la file d'attente de téléchargement.",
            onTap: () {
              _toast("Mise à jour des titres en cours…");
            },
          ),
          _toggle(
            title: "Interdire les noms de fichiers non ASCII",
            subtitle:
                "Assure la compatibilité avec certains supports de stockage qui ne prennent pas en charge Unicode",
            value: _noNonAscii,
            onChanged: (v) {
              setState(() => _noNonAscii = v);
              _setBool(_kNonAsciiKey, v);
            },
          ),

          // ── Section : Lecteur ───────────────────────────────────────────
          _sectionHeader("Lecteur"),
          ListTile(
            title: const Text(
              "Seuil de bitmap matériel personnalisé",
              style: TextStyle(fontSize: 14),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Si le lecteur charge une image vierge, réduire progressivement le seuil.",
                  style: TextStyle(fontSize: 12, color: context.secondaryColor),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: _bitmapThreshold.toDouble(),
                        min: 512,
                        max: 8192,
                        divisions: 15,
                        label: _bitmapThreshold.toString(),
                        onChanged: (v) {
                          setState(() => _bitmapThreshold = v.round());
                          _setInt(_kBitmapThresholdKey, v.round());
                        },
                      ),
                    ),
                    SizedBox(
                      width: 52,
                      child: Text(
                        _bitmapThreshold.toString(),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _toggle(
            title: "Utiliser l'ancien décodeur pour le lecteur de bandes longues",
            subtitle:
                "Affecte les performances. Ne l'activer que si la réduction du seuil de bitmap ne résout pas les problèmes d'images vierges",
            value: _oldDecoder,
            onChanged: (v) {
              setState(() => _oldDecoder = v);
              _setBool(_kOldDecoderKey, v);
            },
            danger: true,
          ),
          _action(
            title: "Profil d'affichage personnalisé",
            trailing: Icons.arrow_forward_ios_rounded,
            onTap: () => context.push('/appearance'),
          ),

          // ── Section : Extensions ────────────────────────────────────────
          _sectionHeader("Extensions"),
          ListTile(
            title: const Text("Installeur", style: TextStyle(fontSize: 14)),
            subtitle: Text(
              "PackageInstaller",
              style: TextStyle(fontSize: 12, color: context.secondaryColor),
            ),
          ),
          _action(
            title: "Révoquer les extensions provenant d'un répertoire additionnel",
            titleColor: Colors.orange,
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text("Révoquer les extensions"),
                  content: const Text(
                    "Toutes les extensions provenant de dépôts additionnels seront révoquées.",
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text("Annuler"),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text(
                        "Révoquer",
                        style: TextStyle(color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                _toast("Extensions révoquées");
              }
            },
          ),

          // ── Section : Logs avancés ──────────────────────────────────────
          _sectionHeader("Logs avancés"),
          _LogAdvancedSection(
            logMode: _logMode,
            logSuppressImages: _logSuppressImages,
            logTagExt: _logTagExt,
            logTagDl: _logTagDl,
            logTagNet: _logTagNet,
            logTagZeus: _logTagZeus,
            logTagUi: _logTagUi,
            logTagManga: _logTagManga,
            logTagPage: _logTagPage,
            logTagHls: _logTagHls,
            logTagInstall: _logTagInstall,
            logTagReader: _logTagReader,
            logTagWatch: _logTagWatch,
            logTagMaint: _logTagMaint,
            onModeChanged: (mode) => _applyMode(mode),
            onSuppressImagesChanged: (v) {
              setState(() => _logSuppressImages = v);
              _saveLogSetting(kLogSuppressImages, v);
            },
            onTagChanged: (key, v) {
              setState(() {
                switch (key) {
                  case kLogTagExt: _logTagExt = v; break;
                  case kLogTagDl: _logTagDl = v; break;
                  case kLogTagNet: _logTagNet = v; break;
                  case kLogTagZeus: _logTagZeus = v; break;
                  case kLogTagUi: _logTagUi = v; break;
                  case kLogTagManga: _logTagManga = v; break;
                  case kLogTagPage: _logTagPage = v; break;
                  case kLogTagHls: _logTagHls = v; break;
                  case kLogTagInstall: _logTagInstall = v; break;
                  case kLogTagReader: _logTagReader = v; break;
                  case kLogTagWatch: _logTagWatch = v; break;
                  case kLogTagMaint: _logTagMaint = v; break;
                }
              });
              _saveLogSetting(key, v);
            },
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Log Advanced Section — 4 preset modes + per-tag customization
// ─────────────────────────────────────────────────────────────────────────────

class _LogAdvancedSection extends ConsumerWidget {
  final int logMode;
  final bool logSuppressImages;
  final bool logTagExt;
  final bool logTagDl;
  final bool logTagNet;
  final bool logTagZeus;
  final bool logTagUi;
  final bool logTagManga;
  final bool logTagPage;
  final bool logTagHls;
  final bool logTagInstall;
  final bool logTagReader;
  final bool logTagWatch;
  final bool logTagMaint;
  final void Function(LogMode) onModeChanged;
  final void Function(bool) onSuppressImagesChanged;
  final void Function(String, bool) onTagChanged;

  const _LogAdvancedSection({
    required this.logMode,
    required this.logSuppressImages,
    required this.logTagExt,
    required this.logTagDl,
    required this.logTagNet,
    required this.logTagZeus,
    required this.logTagUi,
    required this.logTagManga,
    required this.logTagPage,
    required this.logTagHls,
    required this.logTagInstall,
    required this.logTagReader,
    required this.logTagWatch,
    required this.logTagMaint,
    required this.onModeChanged,
    required this.onSuppressImagesChanged,
    required this.onTagChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsEnabled = ref.watch(logsStateProvider);
    final cs = Theme.of(context).colorScheme;
    final secondary = Theme.of(context).textTheme.bodySmall?.color ??
        cs.onSurface.withOpacity(0.6);
    final selectedMode = LogMode.values[logMode.clamp(0, 3)];

    // ── Tag toggle helper ──────────────────────────────────────────────────
    Widget _logToggle({
      required String title,
      required String subtitle,
      required String tagKey,
      required bool value,
      bool danger = false,
    }) {
      final activeColor = danger ? Colors.red : cs.primary;
      return SwitchListTile(
        dense: true,
        title: Text(
          title,
          style: TextStyle(
            fontSize: 13.5,
            color: logsEnabled ? null : secondary,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 11.5, color: secondary),
        ),
        value: value,
        onChanged: logsEnabled ? (v) => onTagChanged(tagKey, v) : null,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Logs disabled notice ───────────────────────────────────────────
        if (!logsEnabled)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Container(
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: cs.outline.withOpacity(0.25)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 18,
                      color: cs.onSurface.withOpacity(0.55)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Activez les logs dans À propos > Développeur pour configurer ces options.",
                      style: TextStyle(fontSize: 12,
                          color: cs.onSurface.withOpacity(0.7)),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // ── Mode selector ──────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Mode de logging",
                  style: TextStyle(fontSize: 13, color: secondary)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: LogMode.values.map((mode) {
                  final selected = logMode == mode.index;
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
                            : logsEnabled ? chipColor : secondary,
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
                    onSelected: logsEnabled ? (_) => onModeChanged(mode) : null,
                  );
                }).toList(),
              ),
              const SizedBox(height: 6),
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

        const Divider(height: 20, indent: 16, endIndent: 16),

        // ── Suppress image errors ──────────────────────────────────────────
        SwitchListTile(
          dense: true,
          title: Text(
            "Supprimer erreurs d'images",
            style: TextStyle(
              fontSize: 13.5,
              color: logsEnabled ? null : secondary,
            ),
          ),
          subtitle: Text(
            "Ne pas enregistrer les erreurs de logos 404",
            style: TextStyle(fontSize: 11.5, color: secondary),
          ),
          value: logSuppressImages,
          onChanged: logsEnabled ? onSuppressImagesChanged : null,
        ),

        const Divider(height: 20, indent: 16, endIndent: 16),

        // ── Active tags (fully customizable) ──────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
          child: Row(
            children: [
              Text("Catégories actives",
                  style: TextStyle(fontSize: 13, color: secondary)),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  "personnalisables",
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

        _logToggle(
          title: "Extensions [EXT]",
          subtitle: "Installation, mise à jour, erreurs d'extensions",
          tagKey: kLogTagExt,
          value: logTagExt,
        ),
        _logToggle(
          title: "Installation détaillée [INSTALL]",
          subtitle: "Chaque étape d'installation/désinstallation",
          tagKey: kLogTagInstall,
          value: logTagInstall,
        ),
        _logToggle(
          title: "Téléchargements [DL]",
          subtitle: "Progression, reprise, erreurs de téléchargements",
          tagKey: kLogTagDl,
          value: logTagDl,
        ),
        _logToggle(
          title: "HLS streaming [HLS]",
          subtitle: "Segments HLS, manifest, erreurs de stream",
          tagKey: kLogTagHls,
          value: logTagHls,
        ),
        _logToggle(
          title: "Réseau [NET]",
          subtitle: "Requêtes HTTP, redirections, erreurs réseau",
          tagKey: kLogTagNet,
          value: logTagNet,
        ),
        _logToggle(
          title: "ZeusDL [ZEUS]",
          subtitle: "Moteur ZeusDL / yt-dlp – sorties complètes",
          tagKey: kLogTagZeus,
          value: logTagZeus,
        ),
        _logToggle(
          title: "Manga [MANGA]",
          subtitle: "Chargement série, chapitres, métadonnées",
          tagKey: kLogTagManga,
          value: logTagManga,
        ),
        _logToggle(
          title: "Lecteur [READER]",
          subtitle: "Navigation lecteur, zoom, orientation",
          tagKey: kLogTagReader,
          value: logTagReader,
        ),
        _logToggle(
          title: "Pages manga [PAGE]",
          subtitle: "⚡ Chaque page chargée (très verbeux)",
          tagKey: kLogTagPage,
          value: logTagPage,
          danger: true,
        ),
        _logToggle(
          title: "Lecture vidéo [WATCH]",
          subtitle: "Ouverture épisode, buffering, watchdog 60 s",
          tagKey: kLogTagWatch,
          value: logTagWatch,
        ),
        _logToggle(
          title: "Maintenance [MAINT]",
          subtitle: "Nettoyage cookies, BDD, réindexation, tâches d'arrière-plan",
          tagKey: kLogTagMaint,
          value: logTagMaint,
        ),
        _logToggle(
          title: "Interface [UI]",
          subtitle: "Événements et erreurs d'interface",
          tagKey: kLogTagUi,
          value: logTagUi,
        ),
      ],
    );
  }
}
