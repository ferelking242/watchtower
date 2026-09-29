enum ReleaseChannel { stable, beta, nightly }

abstract class Env {
  static bool get hideDonations => false;
  static ReleaseChannel get releaseChannel => ReleaseChannel.stable;
  static bool get enableUpdateChecker => true;
  static String get lastFmApiKey => '';
  static String get lastFmApiSecret => '';
}
