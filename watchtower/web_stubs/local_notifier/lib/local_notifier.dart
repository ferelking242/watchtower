
class LocalNotificationAction {
  final String text;
  const LocalNotificationAction({required this.text});
}
class LocalNotification {
  final String? identifier;
  final String? title;
  final String? body;
  final List<LocalNotificationAction>? actions;
  LocalNotification({this.identifier, this.title, this.body, this.actions});
}
class _LocalNotifier {
  Future<void> setup(String appName, {String? shortcutPolicy}) async {}
  Future<void> notify(LocalNotification n) async {}
  Future<void> close(LocalNotification n) async {}
  void addListener(dynamic listener) {}
  void removeListener(dynamic listener) {}
}
final localNotifier = _LocalNotifier();
