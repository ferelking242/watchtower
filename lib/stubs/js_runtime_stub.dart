// js_runtime_stub.dart — Flutter web JS runtime via dart:js_interop.
  // evaluate()      : <script> injection → class/var declarations persist globally.
  // evaluateAsync() : eval + Promise routed through the existing sendMessage bridge.
  import 'dart:async';
  import 'dart:convert';
  import 'dart:js_interop';

  // ─── Value type ───────────────────────────────────────────────────────────────

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
    Function(String level, String message)? consoleLogHandler;
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

  // ─── Top-level @JS declarations ───────────────────────────────────────────────

  @JS('JSON.stringify')
  external JSString? _jsStringify(JSAny? value);

  @JS('eval')
  external JSAny? _jsEval(JSString code);

  /// Temporary slot for passing a code string from Dart into a JS eval snippet.
  @JS('window.__wt_code')
  external set _wtCode(JSString? v);

  /// Dart sendMessage dispatch callback — set once in _bootstrap.
  @JS('window.__wt_cb')
  external set _wtCb(JSFunction? fn);

  // ─── Runtime ──────────────────────────────────────────────────────────────────

  class QuickJsRuntime2 extends JavascriptRuntime {
    static int _counter = 0;
    final int _instanceId = ++_counter;
    int _pSeq = 0;

    final Map<String, dynamic Function(dynamic)> _channels = {};

    QuickJsRuntime2({int? stackSize}) {
      _bootstrap();
    }

    // ── Bootstrap ─────────────────────────────────────────────────────────────

    void _bootstrap() {
      final bk = '__wt_${_instanceId}';

      // Install the sendMessage bridge + async eval helper via <script> injection.
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

    // Async eval helper: runs code, awaits any Promise, sends result
    // back through sendMessage(ch, ...) so Dart receives it via the bridge.
    window.__wt_run=function(code,ch){
      var r;
      try{ r=(0,eval)(code); }
      catch(e){
        sendMessage(ch, JSON.stringify([{e: e instanceof Error?e.message:String(e)}]));
        return;
      }
      Promise.resolve(r).then(
        function(v){
          var s=(v===null||v===undefined)?'':(typeof v==='string'?v:JSON.stringify(v));
          sendMessage(ch, JSON.stringify([{v:s}]));
        },
        function(e){
          sendMessage(ch, JSON.stringify([{e: e instanceof Error?e.message:String(e)}]));
        }
      );
    };
  })();
  ''');

      // Register the Dart dispatch callback via @JS external setter.
      _wtCb = ((JSString ch, JSString aj, JSNumber id) {
        _dispatch(ch.toDart, aj.toDart, id.toDartInt);
      }).toJS;
    }

    // ── Script injection ──────────────────────────────────────────────────────

    /// Runs [code] via a <script> tag so class/var/function declarations
    /// persist in the browser's global scope across multiple evaluate() calls.
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

    // ── Bridge dispatch ───────────────────────────────────────────────────────

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
      final enc = _jsStringify(result.toJS)?.toDart ?? jsonEncode(result);
      _jsEval('(function(){var b=window["${bk}"];if(!b)return;var e=b.p[$id];if(!e)return;delete b.p[$id];e.rs($enc);})()'.toJS);
    }

    void _evalReject(int id, String error) {
      final bk = '__wt_${_instanceId}';
      final enc = _jsStringify(error.toJS)?.toDart ?? jsonEncode(error);
      _jsEval('(function(){var b=window["${bk}"];if(!b)return;var e=b.p[$id];if(!e)return;delete b.p[$id];e.rj(new Error($enc));})()'.toJS);
    }

    // ── JavascriptRuntime interface ───────────────────────────────────────────

    @override
    void dispose() {
      _channels.clear();
      _jsEval('delete window["__wt_${_instanceId}"];'.toJS);
    }

    /// Runs [code] via <script> injection — class/var/function declarations
    /// persist in global scope for subsequent calls.
    @override
    JsEvalResult evaluate(String code, {String? sourceUrl}) {
      try {
        _injectScript(code);
        final err = _lastScriptError();
        if (err != null) return JsEvalResult(err, null, isError: true);
        return JsEvalResult('', null);
      } catch (e) {
        return JsEvalResult(e.toString(), null, isError: true);
      }
    }

    /// Runs [code] via eval and awaits any returned Promise.
    /// Uses window.__wt_run which routes the result through the sendMessage
    /// bridge — the same mechanism used by HTTP requests (known to work).
    @override
    Future<JsEvalResult> evaluateAsync(String code, {String? sourceUrl}) async {
      final ch = '__wt_p_${_instanceId}_${++_pSeq}';
      final completer = Completer<JsEvalResult>();

      // Register a one-shot handler for this promise result channel.
      _channels[ch] = (dynamic payload) async {
        _channels.remove(ch);
        final map = (payload is List && payload.isNotEmpty)
            ? (payload[0] is Map ? payload[0] as Map : null)
            : null;
        if (map == null) {
          completer.complete(JsEvalResult('', null, isPromise: true));
        } else if (map.containsKey('e')) {
          final msg = map['e']?.toString() ?? 'error';
          completer.complete(JsEvalResult(msg, null, isError: true, isPromise: true));
        } else {
          final val = map['v']?.toString() ?? '';
          completer.complete(JsEvalResult(val, null, isPromise: true));
        }
        return 'ok'; // _evalResolve will be called but nobody awaits it
      };

      // Pass code via window.__wt_code (avoids escaping in eval string).
      _wtCode = code.toJS;
      _jsEval('window.__wt_run(window.__wt_code,${jsonEncode(ch)});delete window.__wt_code;'.toJS);

      return completer.future;
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

  // ─── HandlePromises ───────────────────────────────────────────────────────────

  extension HandlePromises on JavascriptRuntime {
    void enableHandlePromises() {}
    Future<JsEvalResult> handlePromise(JsEvalResult value, {Duration? timeout}) async => value;
  }
  