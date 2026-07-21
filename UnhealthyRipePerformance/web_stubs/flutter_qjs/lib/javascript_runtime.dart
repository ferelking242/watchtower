import 'dart:async';
import 'js_eval_result.dart';

abstract class JavascriptRuntime {
  static bool debugEnabled = false;

  Map<String, dynamic> localContext = {};
  Map<String, dynamic> dartContext = {};

  JavascriptRuntime init() {
    return this;
  }

  void dispose();

  JsEvalResult evaluate(String code, {String? sourceUrl});

  Future<JsEvalResult> evaluateAsync(String code, {String? sourceUrl});

  JsEvalResult callFunction(dynamic fn, dynamic obj);

  T? convertValue<T>(JsEvalResult jsValue);

  String jsonStringify(JsEvalResult jsValue);

  bool setupBridge(String channelName, void Function(dynamic args) fn);

  String getEngineInstanceId();

  void setInspectable(bool inspectable);

  int executePendingJob();

  void initChannelFunctions();

  void onMessage(String channelName, dynamic Function(dynamic args) fn) {
    setupBridge(channelName, fn);
  }
}
