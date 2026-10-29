/// Time-windowed "the user asked for this" signal.
///
/// Both the Dart-side network interceptor and the injected JavaScript hooks
/// need to know whether a media URL that just appeared was *requested* by the
/// user or merely fetched by the page on its own (preloading, autoplay on a
/// listing, scripted redirects). They agree by sharing one rule: a media URL
/// is only acted on while a real user gesture (tap/click/pointerdown) happened
/// within the last [window].
class UserIntentGate {
  UserIntentGate({this.window = const Duration(seconds: 15)});

  final Duration window;

  DateTime? _lastIntent;

  /// Records a user gesture. Call from tap/click/pointer handlers only —
  /// never from navigation or media callbacks, or the gate stops meaning
  /// anything.
  void markIntent([DateTime? at]) => _lastIntent = at ?? DateTime.now();

  /// True while a gesture occurred less than [window] ago.
  bool get hasIntent {
    final at = _lastIntent;
    return at != null && DateTime.now().difference(at) < window;
  }

  /// Clears the signal, e.g. when the browser session is torn down.
  void reset() => _lastIntent = null;
}
