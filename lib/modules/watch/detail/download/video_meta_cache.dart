import 'package:watchtower/modules/watch/detail/download/video_file_meta.dart';

/// Mémoires des métadonnées (poids | durée) d'un flux, partagées par le sheet
/// « Télécharger » et la fiche de téléchargement en masse.
///
/// Clé = URL EXACTE du flux. Un poids déjà mesuré ne change jamais : rouvrir un
/// sheet, changer de qualité ou de langue relit simplement ces valeurs, et deux
/// surfaces qui interrogent la même URL ne la sondent qu'une fois.

class UrlMeta {
  final String? sizeLabel; // « 259.9MB »
  final int? durationSeconds;
  const UrlMeta({this.sizeLabel, this.durationSeconds});
}

final Map<String, UrlMeta> kVideoDirectMetaCache = <String, UrlMeta>{};
final Map<String, HlsMeta> kVideoHlsMetaCache = <String, HlsMeta>{};

void _trimMetaCaches() {
  if (kVideoDirectMetaCache.length > 800) kVideoDirectMetaCache.clear();
  if (kVideoHlsMetaCache.length > 800) kVideoHlsMetaCache.clear();
}

/// HLS master (ou playlist média) : un seul probe réseau par URL, en cache.
Future<HlsMeta?> cachedHlsMeta(String url, Map<String, String>? headers) {
  final hit = kVideoHlsMetaCache[url];
  if (hit != null) return Future.value(hit);
  return fetchHlsMeta(url, headers).then((meta) {
    if (meta != null) {
      _trimMetaCaches();
      kVideoHlsMetaCache[url] = meta;
    }
    return meta;
  });
}

/// Fichier direct : poids via `Content-Range` + durée conteneur, en cache.
Future<UrlMeta?> cachedDirectMeta(String url, Map<String, String>? headers) async {
  final hit = kVideoDirectMetaCache[url];
  if (hit != null) return hit;
  String? size;
  int? seconds;
  try {
    final bytes = await fetchDirectFileSize(url, headers);
    if (bytes != null && bytes > 0) size = formatBytes(bytes);
  } catch (_) {
    // Poids indisponible : la durée reste cherchée.
  }
  try {
    seconds = await fetchDirectFileDuration(url, headers);
  } catch (_) {
    // Durée indisponible.
  }
  final meta = UrlMeta(sizeLabel: size, durationSeconds: seconds);
  if (size != null || seconds != null) {
    _trimMetaCaches();
    kVideoDirectMetaCache[url] = meta;
  }
  return meta;
}
