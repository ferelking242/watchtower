import 'dart:isolate';
import 'package:watchtower/local_indexer/engine/pipeline/discovery_stage.dart';
import 'package:watchtower/local_indexer/models/local_indexed_item.dart';
import 'package:watchtower/local_indexer/normalizer/name_normalizer.dart';

/// Étape 2 du pipeline : Analyse des noms de fichiers.
///
/// Cette étape peut tourner dans un [Isolate] séparé pour exploiter tous
/// les cœurs CPU disponibles. Elle reçoit un [DiscoveredFile] sérialisé
/// et retourne un [AnalysisResult] sérialisé.
///
/// Ne lit jamais le contenu du fichier — uniquement le nom suffit.
class AnalysisStage {
  /// Point d'entrée de l'isolate worker.
  ///
  /// Protocole :
  ///   Entrée  : `{ taskId: String, payload: Map | null }`
  ///   Sortie  : `{ taskId: String, result: Map }` ou `{ taskId, error, stackTrace }`
  static void isolateEntryPoint(SendPort mainSendPort) {
    final receivePort = ReceivePort();

    // Handshake : envoyer notre SendPort au pool
    mainSendPort.send(receivePort.sendPort);

    receivePort.listen((message) {
      if (message is! Map) return;
      final taskId = message['taskId'] as String?;
      if (taskId == null) return;
      if (taskId == '__shutdown__') {
        receivePort.close();
        return;
      }

      final payload = message['payload'] as Map?;
      if (payload == null) {
        mainSendPort.send({'taskId': taskId, 'error': 'null payload'});
        return;
      }

      try {
        final result = _analyze(payload);
        mainSendPort.send({'taskId': taskId, 'result': result});
      } catch (e, st) {
        mainSendPort.send({
          'taskId': taskId,
          'error': e.toString(),
          'stackTrace': st.toString(),
        });
      }
    });
  }

  /// Analyse synchrone dans l'isolate.
  static Map<String, dynamic> _analyze(Map payload) {
    final path = payload['path'] as String;
    final size = payload['size'] as int;
    final modifiedAt = payload['modifiedAt'] as int;
    final extension = payload['extension'] as String;

    final result = NameNormalizer.normalize(path);
    final mime = _mimeOf(extension);

    return {
      'path': path,
      'size': size,
      'modifiedAt': modifiedAt,
      'extension': extension,
      'mime': mime,
      'title': result.title,
      'canonicalKey': result.canonicalKey,
      'kind': result.kind.index,
      'season': result.season,
      'episode': result.episode,
      'chapter': result.chapter,
      'volume': result.volume,
      'part': result.part,
      'quality': result.quality,
      'codec': result.codec,
      'audioCodec': result.audioCodec,
      'language': result.language,
      'releaseGroup': result.releaseGroup,
      'confidence': result.confidence,
    };
  }

  /// Analyse en-process (sans isolate) pour les petits lots.
  static AnalysisResult analyzeSync(DiscoveredFile file) {
    final result = NameNormalizer.normalize(file.path);
    return AnalysisResult(
      discoveredFile: file,
      title: result.title,
      canonicalKey: result.canonicalKey,
      kind: result.kind,
      season: result.season,
      episode: result.episode,
      chapter: result.chapter,
      volume: result.volume,
      part: result.part,
      quality: result.quality,
      codec: result.codec,
      audioCodec: result.audioCodec,
      language: result.language,
      releaseGroup: result.releaseGroup,
      confidence: result.confidence,
      mimeType: _mimeOf(file.extension),
    );
  }

  /// Reconstruit un [AnalysisResult] depuis le Map retourné par l'isolate.
  static AnalysisResult fromMap(Map<String, dynamic> map, DiscoveredFile file) {
    return AnalysisResult(
      discoveredFile: file,
      title: map['title'] as String,
      canonicalKey: map['canonicalKey'] as String,
      kind: _kindFromIndex(map['kind'] as int),
      season: map['season'] as int?,
      episode: map['episode'] as int?,
      chapter: map['chapter'] as int?,
      volume: map['volume'] as int?,
      part: map['part'] as int?,
      quality: map['quality'] as String?,
      codec: map['codec'] as String?,
      audioCodec: map['audioCodec'] as String?,
      language: map['language'] as String?,
      releaseGroup: map['releaseGroup'] as String?,
      confidence: (map['confidence'] as num).toDouble(),
      mimeType: map['mime'] as String?,
    );
  }

  static LocalMediaKind _kindFromIndex(int i) {
    return LocalMediaKind.values[i.clamp(0, LocalMediaKind.values.length - 1)];
  }

  static String? _mimeOf(String ext) => const <String, String>{
        '.mkv': 'video/x-matroska',
        '.mp4': 'video/mp4',
        '.avi': 'video/x-msvideo',
        '.mov': 'video/quicktime',
        '.flv': 'video/x-flv',
        '.wmv': 'video/x-ms-wmv',
        '.ts': 'video/mp2t',
        '.m2ts': 'video/mp2t',
        '.webm': 'video/webm',
        '.cbz': 'application/vnd.comicbook+zip',
        '.cbr': 'application/vnd.comicbook-rar',
        '.epub': 'application/epub+zip',
        '.mobi': 'application/x-mobipocket-ebook',
        '.jpg': 'image/jpeg',
        '.jpeg': 'image/jpeg',
        '.png': 'image/png',
        '.webp': 'image/webp',
      }[ext];
}

/// Résultat de l'analyse d'un fichier découvert.
class AnalysisResult {
  final DiscoveredFile discoveredFile;
  final String title;
  final String canonicalKey;
  final LocalMediaKind kind;
  final int? season;
  final int? episode;
  final int? chapter;
  final int? volume;
  final int? part;
  final String? quality;
  final String? codec;
  final String? audioCodec;
  final String? language;
  final String? releaseGroup;
  final double confidence;
  final String? mimeType;

  const AnalysisResult({
    required this.discoveredFile,
    required this.title,
    required this.canonicalKey,
    required this.kind,
    this.season,
    this.episode,
    this.chapter,
    this.volume,
    this.part,
    this.quality,
    this.codec,
    this.audioCodec,
    this.language,
    this.releaseGroup,
    required this.confidence,
    this.mimeType,
  });
}
