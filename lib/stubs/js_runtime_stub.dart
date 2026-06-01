// js_runtime_stub.dart — Flutter web JS runtime via dart:js_interop.
  // Uses <script> injection for evaluate() so class/var declarations persist
  // in global scope across multiple calls.
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

  @JS('JSON.stringify')
  external JSString? _jsStringify(JSAny? value);

  @JS('eval')
  external JSAny? _jsEval(JSString code);

  /// Slot: code string to inject via <script> (avoids eval escaping issues).
  @JS('window.__wt_code')
  external set _wtCode(JSString? code);

  /// Slot: Dart sendMessage callback.
  @JS('window.__wt_cb')
  external set _wtCb(JSFunction? fn);

  /// Slot: Promise fulfilled callback.
  @JS('window.__wt_res')
  external set _wtRes(JSFunction? fn);

  /// Slot: Promise rejected callback.
  @JS('window.__wt_rej')
  external set _wtRej(JSFunction? fn);

  /// Temporary slot to pass any JS value from Dart to an eval() snippet.
  @JS('window.__wt_err_obj')
  external set _wtErrObj(JSAny? v);

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
      // Install the per-instance sendMessage bridge via script injection.
      _injectScript('''
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
  ''');

      _wtCb = ((JSString ch, JSString aj, JSNumber id) {
        _dispatch(ch.toDart, aj.toDart, id.toDartInt);
      }).toJS;
    }

    // ── Script injection ──────────────────────────────────────────────────────
    // Injects code via a <script> tag so class/var/function declarations
    // persist in global scope across multiple evaluate() calls.
    // Returns the text content of window.__wt_err if the script threw,
    // or null on success.
    void _injectScript(String code) {
      _wtCode = code.toJS;
      _jsEval('''
  (function(){
    var s=document.createElement("script");
    s.textContent=window.__wt_code;
    delete window.__wt_code;
    window.__wt_err=null;
    try{ document.head.appendChild(s); document.head.removeChild(s); }
    catch(e){ window.__wt_err=e&&e.message?e.message:String(e); }
  })();
  '''.toJS);
    }

    String? _lastScriptError() {
      final r = _jsEval('(window.__wt_err||null)'.toJS);
      if (r == null || !r.typeofEquals('string')) return null;
      return (r as JSString).toDart;
    }

    // ── Dart ↔ JS bridge ─────────────────────────────────────────────────────

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
          } catch (_) { args = <dynamic>[]; }
          final result = await handler(args);
          _evalResolve(id, result == null ? 'null' : result.toString());
        } catch (e) {
          _evalReject(id, e.toString());
        }
      });
    }

    void _evalResolve(int id, String result) {
      final bk = '__wt_${_instanceId}';
      final encoded = _jsStringify(result.toJS)?.toDart ?? jsonEncode(result);
      _jsEval('(function(){var b=window["${bk}"];if(!b)return;var e=b.p[$id];if(!e)return;delete b.p[$id];e.rs($encoded);})()'.toJS);
    }

    void _evalReject(int id, String error) {
      final bk = '__wt_${_instanceId}';
      final encoded = _jsStringify(error.toJS)?.toDart ?? jsonEncode(error);
      _jsEval('(function(){var b=window["${bk}"];if(!b)return;var e=b.p[$id];if(!e)return;delete b.p[$id];e.rj(new Error($encoded));})()'.toJS);
    }

    // ── JavascriptRuntime interface ───────────────────────────────────────────

    @override
    void dispose() {
      _channels.clear();
      _jsEval('delete window["__wt_${_instanceId}"];'.toJS);
    }

    /// Executes [code] via <script> injection so that class/var/function
    /// declarations persist in the global scope across multiple calls.
    /// Returns an error JsEvalResult if the script threw.
    @override
    JsEvalResult evaluate(String code, {String? sourceUrl}) {
      try {
        _injectScript(code);
        final err = _lastScriptError();
        if (err != null) {
          return JsEvalResult(err, null, isError: true);
        }
        return JsEvalResult('', null);
      } catch (e) {
        return JsEvalResult(e.toString(), null, isError: true);
      }
    }

    /// Executes [code] via eval() and awaits any returned Promise.
    /// By the time this is called, all globals (MProvider, extention, etc.)
    /// are already in global scope from evaluate() calls above.
    @override
    Future<JsEvalResult> evaluateAsync(String code, {String? sourceUrl}) async {
      try {
        // Wrap into a try/catch that stores result/error in window.__wt_ev.
        _wtCode = code.toJS;
        _jsEval('''
  (function(){
    try { window.__wt_ev=(0,eval)(window.__wt_code); }
    catch(e){ window.__wt_ev=Promise.reject(e); }
    delete window.__wt_code;
  })();
  '''.toJS);

        // Check if window.__wt_ev is a Promise.
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

          _wtRes = ((JSAny? val) {
            String str;
            if (val == null) { str = ''; }
            else if (val.typeofEquals('string')) { str = (val as JSString).toDart; }
            else { str = _jsStringify(val)?.toDart ?? ''; }
            done(JsEvalResult(str, val, isPromise: true));
          }).toJS;

          _wtRej = ((JSAny? err) {
            String msg = 'Promise rejected';
            if (err != null) {
              if (err.typeofEquals('string')) {
                msg = (err as JSString).toDart;
              } else {
                // JSON.stringify(Error) always returns "{}" — extract .message via eval.
                _wtErrObj = err;
                final m = _jsEval(
                  '(function(){var e=window.__wt_err_obj;delete window.__wt_err_obj;'
                  'return e instanceof Error?e.message:(e&&e.message!=null?String(e.message):JSON.stringify(e)||String(e));})()'.toJS,
                );
                if (m != null && m.typeofEquals('string')) {
                  msg = (m as JSString).toDart;
                }
              }
            }
            done(JsEvalResult(msg, err, isError: true, isPromise: true));
          }).toJS;

          _jsEval('window.__wt_ev.then(window.__wt_res,window.__wt_rej);delete window.__wt_ev;'.toJS);

          completer.future.whenComplete(() {
            _wtRes = null;
            _wtRej = null;
          });

          return completer.future;
        }

        // Not a Promise — read the result.
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
  