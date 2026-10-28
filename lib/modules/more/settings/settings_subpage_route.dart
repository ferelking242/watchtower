import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

/// Bare Browser's settings page transition.
///
/// A page comes in from the right while the one behind moves left a little and
/// fades, in 280 ms, and back reverses it. Ported from Bare Browser's
/// `bare_settings_{open,close}_{enter,exit}.xml` animators and the
/// `MainSettings.switchBareCategory()` code that drives them.
const Duration bareSettingsDuration = Duration(milliseconds: 280);

/// `PathInterpolator(0.2, 0.8, 0.2, 1)` — decelerate. Bare uses it for both the
/// open and the close animators, so the reverse uses it too.
const Curve bareSettingsCurve = Cubic(0.2, 0.8, 0.2, 1.0);

/// How far the page behind moves left, as a fraction of the width.
const double bareSettingsBehindShift = 0.24;

/// How much the page behind fades while a page covers it.
const double bareSettingsBehindAlpha = 0.7;

/// The settings routes that use the Bare transition: the settings homepage and
/// every page reachable from it, so the list shifts and dims under each subpage
/// and returns when it closes.
const Set<String> bareSettingsRoutes = {
  'settings',
  'general',
  'appearance',
  'readerMode',
  'playerOverview',
  'downloads',
  'track',
  'sync',
  'browseS',
  'security',
  'localSources',
  'advanced',
  'about',
  'remoteMode',
  'remoteSetup',
  'extension-cookies',
  'recommendations',
  'uiSettings',
  'customNavigationSettings',
  'playerMode',
  'playerDecoderScreen',
  'playerAudioScreen',
  'customButtonScreen',
  'playerAdvancedScreen',
  'playerGestureScreen',
  'playerSubtitleScreen',
  'playerScriptEditor',
  'playerTorrentScreen',
  'manageTrackers',
  'trackingDetail',
  'logViewer',
  'appLanguage',
  'librarySettings',
  'categories',
};

/// Slides [child] in from the right, and moves it left a little and fades it
/// when another page covers it.
///
/// `animation` drives the page's own move: 0 -> 1 on the way in, so it comes
/// from the right, and 1 -> 0 on the way out, so it leaves the same way.
/// `secondaryAnimation` drives what happens while a page sits on top: it moves
/// left by [bareSettingsBehindShift] and dims to [bareSettingsBehindAlpha], and
/// returns when that page leaves.
Widget bareSettingsTransitions(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  final enter = CurvedAnimation(parent: animation, curve: bareSettingsCurve);
  final behind = CurvedAnimation(
    parent: secondaryAnimation,
    curve: bareSettingsCurve,
  );

  return SlideTransition(
    position: Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(enter),
    child: SlideTransition(
      position: Tween<Offset>(
        begin: Offset.zero,
        end: const Offset(-bareSettingsBehindShift, 0),
      ).animate(behind),
      child: FadeTransition(
        opacity: Tween<double>(
          begin: 1,
          end: bareSettingsBehindAlpha,
        ).animate(behind),
        child: child,
      ),
    ),
  );
}

/// Bare Browser's settings search bar: it belongs to the page that is on top.
///
/// While another page slides in over this one, the bar leaves at the start of
/// the slide — it rises away and fades — instead of travelling along with the
/// page and fading out at the end.
///
/// Ported from `SettingsSearchCoordinator.updateSingleColumnSearchBoxVisibility()`
/// in patch 0000196, which hides the box on `SlideState.OPENING`/`OPENED`
/// ("the box goes at the start of the slide rather than at the end, so the page
/// is not moved up when the box leaves"), and from patch 0000185, which sets the
/// box's alpha to 0 the moment the slide starts so it never flashes at the top
/// of the subpage.
///
/// The bar keeps its layout space on purpose: Bare takes the box out of the
/// layout before the slide is visible so the page never jumps, and the page
/// behind is hidden by the incoming one anyway.
class BareSearchBarTransition extends StatelessWidget {
  const BareSearchBarTransition({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final secondary = ModalRoute.of(context)?.secondaryAnimation;
    if (secondary == null) return child;

    // Gone within the first third of the slide: the bar has left the screen
    // while the incoming page is still moving, so nothing flashes above it.
    final gone = CurvedAnimation(
      parent: secondary,
      curve: const Interval(0, 0.34, curve: Curves.easeOut),
    );

    return FadeTransition(
      opacity: Tween<double>(begin: 1, end: 0).animate(gone),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset.zero,
          end: const Offset(0, -0.5),
        ).animate(gone),
        child: child,
      ),
    );
  }
}

/// The Bare transition as a GoRouter page, for the routes in
/// [bareSettingsRoutes].
CustomTransitionPage<void> bareSettingsPage({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: key,
    transitionDuration: bareSettingsDuration,
    reverseTransitionDuration: bareSettingsDuration,
    child: child,
    transitionsBuilder: bareSettingsTransitions,
  );
}

/// Use platform-native settings navigation so reverse transitions and system
/// back gestures remain available on supported platforms. Elsewhere, use the
/// Bare slide.
Route<T> settingsSubpageRoute<T>(Widget page) {
  if (!kIsWeb && (Platform.isIOS || Platform.isMacOS)) {
    return CupertinoPageRoute<T>(builder: (_) => page);
  }
  return PageRouteBuilder<T>(
    transitionDuration: bareSettingsDuration,
    reverseTransitionDuration: bareSettingsDuration,
    pageBuilder: (_, _, _) => page,
    transitionsBuilder: bareSettingsTransitions,
  );
}
