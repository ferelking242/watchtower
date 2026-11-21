/// How a Live TV provider delivers its channel list.
///
/// Each kind has its own reader in `sources/`; the provider record itself only
/// carries the data the reader needs, so a new protocol is one enum value plus
/// one reader rather than a new screen.
enum LiveProviderKind {
  /// A plain M3U/M3U8 playlist URL.
  m3u,

  /// An Xtream Codes panel: one base URL plus credentials.
  xtream,

  /// A JSON document listing channels.
  json,
}

/// A channel as exposed by a provider, normalised across protocols.
class LiveChannel {
  const LiveChannel({
    required this.id,
    required this.name,
    required this.urls,
    this.group,
    this.logoUrl,
    this.tvgId,
    this.language,
    this.country,
  });

  /// Stable identity: `<providerId>:<tvgId|name>`.
  ///
  /// Derived from the provider id so two providers offering the same channel
  /// stay distinct favourites, and so the id survives a playlist re-fetch.
  final String id;

  final String name;

  /// Playback candidates in order. The first that answers is used, which is
  /// what makes a dead mirror survivable.
  final List<String> urls;

  final String? group;
  final String? logoUrl;
  final String? tvgId;
  final String? language;
  final String? country;

  String get primaryUrl => urls.isEmpty ? '' : urls.first;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'urls': urls,
    if (group != null) 'group': group,
    if (logoUrl != null) 'logoUrl': logoUrl,
    if (tvgId != null) 'tvgId': tvgId,
    if (language != null) 'language': language,
    if (country != null) 'country': country,
  };

  static LiveChannel? fromJson(Map<String, dynamic> json) {
    final urls = [
      for (final url in (json['urls'] as List? ?? const []))
        if (url is String && url.isNotEmpty) url,
    ];
    final name = json['name'] as String?;
    if (name == null || name.isEmpty || urls.isEmpty) return null;
    return LiveChannel(
      id: json['id'] as String? ?? name,
      name: name,
      urls: urls,
      group: json['group'] as String?,
      logoUrl: json['logoUrl'] as String?,
      tvgId: json['tvgId'] as String?,
      language: json['language'] as String?,
      country: json['country'] as String?,
    );
  }
}

/// A provider of live channels — the Live TV equivalent of a Watch or Manga
/// extension.
///
/// Providers are data, not code: adding one never loads foreign Dart, so a
/// malformed or hostile playlist can only produce bad channels, never execute
/// anything. That is also why [isBuiltin] exists — shipped providers are
/// restored on launch and cannot be deleted, only disabled.
class LiveProvider {
  const LiveProvider({
    required this.id,
    required this.name,
    required this.kind,
    required this.source,
    this.username,
    this.password,
    this.iconUrl,
    this.version = '1.0.0',
    this.author,
    this.description,
    this.isBuiltin = false,
    this.isEnabled = true,
    this.updatedAt,
    this.lastFetchedAt,
  });

  final String id;
  final String name;
  final LiveProviderKind kind;

  /// Playlist URL (m3u/json) or panel base URL (xtream).
  final String source;

  final String? username;
  final String? password;
  final String? iconUrl;

  /// Compared against the catalogue to decide whether an update exists.
  final String version;

  final String? author;
  final String? description;

  /// Shipped with the app: cannot be removed.
  final bool isBuiltin;

  final bool isEnabled;

  final DateTime? updatedAt;
  final DateTime? lastFetchedAt;

  LiveProvider copyWith({
    String? name,
    LiveProviderKind? kind,
    String? source,
    String? username,
    String? password,
    String? iconUrl,
    String? version,
    String? author,
    String? description,
    bool? isEnabled,
    DateTime? updatedAt,
    DateTime? lastFetchedAt,
  }) {
    return LiveProvider(
      id: id,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      source: source ?? this.source,
      username: username ?? this.username,
      password: password ?? this.password,
      iconUrl: iconUrl ?? this.iconUrl,
      version: version ?? this.version,
      author: author ?? this.author,
      description: description ?? this.description,
      isBuiltin: isBuiltin,
      isEnabled: isEnabled ?? this.isEnabled,
      updatedAt: updatedAt ?? this.updatedAt,
      lastFetchedAt: lastFetchedAt ?? this.lastFetchedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'kind': kind.name,
    'source': source,
    if (username != null) 'username': username,
    if (password != null) 'password': password,
    if (iconUrl != null) 'iconUrl': iconUrl,
    'version': version,
    if (author != null) 'author': author,
    if (description != null) 'description': description,
    'isBuiltin': isBuiltin,
    'isEnabled': isEnabled,
    if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    if (lastFetchedAt != null)
      'lastFetchedAt': lastFetchedAt!.toIso8601String(),
  };

  static LiveProvider? fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    final name = json['name'] as String?;
    final source = json['source'] as String?;
    if (id == null || id.isEmpty || name == null || source == null) {
      return null;
    }
    final kindName = json['kind'] as String?;
    final kind = LiveProviderKind.values.firstWhere(
      (value) => value.name == kindName,
      orElse: () => LiveProviderKind.m3u,
    );
    return LiveProvider(
      id: id,
      name: name,
      kind: kind,
      source: source,
      username: json['username'] as String?,
      password: json['password'] as String?,
      iconUrl: json['iconUrl'] as String?,
      version: json['version'] as String? ?? '1.0.0',
      author: json['author'] as String?,
      description: json['description'] as String?,
      isBuiltin: json['isBuiltin'] == true,
      isEnabled: json['isEnabled'] != false,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
      lastFetchedAt: DateTime.tryParse(json['lastFetchedAt'] as String? ?? ''),
    );
  }
}

/// A provider published in a Live TV catalogue, used to offer installs and
/// updates the same way the extension marketplace does.
class LiveProviderCatalogEntry {
  const LiveProviderCatalogEntry({
    required this.id,
    required this.name,
    required this.kind,
    required this.source,
    required this.version,
    this.username,
    this.password,
    this.iconUrl,
    this.author,
    this.description,
  });

  final String id;
  final String name;
  final LiveProviderKind kind;
  final String source;
  final String version;
  final String? username;
  final String? password;
  final String? iconUrl;
  final String? author;
  final String? description;

  LiveProvider toProvider({bool isBuiltin = false}) => LiveProvider(
    id: id,
    name: name,
    kind: kind,
    source: source,
    username: username,
    password: password,
    iconUrl: iconUrl,
    version: version,
    author: author,
    description: description,
    isBuiltin: isBuiltin,
  );

  static LiveProviderCatalogEntry? fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    final name = json['name'] as String?;
    final source = json['source'] as String?;
    final version = json['version'] as String?;
    if (id == null || name == null || source == null || version == null) {
      return null;
    }
    final kindName = json['kind'] as String?;
    return LiveProviderCatalogEntry(
      id: id,
      name: name,
      kind: LiveProviderKind.values.firstWhere(
        (value) => value.name == kindName,
        orElse: () => LiveProviderKind.m3u,
      ),
      source: source,
      version: version,
      username: json['username'] as String?,
      password: json['password'] as String?,
      iconUrl: json['iconUrl'] as String?,
      author: json['author'] as String?,
      description: json['description'] as String?,
    );
  }
}
