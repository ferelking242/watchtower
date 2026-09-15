import 'package:flutter/material.dart';

import 'deep_link_dispatcher.dart';
import 'deep_link_routes.dart';
import 'home_widget_deep_link.dart';

/// Widget intents use the buffered Android link bridge for cold and warm starts.
class HomeWidgetNavigationService {
  HomeWidgetNavigationService._();

  static late LinkSource Function() _source;
  static int _request = 0;
  static Future<Route<void>> Function(HomeWidgetTarget, LinkSource) _prepare =
      DeepLinkRoutes.prepareWidget;

  static void configure({
    required LinkSource Function() source,
    Future<Route<void>> Function(HomeWidgetTarget, LinkSource)? prepare,
  }) {
    _source = source;
    _prepare = prepare ?? DeepLinkRoutes.prepareWidget;
  }

  static Future<void> handle(Uri uri) async {
    final target = HomeWidgetDeepLink.parse(uri);
    if (target == null) return;
    final request = ++_request;
    // Queue immediately so a later tap supersedes even an in-flight fetch.
    final Future<Route<void>>? prepared =
        target is HomeWidgetHomeTarget ? null : _prepare(target, _source());
    DeepLinkDispatcher.submit(
      // The bridge reports each intent once; repeated taps are new requests.
      key: 'widget:$request:$uri',
      open: (navigator) async {
        final route = await prepared;
        if (request != _request || !navigator.mounted) return;
        if (route == null) {
          navigator.popUntil((route) => route.isFirst);
        } else {
          navigator.push(route);
        }
      },
    );
    // During startup this keeps the native splash up until the record is ready.
    await prepared;
  }
}
