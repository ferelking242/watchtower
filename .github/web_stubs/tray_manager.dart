import 'dart:ui' show Rect;

/// Web stub for `tray_manager` 0.5.x. Mirrors the real `menu_base` +
/// `TrayManager` surface so the desktop-only tray code in the music module
/// still compiles for dart2js. Nothing here is ever shown on web.
class MenuItem {
  int id = -1;
  String? key;
  String type;
  String? label;
  String? sublabel;
  String? toolTip;
  String? icon;
  bool? checked;
  bool disabled;
  Menu? submenu;

  void Function(MenuItem menuItem)? onClick;
  void Function(MenuItem menuItem)? onHighlight;
  void Function(MenuItem menuItem)? onLoseHighlight;

  MenuItem.separator()
      : type = 'separator',
        disabled = true;

  MenuItem.submenu({
    this.key,
    this.label,
    this.sublabel,
    this.toolTip,
    this.icon,
    this.disabled = false,
    this.submenu,
    this.onClick,
    this.onHighlight,
    this.onLoseHighlight,
  }) : type = 'submenu';

  MenuItem.checkbox({
    this.key,
    this.label,
    this.sublabel,
    this.toolTip,
    this.icon,
    required this.checked,
    this.disabled = false,
    this.onClick,
    this.onHighlight,
    this.onLoseHighlight,
  }) : type = 'checkbox';

  MenuItem({
    this.key,
    this.type = 'normal',
    this.label,
    this.sublabel,
    this.toolTip,
    this.icon,
    this.checked,
    this.disabled = false,
    this.submenu,
    this.onClick,
    this.onHighlight,
    this.onLoseHighlight,
  });
}

class Menu {
  List<MenuItem>? items;
  Menu({this.items});

  MenuItem? getMenuItem(String key) {
    for (final menuItem in (items ?? const <MenuItem>[])) {
      if (menuItem.key == key) return menuItem;
      if (menuItem.submenu?.getMenuItem(key) != null) {
        return menuItem.submenu?.getMenuItem(key);
      }
    }
    return null;
  }

  MenuItem? getMenuItemById(int id) {
    for (final menuItem in (items ?? const <MenuItem>[])) {
      if (menuItem.id == id) return menuItem;
      if (menuItem.submenu?.getMenuItemById(id) != null) {
        return menuItem.submenu?.getMenuItemById(id);
      }
    }
    return null;
  }
}

class TrayIconPosition {
  final String name;
  const TrayIconPosition._(this.name);
  static const TrayIconPosition left = TrayIconPosition._('left');
  static const TrayIconPosition right = TrayIconPosition._('right');
}

class TrayManager {
  Future<void> destroy() async {}
  Future<void> setIcon(
    String iconPath, {
    bool isTemplate = false,
    TrayIconPosition iconPosition = TrayIconPosition.left,
    int iconSize = 18,
  }) async {}
  Future<void> setIconPosition(TrayIconPosition trayIconPosition) async {}
  Future<void> setToolTip(String toolTip) async {}
  Future<void> setTitle(String title) async {}
  Future<void> setContextMenu(Menu menu) async {}
  Future<void> popUpContextMenu({bool bringAppToFront = false}) async {}
  Future<Rect?> getBounds() async => null;
  void addListener(dynamic listener) {}
  void removeListener(dynamic listener) {}
}

final trayManager = TrayManager();

mixin TrayListener {
  void onTrayIconMouseDown() {}
  void onTrayIconMouseUp() {}
  void onTrayIconRightMouseDown() {}
  void onTrayIconRightMouseUp() {}
  void onTrayMenuItemClick(MenuItem menuItem) {}
}
