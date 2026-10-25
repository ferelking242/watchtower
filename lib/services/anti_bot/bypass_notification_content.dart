/// User-facing text of the “source bloquée” notification.
///
/// The notification used to count *requests*, so a source that fires ten
/// parallel calls announced “10 sources bloquées” — meaningless. It now names
/// the extensions that are actually blocked, once each.
class BlockedSourceAlert {
  const BlockedSourceAlert({
    required this.name,
    required this.url,
    this.sourceId,
  });

  /// Extension (or host) name, already human-readable.
  final String name;

  /// URL that was refused; opened by the notification action.
  final String url;

  final int? sourceId;
}

class BypassNotificationContent {
  const BypassNotificationContent({
    required this.title,
    required this.body,
    required this.primary,
    required this.alerts,
  });

  final String title;
  final String body;

  /// Blocked source the action button opens.
  final BlockedSourceAlert primary;

  final List<BlockedSourceAlert> alerts;
}

/// Maximum number of names spelled out in the body.
const int kBypassNotificationMaxNames = 3;

BypassNotificationContent buildBypassNotificationContent(
  Iterable<BlockedSourceAlert> alerts,
) {
  final unique = <String, BlockedSourceAlert>{};
  for (final alert in alerts) {
    final key = '${alert.sourceId ?? ''}|${alert.name.toLowerCase()}';
    unique.putIfAbsent(key, () => alert);
  }
  final sources = unique.values.toList(growable: false);
  if (sources.isEmpty) {
    throw ArgumentError.value(alerts, 'alerts', 'At least one alert is needed');
  }
  final primary = sources.first;

  if (sources.length == 1) {
    return BypassNotificationContent(
      title: '🛡 ${primary.name} bloquée par Cloudflare',
      body:
          'L’extension est refusée, pas le site. Touche « Battre le challenge » '
          'pour ouvrir la source.',
      primary: primary,
      alerts: sources,
    );
  }

  final names = sources
      .take(kBypassNotificationMaxNames)
      .map((alert) => alert.name)
      .join(', ');
  final more = sources.length > kBypassNotificationMaxNames ? '…' : '';
  return BypassNotificationContent(
    title: '🛡 ${sources.length} extensions bloquées par Cloudflare',
    body:
        '$names$more — touche « Battre le challenge » pour ouvrir '
        '${primary.name}.',
    primary: primary,
    alerts: sources,
  );
}
