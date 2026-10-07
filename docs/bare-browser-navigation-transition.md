# Bare Browser navigation transition

## Finding

Bare Browser's patch 0109 was inspected at upstream commit
`a0adb50385edae2041ffa509c3e48fdb92c6e9cb`. It is a Chromium Android browser
embedder change, not an app-route animation:

- `patches/0109-Leave-the-navigation-blur-transition-off.patch` makes
  `ChromeWebContentsViewDelegateAndroid::ShouldShowBlurTransitionAnimation`
  return `false` before Chromium starts its navigation blur animation.
- The patch explains that the animation blurs the outgoing page, fades to a
  solid color if the new page has not painted after 350 ms, then fades to the
  new page. Without a page `theme-color`, the solid color is white.
- `docs/build-constraints.md` explains why the animation was active in Bare:
  the unbranded build compiles a field-trial testing configuration that enables
  the experiment. Bare addresses this in its Chromium build and embedder.

## Applicability to Watchtower

Watchtower's `mangawebview` route displays `MangaWebView`, which creates an
`InAppWebView` from `flutter_inappwebview`. Flutter route transitions in
`lib/router/router.dart` apply when entering or leaving the Flutter screen;
they do not control cross-site navigations inside Chromium's
`ChromeWebContentsViewDelegateAndroid`.

Watchtower does not build or embed Bare Browser's Chrome Android browser
embedder. Adding a Flutter `FadeTransition`, `SlideTransition`, or changing
the `mangawebview` route would therefore not implement patch 0109 and could
alter unrelated screen navigation. No runtime transition was changed.

## Boundary for a real fix

If the same white flash is reproduced inside Watchtower's Android
`InAppWebView`, it must be traced to the Android WebView provider or the
plugin's native integration first. Patch 0109 itself cannot be applied to
Watchtower's Flutter route. A fix should only be added after confirming that
the embedded WebView exposes an equivalent Chromium hook or configuration;
otherwise the exact Bare Browser behavior is outside this app's control.
