import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

/// Global keyboard shortcuts for the desktop and web builds.
///
/// A mouse-and-keyboard user expects the shell to answer to the same muscle
/// memory as a browser: the number keys jump between the main sections, the
/// arrows step through history, `Ctrl/Cmd+K` opens search and `Ctrl/Cmd+,`
/// opens the settings. This wraps the whole app so the shortcuts work no matter
/// which page is focused, and it is a no-op on mobile (no hardware keyboard)
/// and inside text fields (where the keys must type).
class DesktopShortcuts extends StatelessWidget {
  const DesktopShortcuts({super.key, required this.router, required this.child});

  /// The app router. Passed explicitly because this widget sits above the
  /// [Navigator] (inside `MaterialApp.builder`), where `GoRouter.maybeOf` cannot
  /// see the `InheritedGoRouter` that the navigator installs below itself.
  final GoRouter router;
  final Widget child;

  /// Whether the platform is one where hardware-keyboard shortcuts make sense.
  static bool get isEnabled =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.windows;

  /// Section routes reachable through the number keys, in order.
  static const List<String> sectionRoutes = [
    '/WatchtowerHome',
    '/AnimeLibrary',
    '/MangaLibrary',
    '/NovelLibrary',
    '/MusicLibrary',
    '/GameLibrary',
    '/MoviesLibrary',
    '/SeriesLibrary',
    '/Library',
  ];

  static const _numberKeys = <LogicalKeyboardKey>[
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3,
    LogicalKeyboardKey.digit4,
    LogicalKeyboardKey.digit5,
    LogicalKeyboardKey.digit6,
    LogicalKeyboardKey.digit7,
    LogicalKeyboardKey.digit8,
    LogicalKeyboardKey.digit9,
  ];

  /// True when the primary focus is a text field, in which case the shortcut
  /// keys must be left alone so the user can type.
  static bool _inTextField() {
    final focus = FocusManager.instance.primaryFocus;
    final widget = focus?.context?.widget;
    return widget is EditableText;
  }

  /// Full-screen surfaces that own the keyboard: a reader or a video player
  /// has its own key handling (page turns, seek, volume), so a stray number
  /// key must never navigate away from them.
  static const _immersivePrefixes = [
    '/manga-reader',
    '/novel-reader',
    '/animePlayerView',
  ];

  void _go(int index) {
    if (index < 0 || index >= sectionRoutes.length) return;
    final location = router.state.uri.path;
    if (_immersivePrefixes.any(location.startsWith)) return;
    router.go(sectionRoutes[index]);
  }

  @override
  Widget build(BuildContext context) {
    if (!isEnabled) return child;

    final isMac = !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        SingleActivator(
          LogicalKeyboardKey.keyK,
          control: !isMac,
          meta: isMac,
        ): const _OpenSearchIntent(),
        // Ctrl/Cmd+, → settings, the platform convention for preferences.
        SingleActivator(
          LogicalKeyboardKey.comma,
          control: !isMac,
          meta: isMac,
        ): const _OpenSettingsIntent(),
        // Alt+Left / Alt+Right → back / forward, like a browser.
        const SingleActivator(
          LogicalKeyboardKey.arrowLeft,
          alt: true,
        ): _BackIntent(),
        const SingleActivator(
          LogicalKeyboardKey.arrowRight,
          alt: true,
        ): _ForwardIntent(),
        for (var i = 0; i < _numberKeys.length; i++)
          SingleActivator(_numberKeys[i]): _GoSectionIntent(i),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _OpenSearchIntent: CallbackAction<_OpenSearchIntent>(
            onInvoke: (_) {
              if (_inTextField()) return null;
              router.go('/globalSearch');
              return null;
            },
          ),
          _OpenSettingsIntent: CallbackAction<_OpenSettingsIntent>(
            onInvoke: (_) {
              if (_inTextField()) return null;
              router.go('/settings');
              return null;
            },
          ),
          _BackIntent: CallbackAction<_BackIntent>(
            onInvoke: (_) {
              if (_inTextField()) return null;
              if (router.canPop()) router.pop();
              return null;
            },
          ),
          _ForwardIntent: CallbackAction<_ForwardIntent>(
            onInvoke: (_) {
              if (_inTextField()) return null;
              if (router.canPop()) router.pop();
              return null;
            },
          ),
          _GoSectionIntent: CallbackAction<_GoSectionIntent>(
            onInvoke: (intent) {
              if (_inTextField()) return null;
              _go(intent.index);
              return null;
            },
          ),
        },
        // autofocus gives the scope an initial focus so the shortcuts fire
        // before the user has clicked anything.
        child: Focus(autofocus: true, child: child),
      ),
    );
  }
}

class _OpenSearchIntent extends Intent {
  const _OpenSearchIntent();
}

class _OpenSettingsIntent extends Intent {
  const _OpenSettingsIntent();
}

class _BackIntent extends Intent {
  const _BackIntent();
}

class _ForwardIntent extends Intent {
  const _ForwardIntent();
}

class _GoSectionIntent extends Intent {
  const _GoSectionIntent(this.index);
  final int index;
}
