import 'dart:async';
import 'package:flutter/material.dart';

bool runWebViewTitleBarWidget(List<String> args) => false;

class WebViewEnvironmentSettings {
  final String? userDataFolder;
  const WebViewEnvironmentSettings({this.userDataFolder});
}

class WebViewEnvironment {
  static Future<String?> getAvailableVersion() async => null;
  static Future<WebViewEnvironment> create({
    WebViewEnvironmentSettings? settings,
  }) async =>
      WebViewEnvironment._();
  WebViewEnvironment._();
}

/// Stub for the WebView creation configuration.
/// The real class lives in the desktop_webview_window package.
class CreateConfiguration {
  final String? userDataFolderWindows;
  final WebViewEnvironment? environment;
  final String? title;
  final int? windowHeight;
  final int? windowWidth;
  const CreateConfiguration({
    this.userDataFolderWindows,
    this.environment,
    this.title,
    this.windowHeight,
    this.windowWidth,
  });
}

class _WebviewOnClose {
  Future<void> whenComplete(void Function() fn) async {}
}

class Webview {
  final _WebviewOnClose onClose = _WebviewOnClose();

  Future<void> close() async {}

  /// Returns dynamic list to avoid Cookie class ambiguity with flutter_inappwebview.
  Future<List<dynamic>> getAllCookies() async => [];

  Future<String?> evaluateJavaScript(String script) async => null;
  void addScriptToExecuteOnDocumentCreated(String script) {}
  void setApplicationNameForUserAgent(String name) {}
  void setApplicationUserAgent(String userAgent) {}
  void launch(String url) {}
  void setBrightness(Brightness brightness) {}
  void setNavigationDelegate({
    void Function(String url)? onPageStarted,
    void Function(String url)? onPageFinished,
    bool Function(String url)? onNavigationRequest,
  }) {}

  void setOnUrlRequestCallback(bool Function(String url) callback) {}
}

class WebviewWindow {
  static Future<Webview> create({
    CreateConfiguration? configuration,
  }) async =>
      Webview();

  static Future<void> clearAll({
    String? userDataFolderWindows,
  }) async {}
}
