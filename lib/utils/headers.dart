import 'dart:convert';
import 'package:watchtower/eval/javascript/http.dart';
import 'package:watchtower/eval/lib.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/utils/utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'headers.g.dart';

@riverpod
Map<String, String> headers(
  Ref ref, {
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
    final service = getExtensionService(mSource);
    try {
      headers.addAll(service.getHeaders());
    } finally {
      service.dispose();
    }
  }

  return headers;
}
