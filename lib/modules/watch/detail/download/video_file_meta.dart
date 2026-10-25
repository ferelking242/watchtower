import 'dart:async';
import 'dart:io'
    if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'package:watchtower/services/hls_variant_resolver.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Métadonnées (poids | durée) d'une vidéo, quel que soit le flux :
//   • Fichier direct (mp4/mkv/webm…) : GET `Range: bytes=0-0` → l'entête
//     `Content-Range: bytes 0-0/TOTAL` donne le POIDS EXACT sans télécharger
//     le fichier (1 seule requête, quelques octets). Repli : Content-Length.
//   • HLS (.m3u8) : master → variantes (HlsVariantResolver) ; la DURÉE exacte
//     se lit en sommant les `#EXTINF` de la playlist média ; le poids de chaque
//     variante s'estime à BANDWIDTH × durée ÷ 8 (estimation de référence).
//   • DURÉE d'un fichier direct, quel que soit le conteneur :
//     – MP4/MOV : le conteneur porte la durée dans la boîte `mvhd`
//       (`moov › mvhd`) : `Durée = duration × timescale⁻¹`, champs contigus
//       à offsets fixes après le sigle ASCII `mvhd`. Le `moov` étant presque
//       toujours placé en tête au début (166 Ko suffisent), avec repli sur
//       la fin de fichier quand il n'y est pas.
//     – MKV/WebM : la durée est l'élément Matroska `Duration` (ID `0x4489`),
//       un flottant en NANOSECONDES dans le Segment `Info`. Un scan du
//       premier Mo suffit (Info est collé après l'entête EBML).
//     – Autres : repli sur la durée persistée par le lecteur.
//   • Durée de repli : celle persistée par le lecteur (chapter.duration),
//     disponible dès que la vidéo a été lue une fois.
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:convert' show ascii, utf8;
import 'dart:typed_data' show ByteData, BytesBuilder, Uint8List;

/// Lit un entier big-endian non signé de [length] octets à [offset].
int _beUint(Uint8List b, int offset, int length) {
  var v = 0;
  for (var i = 0; i < length; i++) {
    if (offset + i < b.length) v = (v << 8) | b[offset + i];
  }
  return v;
}

/// Durée D'UN CONTENEUR direct, lue côté client, sans télécharger le fichier.
///
/// Méthode par conteneur : MP4/MOV → boîte `mvhd` (offsets fixes) ;
/// MKV/WebM → élément Matroska `Duration` (flottant en ns). Rien ne change
/// par extension de fichier : c'est la structure du conteneur qui décide,
/// donc un `.mp4` nommé n'importe comment est quand même reconnu.
Future<int?> fetchDirectFileDuration(
  String url,
  Map<String, String>? headers,
) async {
  const probeBytes = 1 << 20; // 1 Mo : moov en tête ou Info EBML suffit.
  final head = await _fetchByteRange(url, headers, 0, probeBytes);
  if (head == null || head.isEmpty) return null;
  final seconds = _containerDurationFromBytes(head);
  if (seconds != null) return seconds;
  // Fichier avec `moov` en fin : scan des derniers octets.
  final tail = await _fetchByteRange(url, headers, -1, probeBytes);
  return tail == null ? null : _containerDurationFromBytes(tail);
}

/// Durée en secondes lue depuis les octets d'ouverture du conteneur.
int? _containerDurationFromBytes(Uint8List b) =>
    _mp4DurationFromBytes(b) ?? _matroskaDurationFromBytes(b);

/// Durée MP4 : sigle ASCII `mvhd` → version à +4, puis (v0) timescale à +16
/// et duration à +20 (4 octets), (v1) timescale à +24 et duration à +28
/// (8 octets). Durée = duration ÷ timescale.
int? _mp4DurationFromBytes(Uint8List b) {
  final needle = Uint8List.fromList(ascii.encode('mvhd'));
  final idx = _indexOf(b, needle);
  if (idx < 0 || idx + 32 > b.length) return null;
  final version = b[idx + 4];
  if (version == 1) {
    final timescale = _beUint(b, idx + 24, 4);
    final duration = _beUint(b, idx + 28, 8);
    if (timescale > 0) return (duration / timescale).round();
  } else {
    final timescale = _beUint(b, idx + 16, 4);
    final duration = _beUint(b, idx + 20, 4);
    if (timescale > 0) return (duration / timescale).round();
  }
  return null;
}

/// Durée Matroska (MKV/WebM) : élément `Duration` (ID `0x4489`), dont la
/// valeur est un flottant IEEE en NANOSECONDES (4 octets = float32 restant
/// élargi, 8 = float64). Durée = valeur ÷ 1e9.
int? _matroskaDurationFromBytes(Uint8List bytes) {
  for (var i = 0; i + 12 <= bytes.length; i++) {
    if (bytes[i] == 0x44 && bytes[i + 1] == 0x89) {
      final sizeByte = bytes[i + 2];
      final data = ByteData.sublistView(
        bytes,
        i + 3,
        i + 3 + (sizeByte >= 4 && sizeByte <= 8 ? sizeByte : 0),
      );
      // Toutes les valeurs sont en NANOSECONDES, en flottant (l'encodage
      // historique float32 n'est que plus court, pas en secondes).
      const minSeconds = 1.0, maxSeconds = 7 * 24 * 3600.0;
      if (data.lengthInBytes == 4) {
        final seconds = data.getFloat32(0) / 1e9;
        if (seconds >= minSeconds && seconds <= maxSeconds) {
          return seconds.round();
        }
      }
      if (data.lengthInBytes == 8) {
        final seconds = data.getFloat64(0) / 1e9;
        if (seconds >= minSeconds && seconds <= maxSeconds) {
          return seconds.round();
        }
      }
    }
  }
  return null;
}

int _indexOf(Uint8List haystack, Uint8List needle) {
  outer:
  for (var i = 0; i <= haystack.length - needle.length; i++) {
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) continue outer;
    }
    return i;
  }
  return -1;
}

/// GET `Range: bytes=…` léger. [from] négatif = relativement à la FIN du
/// fichier (`bytes=-N`, la taille totale est renvoyée dans Content-Range).
Future<Uint8List?> _fetchByteRange(
  String url,
  Map<String, String>? headers,
  int from,
  int length,
) async {
  final (client, request) = await _open('GET', url, headers);
  try {
    final range = from < 0 ? 'bytes=-$length' : 'bytes=$from-${from + length - 1}';
    // Littéraux : le stub web du HttpClient ne déclare pas les constantes.
    request.headers.set('range', range);
    final response = await request.close().timeout(const Duration(seconds: 15));
    if (response.statusCode ~/ 100 != 2) {
      await response.drain<void>().timeout(const Duration(seconds: 15));
      return null;
    }
    final b = BytesBuilder();
    await for (final chunk in response) {
      b.add(chunk);
      if (b.length >= length) break; // assez lu : on coupe le téléchargement
    }
    return b.takeBytes();
  } catch (_) {
    return null;
  } finally {
    client.close(force: true);
  }
}

class VideoFileMeta {
  final String? sizeLabel;
  final String? durationLabel;

  const VideoFileMeta({this.sizeLabel, this.durationLabel});
}

class HlsTrackMeta {
  final String url;

  /// Libellé de qualité (« 480p »…), tel que résolu depuis le master.
  final String label;

  /// Poids estimé de la variante (BANDWIDTH × durée), en octets.
  final int? estimatedBytes;

  const HlsTrackMeta({
    required this.url,
    required this.label,
    this.estimatedBytes,
  });
}

class HlsMeta {
  final String? durationLabel;
  final List<HlsTrackMeta> tracks;

  const HlsMeta({this.durationLabel, required this.tracks});
}

bool isHlsUrl(String url) {
  final u = url.toLowerCase();
  return u.contains('.m3u8') || u.contains('/m3u8');
}

String formatBytes(int? bytes) {
  if (bytes == null || bytes <= 0) return '';
  if (bytes >= 1 << 30) return '${(bytes / (1 << 30)).toStringAsFixed(1)}GB';
  if (bytes >= 1 << 20) return '${(bytes / (1 << 20)).toStringAsFixed(1)}MB';
  return '${(bytes / (1 << 10)).toStringAsFixed(0)}KB';
}

String formatDurationSeconds(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  final mm = m.toString().padLeft(2, '0');
  final ss = s.toString().padLeft(2, '0');
  return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
}

/// Somme les `#EXTINF:<d>,` d'une playlist média (durée totale, secondes).
int? _sumExtinf(String body) {
  final re = RegExp(r'#EXTINF:([\d.]+)');
  double total = 0;
  for (final m in re.allMatches(body)) {
    total += double.tryParse(m.group(1)!) ?? 0;
  }
  if (total <= 0) return null;
  return total.round();
}

Future<(HttpClient, HttpClientRequest)> _open(
  String method,
  String url,
  Map<String, String>? headers,
) async {
  final client = HttpClient();
  client.connectionTimeout = const Duration(seconds: 12);
  final request = await client.openUrl(method, Uri.parse(url));
  headers?.forEach(request.headers.set);
  return (client, request);
}

/// GET léger → corps texte (playlists).
Future<String?> httpGetText(
  String url,
  Map<String, String>? headers,
) async {
  final (client, request) = await _open('GET', url, headers);
  try {
    final response = await request.close().timeout(const Duration(seconds: 15));
    if (response.statusCode ~/ 100 != 2) return null;
    return await response
        .transform(utf8.decoder)
        .join();
  } catch (_) {
    return null;
  } finally {
    client.close(force: true);
  }
}

/// Poids EXACT d'un fichier direct via `Range: bytes=0-0`.
Future<int?> fetchDirectFileSize(
  String url,
  Map<String, String>? headers,
) async {
  final (client, request) = await _open('GET', url, headers);
  try {
    request.headers.set('range', 'bytes=0-0');
    final response = await request.close().timeout(const Duration(seconds: 15));
    // On ne lit pas le corps : seules les entêtes nous intéressent.
    await response.drain<void>().timeout(const Duration(seconds: 15));
    if (response.statusCode ~/ 100 != 2) return null;
    final contentRange = response.headers.value('content-range'); // b 0-0/TOTAL
    if (contentRange != null) {
      final slash = contentRange.lastIndexOf('/');
      if (slash != -1) return int.tryParse(contentRange.substring(slash + 1));
    }
    final length = response.headers.value('content-length');
    return length == null ? null : int.tryParse(length.split('.')[0]);
  } catch (_) {
    return null;
  } finally {
    client.close(force: true);
  }
}

/// Détail HLS complet pour un master (ou une playlist simple).
Future<HlsMeta?> fetchHlsMeta(
  String url,
  Map<String, String>? headers,
) async {
  try {
    final uri = Uri.parse(url);
    final masterBody = await httpGetText(url, headers);
    if (masterBody == null) return null;

    if (HlsVariantResolver.isMasterPlaylist(masterBody)) {
      final variants =
          HlsVariantResolver.parseMaster(masterBody, masterUrl: uri);
      if (variants.isEmpty) return const HlsMeta(tracks: []);

      // La durée est identique sur toutes les variantes : une seule
      // interrogation suffit. On interroge la plus haute qualité (le CDN la
      // met presque toujours en cache matrice déjà chaud) puis on applique
      // BANDWIDTH × durée pour estimer le poids de chaque variante.
      final best = variants.first;
      final mediaBody = await httpGetText(best.url, headers);
      final seconds =
          mediaBody == null ? null : _sumExtinf(mediaBody);

      final tracks = <HlsTrackMeta>[];
      for (final v in variants) {
        int? bytes;
        if (seconds != null && v.bandwidth != null && v.bandwidth! > 0) {
          bytes = ((v.bandwidth! / 8).round() * seconds);
        }
        tracks.add(HlsTrackMeta(
          url: v.url,
          label: v.label,
          estimatedBytes: bytes,
        ));
      }
      return HlsMeta(
        durationLabel:
            seconds == null ? null : formatDurationSeconds(seconds),
        tracks: tracks,
      );
    }

    // Playlist média directe : durée exacte, pas de poids déclaré.
    final seconds = _sumExtinf(masterBody);
    return HlsMeta(
      durationLabel: seconds == null ? null : formatDurationSeconds(seconds),
      tracks: const [],
    );
  } catch (_) {
    return null;
  }
}

/// Métadonnées d'un fichier direct ; [fallbackDuration] = durée connue
/// (persistée par le lecteur) pour complète l'affichage.
Future<VideoFileMeta> fetchVideoFileMeta(
  String url,
  Map<String, String>? headers, {
  String? fallbackDuration,
}) async {
  VideoFileMeta meta = const VideoFileMeta();
  if (isHlsUrl(url)) {
    final hls = await fetchHlsMeta(url, headers);
    if (hls != null && hls.tracks.isNotEmpty) {
      final best = hls.tracks.first;
      meta = VideoFileMeta(
        sizeLabel: formatBytes(best.estimatedBytes),
        durationLabel: hls.durationLabel ?? fallbackDuration,
      );
    }
  } else {
    final bytes = await fetchDirectFileSize(
      url,
      headers,
    ).timeout(const Duration(seconds: 18), onTimeout: () => null);
    meta = VideoFileMeta(
      sizeLabel: formatBytes(bytes),
      durationLabel: fallbackDuration,
    );
  }
  return meta;
}
