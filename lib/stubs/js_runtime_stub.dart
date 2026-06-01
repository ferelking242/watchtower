// js_runtime_stub.dart — Flutter web JS runtime via dart:js_interop.
  // This file is conditionally imported instead of flutter_qjs on web builds.
  import 'dart:async';
  import 'dart:convert';
  import 'dart:js_interop';

  // ─── Shared value type ────────────────────────────────────────────────────────

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

  // ─── Abstract interface ───────────────────────────────────────────────────────

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

  // ─── Top-level @JS interop ────────────────────────────────────────────────────
  // All @JS external declarations must be at library scope, not inside a class.

  @JS('JSON.stringify')
  external JSString? _jsStringify(JSAny? value);

  @JS('eval')
  external JSAny? _jsEval(JSString code);

  /// Slot for the sendMessage Dart callback (set before each extension call).
  @JS('window.__wt_cb')
  external set _wtCb(JSFunction? fn);

  /// Temporary slot for Promise fulfilled callback.
  @JS('window.__wt_res')
  external set _wtRes(JSFunction? fn);

  /// Temporary slot for Promise rejected callback.
  @JS('window.__wt_rej')
  external set _wtRej(JSFunction? fn);

  // ─── Browser-native runtime ───────────────────────────────────────────────────

  class QuickJsRuntime2 extends JavascriptRuntime {
    static int _counter = 0;
    final int _instanceId = ++_counter;

    final Map<String, dynamic Function(dynamic)> _channels = {};

    QuickJsRuntime2({int? stackSize}) {
      _bootstrap();
    }

    void _bootstrap() {
      final bk = '__wt_${_instanceId}';
      _jsEval('''
  (function(){
    var k="${bk}";
    if(window[k])return;
    var p={},s=0;
    window[k]={p:p,
      send:function(ch,aj){
        return new Promise(function(rs,rj){
          var id=++s; p[id]={rs:rs,rj:rj};
          if(window.__wt_cb){ window.__wt_cb(ch,aj,id); }
          else { rj(new Error("Dart not ready: "+ch)); }
        });
      }
    };
    window.sendMessage=function(ch,aj){ return window[k].send(ch,aj); };
  })();
  '''.toJS);

      // Register Dart dispatch callback via @JS external setter.
      _wtCb = ((JSString ch, JSString aj, JSNumber id) {
        _dispatch(ch.toDart, aj.toDart, id.toDartInt);
      }).toJS;
    }

    void _dispatch(String channel, String argsJson, int id) {
      final handler = _channels[channel];
      if (handler == null) {
        _evalReject(id, 'No handler: $channel');
        return;
      }
      Future.microtask(() async {
        try {
          dynamic args;
          try {
            args = (argsJson.isEmpty || argsJson == 'null')
                ? <dynamic>[] : jsonDecode(argsJson);
          } catch (_) {
            args = <dynamic>[];
          }
          final result = await handler(args);
          _evalResolve(id, result == null ? 'null' : result.toString());
        } catch (e) {
          _evalReject(id, e.toString());
        }
      });
    }

    // Safe resolve: JSON.stringify the result string for eval embedding.
    void _evalResolve(int id, String result) {
      final bk = '__wt_${_instanceId}';
      // _jsStringify returns the JSON-encoded form of the string (with quotes).
      final encoded = _jsStringify(result.toJS)?.toDart ?? jsonEncode(result);
      _jsEval('(function(){var b=window["${bk}"];if(!b)return;var e=b.p[$id];if(!e)return;delete b.p[$id];e.rs($encoded);})()'.toJS);
    }

    void _evalReject(int id, String error) {
      final bk = '__wt_${_instanceId}';
      final encoded = _jsStringify(error.toJS)?.toDart ?? jsonEncode(error);
      _jsEval('(function(){var b=window["${bk}"];if(!b)return;var e=b.p[$id];if(!e)return;delete b.p[$id];e.rj(new Error($encoded));})()'.toJS);
    }

    @override
    void dispose() {
      _channels.clear();
      _jsEval('delete window["__wt_${_instanceId}"];'.toJS);
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
      // Evaluate code and store result in window.__wt_ev for Promise detection.
      // We wrap the eval so JS stores the result we can check.
      try {
        _jsEval('window.__wt_ev=void 0;'.toJS);
        final wrapped = '(function(){try{window.__wt_ev=(${code});}catch(e){window.__wt_ev=Promise.reject(e);}})()';
        _jsEval(wrapped.toJS);

        // Check if window.__wt_ev is a Promise (has .then)
        final isPromise = _jsEval(
          'typeof window.__wt_ev==="object"&&window.__wt_ev!==null&&typeof window.__wt_ev.then==="function"'.toJS,
        );
        final isPromiseBool = isPromise != null &&
            isPromise.typeofEquals('boolean') &&
            (isPromise as JSBoolean).toDart;

        if (isPromiseBool) {
          final completer = Completer<JsEvalResult>();
          void done(JsEvalResult r) {
            if (!completer.isCompleted) completer.complete(r);
          }

          // Set fulfilled callback via @JS setter
          _wtRes = ((JSAny? val) {
            String str;
            if (val == null) { str = ''; }
            else if (val.typeofEquals('string')) { str = (val as JSString).toDart; }
            else { str = _jsStringify(val)?.toDart ?? ''; }
            done(JsEvalResult(str, val, isPromise: true));
          }).toJS;

          // Set rejected callback via @JS setter
          _wtRej = ((JSAny? err) {
            String msg = 'Promise rejected';
            if (err != null) {
              msg = err.typeofEquals('string')
                  ? (err as JSString).toDart
                  : _jsStringify(err)?.toDart ?? 'error';
            }
            done(JsEvalResult(msg, err, isError: true, isPromise: true));
          }).toJS;

          // Attach .then via eval — window.__wt_ev, window.__wt_res, window.__wt_rej are all set
          _jsEval('window.__wt_ev.then(window.__wt_res,window.__wt_rej);delete window.__wt_ev;'.toJS);

          // Clean up callback slots after completion
          completer.future.whenComplete(() {
            _wtRes = null;
            _wtRej = null;
          });

          return completer.future;
        }

        // Not a Promise — read the value
        final result = _jsEval('(function(){var v=window.__wt_ev;delete window.__wt_ev;return v;})()'.toJS);
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
  }) => QuickJsRuntime2();

  // ─── HandlePromises extension ─────────────────────────────────────────────────

  extension HandlePromises on JavascriptRuntime {
    void enableHandlePromises() {}

    /// evaluateAsync already awaits Promises internally.
    Future<JsEvalResult> handlePromise(JsEvalResult value, {Duration? timeout}) async => value;
  }
  