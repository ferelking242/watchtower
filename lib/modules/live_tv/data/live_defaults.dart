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

  /// Provider ids that were renamed in the published index.
  ///
  /// The catalogue entries for these five used to carry a `wiflix-` prefix that
  /// said nothing about where the streams come from. Renaming them in the index
  /// alone would orphan every install: the stored record keeps the old id, so
  /// the Marketplace offers the entry as "not installed" and the user ends up
  /// with the old provider plus a duplicate of the new one.
  static const renamedIds = {
    'wiflix-iptv-org': 'iptv-org',
    'wiflix-iptv-org-categories': 'iptv-org-categories',
    'wiflix-free-tv': 'free-tv',
    'wiflix-br-extra': 'br-extra',
    'wiflix-direct-feeds': 'direct-feeds',
  };
}
