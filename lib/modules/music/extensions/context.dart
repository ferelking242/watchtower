import 'package:auto_route/auto_route.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:watchtower/modules/music/l10n/l10n.dart';

extension AppLocale on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}

/// Compat shims for auto_route 9.x (context.navigateTo / context.watchRouter
/// were removed; they now live on context.router).
extension AutoRouteCompat on BuildContext {
  /// Navigate to [route] using the nearest auto_route router.
  Future<T?> navigateTo<T extends Object?>(PageRouteInfo route) =>
      router.navigate(route);

  /// Watch the router (causes a rebuild on navigation; same as context.router
  /// in auto_route 9.x since the AutoRouter widget already rebuilds on
  /// stack changes).
  StackRouter get watchRouter => router;
}
