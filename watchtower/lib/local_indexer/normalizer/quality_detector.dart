/// Étapes 7+8 du pipeline : Détection qualité, codec vidéo et audio.

class QualityResult {
  final String? resolution;   // "1080p", "4K", "720p"…
  final String? videoCodec;   // "x265", "H.264", "AV1"…
  final String? audioCodec;   // "AAC", "FLAC", "DTS"…
  final String? source;       // "BluRay", "WEB-DL", "HDTV"…
  final bool isHdr;
  final Set<int> consumedIndices;

  const QualityResult({
    this.resolution,
    this.videoCodec,
    this.audioCodec,
    this.source,
    this.isHdr = false,
    required this.consumedIndices,
  });
}

class QualityDetector {
  // ── Résolution ────────────────────────────────────────────────────────────
  static final _resolutionMap = <Pattern, String>{
    RegExp(r'^4[Kk]$|^2160[Pp]?$'): '4K',
    RegExp(r'^1080[Pp]?[Ii]?$'): '1080p',
    RegExp(r'^720[Pp]?$'): '720p',
    RegExp(r'^480[Pp]?$'): '480p',
    RegExp(r'^360[Pp]?$'): '360p',
    RegExp(r'^2560x1440$'): '1440p',
    RegExp(r'^3840x2160$'): '4K',
    RegExp(r'^1920x1080$'): '1080p',
    RegExp(r'^1280x720$'): '720p',
  };

  // ── Codec vidéo ───────────────────────────────────────────────────────────
  static final _videoCodecMap = <Pattern, String>{
    RegExp(r'^[Xx]265$|^[Hh]\.?265$|^HEVC$', caseSensitive: false): 'x265',
    RegExp(r'^[Xx]264$|^[Hh]\.?264$|^AVC$', caseSensitive: false): 'x264',
    RegExp(r'^AV1$', caseSensitive: false): 'AV1',
    RegExp(r'^VP9$', caseSensitive: false): 'VP9',
    RegExp(r'^XviD$', caseSensitive: false): 'XviD',
    RegExp(r'^DivX$', caseSensitive: false): 'DivX',
  };

  // ── Codec audio ───────────────────────────────────────────────────────────
  static final _audioCodecMap = <Pattern, String>{
    RegExp(r'^AAC$', caseSensitive: false): 'AAC',
    RegExp(r'^FLAC$', caseSensitive: false): 'FLAC',
    RegExp(r'^(?:AC3|DD|Dolby)$', caseSensitive: false): 'AC3',
    RegExp(r'^(?:DDP|EAC3|E-AC-3)$', caseSensitive: false): 'EAC3',
    RegExp(r'^DTS(?:-HD)?(?:\.MA)?$', caseSensitive: false): 'DTS',
    RegExp(r'^(?:MP3|MPEG2Audio)$', caseSensitive: false): 'MP3',
    RegExp(r'^Opus$', caseSensitive: false): 'Opus',
    RegExp(r'^TrueHD$', caseSensitive: false): 'TrueHD',
  };

  // ── Source ────────────────────────────────────────────────────────────────
  static final _sourceMap = <Pattern, String>{
    RegExp(r'^(?:BluRay|BDRip|BRRip|BD)$', caseSensitive: false): 'BluRay',
    RegExp(r'^(?:WEB-?DL|WebDL)$', caseSensitive: false): 'WEB-DL',
    RegExp(r'^WebRip$', caseSensitive: false): 'WEBRip',
    RegExp(r'^HDTV$', caseSensitive: false): 'HDTV',
    RegExp(r'^DVDRip$', caseSensitive: false): 'DVDRip',
    RegExp(r'^(?:AMZN|Amazon)$', caseSensitive: false): 'Amazon',
    RegExp(r'^(?:NF|Netflix)$', caseSensitive: false): 'Netflix',
    RegExp(r'^(?:CR|Crunchyroll)$', caseSensitive: false): 'Crunchyroll',
    RegExp(r'^(?:DSNP|Disney\+?)$', caseSensitive: false): 'Disney+',
  };

  // ── HDR ───────────────────────────────────────────────────────────────────
  static final _hdrPattern = RegExp(
    r'^(?:HDR10?\+?|DolbyVision|DV|SDR|HLG)$',
    caseSensitive: false,
  );

  static QualityResult detect(List<String> tokens) {
    String? resolution, videoCodec, audioCodec, source;
    bool isHdr = false;
    final consumed = <int>{};

    for (var i = 0; i < tokens.length; i++) {
      final t = tokens[i];

      if (resolution == null) {
        final r = _match(t, _resolutionMap);
        if (r != null) {
          resolution = r;
          consumed.add(i);
          continue;
        }
      }

      if (videoCodec == null) {
        final v = _match(t, _videoCodecMap);
        if (v != null) {
          videoCodec = v;
          consumed.add(i);
          continue;
        }
      }

      if (audioCodec == null) {
        final a = _match(t, _audioCodecMap);
        if (a != null) {
          audioCodec = a;
          consumed.add(i);
          continue;
        }
      }

      if (source == null) {
        final s = _match(t, _sourceMap);
        if (s != null) {
          source = s;
          consumed.add(i);
          continue;
        }
      }

      if (_hdrPattern.hasMatch(t)) {
        isHdr = true;
        consumed.add(i);
      }
    }

    return QualityResult(
      resolution: resolution,
      videoCodec: videoCodec,
      audioCodec: audioCodec,
      source: source,
      isHdr: isHdr,
      consumedIndices: consumed,
    );
  }

  static String? _match(String token, Map<Pattern, String> map) {
    for (final entry in map.entries) {
      if (entry.key is RegExp) {
        if ((entry.key as RegExp).hasMatch(token)) return entry.value;
      } else {
        if (entry.key == token) return entry.value;
      }
    }
    return null;
  }
}
