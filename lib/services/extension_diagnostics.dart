import 'package:isar_community/isar.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/services/get_popular.dart';
import 'package:watchtower/utils/log/logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Fires `getPopular(page=1)` on every installed source for [itemType] in
/// parallel so that any extension that throws is captured by [AppLogger].
///
/// Returns a tuple of `(ok, failed, total)`.
Future<(int ok, int failed, int total)> runExtensionDiagnostics(
  Ref ref, {
  required ItemType itemType,
}) async {
  final sources = isar.sources
      .filter()
      .idIsNotNull()
      .and()
      .isAddedEqualTo(true)
      .and()
      .itemTypeEqualTo(itemType)
      .findAllSync();

  AppLogger.log(
    '🔬 Diagnostics started — type=${itemType.name} '
    '| sources=${sources.length}',
    logLevel: LogLevel.info,
    tag: LogTag.extension_,
  );

  int ok = 0;
  int failed = 0;
  final futures = <Future<void>>[];

  for (final src in sources) {
    if (src.name == 'local' && src.lang == '') continue;
    futures.add(_diagnose(ref, src).then((success) {
      if (success) {
        ok++;
      } else {
        failed++;
      }
    }));
  }

  await Future.wait(futures);

  AppLogger.log(
    '🔬 Diagnostics finished — ok=$ok | failed=$failed '
    '| total=${ok + failed}',
    logLevel: failed > 0 ? LogLevel.warning : LogLevel.info,
    tag: LogTag.extension_,
  );

  return (ok, failed, ok + failed);
}

Future<bool> _diagnose(Ref ref, Source src) async {
  final start = DateTime.now();
  try {
    AppLogger.log(
      '→ ${src.name} [${src.lang}] v${src.version} : popular(page=1)',
      logLevel: LogLevel.debug,
      tag: LogTag.extension_,
    );
    final pages = await ref.read(
      getPopularProvider(source: src, page: 1).future,
    );
    final elapsed = DateTime.now().difference(start).inMilliseconds;
    final count = pages?.list?.length ?? 0;
    AppLogger.log(
      '✓ ${src.name} OK · $count items · ${elapsed}ms',
      logLevel: LogLevel.info,
      tag: LogTag.extension_,
    );
    return true;
  } catch (e, st) {
    final elapsed = DateTime.now().difference(start).inMilliseconds;
    AppLogger.log(
      '✗ ${src.name} FAILED · ${elapsed}ms',
      logLevel: LogLevel.error,
      tag: LogTag.extension_,
      error: e,
      stackTrace: st,
    );
    return false;
  }
}
