class RPCAssets {
  final String? largeImage;
  final String? largeText;
  final String? smallImage;
  final String? smallText;
  const RPCAssets({this.largeImage, this.largeText, this.smallImage, this.smallText});
}

class RPCButton {
  final String label;
  final String url;
  const RPCButton({required this.label, required this.url});
}

class RPCTimestamps {
  final int? start;
  final int? end;
  const RPCTimestamps({this.start, this.end});
}

class RPCParty {
  final String? id;
  final int? size;
  final int? max;
  const RPCParty({this.id, this.size, this.max});
}

class RPCSecrets {
  final String? match;
  final String? join;
  final String? spectate;
  const RPCSecrets({this.match, this.join, this.spectate});
}

enum ActivityType { playing, streaming, listening, watching, competing }

class RPCActivity {
  final String? name;
  final String? state;
  final String? details;
  final RPCTimestamps? timestamps;
  final RPCAssets? assets;
  final RPCParty? party;
  final List<RPCButton>? buttons;
  final RPCSecrets? secrets;
  final ActivityType? activityType;
  const RPCActivity({
    this.name,
    this.state,
    this.details,
    this.timestamps,
    this.assets,
    this.party,
    this.buttons,
    this.secrets,
    this.activityType,
  });
}

class RpcActivity {
  final RPCAssets? assets;
  final List<RPCButton>? buttons;
  final String? state;
  final String? details;
  final int? startTimestamp;
  const RpcActivity({
    this.assets,
    this.buttons,
    this.state,
    this.details,
    this.startTimestamp,
  });
}

class _FlutterDiscordRPCInstance {
  bool isConnected = false;
  Stream<bool> get isConnectedStream => Stream.empty();
  Future<void> connect({
    required dynamic autoRetry,
    Duration? retryDelay,
  }) async {}
  Future<void> disconnect() async {}
  Future<void> dispose() async {}
  Future<void> setActivity({RPCActivity? activity}) async {}
}

class FlutterDiscordRPC {
  static final _FlutterDiscordRPCInstance instance = _FlutterDiscordRPCInstance();
  static Future<void> initialize(String applicationId) async {}
}
