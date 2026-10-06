/// Evidence-based anti-bot classification shared by the HTTP layer, the
/// bypass WebView and the UI.
///
/// Rule #1: an HTTP 403/503 (or a timeout, or a connection error) is **not**
/// Cloudflare by itself. Cloudflare is only reported when the response or the
/// page carries actual evidence:
///
///  * Cloudflare CDN markers (`cf-ray`, `cf-mitigated`,
///    `server: cloudflare`, `challenge-platform`, `cf-chl`…), and/or
///  * Cloudflare-specific challenge markup/text, a Cloudflare response header
///    paired with challenge text, or a Cloudflare challenge DOM element; and/or
///  * a Cloudflare block page (`Attention Required`, `You have been blocked`…).
///
/// A page that loads normally is classified [AntiBotPageType.normal] and must
/// never be presented as a challenge that was “resolved”.
library;

import 'dart:convert';

/// What the inspected page/response actually is.
enum AntiBotPageType {
  /// Interactive challenge present (user action required).
  challenge,

  /// Block page without interactive challenge (WAF / “You have been blocked”).
  blocked,

  /// Page loaded normally, no anti-bot marker found.
  normal,

  /// Not enough information (empty body, probe failure, plain API 403…).
  unknown,
}

/// Result of an anti-bot inspection. [evidence] never contains secrets: only
/// marker names / header names useful for diagnostics.
class AntiBotAssessment {
  final AntiBotPageType pageType;
  final bool cloudflareInvolved;
  final bool isHttpError;
  final List<String> evidence;

  const AntiBotAssessment({
    this.pageType = AntiBotPageType.unknown,
    this.cloudflareInvolved = false,
    this.isHttpError = false,
    this.evidence = const [],
  });

  bool get challenge => pageType == AntiBotPageType.challenge;
  bool get blocked => pageType == AntiBotPageType.blocked;
  bool get normal => pageType == AntiBotPageType.normal;

  @override
  String toString() =>
      'AntiBotAssessment(pageType: ${pageType.name}, '
      'cloudflare: $cloudflareInvolved, httpError: $isHttpError, '
      'evidence: ${evidence.join('|')})';
}

/// Interactive challenge markers. Deliberately specific: the bare word
/// “challenge” is NOT part of this list (OAuth `code_challenge`, captchas,
/// game challenges… must not trigger a Cloudflare UI).
const List<String> kChallengeMarkers = [
  'just a moment',
  'checking your browser',
  'checking if the site connection is secure',
  'verify you are human',
  'verify that you are human',
  'performing security verification',
  'challenge-platform',
  'cf-challenge-running',
  'cf-chl',
  'cf_chl',
  'turnstile',
  'enable javascript and cookies to continue',
  'challenge required',
];

/// Block-page markers (no interactive challenge).
const List<String> kBlockMarkers = [
  'attention required',
  'sorry, you have been blocked',
  'you have been blocked',
  'error 1020',
  'error code: 1020',
  'request blocked',
  'access denied',
  'cf-error-details',
];

/// Markers that are Cloudflare-specific even without CDN headers.
const List<String> _kCloudflareOnlyMarkers = [
  'attention required',
  'sorry, you have been blocked',
  'you have been blocked',
  'error 1020',
  'cf-error-details',
  'challenge-platform',
  'cf-chl',
  'cf_chl',
  'just a moment',
  'checking your browser',
  'cf-challenge-running',
];

/// Challenge-page markers that are specific enough to identify Cloudflare
/// without relying on a generic CAPTCHA message.
const List<String> _kCloudflareChallengeMarkers = [
  'challenge-platform',
  'cf-challenge-running',
  'cf-chl',
  'cf_chl',
];

List<String> _foundMarkers(String haystack, List<String> markers) =>
    [for (final marker in markers) if (haystack.contains(marker)) marker];

Map<String, String> _normalizedHeaders(Map<String, String>? headers) {
  final normalized = <String, String>{};
  headers?.forEach((key, value) {
    normalized[key.toLowerCase()] = value.toLowerCase();
  });
  return normalized;
}

bool _isCodeOrJsonContentType(String contentType) {
  final mimeType = contentType.split(';').first.trim();
  return mimeType.contains('javascript') ||
      mimeType.contains('ecmascript') ||
      mimeType == 'application/json' ||
      mimeType == 'text/json' ||
      mimeType.endsWith('+json');
}

/// Inspects an HTTP response (status + headers + optional body).
///
/// `403` / `503` alone → pageType [AntiBotPageType.unknown], so the caller
/// keeps the normal “HTTP error” path instead of a Cloudflare UI. Challenge
/// body markers are ignored for JavaScript and JSON payloads, where they may
/// appear as source/data rather than as a page shown to the user.
AntiBotAssessment assessHttpResponse({
  required int statusCode,
  Map<String, String>? headers,
  String? body,
}) {
  final h = _normalizedHeaders(headers);
  final evidence = <String>[];

  final server = h['server'] ?? '';
  final cfRay = h['cf-ray'] ?? '';
  final cfMitigated = h['cf-mitigated'] ?? '';
  final contentType = h['content-type'] ?? '';

  var cloudflareInvolved = false;
  if (cfRay.isNotEmpty) {
    cloudflareInvolved = true;
    evidence.add('header:cf-ray');
  }
  if (server.contains('cloudflare')) {
    cloudflareInvolved = true;
    evidence.add('header:server=cloudflare');
  }
  if (cfMitigated.isNotEmpty) {
    cloudflareInvolved = true;
    evidence.add('header:cf-mitigated=${cfMitigated.split(',').first.trim()}');
  }

  final haystack = _isCodeOrJsonContentType(contentType)
      ? ''
      : (body ?? '').toLowerCase();
  final challengeMarkers = _foundMarkers(haystack, kChallengeMarkers);
  final blockMarkers = _foundMarkers(haystack, kBlockMarkers);

  final cfOnlyHit = _foundMarkers(haystack, _kCloudflareOnlyMarkers).isNotEmpty;
  if (cfOnlyHit) cloudflareInvolved = true;

  final challengeRequested = cfMitigated.contains('challenge');
  final hasCloudflareResponseHeader =
      server.contains('cloudflare') ||
      cfRay.isNotEmpty ||
      cfMitigated.isNotEmpty;
  final hasCloudflareChallengeMarker =
      _foundMarkers(haystack, _kCloudflareChallengeMarkers).isNotEmpty;
  final blockRequested = cfMitigated.contains('block');
  if (challengeRequested ||
      hasCloudflareChallengeMarker ||
      (!blockRequested &&
          challengeMarkers.isNotEmpty &&
          hasCloudflareResponseHeader &&
          blockMarkers.isEmpty)) {
    if (challengeRequested) evidence.add('header:cf-mitigated=challenge');
    evidence.addAll(challengeMarkers.map((m) => 'body:$m'));
    return AntiBotAssessment(
      pageType: AntiBotPageType.challenge,
      cloudflareInvolved: true,
      isHttpError: statusCode >= 400,
      evidence: evidence,
    );
  }

  if (blockMarkers.isNotEmpty &&
      (cloudflareInvolved || blockRequested) &&
      (statusCode >= 400 || blockRequested || contentType.contains('html'))) {
    evidence.addAll(blockMarkers.map((m) => 'body:$m'));
    return AntiBotAssessment(
      pageType: AntiBotPageType.blocked,
      cloudflareInvolved: cloudflareInvolved,
      isHttpError: statusCode >= 400,
      evidence: evidence,
    );
  }

  return AntiBotAssessment(
    // A plain 4xx/5xx stays a plain HTTP error: no anti-bot claim.
    pageType: statusCode >= 400
        ? AntiBotPageType.unknown
        : AntiBotPageType.normal,
    cloudflareInvolved: cloudflareInvolved,
    isHttpError: statusCode >= 400,
    evidence: evidence,
  );
}

/// Inspects a page already rendered in a WebView (title + visible text).
AntiBotAssessment assessPageContent({
  String? title,
  String? text,
  bool cloudflareChallengeDom = false,
}) {
  final haystack = '${title ?? ''}\n${text ?? ''}'.toLowerCase();
  final hasContent = (title?.trim().isNotEmpty ?? false) ||
      (text?.trim().isNotEmpty ?? false);

  final challengeMarkers = _foundMarkers(haystack, kChallengeMarkers);
  final cloudflareChallengeMarkers =
      _foundMarkers(haystack, _kCloudflareChallengeMarkers);
  final blockMarkers = _foundMarkers(haystack, kBlockMarkers);
  if (cloudflareChallengeDom ||
      (challengeMarkers.isNotEmpty &&
          (cloudflareChallengeMarkers.isNotEmpty ||
              (haystack.contains('cloudflare') && blockMarkers.isEmpty)))) {
    return AntiBotAssessment(
      pageType: AntiBotPageType.challenge,
      cloudflareInvolved: true,
      evidence: [
        if (cloudflareChallengeDom) 'dom:cloudflare-challenge',
        for (final m in challengeMarkers) 'page:$m',
      ],
    );
  }

  final cfOnlyHit = _foundMarkers(haystack, _kCloudflareOnlyMarkers).isNotEmpty;
  final mentionsCloudflare = haystack.contains('cloudflare');
  if (blockMarkers.isNotEmpty && (cfOnlyHit || mentionsCloudflare)) {
    return AntiBotAssessment(
      pageType: AntiBotPageType.blocked,
      cloudflareInvolved: true,
      evidence: [for (final m in blockMarkers) 'page:$m'],
    );
  }

  return AntiBotAssessment(
    pageType: hasContent ? AntiBotPageType.normal : AntiBotPageType.unknown,
  );
}

/// Inspects an error message/string coming from an extension or the runtime.
///
/// Only real Cloudflare markers are accepted — “403”, “503”, “timeout” or the
/// word “challenge” are not evidence on their own.
AntiBotAssessment assessErrorMessage(String? message) {
  final haystack = (message ?? '').toLowerCase();
  if (haystack.trim().isEmpty) return const AntiBotAssessment();

  final challengeMarkers = _foundMarkers(haystack, kChallengeMarkers);
  final cloudflareChallengeMarkers =
      _foundMarkers(haystack, _kCloudflareChallengeMarkers);
  if (challengeMarkers.isNotEmpty &&
      (cloudflareChallengeMarkers.isNotEmpty ||
          (haystack.contains('cloudflare') &&
              _foundMarkers(haystack, kBlockMarkers).isEmpty))) {
    return AntiBotAssessment(
      pageType: AntiBotPageType.challenge,
      cloudflareInvolved: true,
      evidence: [for (final m in challengeMarkers) 'message:$m'],
    );
  }

  final cfMarkers = [
    'cloudflare',
    'cf_clearance',
    'cf-ray',
    'failed to bypass',
    'attention required',
  ];
  final cfHits = _foundMarkers(haystack, cfMarkers);
  if (cfHits.isNotEmpty) {
    return AntiBotAssessment(
      pageType: AntiBotPageType.blocked,
      cloudflareInvolved: true,
      evidence: [for (final m in cfHits) 'message:$m'],
    );
  }

  return const AntiBotAssessment();
}

/// The exact URL a bypass WebView must open. Never rewrites an API URL to the
/// site root: the challenge must be solved on the URL that actually failed.
String? resolveBypassUrl(String? url) {
  if (url == null) return null;
  final trimmed = url.trim();
  if (trimmed.isEmpty) return null;
  final uri = Uri.tryParse(trimmed);
  if (uri == null || uri.host.isEmpty) return null;
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;
  return trimmed;
}

/// Whether the UI is allowed to declare the challenge solved.
///
/// Requires all of:
///  * a challenge was actually observed (`challengeSeen`), and
///  * the page no longer shows a challenge, and
///  * the `cf_clearance` cookie is available for the HTTP retry.
///
/// A normal page with a pre-existing cookie is [AntiBotPageType.normal] and
/// must NOT be reported as “challenge resolved”.
bool canMarkChallengeResolved({
  required bool challengeSeen,
  required bool cfClearancePresent,
  AntiBotPageType currentPage = AntiBotPageType.normal,
}) {
  if (!challengeSeen) return false;
  if (currentPage == AntiBotPageType.challenge) return false;
  return cfClearancePresent;
}

/// JavaScript probe run inside the bypass WebView. Returns a JSON payload
/// consumed by [parsePageProbe]; deliberately small (title + text snippet).
const String kCfPageProbeJs = r'''
(function () {
  try {
    var title = '';
    var text = '';
    var cloudflareChallengeDom = false;
    try { title = String(document.title || ''); } catch (e) {}
    try {
      var body = document.body;
      text = String((body && (body.innerText || body.textContent)) || '');
    } catch (e) {}
    try {
      cloudflareChallengeDom = !!document.querySelector(
        '#challenge-error-title, #challenge-error-text, #challenge-form, ' +
        'input[name="cf-turnstile-response"], #cf-challenge-running, ' +
        'script[src*="/cdn-cgi/challenge-platform/"], ' +
        'iframe[src*="challenges.cloudflare.com"]'
      );
    } catch (e) {}
    if (text.length > 20000) text = text.substring(0, 20000);
    return JSON.stringify({
      ok: true,
      title: title,
      url: String(location.href || ''),
      text: text,
      cloudflareChallengeDom: cloudflareChallengeDom
    });
  } catch (e) {
    return JSON.stringify({ ok: false, error: String(e) });
  }
})()
''';

/// Decodes the payload returned by [kCfPageProbeJs].
AntiBotAssessment parsePageProbe(String? raw) {
  if (raw == null || raw.isEmpty) return const AntiBotAssessment();
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map || decoded['ok'] != true) {
      return const AntiBotAssessment();
    }
    return assessPageContent(
      title: decoded['title']?.toString(),
      text: decoded['text']?.toString(),
      cloudflareChallengeDom: decoded['cloudflareChallengeDom'] == true,
    );
  } catch (_) {
    return const AntiBotAssessment();
  }
}

/// Safe diagnostic line — never includes cookie values or request bodies.
String antiBotLogLine({
  required AntiBotAssessment assessment,
  String? url,
  int? statusCode,
  Map<String, String>? headers,
}) {
  final h = _normalizedHeaders(headers);
  final parts = <String>[
    '[AntiBot]',
    if (url != null && url.isNotEmpty) 'url=${redactUrl(url)}',
    if (statusCode != null) 'status=$statusCode',
    if (h['server'] != null) 'server=${h['server']}',
    'cfRayPresent=${(h['cf-ray'] ?? '').isNotEmpty}',
    if (h['content-type'] != null) 'contentType=${h['content-type']}',
    'pageType=${assessment.pageType.name}',
    'cloudflare=${assessment.cloudflareInvolved}',
    if (assessment.evidence.isNotEmpty)
      'evidence=${assessment.evidence.join('|')}',
  ];
  return parts.join(' ');
}

/// Keeps scheme/host/path but removes query values (they may contain tokens).
String redactUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasQuery) return url;
  return uri.replace(query: 'redacted').toString();
}
