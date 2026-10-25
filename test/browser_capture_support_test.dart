import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/services/anti_bot/browser_capture.dart';

/// The method used to beat Cloudflare depends on the platform: a hidden WebView
/// where one exists, the Worker proxy on Flutter web, and the visible panel
/// everywhere else. This matrix must not drift.
void main() {
  group('Browser capture support matrix', () {
    test('mobile and desktop with an engine capture in a hidden WebView', () {
      for (final os in ['android', 'ios', 'macos', 'windows', 'linux']) {
        expect(
          browserCaptureSupportFor(
            isWeb: false,
            operatingSystem: os,
            engineRegistered: true,
          ),
          BrowserCaptureSupport.headless,
          reason: '$os should use the headless browser',
        );
      }
    });

    test('Flutter web goes through the Worker proxy, never a WebView', () {
      expect(
        browserCaptureSupportFor(
          isWeb: true,
          operatingSystem: 'web',
          engineRegistered: false,
        ),
        BrowserCaptureSupport.proxy,
      );
    });

    test('no registered engine means no capture, even on a phone', () {
      expect(
        browserCaptureSupportFor(
          isWeb: false,
          operatingSystem: 'android',
          engineRegistered: false,
        ),
        BrowserCaptureSupport.none,
      );
    });

    test('an unknown platform is never assumed to have a browser', () {
      expect(
        browserCaptureSupportFor(
          isWeb: false,
          operatingSystem: 'fuchsia',
          engineRegistered: true,
        ),
        BrowserCaptureSupport.none,
      );
    });
  });
}
