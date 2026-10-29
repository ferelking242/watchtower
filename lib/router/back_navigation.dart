import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Ordered list of the top-level locations the user visited.
///
/// A `go()` navigation appends to the list; returning to the entry just below
/// the current one is recognised as a pop and removes it. Keeping the two cases
/// apart is what stops back from ping-ponging between two pages.
class BackHistory {
  BackHistory({this.maxEntries = 32});

  /// Upper bound so a long session cannot grow the list without end.
  final int maxEntries;

  final List<String> _entries = [];

  List<String> get entries => List.unmodifiable(_entries);

  String? get current => _entries.isEmpty ? null : _entries.last;

  /// Records that the router moved to [location].
  void record(String location) {
    if (_entries.isNotEmpty && _entries.last == location) return;
    // A→B→A: the user came back, so drop B instead of stacking another A.
    if (_entries.length >= 2 && _entries[_entries.length - 2] == location) {
      _entries.removeLast();
      return;
    }
    _entries.add(location);
    if (_entries.length > maxEntries) _entries.removeAt(0);
  }

  /// The location to open on a back press, or `null` to leave the app.
  ///
  /// [defaultLocation] is the tab the app starts on: returning to it from the
  /// start screen is what "exit" means, so back is left to the platform there.
  String? backTarget(String? location, String defaultLocation) {
    final here = location ?? current;
    if (here == null) return null;
    if (here == defaultLocation) return null;
    if (_entries.length >= 2) {
      final previous = _entries[_entries.length - 2];
      if (previous != here && previous != defaultLocation) return previous;
    }
    return defaultLocation;
  }
}

/// Back button dispatcher that gives top-level pages a back destination.
///
/// It first defers to the router (which pops a pushed page or closes a dialog).
/// Only when the router has nothing to pop does it fall back to the previously
/// visited tab, or to the default tab, instead of letting the platform close
/// the app.
class WatchtowerBackDispatcher extends RootBackButtonDispatcher {
  WatchtowerBackDispatcher({
    required GoRouter Function() router,
    required String Function() defaultLocation,
  }) : _router = router,
       _defaultLocation = defaultLocation {
    ensureAttached();
  }

  final GoRouter Function() _router;
  final String Function() _defaultLocation;

  @visibleForTesting
  final BackHistory history = BackHistory();

  GoRouter? _attachedRouter;

  /// Starts (or restarts) listening to the router delegate. The router is
  /// recreated whenever the navigation order changes, so this re-attaches to
  /// the current instance and keeps the history accurate.
  void ensureAttached() {
    final GoRouter router;
    try {
      router = _router();
    } catch (_) {
      return;
    }
    if (identical(_attachedRouter, router)) return;
    _attachedRouter?.routerDelegate.removeListener(_onRouteChanged);
    _attachedRouter = router;
    final now = _currentLocation();
    if (now != null) history.record(now);
    router.routerDelegate.addListener(_onRouteChanged);
  }

  String? _currentLocation() {
    try {
      final matches = _router().routerDelegate.currentConfiguration;
      if (matches.isEmpty) return null;
      final lastMatch = matches.last;
      final matchList = lastMatch is ImperativeRouteMatch
          ? lastMatch.matches
          : matches;
      return matchList.uri.toString();
    } catch (_) {
      return null;
    }
  }

  void _onRouteChanged() {
    final now = _currentLocation();
    if (now != null) history.record(now);
  }

  @override
  Future<bool> didPopRoute() async {
    // Let the router pop a pushed page or close a dialog first.
    if (await super.didPopRoute()) return true;

    ensureAttached();
    final location = _currentLocation() ?? history.current;
    // Onboarding is a one-way gate: back there should leave the app.
    if (location == '/onboarding') return false;

    final target = history.backTarget(location, _defaultLocation());
    if (target == null) return false;

    _router().go(target);
    return true;
  }

  /// Stops listening to the router delegate. The dispatcher lives as long as
  /// the app, so this is only needed by tests that build several dispatchers.
  void detach() {
    _attachedRouter?.routerDelegate.removeListener(_onRouteChanged);
    _attachedRouter = null;
  }
}
