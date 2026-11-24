import 'package:flutter_riverpod/flutter_riverpod.dart';

class SideDrawerOpenNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

/// Whether the Namida-style left drawer is open on the current page.
final sideDrawerOpenProvider =
    NotifierProvider<SideDrawerOpenNotifier, bool>(SideDrawerOpenNotifier.new);

class SideDrawerCloseNotifier extends Notifier<void Function()?> {
  @override
  void Function()? build() => null;

  void set(void Function()? value) => state = value;
}

/// Closes the active left drawer; registered by the page that owns it.
final sideDrawerCloseProvider =
    NotifierProvider<SideDrawerCloseNotifier, void Function()?>(
      SideDrawerCloseNotifier.new,
    );
