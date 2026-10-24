import 'package:media_kit/media_kit.dart';

Future<Duration?> probeActualVideoDuration(String path) async {
  Player? probe;
  try {
    probe = Player();
    await probe
        .open(Media(path), play: false)
        .timeout(const Duration(seconds: 8));
    final current = probe.state.duration;
    if (current > Duration.zero) return current;
    return await probe.stream.duration
        .firstWhere((duration) => duration > Duration.zero)
        .timeout(const Duration(seconds: 8));
  } catch (_) {
    return null;
  } finally {
    await probe?.dispose();
  }
}
