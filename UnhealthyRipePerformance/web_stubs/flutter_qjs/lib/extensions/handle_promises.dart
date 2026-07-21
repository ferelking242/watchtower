import 'dart:async';
  import '../javascript_runtime.dart';
  import '../js_eval_result.dart';

  extension HandlePromises on JavascriptRuntime {
    void enableHandlePromises() {}

    /// Returns the already-resolved [JsEvalResult] from [evaluateAsync].
    /// On web, evaluateAsync awaits Promises internally via .then() chaining.
    /// On native (QuickJS), the runtime fills stringResult after job execution.
    Future<JsEvalResult> handlePromise(
      JsEvalResult value, {
      Duration? timeout,
    }) async {
      return value;
    }
  }
  