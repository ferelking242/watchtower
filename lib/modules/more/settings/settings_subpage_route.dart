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
  'manageTrackers',
  'trackingDetail',
  'logViewer',
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
