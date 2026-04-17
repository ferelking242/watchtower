import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
          final ua2 = await _desktopWebview!.evaluateJavaScript("navigator.userAgent") ?? "";
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
      target = _snap == _PanelSnap.full
          ? _PanelSnap.half
          : _PanelSnap.mini;
    } else if (velocity < -600) {
      target = _snap == _PanelSnap.mini
          ? _PanelSnap.half
          : _PanelSnap.full;
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

    return Material(
      color: Colors.black.withValues(
        alpha: (0.6 * _currentFraction).clamp(0.0, 0.6),
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
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(18),
                ),
                child: Scaffold(
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  body: Column(
                    children: [
                      // Handle area (draggable)
                      GestureDetector(
                        onVerticalDragStart: _onDragStart,
                        onVerticalDragUpdate: _onDragUpdate,
                        onVerticalDragEnd: _onDragEnd,
                        behavior: HitTestBehavior.opaque,
                        child: _Header(
                          title: _title,
                          url: _url,
                          progress: _progress,
                          canGoBack: _canGoback,
                          canGoForward: _canGoForward,
                          adEnabled: _adBlockEnabled,
                          blocked: _blockedCount,
                          onBack: () => _webViewController?.goBack(),
                          onForward: () => _webViewController?.goForward(),
                          onRefresh: () => _webViewController?.reload(),
                          onClose: _dismiss,
                          onAdBlock: _showAdMenu,
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
                          onOpenBrowser: () => InAppBrowser.openWithSystemBrowser(
                            url: WebUri(_url),
                          ),
                          onClearCookies: () {
                            CookieManager.instance().deleteAllCookies();
                            MClient.deleteAllCookies(_url);
                          },
                        ),
                      ),

                      // WebView
                      if (!Platform.isWindows)
                        Expanded(
                          child: WillPopScope(
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
                                    ref.read(userAgentStateProvider) == defaultUserAgent
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
                                if (mounted) setState(() => _progress = progress / 100);
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
                                if (policy == NavigationActionPolicy.CANCEL) return policy;
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
                                        if (mounted) setState(() => _blockedCount++);
                                        return WebResourceResponse(
                                          contentType: 'text/plain',
                                          data: Uint8List(0),
                                        );
                                      }
                                      return null;
                                    }
                                  : null,
                            ),
                          ),
                        ),
                    ],
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

// ─── Header ───────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final String title;
  final String url;
  final double progress;
  final bool canGoBack;
  final bool canGoForward;
  final bool adEnabled;
  final int blocked;
  final VoidCallback onBack;
  final VoidCallback onForward;
  final VoidCallback onRefresh;
  final VoidCallback onClose;
  final VoidCallback onAdBlock;
  final VoidCallback onShare;
  final VoidCallback onOpenBrowser;
  final VoidCallback onClearCookies;

  const _Header({
    required this.title,
    required this.url,
    required this.progress,
    required this.canGoBack,
    required this.canGoForward,
    required this.adEnabled,
    required this.blocked,
    required this.onBack,
    required this.onForward,
    required this.onRefresh,
    required this.onClose,
    required this.onAdBlock,
    required this.onShare,
    required this.onOpenBrowser,
    required this.onClearCookies,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Handle bar
        Container(
          width: 36,
          height: 4,
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(2),
          ),
        ),

        // Title + URL
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 2),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        overflow: TextOverflow.ellipsis,
                      ),
                      maxLines: 1,
                    ),
                    Text(
                      url,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                        overflow: TextOverflow.ellipsis,
                      ),
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Controls
        SizedBox(
          height: 42,
          child: Row(
            children: [
              IconButton(
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 17,
                  color: canGoBack ? null : Colors.grey.shade700,
                ),
                onPressed: canGoBack ? onBack : null,
                padding: const EdgeInsets.all(8),
              ),
              IconButton(
                icon: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 17,
                  color: canGoForward ? null : Colors.grey.shade700,
                ),
                onPressed: canGoForward ? onForward : null,
                padding: const EdgeInsets.all(8),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 18),
                onPressed: onRefresh,
                padding: const EdgeInsets.all(8),
              ),
              const Spacer(),

              // AdBlock badge
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.shield_rounded,
                      size: 20,
                      color: adEnabled
                          ? Colors.greenAccent.shade400
                          : Colors.grey.shade600,
                    ),
                    onPressed: onAdBlock,
                    padding: const EdgeInsets.all(8),
                  ),
                  if (blocked > 0)
                    Positioned(
                      top: 6,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 3,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade700,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          blocked > 99 ? '99+' : '$blocked',
                          style: const TextStyle(
                            fontSize: 8,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),

              PopupMenuButton<int>(
                popUpAnimationStyle: popupAnimationStyle,
                icon: const Icon(Icons.more_vert_rounded, size: 20),
                padding: const EdgeInsets.all(8),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 0, child: Text("Partager")),
                  PopupMenuItem(value: 1, child: Text("Ouvrir dans le navigateur")),
                  PopupMenuItem(value: 2, child: Text("Effacer les cookies")),
                ],
                onSelected: (v) {
                  if (v == 0) onShare();
                  else if (v == 1) onOpenBrowser();
                  else onClearCookies();
                },
              ),

              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: onClose,
                padding: const EdgeInsets.all(8),
              ),
            ],
          ),
        ),

        // Progress
        if (progress < 1.0)
          LinearProgressIndicator(value: progress, minHeight: 2)
        else
          const SizedBox(height: 2),

        const Divider(height: 1),
      ],
    );
  }
}

// ─── AdBlock menu sheet ───────────────────────────────────────────────────────

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
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Icon(
                  Icons.shield_rounded,
                  color: enabled ? Colors.greenAccent : Colors.grey,
                  size: 22,
                ),
                const SizedBox(width: 10),
                const Text(
                  'AdBlock',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (blockedCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.green.shade800.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$blockedCount bloqués',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.green.shade300,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          SwitchListTile(
            title: const Text("Activer l'AdBlock"),
            subtitle: const Text(
              'Bloque les domaines publicitaires connus et injecte un filtre CSS/DOM',
            ),
            value: enabled,
            onChanged: onToggle,
            activeColor: Colors.greenAccent,
          ),
          ListTile(
            leading: const Icon(Icons.refresh_rounded, size: 20),
            title: const Text('Réinitialiser le compteur'),
            onTap: onReset,
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
          await webViewController!.evaluateJavascript(source: 'navigator.userAgent') ?? '';
      await MClient.setCookie(url.toString(), ua, webViewController);
    }
  }

  @override
  Future<NavigationActionPolicy> shouldOverrideUrlLoading(action) async {
    final uri = action.request.url!;
    if (!['http', 'https', 'file', 'chrome', 'data', 'javascript', 'about'].contains(
      uri.scheme,
    )) {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        return NavigationActionPolicy.CANCEL;
      }
    }
    return NavigationActionPolicy.ALLOW;
  }
}
