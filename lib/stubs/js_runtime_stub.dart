// js_runtime_stub.dart — Web JS runtime using the browser's native engine.
  // Selected via: export '...' if (dart.library.js_interop) 'js_runtime_stub.dart'
  import 'dart:async';
  import 'dart:convert';
  import 'dart:js_interop';
  import 'package:web/web.dart' as web;

  // ─── Value types ─────────────────────────────────────────────────────────────

  class JsEvalResult {
    final String stringResult;
    final dynamic rawResult;
    final bool isPromise;
    final bool isError;

    JsEvalResult(this.stringResult, this.rawResult,
        {this.isError = false, this.isPromise = false});

    @override
    String toString() => stringResult;
  }

  // ─── Abstract runtime ─────────────────────────────────────────────────────────

  abstract class JavascriptRuntime {
    static bool debugEnabled = false;
    Map<String, dynamic> localContext = {};
    Map<String, dynamic> dartContext = {};

    JavascriptRuntime init() => this;
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

  // ─── JS interop helpers ───────────────────────────────────────────────────────

  @JS('JSON.stringify')
  external JSString? _jsStringify(JSAny? value);

  @JS('eval')
  external JSAny? _jsEval(JSString code);

  @JS('Error')
  external JSObject _newJsError(JSString message);

  // ─── Browser-native runtime ───────────────────────────────────────────────────

  class QuickJsRuntime2 extends JavascriptRuntime {
    static int _counter = 0;
    final int _instanceId = ++_counter;
    String get _bk => '__wt_${_instanceId}';

    final Map<String, dynamic Function(dynamic)> _channels = {};

    QuickJsRuntime2({int? stackSize}) {
      _bootstrap();
    }

    void _bootstrap() {
      final bk = _bk;
      // Install bridge object on window. bk is safe alphanumeric — embed directly.
      _jsEval('''
  (function(){
    var k="${bk}";
    if(window[k])return;
    var p={},s=0;
    window[k]={
      p:p,
      cb:null,
      send:function(ch,aj){
        return new Promise(function(res,rej){
          var id=++s;
          p[id]={res:res,rej:rej};
          if(window[k].cb){window[k].cb(ch,aj,id);}
          else{rej(new Error("Dart not ready: "+ch));}
        });
      }
    };
    window.sendMessage=function(ch,aj){return window[k].send(ch,aj);};
  })();
  '''.toJS);

      // Install Dart callback via setProperty — no eval string, no escaping issues.
      final dartCb = ((JSString ch, JSString aj, JSNumber id) {
        _dispatch(ch.toDart, aj.toDart, id.toDartInt);
      }).toJS;

      final bridge = (web.window as JSObject).getProperty(bk.toJS) as JSObject;
      bridge.setProperty('cb'.toJS, dartCb);
    }

    void _dispatch(String channel, String argsJson, int id) {
      final handler = _channels[channel];
      if (handler == null) {
        _reject(id, 'No handler: $channel');
        return;
      }
      Future.microtask(() async {
        try {
          dynamic args;
          try {
            args = (argsJson.isEmpty || argsJson == 'null')
                ? <dynamic>[]
                : jsonDecode(argsJson);
          } catch (_) {
            args = <dynamic>[];
          }
          final result = await handler(args);
          _resolve(id, result == null ? 'null' : result.toString());
        } catch (e) {
          _reject(id, e.toString());
        }
      });
    }

    JSObject? _getPendingEntry(int id) {
      final bridge = (web.window as JSObject).getProperty(_bk.toJS);
      if (bridge == null) return null;
      final p = (bridge as JSObject).getProperty('p'.toJS);
      if (p == null) return null;
      final entry = (p as JSObject).getProperty(id.toJS);
      if (entry == null) return null;
      return entry as JSObject;
    }

    void _removePending(int id) {
      final bridge = (web.window as JSObject).getProperty(_bk.toJS);
      if (bridge == null) return;
      final p = (bridge as JSObject).getProperty('p'.toJS);
      if (p != null) (p as JSObject).delete(id.toJS);
    }

    void _resolve(int id, String result) {
      final entry = _getPendingEntry(id);
      if (entry == null) return;
      final fn = entry.getProperty('res'.toJS);
      if (fn != null) (fn as JSFunction).callAsFunction(null, result.toJS);
      _removePending(id);
    }

    void _reject(int id, String error) {
      final entry = _getPendingEntry(id);
      if (entry == null) return;
      final fn = entry.getProperty('rej'.toJS);
      if (fn != null) {
        final errObj = _newJsError(error.toJS);
        (fn as JSFunction).callAsFunction(null, errObj as JSAny);
      }
      _removePending(id);
    }

    // ── JavascriptRuntime interface ────────────────────────────────────────────

    @override
    void dispose() {
      _channels.clear();
      _jsEval('(function(){delete window["${_bk}"];})()'.toJS);
    }

    @override
    JsEvalResult evaluate(String code, {String? sourceUrl}) {
      try {
        final result = _jsEval(code.toJS);
        if (result == null) return JsEvalResult('', null);
        if (result.typeofEquals('string')) {
          return JsEvalResult((result as JSString).toDart, result);
        }
        return JsEvalResult(_jsStringify(result)?.toDart ?? '', result);
      } catch (e) {
        return JsEvalResult(e.toString(), null, isError: true);
      }
    }

    @override
    Future<JsEvalResult> evaluateAsync(String code, {String? sourceUrl}) async {
      try {
        final result = _jsEval(code.toJS);
        if (result == null) return JsEvalResult('', null);

        // Detect Promise by checking for callable .then
        if (!result.typeofEquals('string') &&
            !result.typeofEquals('number') &&
            !result.typeofEquals('boolean')) {
          final obj = result as JSObject;
          final thenFn = obj.getProperty('then'.toJS);
          if (thenFn != null && (thenFn as JSAny).typeofEquals('function')) {
            final completer = Completer<JsEvalResult>();
            void done(JsEvalResult r) {
              if (!completer.isCompleted) completer.complete(r);
            }

            final onFulfilled = ((JSAny? val) {
              if (val == null) {
                done(JsEvalResult('', null, isPromise: true));
              } else if (val.typeofEquals('string')) {
                // jsonStringify() resolved to a JS string — take it as-is.
                done(JsEvalResult((val as JSString).toDart, val, isPromise: true));
              } else {
                done(JsEvalResult(
                  _jsStringify(val)?.toDart ?? '', val, isPromise: true));
              }
            }).toJS;

            final onRejected = ((JSAny? err) {
              String msg = 'Promise rejected';
              if (err != null) {
                if (!err.typeofEquals('string')) {
                  final m = (err as JSObject).getProperty('message'.toJS);
                  msg = (m != null && (m as JSAny).typeofEquals('string'))
                      ? (m as JSString).toDart
                      : (_jsStringify(err)?.toDart ?? 'error');
                } else {
                  msg = (err as JSString).toDart;
                }
              }
              done(JsEvalResult(msg, err, isError: true, isPromise: true));
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
    String getEngineInstanceId() => 'web-browser-${_instanceId}';

    @override
    void setInspectable(bool inspectable) {}

    @override
    int executePendingJob() => 0;

    @override
    void initChannelFunctions() {}
  }

  // ─── Factory ──────────────────────────────────────────────────────────────────

  JavascriptRuntime getJavascriptRuntime({
    Map<String, dynamic>? extraArgs = const {},
  }) =>
      QuickJsRuntime2();

  // ─── HandlePromises ───────────────────────────────────────────────────────────

  extension HandlePromises on JavascriptRuntime {
    void enableHandlePromises() {}

    /// evaluateAsync already awaits Promises internally on web.
    /// This extension just returns the already-resolved result.
    Future<JsEvalResult> handlePromise(
      JsEvalResult value, {
      Duration? timeout,
    }) async =>
        value;
  }
  