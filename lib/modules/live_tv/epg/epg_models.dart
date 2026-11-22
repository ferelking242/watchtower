/// One programme in a TV guide.
class EpgProgramme {
  const EpgProgramme({
    required this.channelId,
    required this.title,
    required this.start,
    required this.stop,
    this.description = '',
    this.category = '',
    this.episode,
  });

  /// Guide channel id this programme belongs to (`tvg-id` upstream).
  final String channelId;

  final String title;
  final DateTime start;
  final DateTime stop;
  final String description;
  final String category;

  /// Episode numbering, when the guide provides it.
  final String? episode;

  Duration get duration => stop.difference(start);

  bool isLiveAt(DateTime moment) =>
      !moment.isBefore(start) && moment.isBefore(stop);

  /// How far through the programme [moment] is, from 0 to 1.
  double progressAt(DateTime moment) {
    final total = stop.difference(start).inSeconds;
    if (total <= 0) return 1;
    final elapsed = moment.difference(start).inSeconds;
    if (elapsed <= 0) return 0;
    if (elapsed >= total) return 1;
    return elapsed / total;
  }

  Map<String, dynamic> toJson() => {
    'c': channelId,
    't': title,
    's': start.toUtc().millisecondsSinceEpoch,
    'e': stop.toUtc().millisecondsSinceEpoch,
    if (description.isNotEmpty) 'd': description,
    if (category.isNotEmpty) 'k': category,
    if (episode != null) 'n': episode,
  };

  static EpgProgramme? fromJson(Map<String, dynamic> json) {
    final channelId = json['c'] as String?;
    final title = json['t'] as String?;
    final start = json['s'];
    final stop = json['e'];
    if (channelId == null ||
        title == null ||
        title.isEmpty ||
        start is! int ||
        stop is! int) {
      return null;
    }
    return EpgProgramme(
      channelId: channelId,
      title: title,
      start: DateTime.fromMillisecondsSinceEpoch(start, isUtc: true).toLocal(),
      stop: DateTime.fromMillisecondsSinceEpoch(stop, isUtc: true).toLocal(),
      description: json['d'] as String? ?? '',
      category: json['k'] as String? ?? '',
      episode: json['n'] as String?,
    );
  }
}

/// A display name a guide channel is known by.
class EpgChannel {
  const EpgChannel({
    required this.id,
    required this.names,
    this.iconUrl,
    this.country,
  });

  final String id;

  /// Display names, the first being the canonical one.
  final List<String> names;

  final String? iconUrl;

  /// ISO country code when the guide declares one.
  final String? country;

  String get displayName => names.isEmpty ? id : names.first;
}

/// A parsed guide: its channels and their programmes, ordered by start time.
class EpgGuide {
  EpgGuide({
    required this.channels,
    required this.programmes,
    required this.source,
    required this.fetchedAt,
  });

  final Map<String, EpgChannel> channels;

  /// Programmes keyed by guide channel id, each list sorted by start.
  final Map<String, List<EpgProgramme>> programmes;

  /// Where the guide came from, for the settings screen.
  final String source;

  final DateTime fetchedAt;

  /// Programme on [channelId] at [moment], if the guide covers it.
  EpgProgramme? currentOn(String channelId, DateTime moment) {
    final list = programmes[channelId];
    if (list == null) return null;
    for (final programme in list) {
      if (programme.isLiveAt(moment)) return programme;
    }
    return null;
  }

  /// The programme after [moment] on [channelId].
  EpgProgramme? nextOn(String channelId, DateTime moment) {
    final list = programmes[channelId];
    if (list == null) return null;
    for (final programme in list) {
      if (programme.start.isAfter(moment)) return programme;
    }
    return null;
  }

  /// Programmes of [channelId] overlapping the [from]-[to] window.
  List<EpgProgramme> windowOn(String channelId, DateTime from, DateTime to) {
    final list = programmes[channelId];
    if (list == null) return const [];
    return [
      for (final programme in list)
        if (programme.stop.isAfter(from) && programme.start.isBefore(to))
          programme,
    ];
  }

  int get programmeCount {
    var total = 0;
    for (final list in programmes.values) {
      total += list.length;
    }
    return total;
  }

  Map<String, dynamic> toJson() => {
    'source': source,
    'fetchedAt': fetchedAt.toUtc().millisecondsSinceEpoch,
    'channels': [
      for (final channel in channels.values)
        {
          'id': channel.id,
          'names': channel.names,
          if (channel.iconUrl != null) 'icon': channel.iconUrl,
          if (channel.country != null) 'country': channel.country,
        },
    ],
    'programmes': [
      for (final list in programmes.values)
        for (final programme in list) programme.toJson(),
    ],
  };

  static EpgGuide? fromJson(Map<String, dynamic> json) {
    final source = json['source'] as String?;
    final fetchedAt = json['fetchedAt'];
    if (source == null || fetchedAt is! int) return null;

    final channels = <String, EpgChannel>{};
    for (final raw in (json['channels'] as List? ?? const [])) {
      if (raw is! Map) continue;
      final id = raw['id'] as String?;
      if (id == null || id.isEmpty) continue;
      final names = [
        for (final name in (raw['names'] as List? ?? const []))
          if (name is String && name.isNotEmpty) name,
      ];
      channels[id] = EpgChannel(
        id: id,
        names: names.isEmpty ? [id] : names,
        iconUrl: raw['icon'] as String?,
        country: raw['country'] as String?,
      );
    }

    final programmes = <String, List<EpgProgramme>>{};
    for (final raw in (json['programmes'] as List? ?? const [])) {
      if (raw is! Map) continue;
      final programme = EpgProgramme.fromJson(Map<String, dynamic>.from(raw));
      if (programme == null) continue;
      programmes.putIfAbsent(programme.channelId, () => []).add(programme);
    }
    for (final list in programmes.values) {
      list.sort((a, b) => a.start.compareTo(b.start));
    }

    return EpgGuide(
      channels: channels,
      programmes: programmes,
      source: source,
      fetchedAt: DateTime.fromMillisecondsSinceEpoch(
        fetchedAt,
        isUtc: true,
      ).toLocal(),
    );
  }
}
