// Web stub for receive_sharing_intent — platform intent sharing not available on Flutter Web.
import 'dart:async';

class SharedMediaFile {
  final String path;
  final String? thumbnail;
  final String? duration;
  final SharedMediaType type;
  SharedMediaFile(this.path, this.thumbnail, this.duration, this.type);
}

enum SharedMediaType { image, video, file, url, text }

class _ReceiveSharingIntentInstance {
  Stream<List<SharedMediaFile>> getMediaStream() => const Stream.empty();
  Future<List<SharedMediaFile>> getInitialMedia() async => [];
  void reset() {}
}

// ignore: non_constant_identifier_names
final ReceiveSharingIntent = _ReceiveSharingIntentInstance();
