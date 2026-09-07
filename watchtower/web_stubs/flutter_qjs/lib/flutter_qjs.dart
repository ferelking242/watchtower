export 'javascript_runtime.dart';
export 'js_eval_result.dart';
export 'extensions/handle_promises.dart';
export 'quickjs/quickjs_runtime2.dart';

import 'javascript_runtime.dart';
import 'quickjs/quickjs_runtime2.dart';

JavascriptRuntime getJavascriptRuntime({
  Map<String, dynamic>? extraArgs = const {},
}) {
  return QuickJsRuntime2();
}
