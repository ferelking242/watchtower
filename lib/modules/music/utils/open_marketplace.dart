import 'package:flutter/material.dart';
import 'package:watchtower/modules/browse/marketplace_screen.dart';

/// Opens the Watchtower Extension Marketplace on the ROOT navigator.
///
/// The music module runs inside its own nested auto_route Router, so
/// context.pushRoute(...) can only reach music-internal pages. App-level
/// destinations (e.g. the Marketplace, which owns all extension/plugin
/// management since the dedicated plugin page was removed) must be pushed on
/// the root navigator instead.
Future<void> openMarketplace(BuildContext context) {
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(builder: (_) => const MarketplaceScreen()),
  );
}
