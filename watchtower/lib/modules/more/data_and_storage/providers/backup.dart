import 'dart:convert';
import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'package:archive/archive_io.dart';
import 'package:watchtower/eval/model/m_bridge.dart';
import 'package:flutter/material.dart' hide Category;
import 'package:isar_community/isar.dart';
import 'package:watchtower/eval/model/source_preference.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/category.dart';
import 'package:watchtower/models/chapter.dart';
import 'package:watchtower/models/custom_button.dart';
import 'package:watchtower/models/download.dart';
import 'package:watchtower/models/history.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/settings.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/models/track.dart';
import 'package:watchtower/models/track_preference.dart';
import 'package:watchtower/models/update.dart';
import 'package:watchtower/modules/more/data_and_storage/providers/backup_compression.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:path/path.dart' as p;
part 'backup.g.dart';

@riverpod
Future<void> doBackUp(
  Ref ref, {
  required List<int> list,
  required String path,
  required BuildContext? context,
}) async {
  final compression = ref.read(backupCompressionLevelProvider);
  final compressionLevel = compression.clamp(0, 9).toInt();
  try {
    Map<String, dynamic> datas = {};
    datas.addAll({"version": "2"});
    if (list.contains(0)) {
      final res = isar.mangas
          .filter()
          .idIsNotNull()
          .favoriteEqualTo(true)
          .isLocalArchiveEqualTo(false)
          .findAllSync()
          .map((e) => e.toJson())
          .toList();
      datas.addAll({"manga": res});
    }
    if (list.contains(1)) {
      final res = isar.categorys
          .filter()
          .idIsNotNull()
          .findAllSync()
          .map((e) => e.toJson())
          .toList();
      datas.addAll({"categories": res});
    }
    if (list.contains(2)) {
      final res = isar.chapters
          .filter()
          .idIsNotNull()
          .findAllSync()
          .map((e) => e.toJson())
          .toList();
      datas.addAll({"chapters": res});
      final res_ = isar.downloads
          .filter()
          .idIsNotNull()
          .findAllSync()
          .map((e) => e.toJson())
          .toList();
      datas.addAll({"downloads": res_});
    }
    if (list.contains(3)) {
      final res = isar.tracks
          .filter()
          .idIsNotNull()
          .findAllSync()
          .map((e) => e.toJson())
          .toList();
      datas.addAll({"tracks": res});
    }
    if (list.contains(4)) {
      final res = isar.historys
          .filter()
          .idIsNotNull()
          .findAllSync()
          .map((e) => e.toJson())
          .toList();
      datas.addAll({"history": res});
    }
    if (list.contains(5)) {
      final res = isar.updates
          .filter()
          .idIsNotNull()
          .findAllSync()
          .map((e) => e.toJson())
          .toList();
      datas.addAll({"updates": res});
    }
    if (list.contains(6)) {
      final res = isar.settings
          .filter()
          .idIsNotNull()
          .findAllSync()
          .map((e) => e.toJson())
          .toList();
      datas.addAll({"settings": res});
    }
    if (list.contains(7)) {
      final res = isar.sourcePreferences
          .filter()
          .idIsNotNull()
          .findAllSync()
          .map((e) => e.toJson())
          .toList();
      datas.addAll({"extensions_preferences": res});
    }
    if (list.contains(8)) {
      final res_ = isar.trackPreferences
          .filter()
          .syncIdIsNotNull()
          .findAllSync()
          .map((e) => e.toJson())
          .toList();
      datas.addAll({"trackPreferences": res_});
    }
    if (list.contains(9)) {
      final res = isar.sources
          .filter()
          .idIsNotNull()
          .findAllSync()
          .map((e) => e.toJson())
          .toList();
      datas.addAll({"extensions": res});
    }
    if (list.contains(10)) {
      final res = isar.customButtons
          .filter()
          .idIsNotNull()
          .findAllSync()
          .map((e) => e.toJson())
          .toList();
      datas.addAll({"customButtons": res});
    }
    final regExp = RegExp(r'[^a-zA-Z0-9 .()\-\s]');
    final name =
        'watchtower_${DateTime.now().toString().replaceAll(regExp, '_').replaceAll(' ', '_')}';
    final backupFilePath = p.join(path, "$name.backup.db");
    final file = File(backupFilePath);

    await file.writeAsString(jsonEncode(datas));
    final zipPath = p.join(path, "$name.backup");
    final zipEncoder = ZipFileEncoder();
    zipEncoder.create(zipPath, level: compressionLevel);
    await zipEncoder.addFile(file);
    await zipEncoder.close();
    file.delete();
    if (context != null && context.mounted) {
      Navigator.pop(context);
      botToast("Backup created!", second: 5);
    }
  } catch (e) {
    if (context?.mounted ?? false) {
      botToast("Backup failed: $e", second: 7);
    }
  }
}
