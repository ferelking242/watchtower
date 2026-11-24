import 'dart:convert';
import 'package:watchtower/eval/javascript/http.dart';
import 'package:watchtower/eval/lib.dart';
import 'package:watchtower/utils/utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'headers.g.dart';

/// Headers depend only on the source, so they are computed once and reused.
///
/// The previous implementation created a fresh extension service and disposed
/// it on every call. `headersProvider` is watched by every visible cover in the
/// library grid/list, so that meant booting (and tearing down) a QuickJS
/// interpreter per card per rebuild — the main reason the library felt slow and
/// janky. The runtime is now borrowed from [ExtensionServiceRegistry] (which
/// already caches one service per source and never disposes it mid-session) and
/// the resulting map is memoised by source signature.
final _headersCache = <String, Map<String, String>>{};

Map<String, String> _computeHeaders({
  required String source,
  required String lang,
  required int? sourceId,
}) {
  final mSource = getSource(lang, source, sourceId);

  Map<String, String> headers = {};

  if (mSource != null) {
    final fromSource = mSource.headers;

    if (fromSource != null && fromSource.isNotEmpty) {
      headers.addAll((jsonDecode(fromSource) as Map).toMapStringString!);
    }
    // Never *boot* an extension runtime here. `headersProvider` is watched
    // from every visible cover and from the watch banner, i.e. on the UI
    // isolate, and `ExtensionServiceRegistry.get` would build a second QuickJS
    // engine with its own FFI trampoline next to the worker's — the native
    // SIGSEGV seen right after `getVideoList` returned (crash frames
    // `js_channel` <- `JS_Eval` <- `anon:FfiCallbackMetadata::TrampolinePage`).
    //
    // A runtime that already exists is reused: `peek` never creates one, so a
    // source whose `getHeaders` is dynamic still contributes when its engine
    // is up, and a cold one simply falls back to the static headers above.
    final service = ExtensionServiceRegistry.peek(mSource);
    if (service != null) {
      try {
        headers.addAll(service.getHeaders());
      } catch (_) {
        // A source without a runnable `getHeaders` must not take the grid down.
      }
    }
  }

  return headers;
}

@riverpod
Map<String, String> headers(
  Ref ref, {
  required String source,
  required String lang,
  required int? sourceId,
}) {
  final mSource = getSource(lang, source, sourceId);
  final key = mSource == null
      ? '$lang|$source|$sourceId|missing'
      : '${mSource.id}|${mSource.version}|${mSource.sourceCode?.hashCode}';
  return _headersCache.putIfAbsent(
    key,
    () => _computeHeaders(source: source, lang: lang, sourceId: sourceId),
  );
}
