import 'dart:async';
import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'dart:typed_data';

import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/modules/more/settings/general/providers/general_state_provider.dart';
import 'package:watchtower/services/http/m_client.dart';
import 'package:watchtower/utils/constant.dart';
import 'package:watchtower/utils/global_style.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_svg/flutter_svg.dart';

// ─── AdBlock domain blocklist ─────────────────────────────────────────────────

const _kBlockedDomains = [
  // Google
  'doubleclick.net', 'googlesyndication.com', 'googleadservices.com',
  'googletagservices.com', 'googletagmanager.com', 'adservice.google.com',
  'pagead2.googlesyndication.com', 'fundingchoicesmessages.google.com',
  'tpc.googlesyndication.com', 'admanager.google.com',
  // Yahoo / AOL
  'ads.yahoo.com', 'advertising.com', 'aolcloud.net', 'ssp.yahoo.com',
  // Amazon
  'amazon-adsystem.com', 'assoc-amazon.com',
  // Major ad exchanges
  'adnxs.com', 'appnexus.com', 'taboola.com', 'outbrain.com',
  'popads.net', 'adsterra.com', 'propellerads.com', 'revcontent.com',
  'media.net', 'yandexadexchange.net', 'smartadserver.com',
  'rubiconproject.com', 'openx.net', 'openx.com', 'criteo.com', 'criteo.net',
  'adsrvr.org', 'bidswitch.net', 'pubmatic.com', 'adroll.com',
  'quantserve.com', 'scorecardresearch.com',
  // Adult / streaming ad nets
  'trafficjunky.net', 'exoclick.com', 'juicyads.com',
  'ero-advertising.com', 'plugrush.com', 'clickadu.com',
  'trafficholder.com', 'adspyglass.com', 'tubecorporate.com',
  'hilltopads.net', 'adnium.com', 'sublimemedia.net', 'cpmstar.com',
  // Programmatic / SSPs
  '3lift.com', 'triplelift.com', 'sovrn.com', 'lijit.com',
  'spotxchange.com', 'spotx.tv', 'sharethrough.com', 'sizmek.com',
  'turn.com', 'teads.tv', 'teads.com', 'indexexchange.com',
  'casalemedia.com', 'rhythmone.com', '33across.com', 'undertone.com',
  'yieldmo.com', 'adform.net', 'adform.com', 'emxdgt.com',
  'lkqd.net', 'districtm.io', 'innovid.com', 'springserve.com',
  'yieldbot.com', 'smartclip.net', 'conversantmedia.com',
  'flashtalking.com', 'advertising.com', 'adblade.com', 'adbuddiz.com',
  'adcolony.com', 'admixer.net', 'adtegrity.net',
  // Trackers / analytics
  'moatads.com', 'moatpixel.com', 'adsafeprotected.com',
  'mixpanel.com', 'amplitude.com', 'hotjar.com', 'crazyegg.com',
  'fullstory.com', 'mouseflow.com', 'nr-data.net',
  'appsflyer.com', 'adjust.com', 'kochava.com', 'branch.io',
  // Twitter / LinkedIn ads
  'ads-twitter.com', 'analytics.twitter.com', 'static.ads-twitter.com',
  'ads.linkedin.com', 'syndication.twitter.com',
  // Popup / redirect shorteners
  'adf.ly', 'ouo.io', 'bc.vc', 'sh.st', 'clkmon.com',
  'clkrev.com', 'shorte.st', 'za.gl', 'fc.lc',
  // Anime/streaming site specific
  'vdo.ai', 'adspeed.com', 'adinplay.com',
  'seedr.cc', 'streamtape.com', 'vidstreaming.io',
  'bunnycdn.com', 'bunny.net',
  // Coinminer / malware
  'coinhive.com', 'cryptoloot.pro', 'coin-hive.com', 'jsecoin.com',
  // Misc
  'mgid.com', 'zergnet.com', 'content.ad', 'kiosked.com', 'adloox.com',
  'prebid.org', 'prebid.io', 'a9.com',
];

bool _isAdDomain(String url) {
  try {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    final host = uri.host.toLowerCase();
    for (final blocked in _kBlockedDomains) {
      if (host == blocked || host.endsWith('.$blocked')) return true;
    }
    return false;
  } catch (_) {
    return false;
  }
}

const _kAdBlockJs = r"""
(function() {
  if (window.__watchtowerAdBlockActive) return;
  window.__watchtowerAdBlockActive = true;

  // ── Blocked network patterns ─────────────────────────────────────────────────
  var _blockedPatterns = [
    'doubleclick','googlesyndication','googleadservices','googletagservices',
    'adservice.google','pagead','adnxs','appnexus','taboola','outbrain',
    'popads','adsterra','propellerads','media.net','smartadserver',
    'rubiconproject','openx','criteo','pubmatic','adroll',
    'trafficjunky','exoclick','juicyads','ero-advertising','plugrush',
    'clickadu','trafficholder','adspyglass','hilltopads','adnium',
    'triplelift','sovrn','spotxchange','spotx.tv','sharethrough',
    'teads','indexexchange','casalemedia','adform','districtm',
    'moatads','fundingchoicesmessages.google','prebid','vdo.ai',
    'adinplay','mgid','zergnet','coinhive','cryptoloot',
    'adf.ly','ouo.io','clkmon','clkrev'
  ];

  function _isBlocked(url) {
    if (!url) return false;
    var u = url.toLowerCase();
    for (var i=0; i<_blockedPatterns.length; i++) {
      if (u.indexOf(_blockedPatterns[i]) !== -1) return true;
    }
    return false;
  }

  // ── Block fetch ──────────────────────────────────────────────────────────────
  var _origFetch = window.fetch;
  window.fetch = function(resource, init) {
    var url = (typeof resource === 'string') ? resource : (resource && resource.url) || '';
    if (_isBlocked(url)) return new Promise(function(_, rej) { rej(new TypeError('blocked')); });
    return _origFetch.apply(this, arguments);
  };

  // ── Block XMLHttpRequest ─────────────────────────────────────────────────────
  var _origOpen = XMLHttpRequest.prototype.open;
  XMLHttpRequest.prototype.open = function(method, url) {
    if (_isBlocked(url)) {
      this._wtBlocked = true;
    }
    return _origOpen.apply(this, arguments);
  };
  var _origSend = XMLHttpRequest.prototype.send;
  XMLHttpRequest.prototype.send = function() {
    if (this._wtBlocked) return;
    return _origSend.apply(this, arguments);
  };

  // ── Block window.open / popups / alerts ──────────────────────────────────────
  try { window.open = function() { return null; }; } catch(e) {}
  try { window.alert = function() {}; } catch(e) {}
  try { window.confirm = function() { return true; }; } catch(e) {}
  try { window.prompt = function() { return ''; }; } catch(e) {}

  // ── CSS rules ───────────────────────────────────────────────────────────────
  var style = document.createElement('style');
  style.id = '__watchtower_adblock_css';
  style.textContent = `
    .ad,.ads,.ad-container,.ad-wrapper,.ad-slot,.ad-unit,.ads-container,
    .advertisement,.advert,.advertise,.advertising,.sponsor,.sponsored,
    .popup,.pop-up,.interstitial,.overlay-ad,.ad-overlay,.modal-ad,
    .gdpr-banner,.gdpr-overlay,.cookie-banner,.cookie-notice,.cookie-popup,
    .consent-banner,.consent-popup,.newsletter-popup,.newsletter-modal,
    .pushad,.push-ad,.sticky-ad,.fixed-ad,.floating-ad,.banner-ad,
    .vid-container>div[style*="position:fixed"],
    div[style*="position:fixed"][style*="z-index:9"],
    div[style*="position:fixed"][style*="z-index: 9"],
    [class*="google-ads"],[class*="google_ads"],[id*="google_ads"],
    [class*="adsense"],[id*="adsense"],
    [class*="adsbygoogle"],[id*="adsbygoogle"],
    [id^="div-gpt-ad"],[id^="gpt-ad"],
    iframe[src*="doubleclick"],iframe[src*="googlesyndication"],
    iframe[src*="adnxs"],iframe[src*="ads."],iframe[src*="/ads/"],
    iframe[src*="adservice"],iframe[src*="pagead"],iframe[src*="taboola"],
    iframe[src*="outbrain"],iframe[src*="criteo"],iframe[src*="popads"],
    div[id^="ad_"],div[id^="ads_"],div[class^="ad_"],div[class^="ads_"],
    ins.adsbygoogle,
    #ad,#ads,#banner-ad,#sponsor,#sponsored,#popup,#interstitial,
    #cookie-banner,#gdpr-overlay,#consent-modal,#newsletter-popup,
    .overlay,.modal-overlay,.bg-overlay:not(.video-overlay) {
      display:none!important;
      visibility:hidden!important;
      opacity:0!important;
      pointer-events:none!important;
      height:0!important;
      max-height:0!important;
      overflow:hidden!important;
    }
    body { overflow: auto !important; }
    html, body { position: static !important; }
  `;
  (document.head || document.documentElement).appendChild(style);

  // ── DOM cleaning ─────────────────────────────────────────────────────────────
  var adSelectors = [
    'iframe[src*="ads"]','iframe[src*="doubleclick"]',
    'iframe[src*="googlesyndication"]','iframe[src*="adnxs"]',
    'iframe[src*="adservice"]','iframe[src*="pagead"]',
    'iframe[src*="taboola"]','iframe[src*="outbrain"]',
    'ins.adsbygoogle','[id^="div-gpt-ad"]',
    '[class*="overlay-ad"]','[class*="modal-ad"]',
    '[class*="gdpr"]','[class*="consent"]','[class*="cookie-banner"]',
    '[class*="newsletter-popup"]','[data-ad]','[data-ads]','[data-adunit]',
    '.adsbygoogle','#cookie-banner','#gdpr-overlay','#consent-modal',
    '[class*="popup-ad"]','[class*="ad-popup"]','[id*="popup-ad"]'
  ];

  function removeAdNodes() {
    adSelectors.forEach(function(sel) {
      try {
        document.querySelectorAll(sel).forEach(function(el) {
          try { el.remove(); } catch(e) {}
        });
      } catch(e) {}
    });
    document.querySelectorAll('div,section,aside,span').forEach(function(el) {
      try {
        var c = (el.className||'').toLowerCase();
        var i = (el.id||'').toLowerCase();
        if (/\bad\b|^ads$|advert|adsense|adsbygoogle|sponsor|popup|gdpr|consent|cookie.banner|interstitial/.test(c+' '+i)) {
          if (el.offsetHeight < 500 || /popup|modal|interstitial|overlay/.test(c+' '+i)) {
            el.style.cssText = 'display:none!important;height:0!important;overflow:hidden!important;';
          }
        }
        // Remove fixed/absolute fullscreen overlays
        if (/fixed|absolute/.test(getComputedStyle(el).position||'')) {
          var z = parseInt(getComputedStyle(el).zIndex||'0');
          if (z > 9999 && el.offsetHeight > 200) {
            var tag = el.tagName.toLowerCase();
            if (tag !== 'video' && tag !== 'canvas') {
              el.style.cssText = 'display:none!important;';
            }
          }
        }
      } catch(e) {}
    });
  }

  removeAdNodes();
  document.addEventListener('DOMContentLoaded', removeAdNodes);
  setTimeout(removeAdNodes, 300);
  setTimeout(removeAdNodes, 800);
  setTimeout(removeAdNodes, 2000);
  setTimeout(removeAdNodes, 5000);
  setTimeout(removeAdNodes, 10000);

  // ── MutationObserver — catch dynamic ads ────────────────────────────────────
  var observer = new MutationObserver(function(mutations) {
    var dirty = false;
    mutations.forEach(function(m) {
      m.addedNodes.forEach(function(node) {
        if (node.nodeType !== 1) return;
        dirty = true;
        var c = (node.className||'').toLowerCase();
        var i = (node.id||'').toLowerCase();
        var src = (node.src||node.getAttribute&&node.getAttribute('src')||'').toLowerCase();
        if (/\bad\b|^ads$|advert|adsense|adsbygoogle|sponsor|popup|gdpr|consent|doubleclick|googlesyndication|taboola|outbrain|criteo/.test(c+' '+i+' '+src)) {
          try { node.remove(); return; } catch(e) {
            try { node.style.display='none'; } catch(e2) {}
          }
        }
        try {
          node.querySelectorAll && adSelectors.forEach(function(sel) {
            node.querySelectorAll(sel).forEach(function(child) {
              try { child.remove(); } catch(e) {}
            });
          });
        } catch(e) {}
      });
    });
    if (dirty) {
      try {
        document.querySelectorAll('div[style*="z-index: 2147483647"],div[style*="z-index:2147483647"]').forEach(function(el) {
          if (el.tagName !== 'VIDEO' && el.tagName !== 'CANVAS') {
            try { el.remove(); } catch(e) {}
          }
        });
      } catch(e) {}
    }
  });
  try {
    observer.observe(document.documentElement, { childList: true, subtree: true });
  } catch(e) {}
})();
""";

// ── Element picker JS (injected on demand) ────────────────────────────────────
const _kPickerJs = r"""
(function() {
  if (window.__watchtowerPickerActive) return;
  window.__watchtowerPickerActive = true;

  var overlay = document.createElement('div');
  overlay.id = '__wt_picker_overlay';
  overlay.style.cssText = 'position:fixed;top:0;left:0;width:100%;height:100%;z-index:2147483647;cursor:crosshair;background:rgba(255,0,0,0.05);';
  document.body.appendChild(overlay);

  var highlight = document.createElement('div');
  highlight.style.cssText = 'position:fixed;pointer-events:none;border:2px solid red;background:rgba(255,0,0,0.15);z-index:2147483646;transition:all 0.1s;box-sizing:border-box;';
  document.body.appendChild(highlight);

  function getBounds(el) {
    var r = el.getBoundingClientRect();
    return { top: r.top, left: r.left, width: r.width, height: r.height };
  }

  overlay.addEventListener('mousemove', function(e) {
    overlay.style.pointerEvents = 'none';
    var el = document.elementFromPoint(e.clientX, e.clientY);
    overlay.style.pointerEvents = 'all';
    if (!el || el === overlay || el === highlight) return;
    var b = getBounds(el);
    highlight.style.top = b.top + 'px';
    highlight.style.left = b.left + 'px';
    highlight.style.width = b.width + 'px';
    highlight.style.height = b.height + 'px';
  });

  overlay.addEventListener('click', function(e) {
    e.preventDefault();
    e.stopPropagation();
    overlay.style.pointerEvents = 'none';
    var el = document.elementFromPoint(e.clientX, e.clientY);
    overlay.style.pointerEvents = 'all';
    if (!el || el === overlay || el === highlight) return;
    var tag = el.tagName || '';
    var cls = el.className || '';
    var id = el.id || '';
    var src = el.src || el.getAttribute('src') || '';
    var info = JSON.stringify({ tag: tag, cls: cls, id: id, src: src });
    // Store for Flutter to retrieve
    window.__watchtowerPickedInfo = info;
    // Clean up
    overlay.remove();
    highlight.remove();
    window.__watchtowerPickerActive = false;
    // Notify Flutter
    try { window.flutter_inappwebview.callHandler('elementPicked', info); } catch(e2) {}
  });
})();
""";

// ─── Panel snap positions ─────────────────────────────────────────────────────

enum _PanelSnap { mini, half, full }

double _snapFraction(_PanelSnap s) {
  switch (s) {
    case _PanelSnap.mini:
      return 0.35;
    case _PanelSnap.half:
      return 0.65;
    case _PanelSnap.full:
      return 1.0;
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

/// Returns just the registrable domain+TLD (e.g. "manga-scan.fr")
String _displayHost(String rawUrl) {
  try {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null || uri.host.isEmpty) return rawUrl;
    final parts = uri.host.split('.');
    if (parts.length <= 2) return uri.host;
    return parts.sublist(parts.length - 2).join('.');
  } catch (_) {
    return rawUrl;
  }
}

bool _isSecure(String rawUrl) {
  try {
    final uri = Uri.tryParse(rawUrl);
    return uri?.scheme == 'https';
  } catch (_) {
    return false;
  }
}

// ─── Main widget ──────────────────────────────────────────────────────────────

class MangaWebView extends ConsumerStatefulWidget {
  final String url;
  final String title;
  const MangaWebView({super.key, required this.url, required this.title});

  @override
  ConsumerState<MangaWebView> createState() => _MangaWebViewState();
}

class _MangaWebViewState extends ConsumerState<MangaWebView>
    with SingleTickerProviderStateMixin {
  // Desktop
  MyInAppBrowser? browser;
  Webview? _desktopWebview;
  bool isNotWebviewWindow = false;
  bool _initialized = false;

  // WebView state
  InAppWebViewController? _webViewController;
  late String _url = widget.url;
  late String _title = widget.title;
  bool _canGoback = false;
  bool _canGoForward = false;
  double _progress = 0;

  // AdBlock
  bool _adBlockEnabled = true;
  int _blockedCount = 0;
  bool _pickerMode = false;
  List<String> _blockedElements = [];

  // Footer visibility (toggled by ghost icon)
  bool _showFooter = true;

  // Night mode / text size / desktop / incognito
  bool _nightMode = false;
  int _textSizeStep = 0;
  bool _desktopMode = false;
  bool _incognitoMode = false;

  // Panel drag
  _PanelSnap _snap = _PanelSnap.full;
  double _currentFraction = 1.0;
  double _dragStartFraction = 1.0;
  double _dragStartY = 0;

  late AnimationController _animCtrl;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _animation = Tween<double>(begin: 1.0, end: 1.0).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic),
    );
    _animation.addListener(() {
      if (mounted) setState(() => _currentFraction = _animation.value);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    if (!kIsWeb && (Platform.isLinux || Platform.isWindows)) {
      _runWebViewDesktop();
    } else {
      setState(() => isNotWebviewWindow = true);
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    if (!kIsWeb && Platform.isLinux) {
      _desktopWebview?.close();
    } else if (browser != null) {
      if (browser!.isOpened()) browser!.close();
      browser!.dispose();
    }
    super.dispose();
  }

  // ── Desktop ───────────────────────────────────────────────────────────────

  Future<void> _runWebViewDesktop() async {
    String? ua = ref.read(userAgentStateProvider);
    if (ua == defaultUserAgent) ua = null;

    if (!kIsWeb && Platform.isLinux) {
      _desktopWebview = await WebviewWindow.create();
      final timer = Timer.periodic(const Duration(seconds: 1), (t) async {
        try {
          final cookies = await _desktopWebview!.getAllCookies();
          final ua2 =
              await _desktopWebview!.evaluateJavaScript("navigator.userAgent") ??
              "";
          final cookie = cookies.map((e) => '${e.name}=${e.value}').join(';');
          await MClient.setCookie(_url, ua2, null, cookie: cookie);
        } catch (_) {}
      });
      _desktopWebview!
        ..setBrightness(Brightness.dark)
        ..launch(widget.url)
        ..onClose.whenComplete(() {
          timer.cancel();
          if (mounted) Navigator.pop(context);
        });
    } else {
      browser = MyInAppBrowser(
        context: context,
        controller: (c) => _webViewController = c,
        onProgress: (progress) async {
          final back = await _webViewController?.canGoBack();
          final fwd = await _webViewController?.canGoForward();
          final title = await _webViewController?.getTitle();
          final url = await _webViewController?.getUrl();
          if (mounted) {
            setState(() {
              _progress = progress / 100;
              _url = url.toString();
              _title = title ?? _title;
              _canGoback = back ?? false;
              _canGoForward = fwd ?? false;
            });
          }
        },
      );
      await browser!.openUrlRequest(
        urlRequest: URLRequest(url: WebUri(widget.url)),
        settings: InAppBrowserClassSettings(
          browserSettings: InAppBrowserSettings(
            presentationStyle: ModalPresentationStyle.POPOVER,
          ),
          webViewSettings: InAppWebViewSettings(
            isInspectable: kDebugMode,
            useShouldOverrideUrlLoading: true,
            userAgent: ua,
          ),
        ),
      );
    }
  }

  // ── Panel drag ────────────────────────────────────────────────────────────

  void _onDragStart(DragStartDetails d) {
    _dragStartY = d.globalPosition.dy;
    _dragStartFraction = _currentFraction;
  }

  void _onDragUpdate(DragUpdateDetails d) {
    final screenH = MediaQuery.of(context).size.height;
    final dy = d.globalPosition.dy - _dragStartY;
    final newFraction = (_dragStartFraction - dy / screenH).clamp(0.2, 1.0);
    setState(() => _currentFraction = newFraction);
  }

  void _onDragEnd(DragEndDetails d) {
    final velocity = d.primaryVelocity ?? 0;
    _PanelSnap target;

    if (velocity > 600) {
      target = _snap == _PanelSnap.full ? _PanelSnap.half : _PanelSnap.mini;
    } else if (velocity < -600) {
      target = _snap == _PanelSnap.mini ? _PanelSnap.half : _PanelSnap.full;
    } else {
      final all = [_PanelSnap.mini, _PanelSnap.half, _PanelSnap.full];
      target = all.reduce((a, b) {
        final da = (_snapFraction(a) - _currentFraction).abs();
        final db = (_snapFraction(b) - _currentFraction).abs();
        return da < db ? a : b;
      });
    }

    if (_currentFraction < 0.25) {
      _dismiss();
      return;
    }

    _snap = target;
    _animateTo(_snapFraction(target));
  }

  void _animateTo(double target) {
    _animation = Tween<double>(begin: _currentFraction, end: target).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic),
    );
    _animCtrl.forward(from: 0);
  }

  void _dismiss() {
    _animateTo(0.0);
    Future.delayed(const Duration(milliseconds: 280), () {
      if (mounted) context.pop();
    });
  }

  // ── AdBlock ───────────────────────────────────────────────────────────────

  NavigationActionPolicy _checkAd(NavigationAction action) {
    if (!_adBlockEnabled) return NavigationActionPolicy.ALLOW;
    final url = action.request.url?.toString() ?? '';
    if (_isAdDomain(url)) {
      if (mounted) setState(() => _blockedCount++);
      return NavigationActionPolicy.CANCEL;
    }
    return NavigationActionPolicy.ALLOW;
  }

  Future<void> _injectJs() async {
    if (!_adBlockEnabled) return;
    try {
      await _webViewController?.evaluateJavascript(source: _kAdBlockJs);
    } catch (_) {}
  }

  Future<void> _activatePicker() async {
    try {
      await _webViewController?.evaluateJavascript(source: _kPickerJs);
    } catch (_) {}
  }

  Future<void> _toggleNightMode() async {
    setState(() => _nightMode = !_nightMode);
    if (_nightMode) {
      await _webViewController?.evaluateJavascript(source: r"""
(function(){
  var s=document.getElementById('__wt_night');
  if(!s){s=document.createElement('style');s.id='__wt_night';document.head.appendChild(s);}
  s.textContent='html{filter:invert(1) hue-rotate(180deg)!important;}img,video,canvas{filter:invert(1) hue-rotate(180deg)!important;}';
})();
""");
    } else {
      await _webViewController?.evaluateJavascript(source:
          "var s=document.getElementById('__wt_night');if(s)s.remove();");
    }
  }

  Future<void> _cycleTextSize() async {
    _textSizeStep = (_textSizeStep + 1) % 3;
    final sizes = ['100%', '125%', '150%'];
    final labels = ['Normal', 'Grand', 'Très grand'];
    await _webViewController?.evaluateJavascript(source: """
(function(){
  var s=document.getElementById('__wt_textsize');
  if(!s){s=document.createElement('style');s.id='__wt_textsize';document.head.appendChild(s);}
  s.textContent='html{font-size:${sizes[_textSizeStep]}!important;}';
})();
""");
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Taille du texte : ${labels[_textSizeStep]}'),
        duration: const Duration(seconds: 1),
      ));
    }
  }

  Future<void> _toggleIncognito() async {
    setState(() => _incognitoMode = !_incognitoMode);
    if (_incognitoMode) {
      await CookieManager.instance().deleteAllCookies();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mode incognito activé — cookies effacés'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mode incognito désactivé'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _toggleDesktopMode() async {
    setState(() => _desktopMode = !_desktopMode);
    const desktopUA =
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';
    await _webViewController?.setSettings(
      settings: InAppWebViewSettings(
        userAgent: _desktopMode ? desktopUA : null,
      ),
    );
    await _webViewController?.reload();
  }

  void _openTranslation() {
    final encoded = Uri.encodeComponent(_url);
    InAppBrowser.openWithSystemBrowser(
        url: WebUri('https://translate.google.com/translate?u=$encoded'));
  }

  void _openDownload() {
    InAppBrowser.openWithSystemBrowser(url: WebUri(_url));
  }

  void _copyUrlAsBookmark() {
    Clipboard.setData(ClipboardData(text: _url));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('URL copiée dans le presse-papier'),
          duration: Duration(seconds: 2)),
    );
  }

  void _showQrCode() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF2C2C2E) : Colors.white,
        title: Text('QR Code',
            style: TextStyle(
                color: isDark ? Colors.white : Colors.black87, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_url,
                style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 12),
            Text('Ouvrez l\'URL dans un générateur QR externe',
                style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                textAlign: TextAlign.center),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _copyUrlAsBookmark();
            },
            child: const Text('Copier URL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  void _toggleOrientation() {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    if (isLandscape) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    Navigator.of(context).pop();
  }

  Future<void> _injectHideRule(String css) async {
    final js = '''
(function(){
  var s=document.getElementById('__wt_custom_hide')||document.createElement('style');
  s.id='__wt_custom_hide';
  s.textContent+='$css{display:none!important;}';
  (document.head||document.documentElement).appendChild(s);
})();
''';
    try {
      await _webViewController?.evaluateJavascript(source: js);
    } catch (_) {}
  }

  void _showPickedElementDialog(String info) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String cssId = '';
    String cssClass = '';
    String domain = '';
    try {
      final m = RegExp(r'"id":"([^"]*)"').firstMatch(info);
      final c = RegExp(r'"cls":"([^"]*)"').firstMatch(info);
      final s = RegExp(r'"src":"([^"]*)"').firstMatch(info);
      cssId = m?.group(1) ?? '';
      cssClass = (c?.group(1) ?? '').split(' ').first;
      final src = s?.group(1) ?? '';
      if (src.isNotEmpty) {
        final uri = Uri.tryParse(src);
        domain = uri?.host ?? '';
      }
    } catch (_) {}

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF2C2C2E) : Colors.white,
        title: Text('Élément sélectionné', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 16)),
        content: Text('Que voulez-vous faire ?', style: TextStyle(color: isDark ? Colors.grey.shade300 : Colors.black54, fontSize: 13)),
        actions: [
          if (cssId.isNotEmpty)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _injectHideRule('#$cssId');
                setState(() => _blockedElements.add('#$cssId'));
              },
              child: Text('Masquer #$cssId', style: const TextStyle(color: Colors.orange)),
            ),
          if (cssClass.isNotEmpty)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _injectHideRule('.$cssClass');
                setState(() => _blockedElements.add('.$cssClass'));
              },
              child: Text('Masquer .$cssClass', style: const TextStyle(color: Colors.orange)),
            ),
          if (domain.isNotEmpty)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  _blockedElements.add(domain);
                  _blockedCount++;
                });
              },
              child: Text('Bloquer $domain', style: const TextStyle(color: Colors.red)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  void _showAdMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _AdBlockSheet(
        enabled: _adBlockEnabled,
        blockedCount: _blockedCount,
        onToggle: (v) {
          setState(() => _adBlockEnabled = v);
          Navigator.pop(context);
        },
        onReset: () {
          setState(() => _blockedCount = 0);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showMoreMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      enableDrag: false,
      builder: (sheetCtx) {
        // Use sheetCtx (the modal's own context) to pop the bottom sheet.
        // Using the outer widget context causes a navigator mismatch with
        // GoRouter nested navigators, making it look like buttons don't work.
        void dismiss() {
          if (Navigator.of(sheetCtx).canPop()) {
            Navigator.of(sheetCtx).pop();
          }
        }

        return _MoreSheet(
          adEnabled: _adBlockEnabled,
          blockedCount: _blockedCount,
          blockedElements: _blockedElements,
          nightMode: _nightMode,
          desktopMode: _desktopMode,
          textSizeStep: _textSizeStep,
          incognito: _incognitoMode,
          onCopyUrl: () {
            dismiss();
            Clipboard.setData(ClipboardData(text: _url));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('URL copiée'), duration: Duration(seconds: 2)),
            );
          },
          onShare: () {
            dismiss();
            final box = context.findRenderObject() as RenderBox?;
            SharePlus.instance.share(
              ShareParams(
                text: _url,
                sharePositionOrigin: box != null
                    ? box.localToGlobal(Offset.zero) & box.size
                    : null,
              ),
            );
          },
          onOpenBrowser: () {
            dismiss();
            InAppBrowser.openWithSystemBrowser(url: WebUri(_url));
          },
          onViewSource: () {
            dismiss();
            _webViewController?.evaluateJavascript(source: "document.documentElement.outerHTML");
          },
          onFindInPage: () {
            dismiss();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Recherche dans la page non disponible'), duration: Duration(seconds: 2)),
            );
          },
          onToggleAdBlock: () {
            setState(() => _adBlockEnabled = !_adBlockEnabled);
            if (_adBlockEnabled) _injectJs();
            dismiss();
          },
          onPickElement: () {
            dismiss();
            setState(() => _pickerMode = true);
            _activatePicker();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Tap sur un élément pour le bloquer'), duration: Duration(seconds: 4)),
            );
          },
          onResetRules: () {
            setState(() { _blockedCount = 0; _blockedElements.clear(); });
            dismiss();
          },
          onClearCookies: () {
            dismiss();
            CookieManager.instance().deleteAllCookies();
            MClient.deleteAllCookies(_url);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Cookies effacés'), duration: Duration(seconds: 2)),
            );
          },
          onFullscreen: () {
            dismiss();
            _snap = _PanelSnap.full;
            _animateTo(1.0);
          },
          onUserAgent: () {
            dismiss();
            _toggleDesktopMode();
          },
          onNetworkLog: () {
            dismiss();
            _showAdMenu();
          },
          onNightMode: () {
            dismiss();
            _toggleNightMode();
          },
          onTextSize: () {
            dismiss();
            _cycleTextSize();
          },
          onDesktopMode: () {
            dismiss();
            _toggleDesktopMode();
          },
          onTranslate: () {
            dismiss();
            _openTranslation();
          },
          onDownload: () {
            dismiss();
            _openDownload();
          },
          onBookmark: () {
            dismiss();
            _copyUrlAsBookmark();
          },
          onQrCode: () {
            dismiss();
            _showQrCode();
          },
          onOrientation: () {
            dismiss();
            _toggleOrientation();
          },
          onIncognito: () {
            dismiss();
            _toggleIncognito();
          },
          onCloseWebView: () => context.pop(),
        );
      },
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Desktop: simple screen
    if (!isNotWebviewWindow && !kIsWeb && (Platform.isLinux || Platform.isWindows)) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            _title,
            style: const TextStyle(
              overflow: TextOverflow.ellipsis,
              fontWeight: FontWeight.bold,
            ),
          ),
          leading: IconButton(
            onPressed: () {
              _desktopWebview?.close();
              Navigator.pop(context);
            },
            icon: const Icon(Icons.close),
          ),
        ),
      );
    }

    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _webViewController?.canGoBack() ?? false) {
          _webViewController?.goBack();
        } else {
          if (mounted) context.pop();
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        // ── Top bar: address + close ──────────────────────────────────
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(54),
          child: _BrowserHeader(
            url: _url,
            title: _title,
            progress: _progress,
            isDark: isDark,
            cs: cs,
            adEnabled: _adBlockEnabled,
            blockedCount: _blockedCount,
            showFooter: _showFooter,
            incognito: _incognitoMode,
            onToggleFooter: () => setState(() => _showFooter = !_showFooter),
            onRefresh: () => _webViewController?.reload(),
          ),
        ),
        // ── WebView body ──────────────────────────────────────────────
        body: kIsWeb || !Platform.isWindows
            ? InAppWebView(
                            webViewEnvironment: webViewEnvironment,
                            initialUrlRequest: URLRequest(url: WebUri(widget.url)),
                            initialSettings: InAppWebViewSettings(
                              isInspectable: kDebugMode,
                              useShouldOverrideUrlLoading: true,
                              useShouldInterceptRequest: !kIsWeb && Platform.isAndroid,
                              incognito: _incognitoMode,
                              // Transparent bg so scaffold colour shows during load
                              transparentBackground: true,
                              userAgent:
                                  ref.read(userAgentStateProvider) ==
                                          defaultUserAgent
                                      ? null
                                      : ref.read(userAgentStateProvider),
                            ),
                            onWebViewCreated: (c) {
                              _webViewController = c;
                              c.addJavaScriptHandler(
                                handlerName: 'elementPicked',
                                callback: (args) {
                                  if (!mounted) return;
                                  setState(() => _pickerMode = false);
                                  final info = args.isNotEmpty ? args[0].toString() : '';
                                  _showPickedElementDialog(info);
                                },
                              );
                            },
                            onLoadStart: (c, url) {
                              if (mounted) setState(() => _url = url.toString());
                            },
                            onLoadStop: (c, url) async {
                              if (mounted) setState(() => _url = url.toString());
                              await _injectJs();
                            },
                            onProgressChanged: (c, progress) {
                              if (mounted) {
                                setState(() => _progress = progress / 100);
                              }
                            },
                            onUpdateVisitedHistory: (c, url, _) async {
                              final ua = await c.evaluateJavascript(
                                    source: 'navigator.userAgent',
                                  ) ??
                                  '';
                              await MClient.setCookie(url.toString(), ua, c);
                              final back = await c.canGoBack();
                              final fwd = await c.canGoForward();
                              final title = await c.getTitle();
                              if (mounted) {
                                setState(() {
                                  _url = url.toString();
                                  _title = title ?? _title;
                                  _canGoback = back;
                                  _canGoForward = fwd;
                                });
                              }
                            },
                            shouldOverrideUrlLoading: (c, action) async {
                              final policy = _checkAd(action);
                              if (policy == NavigationActionPolicy.CANCEL) {
                                return policy;
                              }
                              final uri = action.request.url!;
                              if (![
                                'http',
                                'https',
                                'file',
                                'chrome',
                                'data',
                                'javascript',
                                'about',
                              ].contains(uri.scheme)) {
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri);
                                  return NavigationActionPolicy.CANCEL;
                                }
                              }
                              return NavigationActionPolicy.ALLOW;
                            },
                            shouldInterceptRequest: (!kIsWeb && Platform.isAndroid)
                                ? (c, request) async {
                                    final url = request.url.toString();
                                    if (_adBlockEnabled && _isAdDomain(url)) {
                                      if (mounted) {
                                        setState(() => _blockedCount++);
                                      }
                                      return WebResourceResponse(
                                        contentType: 'text/plain',
                                        data: Uint8List(0),
                                      );
                                    }
                                    return null;
                                  }
                                : null,
                          )
            : const SizedBox.shrink(),
        // ── Bottom toolbar ────────────────────────────────────────────
        bottomNavigationBar: _showFooter
            ? _BrowserToolbar(
                isDark: isDark,
                cs: cs,
                canGoBack: _canGoback,
                canGoForward: _canGoForward,
                onBack: () => _webViewController?.goBack(),
                onForward: () => _webViewController?.goForward(),
                onHome: () => _webViewController?.loadUrl(
                  urlRequest: URLRequest(url: WebUri(widget.url)),
                ),
                onTabs: _showMoreMenu,
                onMore: _showMoreMenu,
              )
            : null,
      ),
    );
  }
}

// ─── Browser header (drag handle + address bar + progress) ───────────────────

class _BrowserHeader extends StatelessWidget {
  final String url;
  final String title;
  final double progress;
  final bool isDark;
  final ColorScheme cs;
  final bool adEnabled;
  final int blockedCount;
  final bool showFooter;
  final bool incognito;
  final VoidCallback onToggleFooter;
  final VoidCallback onRefresh;

  const _BrowserHeader({
    required this.url,
    required this.title,
    required this.progress,
    required this.isDark,
    required this.cs,
    required this.adEnabled,
    required this.blockedCount,
    required this.showFooter,
    required this.incognito,
    required this.onToggleFooter,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final secure = _isSecure(url);
    final displayTitle = title.isNotEmpty ? title : _displayHost(url);
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.grey.shade500 : Colors.grey.shade500;

    // Left icon colour: incognito=purple, HTTPS=green, HTTP=grey
    final Color shieldColor = incognito
        ? Colors.deepPurple.shade300
        : secure
            ? (isDark ? Colors.greenAccent.shade400 : Colors.green.shade600)
            : subColor;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Address bar row — completely flat, no container/pill/box
        SizedBox(
          height: 46,
          child: Row(
            children: [
              // Left: shield (secure) or ghost (incognito) — tap = toggle footer
              GestureDetector(
                onTap: onToggleFooter,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  child: SvgPicture.asset(
                    incognito ? 'assets/icons/ghost.svg' : 'assets/icons/block-ads.svg',
                    width: 22,
                    height: 22,
                    colorFilter: ColorFilter.mode(shieldColor, BlendMode.srcIn),
                  ),
                ),
              ),

              // Title — centered, plain text, no box
              Expanded(
                child: GestureDetector(
                  onLongPress: () {
                    Clipboard.setData(ClipboardData(text: url));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Lien copié'), duration: Duration(seconds: 2)),
                    );
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          displayTitle,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: textColor,
                            overflow: TextOverflow.ellipsis,
                          ),
                          maxLines: 1,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      if (adEnabled && blockedCount > 0) ...[
                        const SizedBox(width: 6),
                        Text(
                          blockedCount > 99 ? '99+' : '$blockedCount',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.greenAccent.shade400 : Colors.green.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Right: ONLY refresh icon
              GestureDetector(
                onTap: onRefresh,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  child: Icon(
                    Icons.refresh_rounded,
                    size: 22,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Progress bar
        SizedBox(
          height: 2,
          child: progress < 1.0
              ? LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                )
              : const SizedBox.shrink(),
        ),

        // Subtle divider
        Divider(
          height: 1,
          thickness: 0.5,
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.08),
        ),
      ],
    );
  }
}

// ─── Bottom browser toolbar ───────────────────────────────────────────────────

class _BrowserToolbar extends StatelessWidget {
  final bool isDark;
  final ColorScheme cs;
  final bool canGoBack;
  final bool canGoForward;
  final VoidCallback onBack;
  final VoidCallback onForward;
  final VoidCallback onHome;
  final VoidCallback onTabs;
  final VoidCallback onMore;

  const _BrowserToolbar({
    required this.isDark,
    required this.cs,
    required this.canGoBack,
    required this.canGoForward,
    required this.onBack,
    required this.onForward,
    required this.onHome,
    required this.onTabs,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final dividerColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);
    final inactiveColor = isDark ? Colors.grey.shade700 : Colors.grey.shade400;

    return Container(
      color: bg,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Divider(height: 1, thickness: 0.5, color: dividerColor),
          SafeArea(
            top: false,
            child: SizedBox(
              height: 52,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // Back
                  _ToolbarBtn(
                    svgAsset: 'assets/icons/arrow-left.svg',
                    size: 18,
                    onTap: canGoBack ? onBack : null,
                    isDark: isDark,
                    disabledColor: inactiveColor,
                  ),
                  // Forward
                  _ToolbarBtn(
                    svgAsset: 'assets/icons/arrow-right.svg',
                    size: 18,
                    onTap: canGoForward ? onForward : null,
                    isDark: isDark,
                    disabledColor: inactiveColor,
                  ),
                  // Home
                  _ToolbarBtn(
                    svgAsset: 'assets/icons/home.svg',
                    size: 22,
                    onTap: onHome,
                    isDark: isDark,
                  ),
                  // Tabs / onglets
                  _ToolbarBtn(
                    svgAsset: 'assets/icons/number-square-one.svg',
                    size: 21,
                    onTap: onTabs,
                    isDark: isDark,
                  ),
                  // Menu (3 barres / hamburger)
                  _ToolbarBtn(
                    svgAsset: 'assets/icons/menu.svg',
                    size: 22,
                    onTap: onMore,
                    isDark: isDark,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Reusable icon button ─────────────────────────────────────────────────────

class _ToolbarBtn extends StatelessWidget {
  final IconData? icon;
  final String? svgAsset;
  final double size;
  final VoidCallback? onTap;
  final bool isDark;
  final Color? disabledColor;

  const _ToolbarBtn({
    this.icon,
    this.svgAsset,
    required this.size,
    required this.onTap,
    required this.isDark,
    this.disabledColor,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = isDark ? Colors.white : Colors.black87;
    final color = onTap == null
        ? (disabledColor ?? (isDark ? Colors.grey.shade700 : Colors.grey.shade400))
        : activeColor;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: svgAsset != null
            ? SvgPicture.asset(
                svgAsset!,
                width: size,
                height: size,
                colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
              )
            : Icon(icon, size: size, color: color),
      ),
    );
  }
}

// ─── More options sheet (Via-style, 3 swipeable pages) ────────────────────────

class _MoreSheet extends StatefulWidget {
  final bool adEnabled;
  final int blockedCount;
  final List<String> blockedElements;
  final bool nightMode;
  final bool desktopMode;
  final int textSizeStep;
  final VoidCallback onCopyUrl;
  final VoidCallback onShare;
  final VoidCallback onOpenBrowser;
  final VoidCallback onViewSource;
  final VoidCallback onFindInPage;
  final VoidCallback onToggleAdBlock;
  final VoidCallback onPickElement;
  final VoidCallback onResetRules;
  final VoidCallback onClearCookies;
  final VoidCallback onFullscreen;
  final VoidCallback onUserAgent;
  final VoidCallback onNetworkLog;
  final VoidCallback onNightMode;
  final VoidCallback onTextSize;
  final VoidCallback onDesktopMode;
  final VoidCallback onTranslate;
  final VoidCallback onDownload;
  final VoidCallback onBookmark;
  final VoidCallback onQrCode;
  final VoidCallback onOrientation;
  final VoidCallback onIncognito;
  final VoidCallback onCloseWebView;
  final bool incognito;

  const _MoreSheet({
    required this.adEnabled,
    required this.blockedCount,
    required this.blockedElements,
    required this.nightMode,
    required this.desktopMode,
    required this.textSizeStep,
    required this.incognito,
    required this.onCopyUrl,
    required this.onShare,
    required this.onOpenBrowser,
    required this.onViewSource,
    required this.onFindInPage,
    required this.onToggleAdBlock,
    required this.onPickElement,
    required this.onResetRules,
    required this.onClearCookies,
    required this.onFullscreen,
    required this.onUserAgent,
    required this.onNetworkLog,
    required this.onNightMode,
    required this.onTextSize,
    required this.onDesktopMode,
    required this.onTranslate,
    required this.onDownload,
    required this.onBookmark,
    required this.onQrCode,
    required this.onOrientation,
    required this.onIncognito,
    required this.onCloseWebView,
  });

  @override
  State<_MoreSheet> createState() => _MoreSheetState();
}

class _MoreSheetState extends State<_MoreSheet> {
  final PageController _pageCtrl = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final iconColor = isDark ? Colors.white : Colors.black87;
    final labelColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    Widget item(IconData? icon, String label, VoidCallback onTap, {Color? accent, bool highlight = false, String? svgAsset}) {
      final effectiveColor = highlight
          ? (accent ?? (isDark ? Colors.greenAccent.shade400 : Colors.green.shade600))
          : (accent ?? iconColor);
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 64,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 64,
                height: 44,
                child: Center(
                  child: svgAsset != null
                      ? SvgPicture.asset(
                          svgAsset,
                          width: 24,
                          height: 24,
                          colorFilter: ColorFilter.mode(effectiveColor, BlendMode.srcIn),
                        )
                      : Icon(icon, size: 24, color: effectiveColor),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: highlight ? effectiveColor : (accent ?? labelColor),
                  fontWeight: highlight ? FontWeight.w600 : FontWeight.w400,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      );
    }

    // ── Build pages ──────────────────────────────────────────────────────────
    Widget buildPage(List<Widget> items) {
      final rows = <Widget>[];
      for (int i = 0; i < items.length; i += 5) {
        final rowItems = items.sublist(i, (i + 5).clamp(0, items.length));
        while (rowItems.length < 5) rowItems.add(const SizedBox(width: 62));
        rows.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: rowItems,
            ),
          ),
        );
      }
      return Column(children: rows);
    }

    final page1 = buildPage([
      item(null, 'Chercher', widget.onFindInPage, svgAsset: 'assets/icons/search-in-page.svg'),
      item(Icons.copy_rounded, 'Copier URL', widget.onCopyUrl),
      item(null, 'Partager', widget.onShare, svgAsset: 'assets/icons/share-2.svg'),
      item(null, 'Navigateur', widget.onOpenBrowser, svgAsset: 'assets/icons/globe.svg'),
      item(null, 'Source', widget.onViewSource, svgAsset: 'assets/icons/code.svg'),
      item(null, 'Plein écran', widget.onFullscreen, svgAsset: 'assets/icons/maximize.svg'),
      item(null, 'Cookies', widget.onClearCookies, svgAsset: 'assets/icons/trash-2.svg'),
      item(null, 'User-Agent', widget.onUserAgent, svgAsset: 'assets/icons/user-agent.svg'),
      item(null, 'Réseau', widget.onNetworkLog, svgAsset: 'assets/icons/network-log.svg'),
      item(Icons.info_outline_rounded, 'À propos', () => Navigator.pop(context)),
    ]);

    final page2 = buildPage([
      item(
        null,
        widget.adEnabled
            ? (widget.blockedCount > 0 ? '${widget.blockedCount} bloqués' : 'AdBlock ON')
            : 'AdBlock OFF',
        widget.onToggleAdBlock,
        svgAsset: 'assets/icons/block-ads.svg',
        accent: widget.adEnabled ? Colors.greenAccent.shade400 : Colors.grey,
        highlight: widget.adEnabled,
      ),
      item(null, 'Sélect. élém.', widget.onPickElement, svgAsset: 'assets/icons/edit-2.svg', accent: Colors.orange),
      item(null, 'Masquer élém.', widget.onPickElement, svgAsset: 'assets/icons/eye-slash.svg'),
      item(null, 'Bloquer dom.', widget.onPickElement, svgAsset: 'assets/icons/minus-circle.svg', accent: Colors.redAccent),
      item(Icons.refresh_rounded, 'Réinitialiser', widget.onResetRules),
      item(
        null,
        widget.blockedElements.isEmpty ? 'Aucun bloqué' : '${widget.blockedElements.length} règles',
        () {},
        svgAsset: 'assets/icons/layers.svg',
      ),
      item(null, 'Nuit', widget.onNightMode,
          svgAsset: 'assets/icons/moon.svg',
          highlight: widget.nightMode,
          accent: widget.nightMode ? Colors.indigo.shade300 : null),
      item(null, 'Statistiques', () => Navigator.pop(context), svgAsset: 'assets/icons/activity.svg'),
      item(null, 'Réglages', () => Navigator.pop(context), svgAsset: 'assets/icons/settings.svg'),
      item(null, 'Whitelist', () => Navigator.pop(context), svgAsset: 'assets/icons/block-ads.svg'),
    ]);

    final textSizeLabels = ['Texte', 'Texte+', 'Texte++'];
    final page3 = buildPage([
      item(null, textSizeLabels[widget.textSizeStep], widget.onTextSize,
          svgAsset: 'assets/icons/text-size.svg',
          highlight: widget.textSizeStep > 0,
          accent: widget.textSizeStep > 0 ? Colors.blue.shade400 : null),
      item(Icons.brightness_6_rounded, 'Luminosité', () => Navigator.pop(context)),
      item(null, 'Orientation', widget.onOrientation, svgAsset: 'assets/icons/orientation.svg'),
      item(null, 'Télécharger', widget.onDownload, svgAsset: 'assets/icons/download.svg'),
      item(null, 'Favoris', widget.onBookmark, svgAsset: 'assets/icons/star.svg'),
      item(null, 'Accueil', () => Navigator.pop(context), svgAsset: 'assets/icons/home.svg'),
      item(null, 'QR Code', widget.onQrCode, svgAsset: 'assets/icons/qr-code.svg'),
      item(null, 'Traduction', widget.onTranslate, svgAsset: 'assets/icons/translate.svg'),
      item(null, 'Bureau', widget.onDesktopMode,
          svgAsset: 'assets/icons/desktop.svg',
          highlight: widget.desktopMode,
          accent: widget.desktopMode ? Colors.blue.shade400 : null),
      item(null, 'Incognito', widget.onIncognito,
          svgAsset: 'assets/icons/ghost.svg',
          highlight: widget.incognito,
          accent: widget.incognito ? Colors.deepPurple.shade300 : null),
    ]);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 14),

            // PageView — 3 pages
            SizedBox(
              height: 190,
              child: PageView(
                controller: _pageCtrl,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: page1),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: page2),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: page3),
                ],
              ),
            ),

            // Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 8),
                  width: _page == i ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _page == i
                        ? (isDark ? Colors.white : Colors.black87)
                        : (isDark ? Colors.white.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.2)),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),

            // Divider
            Divider(
              height: 1,
              thickness: 0.5,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.07),
            ),

            // Bottom row: power + down
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Power = close WebView entirely
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      widget.onCloseWebView();
                    },
                    child: Icon(
                      Icons.power_settings_new_rounded,
                      size: 26,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  // Down = dismiss sheet
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 30,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── AdBlock sheet ────────────────────────────────────────────────────────────

class _AdBlockSheet extends StatelessWidget {
  final bool enabled;
  final int blockedCount;
  final void Function(bool) onToggle;
  final VoidCallback onReset;

  const _AdBlockSheet({
    required this.enabled,
    required this.blockedCount,
    required this.onToggle,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF2C2C2E) : Colors.white;

    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.2)
                  : Colors.black.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(
              children: [
                Icon(
                  Icons.shield_rounded,
                  color: enabled ? Colors.greenAccent : Colors.grey,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Text(
                  'AdBlock',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const Spacer(),
                if (blockedCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.green.shade800.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$blockedCount bloqués',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? Colors.greenAccent.shade400
                            : Colors.green.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Divider(
            height: 1,
            thickness: 0.5,
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.07),
          ),
          SwitchListTile(
            title: Text(
              "Activer l'AdBlock",
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 14,
              ),
            ),
            subtitle: Text(
              'Bloque les domaines publicitaires connus et injecte un filtre CSS/DOM',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
            value: enabled,
            onChanged: onToggle,
            activeColor: Colors.greenAccent,
          ),
          ListTile(
            leading: Icon(
              Icons.refresh_rounded,
              size: 20,
              color: isDark ? Colors.white : Colors.black87,
            ),
            title: Text(
              'Réinitialiser le compteur',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            onTap: onReset,
            dense: true,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─── Desktop InAppBrowser wrapper ─────────────────────────────────────────────

class MyInAppBrowser extends InAppBrowser {
  BuildContext context;
  void Function(InAppWebViewController) controller;
  void Function(int) onProgress;

  MyInAppBrowser({
    required this.context,
    required this.controller,
    required this.onProgress,
  }) : super(webViewEnvironment: webViewEnvironment);

  @override
  Future onBrowserCreated() async => controller.call(webViewController!);

  @override
  void onProgressChanged(progress) => onProgress.call(progress);

  @override
  void onExit() => Navigator.pop(context);

  @override
  void onLoadStop(url) async {
    if (webViewController != null) {
      final ua =
          await webViewController!.evaluateJavascript(source: 'navigator.userAgent') ??
          '';
      await MClient.setCookie(url.toString(), ua, webViewController);
    }
  }

  @override
  Future<NavigationActionPolicy> shouldOverrideUrlLoading(action) async {
    final uri = action.request.url!;
    if (!['http', 'https', 'file', 'chrome', 'data', 'javascript', 'about']
        .contains(uri.scheme)) {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        return NavigationActionPolicy.CANCEL;
      }
    }
    return NavigationActionPolicy.ALLOW;
  }
}
