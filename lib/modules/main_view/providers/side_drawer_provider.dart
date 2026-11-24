import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

/// Whether the Namida-style left drawer is open on the current page.
final sideDrawerOpenProvider = StateProvider<bool>((ref) => false);

/// Closes the active left drawer; registered by the page that owns it.
final sideDrawerCloseProvider = StateProvider<void Function()?>((ref) => null);
