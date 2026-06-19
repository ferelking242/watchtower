import 'dart:convert';
  import 'dart:io';
  import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
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
      requirements:  (j['requirements'] is Map)
          ? (j['requirements'] as Map).cast<String, dynamic>()
          : (j['requirements'] is List)
              ? { for (final e in (j['requirements'] as List)) if (e is Map && (e as Map)['id'] != null) (e['id'] as String): Map<String, dynamic>.from(e as Map) }
              : {},
      commandScopes: (j['commandScopes'] as List?)?.map((e) => e is Map ? (e['command'] as String? ?? '') : e.toString()).toList() ?? [],
      userConfig:    (j['userConfig'] as Map<String, dynamic>?) ?? {},
      featured:      j['featured'] as bool? ?? false,
    );

    /// Migration: accepte l'ancien format string ("flutter_eval", "eval") OU le
    /// format objet actuel ({"method": "eval", "evalSource": "ui/main.dart"}).
    /// Sans cette migration, les plugins installés AVANT la correction du manifest
    /// restent bloqués sur la vue JSON générique (cast silencieux → null → method:'json').
    static Map<String, dynamic> _migrateUiField(dynamic raw) {
      if (raw is Map<String, dynamic>) {
        // Normalise la valeur de 'method' même quand c'est déjà un objet
        final method = raw['method'] as String? ?? 'json';
        final normalized = _normalizeUiMethod(method);
        if (normalized == method) return raw;
        return {...raw, 'method': normalized};
      }
      if (raw is String) {
        final method = _normalizeUiMethod(raw);
        return {
          'method': method,
          if (method == 'eval') 'evalSource': 'ui/main.dart',
          if (method == 'html') 'htmlFallback': 'ui/index.html',
          if (method == 'json') 'schema': 'ui/schema.json',
        };
      }
      return {};
    }

    static String _normalizeUiMethod(String raw) {
      switch (raw) {
        case 'flutter_eval':
        case 'eval':
          return 'eval';
        case 'webview':
        case 'html':
          return 'html';
        default:
          return 'json';
      }
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
        debugPrint('[FlareLoader:installFromFile] ERREUR: $e');
        rethrow;
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
        debugPrint('[FlareLoader:loadSingle] id=$pluginId dir=${dir.path}');
        if (!await manifestFile.exists()) {
          debugPrint('[FlareLoader:loadSingle] manifest.json ABSENT — dir=${dir.path}');
          return null;
        }
        final manifest = FlareManifest.fromJson(
          jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>,
        );
        debugPrint('[FlareLoader:loadSingle] OK — method=${manifest.ui.method}');
        return InstalledFlarePlugin(
          id: manifest.id,
          version: manifest.version,
          installedDir: dir.path,
          manifest: manifest,
        );
      } catch (e) {
        debugPrint('[FlareLoader:loadSingle] ERREUR id=$pluginId: $e');
        return null;
      }
    }

    // ── Installer un plugin depuis les URLs brutes GitHub (sans .flare ZIP) ──────
    /// Lance une [Exception] explicite si le manifest ou le fichier UI requis
    /// est absent — ne retourne jamais null.
    static Future<InstalledFlarePlugin> installFromNetwork({
      required String pluginId,
      required String baseUrl,
    }) async {
      final base = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
      final pluginBase = '$base/$pluginId';
      debugPrint('[FlareLoader:installFromNetwork] START id=$pluginId base=$pluginBase');

      // 1. Télécharger manifest.json — obligatoire
      final manifestUrl = '$pluginBase/manifest.json';
      final manifestRes = await http.get(Uri.parse(manifestUrl));
      if (manifestRes.statusCode != 200) {
        throw Exception(
          '[FlareLoader] manifest.json introuvable — '
          'HTTP ${manifestRes.statusCode} — URL: $manifestUrl',
        );
      }
      debugPrint('[FlareLoader:installFromNetwork] manifest.json OK (HTTP 200)');

      final manifest = FlareManifest.fromJson(
        jsonDecode(manifestRes.body) as Map<String, dynamic>,
      );
      debugPrint('[FlareLoader:installFromNetwork] manifest parsé — method=${manifest.ui.method}');

      // 2. Créer le répertoire d'installation
      final pluginsBase = await _pluginsDir();
      final installDir = Directory('${pluginsBase.path}/$pluginId');
      if (await installDir.exists()) await installDir.delete(recursive: true);
      await installDir.create(recursive: true);

      // 3. Sauvegarder manifest.json sur disque
      await File('${installDir.path}/manifest.json').writeAsString(manifestRes.body);
      debugPrint('[FlareLoader:installFromNetwork] manifest.json écrit — ${installDir.path}/manifest.json');

      // 4. Télécharger les fichiers UI (on tente tous, on logue chaque résultat)
      final uiDir = Directory('${installDir.path}/ui');
      await uiDir.create(recursive: true);

      final filesToFetch = <String>[
        'ui/schema.json',
        'ui/main.dart',
        'ui/index.html',
        'assets/icon.png',
        'assets/icon.svg',
      ];

      final downloaded = <String>{};
      final notFound   = <String>{};

      for (final relPath in filesToFetch) {
        final fileUrl = '$pluginBase/$relPath';
        try {
          final res = await http.get(Uri.parse(fileUrl));
          if (res.statusCode == 200) {
            final f = File('${installDir.path}/$relPath');
            await f.parent.create(recursive: true);
            await f.writeAsBytes(res.bodyBytes);
            downloaded.add(relPath);
            debugPrint('[FlareLoader:installFromNetwork] ✓ $relPath');
          } else {
            notFound.add(relPath);
            debugPrint('[FlareLoader:installFromNetwork] ✗ $relPath (HTTP ${res.statusCode})');
          }
        } catch (e) {
          notFound.add(relPath);
          debugPrint('[FlareLoader:installFromNetwork] ✗ $relPath (erreur: $e)');
        }
      }

      // 5. Vérifier que le fichier UI requis par la méthode déclarée est présent
      final method = manifest.ui.method;
      final requiredFile = switch (method) {
        'eval' => manifest.ui.evalSourcePath ?? 'ui/main.dart',
        'html' => manifest.ui.htmlPath ?? 'ui/index.html',
        _      => manifest.ui.schemaPath ?? 'ui/schema.json',
      };

      if (!downloaded.contains(requiredFile)) {
        // Nettoyer le répertoire partiel avant de lever l'exception
        await installDir.delete(recursive: true);
        throw Exception(
          '[FlareLoader] Fichier UI requis manquant pour méthode "$method" — '
          'fichier: $requiredFile — URL tentée: $pluginBase/$requiredFile. '
          'Fichiers téléchargés: ${downloaded.join(", ")}',
        );
      }

      debugPrint(
        '[FlareLoader:installFromNetwork] SUCCÈS — id=${manifest.id} '
        'dir=${installDir.path} method=$method fichier=$requiredFile',
      );

      return InstalledFlarePlugin(
        id: manifest.id,
        version: manifest.version,
        installedDir: installDir.path,
        manifest: manifest,
      );
    }
  
}