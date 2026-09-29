import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

import 'generated_bindings.dart';

Future<int> start(String mcfg) async {
  final bindings = TorrentLibrary(_openLibrary());
  var completer = Completer<int>();
  var res = bindings.Start(mcfg.toNativeUtf8().cast());
  if (res.r1 != nullptr) {
    completer.completeError(Exception(res.r1.cast<Utf8>().toDartString()));
  } else {
    completer.complete(res.r0);
  }
  return completer.future;
}

const String _libName = 'libmtorrentserver';

DynamicLibrary _openLibrary() {
  if (Platform.isMacOS) {
    return DynamicLibrary.open('$_libName.dylib');
  }
  if (Platform.isLinux) {
    return DynamicLibrary.open('$_libName.so');
  }
  if (Platform.isWindows) {
    return DynamicLibrary.open('$_libName.dll');
  }
  throw UnsupportedError('Unknown platform: ${Platform.operatingSystem}');
}
