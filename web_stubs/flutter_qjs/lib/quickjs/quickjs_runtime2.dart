// Web implementation: uses the browser's native JS engine via dart:js_interop.
  // Replaces the no-op QuickJS stub so extensions work on Flutter web.
  import 'dart:async';
  import 'dart:convert';
  import 'dart:js_interop';
  import 'package:web/web.dart' as web;
  import '../javascript_runtime.dart';
  import '../js_eval_result.dart';

  export 'ffi.dart' show JSEvalFlag, JSRef;

  @JS('JSON.stringify')
  external JSAny? _jsStringify(JSAny? value);

  @JS('JSON.parse')
  external JSAny? _jsParse(String json);

  /// Per-instance channel registry: channelName -> async Dart handler.
  /// Each [QuickJsRuntime2] instance has its own isolated namespace in window
  /// via a unique [_instanceId].
  class QuickJsRuntime2 extends JavascriptRuntime {
    static int _counter = 0;
    final int _instanceId = ++_counter;
    String get _ns => '__wt_rt_$_instanceId';

    final Map<String, dynamic Function(dynamic)> _channels = {};

    QuickJsRuntime2({int? stackSize}) {
      _bootstrap();
    }

    // ---------------------------------------------------------------------------
    // Bootstrap: installs the sendMessage bridge for this runtime instance.
    // ---------------------------------------------------------------------------
    void _bootstrap() {
      // 1. Install per-instance channel table + sendMessage function in window.
      web.window.eval("""
  (function() {
    var ns = '$_ns';
    if (window[ns]) return;
    var pending = {};
    var seq = 0;
    window[ns] = {
      pending: pending,
      // Called by JS extension code: sendMessage(channel, argsJson) -> Promise<string>
      sendMessage: function(channel, argsJson) {
        return new Promise(function(resolve, reject) {
          var id = ++seq;
          pending[id] = { resolve: resolve, reject: reject };
          if (window[ns].onMessage) {
            window[ns].onMessage(channel, argsJson, id);
          } else {
            reject(new Error('Dart bridge not ready for: ' + channel));
          }
        });
      },
      resolve: function(id, result) {
        var p = pending[id];
        if (p) { delete pending[id]; p.resolve(result); }
      },
      reject: function(id, err) {
        var p = pending[id];
        if (p) { delete pending[id]; p.reject(new Error(err)); }
      }
    };

    // Install a global sendMessage that routes to this instance.
    // (Extensions call sendMessage() without knowing the namespace.)
    window.sendMessage = function(channel, argsJson) {
      return window[ns].sendMessage(channel, argsJson);
    };
  })();
  """.toJS);

      // 2. Install the Dart-side onMessage callback.
      _installDartCallback();
    }

    void _installDartCallback() {
      final cb = (JSString channelJs, JSString argsJsonJs, JSNumber idJs) {
        final channel = channelJs.toDart;
        final argsJson = argsJsonJs.toDart;
        final id = idJs.toDartInt;
        _dispatch(channel, argsJson, id);
      }.toJS;

      (web.window as JSObject).setProperty('$_ns'.toJS, (web.window as JSObject).getProperty('$_ns'.toJS));
      ((web.window as JSObject).getProperty('$_ns'.toJS) as JSObject)
          .setProperty('onMessage'.toJS, cb);
    }

    void _dispatch(String channel, String argsJson, int id) {
      final handler = _channels[channel];
      if (handler == null) {
        _jsReject(id, 'No handler registered for channel: $channel');
        return;
      }

      Future.microtask(() async {
        try {
          dynamic args;
          try {
            args = argsJson.isEmpty || argsJson == 'null'
                ? []
                : jsonDecode(argsJson);
          } catch (_) {
            args = [];
          }
          final result = await handler(args);
          _jsResolve(id, result == null ? 'null' : result.toString());
        } catch (e) {
          _jsReject(id, e.toString().replaceAll("'", "\\'").replaceAll('\n', ' '));
        }
      });
    }

    void _jsResolve(int id, String result) {
      // Use JSON.stringify to safely pass the result string into JS
      final escaped = jsonEncode(result); // Dart jsonEncode gives a safe JSON string
      web.window.eval(
        "(function(){ var r = window['$_ns']; if(r) r.resolve($id, $escaped); })()".toJS,
      );
    }

    void _jsReject(int id, String error) {
      final escaped = jsonEncode(error);
      web.window.eval(
        "(function(){ var r = window['$_ns']; if(r) r.reject($id, $escaped); })()".toJS,
      );
    }

    // ---------------------------------------------------------------------------
    // JavascriptRuntime interface
    // ---------------------------------------------------------------------------

    @override
    void dispose() {
      _channels.clear();
      web.window.eval("delete window['$_ns'];".toJS);
    }

    @override
    JsEvalResult evaluate(String code, {String? sourceUrl}) {
      try {
        final result = web.window.eval(code.toJS);
        if (result == null) return JsEvalResult('', null);
        final jsResult = result as JSAny;
        final str = (_jsStringify(jsResult) as JSString?)?.toDart ?? '';
        return JsEvalResult(str, result);
      } catch (e) {
        return JsEvalResult(e.toString(), null, isError: true);
      }
    }

    @override
    Future<JsEvalResult> evaluateAsync(String code, {String? sourceUrl}) async {
      try {
        final result = web.window.eval(code.toJS);
        if (result == null) return JsEvalResult('', null);
        final jsResult = result as JSAny;

        // Check if it's a thenable (Promise)
        if (jsResult.typeofEquals('object') || jsResult.typeofEquals('function')) {
          final jsObj = jsResult as JSObject;
          final thenProp = jsObj.getProperty('then'.toJS);
          if (thenProp != null && (thenProp as JSAny).typeofEquals('function')) {
            final completer = Completer<JsEvalResult>();
            final onFulfilled = ((JSAny? val) {
              final s = val == null
                  ? ''
                  : (_jsStringify(val) as JSString?)?.toDart ?? '';
              if (!completer.isCompleted) {
                completer.complete(JsEvalResult(s, val, isPromise: true));
              }
            }).toJS;
            final onRejected = ((JSAny? err) {
              final s = err == null
                  ? 'Promise rejected'
                  : (_jsStringify(err) as JSString?)?.toDart ?? 'error';
              if (!completer.isCompleted) {
                completer.complete(JsEvalResult(s, err, isError: true, isPromise: true));
              }
            }).toJS;
            jsObj.callMethod('then'.toJS, onFulfilled, onRejected);
            return completer.future;
          }
        }

        final str = (_jsStringify(jsResult) as JSString?)?.toDart ?? '';
        return JsEvalResult(str, result);
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
  