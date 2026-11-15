import 'dart:async';
import 'package:flutter/material.dart';

bool runWebViewTitleBarWidget(List<String> args) => false;

/// Web stub for the WebView creation configuration.
/// `WebViewEnvironment` / `WebViewEnvironmentSettings` are intentionally
/// NOT declared here: flutter_inappwebview exports them on every target,
/// so a second copy makes main.dart ambiguous under dart2js.
class CreateConfiguration {
  final String? userDataFolderWindows;
  final String? title;
  final int? windowHeight;
  final int? windowWidth;
  const CreateConfiguration({
    this.userDataFolderWindows,
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
