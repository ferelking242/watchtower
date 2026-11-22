import 'package:watchtower/modules/live_tv/models/live_provider.dart';

/// The one provider the app ships with.
///
/// This is a *record*, not a channel list: it names a JSON catalogue bundled in
/// the assets, so Live TV has something to show on a first launch that has no
/// network. Every other provider comes from the extension catalogue
/// (`index/live.json`), which is where providers are actually published — see
/// [LiveExtensionCatalog].
///
/// Keeping this one bundled provider is what makes the app usable offline. It
/// holds no URLs of its own, so adding or removing channels is a matter of
/// regenerating the asset, never of editing Dart.
class LiveDefaults {
  static const bundledId = 'wt-world';

  /// Asset holding the pre-verified world catalogue.
  static const bundledAsset = 'assets/live/world.json';

  static LiveProvider get bundled => const LiveProvider(
    id: bundledId,
    name: 'Watchtower World',
    kind: LiveProviderKind.bundled,
    source: bundledAsset,
    version: '2.0.0',
    author: 'Watchtower',
    description:
        'Catalogue embarqué de chaînes vérifiées, disponible hors ligne. '
        'Aucun compte requis.',
    isBundled: true,
    isBuiltin: true,
  );

  /// Providers a fresh install starts with.
  static List<LiveProvider> get installed => [bundled];
}
