import 'dart:typed_data';
import 'package:watchtower/stubs/js_runtime_exports.dart';

Uint8List compileJs(JavascriptRuntime runtime, String code, String fileName) {
  throw UnsupportedError('compileJs is not available on Flutter Web');
}

JsEvalResult evalBytecode(JavascriptRuntime runtime, Uint8List bytecode) {
  throw UnsupportedError('evalBytecode is not available on Flutter Web');
}
