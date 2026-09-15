class BannerAd {
  const BannerAd({
    required this.key,
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.targetUrl,
    required this.altText,
    this.shape = 'rectangle',
    this.aspectRatio = 2.2,
    this.placements = const [],
  });

  final String key;
  final String id;
  final String name;
  final String imageUrl;
  final String targetUrl;
  final String altText;
  final String shape;
  final double aspectRatio;
  final List<String> placements;

  factory BannerAd.fromJson(Map<String, dynamic> json) {
    return BannerAd(
      key: json['key']?.toString() ?? json['id']?.toString() ?? '',
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString() ?? '',
      targetUrl: json['targetUrl']?.toString() ?? '',
      altText: json['altText']?.toString() ?? '',
      shape: json['shape']?.toString() ?? 'rectangle',
      aspectRatio: (json['aspectRatio'] as num?)?.toDouble() ?? 2.2,
      placements: (json['placements'] is List)
          ? (json['placements'] as List)
              .whereType<String>()
              .toList(growable: false)
          : const [],
    );
  }
}

class BannerDisplayConfig {
  const BannerDisplayConfig({
    required this.key,
    this.enabled = true,
    this.placements = const [],
    this.shape,
    this.width,
    this.height,
    this.aspectRatio,
  });

  final String key;
  final bool enabled;
  final List<String> placements;
  final String? shape;
  final double? width;
  final double? height;
  final double? aspectRatio;

  factory BannerDisplayConfig.fromJson(String key, Map<String, dynamic> json) {
    final rawPlacements = json['placements'];
    return BannerDisplayConfig(
      key: key,
      enabled: json['enabled'] is bool ? json['enabled'] as bool : true,
      placements: rawPlacements is List
          ? rawPlacements.whereType<String>().toList(growable: false)
          : const [],
      shape: json['shape']?.toString(),
      width: (json['width'] as num?)?.toDouble(),
      height: (json['height'] as num?)?.toDouble(),
      aspectRatio: (json['aspectRatio'] as num?)?.toDouble(),
    );
  }

  bool appliesTo(String placement) =>
      placements.isEmpty || placements.contains(placement);
}
