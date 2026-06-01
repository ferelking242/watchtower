// Web JS runtime — uses the browser's native engine via dart:js_interop.
  // Fix v2: removed Dart string interpolation inside JS eval strings (was the root bug).
  // Bridge is now installed purely via JSObject.setProperty — no eval string escaping.
  import 'dart:async';
  import 'dart:convert';
  import 'dart:js_interop';
  import 'package:web/web.dart' as web;
  import '../javascript_runtime.dart';
  import '../js_eval_result.dart';

  export 'ffi.dart' show JSEvalFlag, JSRef;

  @JS('JSON.stringify')
  external JSString? _jsStringify(JSAny? value);

  @JS('eval')
  external JSAny? _jsEval(JSString code);

  class QuickJsRuntime2 extends JavascriptRuntime {
    static int _counter = 0;
    final int _instanceId = ++_counter;

    final Map<String, dynamic Function(dynamic)> _channels = {};

    QuickJsRuntime2({int? stackSize}) {
      _bootstrap();
    }

    String get _bridgeKey => '__wt_$_instanceId';

    void _bootstrap() {
      // Build the JS bootstrap string using Dart string interpolation
      // so the bridge key is correctly embedded.
      final bk = _bridgeKey;
      final js = '''
  (function() {
    var key = "$bk";
    if (window[key]) return;
    var pending = {};
    var seq = 0;
    window[key] = {
      pending: pending,
      dartCb: null,
      sendMessage: function(channel, argsJson) {
        return new Promise(function(resolve, reject) {
          var id = ++seq;
          pending[id] = { resolve: resolve, reject: reject };
          if (window[key].dartCb) {
            window[key].dartCb(channel, argsJson, id);
          } else {
            reject(new Error("Dart bridge not ready: " + channel));
          }
        });
      }
    };
    // Global sendMessage routes to latest bridge instance
    window.sendMessage = function(channel, argsJson) {
      return window[key].sendMessage(channel, argsJson);
    };
  })();
  ''';
      _jsEval(js.toJS);

      // Install the Dart callback via setProperty — no eval, no escaping issues
      final dartCb = ((JSString ch, JSString argsJson, JSNumber id) {
        _onMessage(ch.toDart, argsJson.toDart, id.toDartInt);
      }).toJS;

      final bridge = (web.window as JSObject).getProperty(bk.toJS) as JSObject;
      bridge.setProperty('dartCb'.toJS, dartCb);
    }

    void _onMessage(String channel, String argsJson, int id) {
      final handler = _channels[channel];
      if (handler == null) {
        _reject(id, 'No handler: $channel');
        return;
      }
      Future.microtask(() async {
        try {
          dynamic args;
          try {
            args = (argsJson.isEmpty || argsJson == 'null') ? [] : jsonDecode(argsJson);
          } catch (_) {
            args = [];
          }
          final result = await handler(args);
          _resolve(id, result == null ? 'null' : result.toString());
        } catch (e) {
          _reject(id, e.toString());
        }
      });
    }

    void _resolve(int id, String result) {
      final bk = _bridgeKey;
      final bridge = (web.window as JSObject).getProperty(bk.toJS);
      if (bridge == null) return;
      final pending = (bridge as JSObject).getProperty('pending'.toJS);
      if (pending == null) return;
      final idJs = id.toJS;
      final entry = (pending as JSObject).getProperty(idJs);
      if (entry == null) return;
      final resolveFn = (entry as JSObject).getProperty('resolve'.toJS);
      if (resolveFn == null) return;
      (resolveFn as JSFunction).callAsFunction(null, result.toJS);
      (pending as JSObject).delete(idJs);
    }

    void _reject(int id, String error) {
      final bk = _bridgeKey;
      // Use eval for reject since we need to wrap in Error object
      final safeErr = error.replaceAll('\\', '\\\\').replaceAll('"', '\\"').replaceAll('\n', ' ');
      _jsEval('(function(){var b=window["$bk"];if(b&&b.pending[$id]){b.pending[$id].reject(new Error("$safeErr"));delete b.pending[$id];}})()'.toJS);
    }

    @override
    void dispose() {
      _channels.clear();
      _jsEval('delete window["$_bridgeKey"];'.toJS);
    }

    @override
    JsEvalResult evaluate(String code, {String? sourceUrl}) {
      try {
        final result = _jsEval(code.toJS);
        if (result == null) return JsEvalResult('', null);
        if (result.typeofEquals('string')) {
          return JsEvalResult((result as JSString).toDart, result);
        }
        final str = _jsStringify(result)?.toDart ?? '';
        return JsEvalResult(str, result);
      } catch (e) {
        return JsEvalResult(e.toString(), null, isError: true);
      }
    }

    @override
    Future<JsEvalResult> evaluateAsync(String code, {String? sourceUrl}) async {
      try {
        final result = _jsEval(code.toJS);
        if (result == null) return JsEvalResult('', null);

        // Detect Promise: has a callable .then property
        if (!result.typeofEquals('string') &&
            !result.typeofEquals('number') &&
            !result.typeofEquals('boolean')) {
          final obj = result as JSObject;
          final thenFn = obj.getProperty('then'.toJS);
          if (thenFn != null && (thenFn as JSAny).typeofEquals('function')) {
            final completer = Completer<JsEvalResult>();
            void complete(JsEvalResult r) {
              if (!completer.isCompleted) completer.complete(r);
            }
            final onFulfilled = ((JSAny? val) {
              String str;
              if (val == null) {
                str = '';
              } else if (val.typeofEquals('string')) {
                // jsonStringify() resolved to a JS string — use as-is
                str = (val as JSString).toDart;
              } else {
                str = _jsStringify(val)?.toDart ?? '';
              }
              complete(JsEvalResult(str, val, isPromise: true));
            }).toJS;
            final onRejected = ((JSAny? err) {
              String str = 'Promise rejected';
              if (err != null) {
                // Try .message first (Error object), else stringify
                if (!err.typeofEquals('string')) {
                  final msg = (err as JSObject).getProperty('message'.toJS);
                  str = (msg != null && (msg as JSAny).typeofEquals('string'))
                      ? (msg as JSString).toDart
                      : (_jsStringify(err)?.toDart ?? 'error');
                } else {
                  str = (err as JSString).toDart;
                }
              }
              complete(JsEvalResult(str, err, isError: true, isPromise: true));
            }).toJS;
            obj.callMethod('then'.toJS, onFulfilled, onRejected);
            return completer.future;
          }
        }

        if (result.typeofEquals('string')) {
          return JsEvalResult((result as JSString).toDart, result);
        }
        return JsEvalResult(_jsStringify(result)?.toDart ?? '', result);
      } catch (e) {
        return JsEvalResult(e.toString(), null, isError: true);
      }
    }

    @override
    JsEvalResult callFunction(dynamic fn, dynamic obj) => JsEvalResult('', null);

    @override
    T? convertValue<T>(JsEvalResult jsValue) {
      try { return jsValue.rawResult as T; } catch (_) { return null; }
    }

    @override
    String jsonStringify(JsEvalResult jsValue) => jsValue.stringResult;

    @override
    bool setupBridge(String channelName, void Function(dynamic args) fn) {
      _channels[channelName] = (dynamic args) async => fn(args);
      return true;
    }

    @override
    void onMessage(String channelName, dynamic Function(dynamic args) fn) {
      _channels[channelName] = fn;
    }

    @override
    String getEngineInstanceId() => 'web-browser-$_instanceId';

    @override
    void setInspectable(bool inspectable) {}

    @override
    int executePendingJob() => 0;

    @override
    void initChannelFunctions() {}
  }
  