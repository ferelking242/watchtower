import 'dart:typed_data';
import 'package:flutter_qjs/js_eval_result.dart';
import 'package:flutter_qjs/quickjs/quickjs_runtime2.dart';
import 'package:watchtower/stubs/js_runtime_exports.dart';

Uint8List compileJs(JavascriptRuntime runtime, String code, String fileName) {
  return (runtime as QuickJsRuntime2).compile(code, fileName);
}

JsEvalResult evalBytecode(JavascriptRuntime runtime, Uint8List bytecode) {
  return (runtime as QuickJsRuntime2).evaluateBytecode(bytecode);
}
