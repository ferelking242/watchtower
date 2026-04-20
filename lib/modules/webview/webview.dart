import 'dart:async';
import 'dart:io';
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
  var style = document.createElement('style');
  style.textContent = `
    .ad,.ads,.banner,.sponsor,.popup,.advertisement,.ad-container,
    .ad-wrapper,.ad-unit,.ads-container,
    iframe[src*="ads"],iframe[src*="doubleclick"],
    iframe[src*="googlesyndication"],iframe[src*="adnxs"],
    div[id*="google_ads"],div[class*="google-ads"],
    div[id*="advert"],div[class*="advert"],
    #ad,#ads,#banner,#sponsor {
      display:none!important;visibility:hidden!important;pointer-events:none!important;
    }
  `;
  if(document.head) document.head.appendChild(style);
  function clean() {
    ['iframe[src*="ads"]','iframe[src*="doubleclick"]',
     'iframe[src*="googlesyndication"]','[class*="overlay"]',
     '[class*="modal-ad"]'].forEach(function(sel){
      try{ document.querySelectorAll(sel).forEach(function(el){el.remove();}); }catch(e){}
    });
  }
  clean();
  document.addEventListener('DOMContentLoaded',clean);
  setTimeout(clean,1500);
  setTimeout(clean,4000);
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
      builder: (_) => _MoreSheet(
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
        onClearCookies: () {
          Navigator.pop(context);
          CookieManager.instance().deleteAllCookies();
          MClient.deleteAllCookies(_url);
        },
        onCopyUrl: () {
          Navigator.pop(context);
          Clipboard.setData(ClipboardData(text: _url));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('URL copiée'), duration: Duration(seconds: 2)),
          );
        },
        onAdBlock: () {
          Navigator.pop(context);
          _showAdMenu();
        },
        adEnabled: _adBlockEnabled,
        blockedCount: _blockedCount,
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
                        progress: _progress,
                        isDark: isDark,
                        cs: cs,
                        adEnabled: _adBlockEnabled,
                        blockedCount: _blockedCount,
                        onClose: _dismiss,
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
                            onWebViewCreated: (c) => _webViewController = c,
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
                  bottomNavigationBar: _BrowserToolbar(
                    isDark: isDark,
                    cs: cs,
                    canGoBack: _canGoback,
                    canGoForward: _canGoForward,
                    onBack: () => _webViewController?.goBack(),
                    onForward: () => _webViewController?.goForward(),
                    onRefresh: () => _webViewController?.reload(),
                    onShare: () {
                      final box = context.findRenderObject() as RenderBox?;
                      SharePlus.instance.share(
                        ShareParams(
                          text: _url,
                          sharePositionOrigin:
                              box!.localToGlobal(Offset.zero) & box.size,
                        ),
                      );
                    },
                    onMore: _showMoreMenu,
                  ),
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
  final double progress;
  final bool isDark;
  final ColorScheme cs;
  final bool adEnabled;
  final int blockedCount;
  final VoidCallback onClose;

  const _BrowserHeader({
    required this.url,
    required this.progress,
    required this.isDark,
    required this.cs,
    required this.adEnabled,
    required this.blockedCount,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final secure = _isSecure(url);
    final host = _displayHost(url);
    final barBg = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7);

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
            padding: const EdgeInsets.fromLTRB(12, 0, 8, 10),
            child: Row(
              children: [
                // Address pill
                Expanded(
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
                            host.isEmpty ? url : host,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white : Colors.black87,
                              overflow: TextOverflow.ellipsis,
                            ),
                            maxLines: 1,
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

                // Close button
                const SizedBox(width: 4),
                _ToolbarBtn(
                  icon: Icons.close_rounded,
                  size: 18,
                  onTap: onClose,
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
  final VoidCallback onRefresh;
  final VoidCallback onShare;
  final VoidCallback onMore;

  const _BrowserToolbar({
    required this.isDark,
    required this.cs,
    required this.canGoBack,
    required this.canGoForward,
    required this.onBack,
    required this.onForward,
    required this.onRefresh,
    required this.onShare,
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
                  // Refresh
                  _ToolbarBtn(
                    icon: Icons.refresh_rounded,
                    size: 22,
                    onTap: onRefresh,
                    isDark: isDark,
                  ),
                  // Share
                  _ToolbarBtn(
                    icon: Icons.ios_share_rounded,
                    size: 20,
                    onTap: onShare,
                    isDark: isDark,
                  ),
                  // More
                  _ToolbarBtn(
                    icon: Icons.more_horiz_rounded,
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

// ─── More options bottom sheet ────────────────────────────────────────────────

class _MoreSheet extends StatelessWidget {
  final VoidCallback onShare;
  final VoidCallback onOpenBrowser;
  final VoidCallback onClearCookies;
  final VoidCallback onCopyUrl;
  final VoidCallback onAdBlock;
  final bool adEnabled;
  final int blockedCount;

  const _MoreSheet({
    required this.onShare,
    required this.onOpenBrowser,
    required this.onClearCookies,
    required this.onCopyUrl,
    required this.onAdBlock,
    required this.adEnabled,
    required this.blockedCount,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF2C2C2E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
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
          ),
          // Quick actions row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _QuickAction(
                  icon: Icons.copy_rounded,
                  label: 'Copier',
                  onTap: onCopyUrl,
                  isDark: isDark,
                ),
                _QuickAction(
                  icon: Icons.ios_share_rounded,
                  label: 'Partager',
                  onTap: onShare,
                  isDark: isDark,
                ),
                _QuickAction(
                  icon: Icons.open_in_browser_rounded,
                  label: 'Navigateur',
                  onTap: onOpenBrowser,
                  isDark: isDark,
                ),
                _QuickAction(
                  icon: adEnabled ? Icons.shield_rounded : Icons.shield_outlined,
                  label: adEnabled
                      ? (blockedCount > 0 ? '$blockedCount bloqués' : 'AdBlock')
                      : 'AdBlock off',
                  onTap: onAdBlock,
                  isDark: isDark,
                  accentColor: adEnabled ? Colors.greenAccent.shade400 : null,
                ),
              ],
            ),
          ),
          // Divider
          Divider(
            height: 1,
            thickness: 0.5,
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.07),
            indent: 16,
            endIndent: 16,
          ),
          // List actions
          _MoreTile(
            icon: Icons.delete_sweep_rounded,
            label: 'Effacer les cookies',
            sublabel: 'Supprime les cookies de ce site',
            onTap: onClearCookies,
            isDark: isDark,
            textColor: textColor,
            subColor: subColor,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDark;
  final Color? accentColor;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isDark,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final btnBg = isDark ? const Color(0xFF3A3A3C) : const Color(0xFFF2F2F7);
    final iconColor = accentColor ?? (isDark ? Colors.white : Colors.black87);

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: btnBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 22, color: iconColor),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _MoreTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? sublabel;
  final VoidCallback onTap;
  final bool isDark;
  final Color textColor;
  final Color subColor;

  const _MoreTile({
    required this.icon,
    required this.label,
    this.sublabel,
    required this.onTap,
    required this.isDark,
    required this.textColor,
    required this.subColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, size: 20, color: textColor),
      title: Text(label, style: TextStyle(fontSize: 14, color: textColor)),
      subtitle: sublabel != null
          ? Text(sublabel!, style: TextStyle(fontSize: 11, color: subColor))
          : null,
      onTap: onTap,
      dense: true,
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
