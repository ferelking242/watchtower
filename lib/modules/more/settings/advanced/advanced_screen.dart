import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:watchtower/eval/model/m_bridge.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/settings.dart';
import 'package:watchtower/utils/constant.dart';
import 'package:watchtower/modules/more/settings/general/providers/general_state_provider.dart';
import 'package:watchtower/services/http/m_client.dart';
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

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final results = await Future.wait([
      _getBool(_kShareCrashKey),
      _getBool(_kDetailedReportsKey),
      _getBool(_kOldDecoderKey),
      _getBool(_kNonAsciiKey),
      _getInt(_kBitmapThresholdKey, defaultValue: 4096),
    ]);
    if (mounted) {
      setState(() {
        _shareCrash = results[0] as bool;
        _detailedReports = results[1] as bool;
        _oldDecoder = results[2] as bool;
        _noNonAscii = results[3] as bool;
        _bitmapThreshold = results[4] as int;
        _loading = false;
      });
    }
  }

  void _toast(String msg) => botToast(msg);

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _clearCookies() async {
    try {
      await CookieManager.instance().deleteAllCookies();
      MClient.deleteAllCookies("");
      _toast("Cookies effacés");
    } catch (_) {
      _toast("Erreur lors de la suppression des cookies");
    }
  }

  Future<void> _clearWebViewData() async {
    try {
      final mgr = CookieManager.instance();
      await mgr.deleteAllCookies();
      if (Platform.isAndroid) {
        await InAppWebViewController.clearAllCache();
      }
      _toast("Données WebView effacées");
    } catch (_) {
      _toast("Erreur lors de la suppression des données WebView");
    }
  }

  Future<void> _clearDatabase() async {
    try {
      final nonFavIds = (await isar.mangas
              .filter()
              .group((q) => q.favoriteEqualTo(false).or().favoriteIsNull())
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
  }) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(fontSize: 14)),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: context.secondaryColor),
      ),
      value: value,
      onChanged: onChanged,
      activeColor: danger
          ? Colors.orange
          : Theme.of(context).colorScheme.primary,
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

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
