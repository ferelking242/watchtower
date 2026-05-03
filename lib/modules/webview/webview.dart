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

// ─── AdBlock domain blocklist ─────────────────────────────────────────────────

const _kBlockedDomains = [
  'doubleclick.net',
  'googlesyndication.com',
  'googleadservices.com',
  'googletagservices.com',
  'googletagmanager.com',
  'ads.yahoo.com',
  'adservice.google.com',
  'amazon-adsystem.com',
  'adnxs.com',
  'taboola.com',
  'outbrain.com',
  'popads.net',
  'adsterra.com',
  'propellerads.com',
  'revcontent.com',
  'media.net',
  'yandexadexchange.net',
  'smartadserver.com',
  'rubiconproject.com',
  'openx.net',
  'criteo.com',
  'adsrvr.org',
  'bidswitch.net',
  'pubmatic.com',
  'appnexus.com',
  'advertising.com',
  'adroll.com',
  'quantserve.com',
  'scorecardresearch.com',
  'trafficjunky.net',
  'exoclick.com',
  'juicyads.com',
  'ero-advertising.com',
  'plugrush.com',
  'clickadu.com',
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
    [class*="google-ads"],[class*="google_ads"],[id*="google_ads"],
    [class*="adsense"],[id*="adsense"],
    [class*="adsbygoogle"],[id*="adsbygoogle"],
    [id^="div-gpt-ad"],[id^="gpt-ad"],
    iframe[src*="doubleclick"],iframe[src*="googlesyndication"],
    iframe[src*="adnxs"],iframe[src*="ads."],iframe[src*="/ads/"],
    iframe[src*="adservice"],iframe[src*="pagead"],
    div[id^="ad_"],div[id^="ads_"],div[class^="ad_"],div[class^="ads_"],
    ins.adsbygoogle,
    #ad,#ads,#banner-ad,#sponsor,#sponsored,#popup,#interstitial {
      display:none!important;
      visibility:hidden!important;
      opacity:0!important;
      pointer-events:none!important;
      height:0!important;
      max-height:0!important;
      overflow:hidden!important;
    }
  `;
  (document.head || document.documentElement).appendChild(style);

  // ── Block window.open / popups ───────────────────────────────────────────────
  try { window.open = function() { return null; }; } catch(e) {}
  try { window.alert = function() {}; } catch(e) {}

  // ── DOM cleaning ─────────────────────────────────────────────────────────────
  var adSelectors = [
    'iframe[src*="ads"]','iframe[src*="doubleclick"]',
    'iframe[src*="googlesyndication"]','iframe[src*="adnxs"]',
    'iframe[src*="adservice"]','iframe[src*="pagead"]',
    'ins.adsbygoogle','[id^="div-gpt-ad"]',
    '[class*="overlay-ad"]','[class*="modal-ad"]',
    '[class*="gdpr"]','[class*="consent"]','[class*="cookie-banner"]',
    '[class*="newsletter-popup"]','[data-ad]','[data-ads]','[data-adunit]',
    '.adsbygoogle','#cookie-banner','#gdpr-overlay','#consent-modal'
  ];

  function removeAdNodes() {
    adSelectors.forEach(function(sel) {
      try {
        document.querySelectorAll(sel).forEach(function(el) {
          try { el.remove(); } catch(e) {}
        });
      } catch(e) {}
    });
    // Also remove by pattern matching id/class
    document.querySelectorAll('div,section,aside').forEach(function(el) {
      try {
        var c = (el.className||'').toLowerCase();
        var i = (el.id||'').toLowerCase();
        if (/\bad\b|^ads$|advert|adsense|adsbygoogle|sponsor|popup|gdpr|consent|cookie.banner|interstitial/.test(c+' '+i)) {
          if (el.offsetHeight < 400 || /popup|modal|interstitial/.test(c+' '+i)) {
            el.style.cssText = 'display:none!important;height:0!important;overflow:hidden!important;';
          }
        }
      } catch(e) {}
    });
  }

  removeAdNodes();
  document.addEventListener('DOMContentLoaded', removeAdNodes);
  setTimeout(removeAdNodes, 500);
  setTimeout(removeAdNodes, 1500);
  setTimeout(removeAdNodes, 4000);
  setTimeout(removeAdNodes, 8000);

  // ── MutationObserver — catch dynamic ads ────────────────────────────────────
  var observer = new MutationObserver(function(mutations) {
    mutations.forEach(function(m) {
      m.addedNodes.forEach(function(node) {
        if (node.nodeType !== 1) return;
        var c = (node.className||'').toLowerCase();
        var i = (node.id||'').toLowerCase();
        var src = (node.src||node.getAttribute&&node.getAttribute('src')||'').toLowerCase();
        if (/\bad\b|^ads$|advert|adsense|adsbygoogle|sponsor|popup|gdpr|consent|doubleclick|googlesyndication/.test(c+' '+i+' '+src)) {
          try { node.remove(); } catch(e) {
            try { node.style.display='none'; } catch(e2) {}
          }
        }
        // Recurse into added subtrees
        try {
          node.querySelectorAll && adSelectors.forEach(function(sel) {
            node.querySelectorAll(sel).forEach(function(child) {
              try { child.remove(); } catch(e) {}
            });
          });
        } catch(e) {}
      });
    });
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
    if (Platform.isLinux || Platform.isWindows) {
      _runWebViewDesktop();
    } else {
      setState(() => isNotWebviewWindow = true);
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    if (Platform.isLinux) {
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

    if (Platform.isLinux) {
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
      builder: (_) => _MoreSheet(
        adEnabled: _adBlockEnabled,
        blockedCount: _blockedCount,
        blockedElements: _blockedElements,
        onCopyUrl: () {
          Navigator.pop(context);
          Clipboard.setData(ClipboardData(text: _url));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('URL copiée'), duration: Duration(seconds: 2)),
          );
        },
        onShare: () {
          Navigator.pop(context);
          final box = context.findRenderObject() as RenderBox?;
          SharePlus.instance.share(
            ShareParams(
              text: _url,
              sharePositionOrigin: box!.localToGlobal(Offset.zero) & box.size,
            ),
          );
        },
        onOpenBrowser: () {
          Navigator.pop(context);
          InAppBrowser.openWithSystemBrowser(url: WebUri(_url));
        },
        onViewSource: () {
          Navigator.pop(context);
          _webViewController?.evaluateJavascript(
            source: "document.documentElement.outerHTML",
          );
        },
        onFindInPage: () {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Recherche dans la page non disponible'), duration: Duration(seconds: 2)),
          );
        },
        onToggleAdBlock: () {
          setState(() => _adBlockEnabled = !_adBlockEnabled);
          if (_adBlockEnabled) _injectJs();
          Navigator.pop(context);
        },
        onPickElement: () {
          Navigator.pop(context);
          setState(() => _pickerMode = true);
          _activatePicker();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tap sur un élément pour le bloquer'),
              duration: Duration(seconds: 4),
            ),
          );
        },
        onResetRules: () {
          setState(() {
            _blockedCount = 0;
            _blockedElements.clear();
          });
          Navigator.pop(context);
        },
        onClearCookies: () {
          Navigator.pop(context);
          CookieManager.instance().deleteAllCookies();
          MClient.deleteAllCookies(_url);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cookies effacés'), duration: Duration(seconds: 2)),
          );
        },
        onFullscreen: () {
          Navigator.pop(context);
          _snap = _PanelSnap.full;
          _animateTo(1.0);
        },
        onUserAgent: () {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Paramètre agent utilisateur dans les réglages'), duration: Duration(seconds: 2)),
          );
        },
        onNetworkLog: () {
          Navigator.pop(context);
          _showAdMenu();
        },
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Desktop: simple screen
    if (!isNotWebviewWindow && (Platform.isLinux || Platform.isWindows)) {
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

    final screenH = MediaQuery.of(context).size.height;
    final panelH = screenH * _currentFraction;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.black.withValues(
        alpha: (0.55 * _currentFraction).clamp(0.0, 0.55),
      ),
      child: Stack(
        children: [
          // Tap outside to close when not fullscreen
          if (_snap != _PanelSnap.full)
            GestureDetector(
              onTap: _dismiss,
              behavior: HitTestBehavior.opaque,
              child: const SizedBox.expand(),
            ),

          // Panel
          Align(
            alignment: Alignment.bottomCenter,
            child: AnimatedContainer(
              duration: Duration.zero,
              height: panelH,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: Scaffold(
                  backgroundColor: isDark
                      ? const Color(0xFF1C1C1E)
                      : Colors.white,
                  // ── Top: drag handle + address bar ─────────────────────
                  appBar: PreferredSize(
                    preferredSize: const Size.fromHeight(86),
                    child: GestureDetector(
                      onVerticalDragStart: _onDragStart,
                      onVerticalDragUpdate: _onDragUpdate,
                      onVerticalDragEnd: _onDragEnd,
                      behavior: HitTestBehavior.opaque,
                      child: _BrowserHeader(
                        url: _url,
                        title: _title,
                        progress: _progress,
                        isDark: isDark,
                        cs: cs,
                        adEnabled: _adBlockEnabled,
                        blockedCount: _blockedCount,
                        showFooter: _showFooter,
                        onToggleFooter: () => setState(() => _showFooter = !_showFooter),
                        onRefresh: () => _webViewController?.reload(),
                      ),
                    ),
                  ),
                  // ── WebView body ────────────────────────────────────────
                  body: !Platform.isWindows
                      ? WillPopScope(
                          onWillPop: () async {
                            if (await _webViewController?.canGoBack() ?? false) {
                              _webViewController?.goBack();
                            } else {
                              _dismiss();
                            }
                            return false;
                          },
                          child: InAppWebView(
                            webViewEnvironment: webViewEnvironment,
                            initialUrlRequest: URLRequest(url: WebUri(widget.url)),
                            initialSettings: InAppWebViewSettings(
                              isInspectable: kDebugMode,
                              useShouldOverrideUrlLoading: true,
                              useShouldInterceptRequest:
                                  _adBlockEnabled && Platform.isAndroid,
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
                            shouldInterceptRequest: Platform.isAndroid
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
                          ),
                        )
                      : const SizedBox.shrink(),
                  // ── Bottom toolbar ──────────────────────────────────────
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
              ),
            ),
          ),
        ],
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
    required this.onToggleFooter,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final secure = _isSecure(url);
    final barBg = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7);
    final displayTitle = title.isNotEmpty ? title : _displayHost(url);
    final ghostColor = showFooter
        ? (isDark ? Colors.white : Colors.black87)
        : (isDark ? Colors.white.withValues(alpha: 0.35) : Colors.black38);

    return Container(
      color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 10),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.2)
                    : Colors.black.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Address bar row
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
            child: Row(
              children: [
                // Footer toggle icon
                GestureDetector(
                  onTap: onToggleFooter,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                    child: Icon(
                      showFooter
                          ? Icons.tab_rounded
                          : Icons.tab_unselected_rounded,
                      size: 22,
                      color: ghostColor,
                    ),
                  ),
                ),
                const SizedBox(width: 4),

                // Address pill — shows page title, long press = copy URL
                Expanded(
                  child: GestureDetector(
                    onLongPress: () {
                      Clipboard.setData(ClipboardData(text: url));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Lien copié'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: barBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        children: [
                          Icon(
                            secure
                                ? Icons.lock_rounded
                                : Icons.info_outline_rounded,
                            size: 13,
                            color: secure
                                ? (isDark
                                      ? Colors.greenAccent.shade400
                                      : Colors.green.shade600)
                                : (isDark
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade600),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              displayTitle,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white : Colors.black87,
                                overflow: TextOverflow.ellipsis,
                              ),
                              maxLines: 1,
                              textAlign: TextAlign.center,
                            ),
                          ),
                          // AdBlock indicator (if active and blocked > 0)
                          if (adEnabled && blockedCount > 0) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.shade700.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.shield_rounded,
                                    size: 10,
                                    color: isDark
                                        ? Colors.greenAccent.shade400
                                        : Colors.green.shade600,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    blockedCount > 99 ? '99+' : '$blockedCount',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? Colors.greenAccent.shade400
                                          : Colors.green.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),

                // Refresh button (right)
                const SizedBox(width: 4),
                _ToolbarBtn(
                  icon: Icons.refresh_rounded,
                  size: 20,
                  onTap: onRefresh,
                  isDark: isDark,
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

          // Divider
          Divider(
            height: 1,
            thickness: 0.5,
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.08),
          ),
        ],
      ),
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
                    icon: Icons.arrow_back_ios_new_rounded,
                    size: 18,
                    onTap: canGoBack ? onBack : null,
                    isDark: isDark,
                    disabledColor: inactiveColor,
                  ),
                  // Forward
                  _ToolbarBtn(
                    icon: Icons.arrow_forward_ios_rounded,
                    size: 18,
                    onTap: canGoForward ? onForward : null,
                    isDark: isDark,
                    disabledColor: inactiveColor,
                  ),
                  // Home
                  _ToolbarBtn(
                    icon: Icons.home_rounded,
                    size: 22,
                    onTap: onHome,
                    isDark: isDark,
                  ),
                  // Tabs / onglets
                  _ToolbarBtn(
                    icon: Icons.tab_rounded,
                    size: 21,
                    onTap: onTabs,
                    isDark: isDark,
                  ),
                  // Menu (3 barres / hamburger)
                  _ToolbarBtn(
                    icon: Icons.menu_rounded,
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
  final IconData icon;
  final double size;
  final VoidCallback? onTap;
  final bool isDark;
  final Color? disabledColor;

  const _ToolbarBtn({
    required this.icon,
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
        child: Icon(icon, size: size, color: color),
      ),
    );
  }
}

// ─── More options sheet (Via-style, 3 swipeable pages) ────────────────────────

class _MoreSheet extends StatefulWidget {
  final bool adEnabled;
  final int blockedCount;
  final List<String> blockedElements;
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

  const _MoreSheet({
    required this.adEnabled,
    required this.blockedCount,
    required this.blockedElements,
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
    final iconBg = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7);
    final iconColor = isDark ? Colors.white : Colors.black87;
    final labelColor = isDark ? Colors.grey.shade300 : Colors.grey.shade700;

    Widget item(IconData icon, String label, VoidCallback onTap, {Color? accent, bool highlight = false}) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 62,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: highlight
                      ? (accent ?? Colors.greenAccent).withValues(alpha: 0.18)
                      : iconBg,
                  borderRadius: BorderRadius.circular(14),
                  border: highlight
                      ? Border.all(color: accent ?? Colors.greenAccent, width: 1.5)
                      : null,
                ),
                child: Icon(icon, size: 22, color: accent ?? iconColor),
              ),
              const SizedBox(height: 5),
              Text(
                label,
                style: TextStyle(fontSize: 9.5, color: accent ?? labelColor, fontWeight: FontWeight.w500),
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
      item(Icons.search_rounded, 'Chercher', widget.onFindInPage),
      item(Icons.copy_rounded, 'Copier URL', widget.onCopyUrl),
      item(Icons.ios_share_rounded, 'Partager', widget.onShare),
      item(Icons.open_in_browser_rounded, 'Navigateur', widget.onOpenBrowser),
      item(Icons.code_rounded, 'Source', widget.onViewSource),
      item(Icons.fullscreen_rounded, 'Plein écran', widget.onFullscreen),
      item(Icons.delete_sweep_rounded, 'Cookies', widget.onClearCookies),
      item(Icons.phone_android_rounded, 'User-Agent', widget.onUserAgent),
      item(Icons.wifi_rounded, 'Réseau', widget.onNetworkLog),
      item(Icons.info_outline_rounded, 'À propos', () => Navigator.pop(context)),
    ]);

    final page2 = buildPage([
      item(
        widget.adEnabled ? Icons.shield_rounded : Icons.shield_outlined,
        widget.adEnabled
            ? (widget.blockedCount > 0 ? '${widget.blockedCount} bloqués' : 'AdBlock ON')
            : 'AdBlock OFF',
        widget.onToggleAdBlock,
        accent: widget.adEnabled ? Colors.greenAccent.shade400 : Colors.grey,
        highlight: widget.adEnabled,
      ),
      item(Icons.ads_click_rounded, 'Sélect. élément', widget.onPickElement, accent: Colors.orange),
      item(Icons.visibility_off_rounded, 'Masquer élément', widget.onPickElement),
      item(Icons.block_rounded, 'Bloquer domaine', widget.onPickElement, accent: Colors.redAccent),
      item(Icons.refresh_rounded, 'Réinitialiser', widget.onResetRules),
      item(
        Icons.list_rounded,
        widget.blockedElements.isEmpty
            ? 'Aucun bloqué'
            : '${widget.blockedElements.length} règles',
        () {},
      ),
      item(Icons.check_circle_outline_rounded, 'Whitelist site', () => Navigator.pop(context)),
      item(Icons.bar_chart_rounded, 'Statistiques', () => Navigator.pop(context)),
      item(Icons.bug_report_rounded, 'Déboguer', () => Navigator.pop(context)),
      item(Icons.settings_rounded, 'Réglages', () => Navigator.pop(context)),
    ]);

    final page3 = buildPage([
      item(Icons.text_fields_rounded, 'Texte', () => Navigator.pop(context)),
      item(Icons.brightness_6_rounded, 'Luminosité', () => Navigator.pop(context)),
      item(Icons.screen_rotation_rounded, 'Orientation', () => Navigator.pop(context)),
      item(Icons.download_rounded, 'Télécharger', () => Navigator.pop(context)),
      item(Icons.bookmark_rounded, 'Favoris', () => Navigator.pop(context)),
      item(Icons.home_rounded, 'Accueil', () => Navigator.pop(context)),
      item(Icons.qr_code_rounded, 'QR Code', () => Navigator.pop(context)),
      item(Icons.save_rounded, 'Sauvegarder', () => Navigator.pop(context)),
      item(Icons.translate_rounded, 'Traduction', () => Navigator.pop(context)),
      item(Icons.build_rounded, 'Outils', () => Navigator.pop(context)),
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
            // Handle
            Center(
              child: Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.2)
                      : Colors.black.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

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
                  // Power = close WebView
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
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
