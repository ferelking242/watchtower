
class MenuItem {
  final String key;
  final String? label;
  final bool? disabled;
  final bool? checked;
  final List<MenuItem>? submenu;
  const MenuItem({required this.key, this.label, this.disabled, this.checked, this.submenu});
  factory MenuItem.separator() => const MenuItem(key: '__sep__');
}
class Menu {
  final List<MenuItem> items;
  const Menu({required this.items});
}
class TrayManager {
  Future<void> setIcon(String path, {bool isTemplate = false}) async {}
  Future<void> setToolTip(String tip) async {}
  Future<void> setContextMenu(Menu menu) async {}
  Future<void> destroy() async {}
  void addListener(dynamic l) {}
  void removeListener(dynamic l) {}
}
final trayManager = TrayManager();
mixin TrayListener {}
