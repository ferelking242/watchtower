import 'dart:convert';
  import 'dart:io';
  import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
  import 'package:path_provider/path_provider.dart';

  // ─────────────────────────────────────────────────────────────────────────────
  // FlareLoader — Gestionnaire de packages .flare pour Watchtower
  //
  // Un fichier .flare est un ZIP renommé contenant :
  //   manifest.json       — métadonnées + commandScopes
  //   ui/schema.json      — UI déclarative (méthode json)
  //   ui/main.dart        — Source Dart interprété par d4rt (méthode eval)
  //   ui/index.html       — WebView HTML (méthode html)
  //   assets/             — icône, bannière, etc.
  // ─────────────────────────────────────────────────────────────────────────────

  class FlareManifest {
    final String id;
    final String name;
    final String version;
    final String description;
    final String iconPath;
    final String color;
    final String category;
    final FlareUiConfig ui;
    final Map<String, dynamic> requirements;
    final List<String> commandScopes;
    final Map<String, dynamic> userConfig;
    final bool featured;

    const FlareManifest({
      required this.id,
      required this.name,
      required this.version,
      required this.description,
      required this.iconPath,
      required this.color,
      required this.category,
      required this.ui,
      required this.requirements,
      required this.commandScopes,
      required this.userConfig,
      required this.featured,
    });

    factory FlareManifest.fromJson(Map<String, dynamic> j) => FlareManifest(
      id:            j['id'] as String? ?? '',
      name:          j['name'] as String? ?? '',
      version:       j['version'] as String? ?? '0.0.0',
      description:   j['description'] as String? ?? '',
      iconPath:      j['icon'] as String? ?? 'assets/icon.png',
      color:         j['color'] as String? ?? '#00D4AA',
      category:      j['category'] as String? ?? 'utility',
      ui:            FlareUiConfig.fromJson(_migrateUiField(j['ui'])),
      requirements:  (j['requirements'] as Map<String, dynamic>?) ?? {},
      commandScopes: (j['commandScopes'] as List?)?.map((e) => e is Map ? (e['command'] as String? ?? '') : e.toString()).toList() ?? [],
      userConfig:    (j['userConfig'] as Map<String, dynamic>?) ?? {},
      featured:      j['featured'] as bool? ?? false,
    );

    /// Migration: accepte l'ancien format string ("flutter_eval", "eval") OU le
    /// format objet actuel ({"method": "eval", "evalSource": "ui/main.dart"}).
    /// Sans cette migration, les plugins installés AVANT la correction du manifest
    /// restent bloqués sur la vue JSON générique (cast silencieux → null → method:'json').
    static Map<String, dynamic> _migrateUiField(dynamic raw) {
      if (raw is Map<String, dynamic>) return raw;
      if (raw is String) {
        final method = (raw == 'flutter_eval' || raw == 'eval') ? 'eval' : 'json';
        return {'method': method, 'evalSource': 'ui/main.dart'};
      }
      return {};
    }
  }

  class FlareUiConfig {
    /// 'json' | 'eval' | 'html'
    final String method;
    final String? schemaPath;
    final String? evalSourcePath;
    final String? htmlPath;
    final String? template;

    const FlareUiConfig({
      required this.method,
      this.schemaPath,
      this.evalSourcePath,
      this.htmlPath,
      this.template,
    });

    factory FlareUiConfig.fromJson(Map<String, dynamic> j) => FlareUiConfig(
      method:         j['method'] as String? ?? 'json',
      schemaPath:     j['schema'] as String?,
      evalSourcePath: j['evalSource'] as String?,
      htmlPath:       j['htmlFallback'] as String?,
      template:       j['template'] as String?,
    );
  }

  class InstalledFlarePlugin {
    final String id;
    final String version;
    final String installedDir;
    final FlareManifest manifest;

    const InstalledFlarePlugin({
      required this.id,
      required this.version,
      required this.installedDir,
      required this.manifest,
    });
  }

  class FlareLoader {
    static const _kPluginsDir = 'flare_plugins';

    // ── Répertoire d'installation ──────────────────────────────────────────────
    static Future<Directory> _pluginsDir() async {
      final base = await getApplicationSupportDirectory();
      final dir = Directory('${base.path}/$_kPluginsDir');
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir;
    }

    // ── Installer un .flare depuis un chemin fichier ───────────────────────────
    static Future<InstalledFlarePlugin?> installFromFile(String flarePath) async {
      try {
        final flareFile = File(flarePath);
        if (!await flareFile.exists()) throw Exception('Fichier .flare introuvable : $flarePath');

        final bytes = await flareFile.readAsBytes();
        final archive = ZipDecoder().decodeBytes(bytes);

        // Lire le manifest avant d'extraire
        final manifestEntry = archive.files.firstWhere(
          (f) => f.name == 'manifest.json' || f.name.endsWith('/manifest.json'),
          orElse: () => throw Exception('manifest.json manquant dans le .flare'),
        );
        final manifest = FlareManifest.fromJson(
          jsonDecode(utf8.decode(manifestEntry.content as List<int>)) as Map<String, dynamic>,
        );

        // Dossier d'installation : pluginsDir/<id>/
        final pluginsBase = await _pluginsDir();
        final installDir = Directory('${pluginsBase.path}/${manifest.id}');
        if (await installDir.exists()) await installDir.delete(recursive: true);
        await installDir.create(recursive: true);

        // Extraire tous les fichiers
        for (final file in archive.files) {
          if (file.isFile) {
            final outFile = File('${installDir.path}/${file.name}');
            await outFile.parent.create(recursive: true);
            await outFile.writeAsBytes(file.content as List<int>);
          }
        }

        return InstalledFlarePlugin(
          id: manifest.id,
          version: manifest.version,
          installedDir: installDir.path,
          manifest: manifest,
        );
      } catch (e) {
        // Log error
        return null;
      }
    }

    // ── Charger tous les plugins installés ────────────────────────────────────
    static Future<List<InstalledFlarePlugin>> loadInstalled() async {
      final base = await _pluginsDir();
      final result = <InstalledFlarePlugin>[];
      if (!await base.exists()) return result;

      await for (final entity in base.list()) {
        if (entity is Directory) {
          final manifestFile = File('${entity.path}/manifest.json');
          if (await manifestFile.exists()) {
            try {
              final manifest = FlareManifest.fromJson(
                jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>,
              );
              result.add(InstalledFlarePlugin(
                id: manifest.id,
                version: manifest.version,
                installedDir: entity.path,
                manifest: manifest,
              ));
            } catch (_) {}
          }
        }
      }
      return result;
    }

    // ── Désinstaller un plugin ─────────────────────────────────────────────────
    static Future<void> uninstall(String pluginId) async {
      final base = await _pluginsDir();
      final dir = Directory('${base.path}/$pluginId');
      if (await dir.exists()) await dir.delete(recursive: true);
    }

    // ── Lire le schema.json d'un plugin installé ──────────────────────────────
    static Future<Map<String, dynamic>?> readSchema(InstalledFlarePlugin plugin) async {
      final schemaPath = plugin.manifest.ui.schemaPath ?? 'ui/schema.json';
      final file = File('${plugin.installedDir}/$schemaPath');
      if (!await file.exists()) return null;
      return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    }

    // ── Lire le source Dart eval d'un plugin installé ─────────────────────────
    static Future<String?> readEvalSource(InstalledFlarePlugin plugin) async {
      final dartPath = plugin.manifest.ui.evalSourcePath ?? 'ui/main.dart';
      final file = File('${plugin.installedDir}/$dartPath');
      if (!await file.exists()) return null;
      return file.readAsString();
    }

    // ── Lire le HTML d'un plugin installé ────────────────────────────────────
    static Future<String?> readHtml(InstalledFlarePlugin plugin) async {
      final htmlPath = plugin.manifest.ui.htmlPath ?? 'ui/index.html';
      final file = File('${plugin.installedDir}/$htmlPath');
      if (!await file.exists()) return null;
      return file.readAsString();
    }
  
    // ── Charger un seul plugin installé par ID ────────────────────────────────
    static Future<InstalledFlarePlugin?> loadSingle(String pluginId) async {
      try {
        final base = await _pluginsDir();
        final dir = Directory('${base.path}/$pluginId');
        final manifestFile = File('${dir.path}/manifest.json');
        if (!await manifestFile.exists()) return null;
        final manifest = FlareManifest.fromJson(
          jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>,
        );
        return InstalledFlarePlugin(
          id: manifest.id,
          version: manifest.version,
          installedDir: dir.path,
          manifest: manifest,
        );
      } catch (_) {
        return null;
      }
    }

    // ── Installer un plugin depuis les URLs brutes GitHub (sans .flare ZIP) ──────
    static Future<InstalledFlarePlugin?> installFromNetwork({
      required String pluginId,
      required String baseUrl,
    }) async {
      try {
        final base = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
        final pluginBase = '$base/$pluginId';

        // Télécharger manifest.json
        final manifestRes = await http.get(Uri.parse('$pluginBase/manifest.json'));
        if (manifestRes.statusCode != 200) {
          throw Exception('manifest.json introuvable (HTTP ${manifestRes.statusCode})');
        }
        final manifest = FlareManifest.fromJson(
          jsonDecode(manifestRes.body) as Map<String, dynamic>,
        );

        // Créer le répertoire local
        final pluginsBase = await _pluginsDir();
        final installDir = Directory('${pluginsBase.path}/$pluginId');
        if (await installDir.exists()) await installDir.delete(recursive: true);
        await installDir.create(recursive: true);

        // Sauvegarder manifest.json
        await File('${installDir.path}/manifest.json').writeAsString(manifestRes.body);

        // Télécharger les fichiers UI selon la méthode déclarée
        final uiDir = Directory('${installDir.path}/ui');
        await uiDir.create(recursive: true);

        final filesToFetch = <String>[
          'ui/schema.json',
          'ui/main.dart',
          'ui/index.html',
        ];

        for (final relPath in filesToFetch) {
          try {
            final res = await http.get(Uri.parse('$pluginBase/$relPath'));
            if (res.statusCode == 200) {
              final f = File('${installDir.path}/$relPath');
              await f.parent.create(recursive: true);
              await f.writeAsBytes(res.bodyBytes);
            }
          } catch (_) {}
        }

        return InstalledFlarePlugin(
          id: manifest.id,
          version: manifest.version,
          installedDir: installDir.path,
          manifest: manifest,
        );
      } catch (e) {
        return null;
      }
    }
  
}