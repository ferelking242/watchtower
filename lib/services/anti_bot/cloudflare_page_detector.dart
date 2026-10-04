/// Returns true while the current WebView document still looks like an
/// interactive Cloudflare challenge.
bool isCloudflareChallengeSnapshot(String snapshot) {
  final text = snapshot.toLowerCase();
  return text.contains('wt_cf_challenge=1') ||
      const [
        'just a moment',
        'checking your browser',
        'checking if the site connection is secure',
        'verify you are human',
        'verify that you are human',
        'performing security verification',
        'cf-challenge-running',
        'challenge-platform',
      ].any(text.contains);
}

/// A Cloudflare WAF/access-denied page is not a solvable browser challenge.
bool isCloudflareBlockedSnapshot(String snapshot) {
  final text = snapshot.toLowerCase();
  final identifiesCloudflare =
      text.contains('cloudflare') || text.contains('cf-ray');
  final explicitlyBlocked = const [
    'sorry, you have been blocked',
    'you have been blocked',
    'access denied',
    'error 1020',
  ].any(text.contains);
  return identifiesCloudflare && explicitlyBlocked;
}