/// The app ships no Live TV provider.
///
/// Live TV is catalogue-driven: every provider is installed from the
/// Marketplace's Live tab (`index/live.json` in the extensions repository), so
/// nothing ships inside the app and a channel list can be corrected without a
/// release.
///
/// The provider this class used to ship (`wt-world`, an `assets/live/world.json`
/// catalogue) was removed for exactly that reason: it made the channel list a
/// build artifact. [retiredIds] keeps it out of installs that still have it
/// stored.
class LiveDefaults {
  /// Ids that used to ship with the app and must not survive an upgrade.
  ///
  /// Deleting the asset alone is not enough: an install that already stored the
  /// record would keep pointing at a missing asset and show "catalogue
  /// introuvable" forever.
  static const retiredIds = {'wt-world'};
}
