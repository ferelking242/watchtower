import 'dart:convert';
import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:watchtower/stubs/js_runtime_exports.dart';
import 'package:watchtower/stubs/js_ffi_exports.dart';
import 'package:http/http.dart' as http;
import 'package:watchtower/src/rust/api/epub.dart';
import 'package:path/path.dart' as p;
import 'package:http_interceptor/http/intercepted_client.dart';
import 'package:js_packer/js_packer.dart';
import 'package:watchtower/eval/javascript/http.dart';
import 'package:watchtower/eval/model/m_bridge.dart';
import 'package:watchtower/providers/storage_provider.dart';
import 'package:watchtower/services/http/m_client.dart';
import 'package:watchtower/utils/cryptoaes/js_unpacker.dart';
import 'package:watchtower/utils/log/log.dart';
import 'package:watchtower/utils/log/logger.dart';

class JsUtils {
  late JavascriptRuntime runtime;
  JsUtils(this.runtime);

  void init() {
    InterceptedClient client() {
      return MClient.init();
    }

    // ── console.log / console.warn / console.error from extension JS ──────────
    // Routed into AppLogger so they appear in the in-app overlay and session
    // log file, not just the legacy Logger in-memory list.
    // Message format: args = [level_string, message_string]
    //   level_string: "log" | "debug" | "info" | "warn" | "error"
    runtime.onMessage('log', (dynamic args) {
      final level  = args.length >= 2 ? args[0] as String : 'log';
      final msg    = args.length >= 2 ? args[1] as String : (args[0] as String);
      final lvl = switch (level) {
        'error' => LogLevel.error,
        'warn'  => LogLevel.warning,
        'info'  => LogLevel.info,
        _       => LogLevel.debug,
      };
      AppLogger.log('[console.$level] $msg', logLevel: lvl, tag: LogTag.extension_);
      if (kDebugMode) debugPrint('[EXT][console.$level] $msg');
      // Keep legacy Logger alive for any UI that still reads it.
      Logger.add(LoggerLevel.warning, '$msg');
      return null;
    });
    runtime.onMessage('cryptoHandler', (dynamic args) {
      return MBridge.cryptoHandler(args[0], args[1], args[2], args[3]);
    });
    runtime.onMessage('encryptAESCryptoJS', (dynamic args) {
      return MBridge.encryptAESCryptoJS(args[0], args[1]);
    });
    runtime.onMessage('decryptAESCryptoJS', (dynamic args) {
      return MBridge.decryptAESCryptoJS(args[0], args[1]);
    });
    runtime.onMessage('deobfuscateJsPassword', (dynamic args) {
      return MBridge.deobfuscateJsPassword(args[0]);
    });
    runtime.onMessage('unpackJsAndCombine', (dynamic args) {
      return JsUnpacker.unpackAndCombine(args[0]) ?? "";
    });
    runtime.onMessage('unpackJs', (dynamic args) {
      return JSPacker(args[0]).unpack() ?? "";
    });
    runtime.onMessage('evaluateJavascriptViaWebview', (dynamic args) async {
      return await MBridge.evaluateJavascriptViaWebview(
        args[0]!,
        (args[1]! as Map).toMapStringString!,
        (args[2]! as List).map((e) => e.toString()).toList(),
      );
    });
    runtime.onMessage('parseEpub', (dynamic args) async {
      final bytes = await _toBytesResponse(client(), "GET", args);
      final book = await parseEpubFromBytes(epubBytes: bytes, fullData: true);
      final List<String> chapters = [];
      for (var chapter in book.chapters) {
        final chapterTitle = chapter.name;
        chapters.add(chapterTitle);
      }
      return jsonEncode({
        "title": book.name,
        "author": book.author,
        "chapters": chapters,
      });
    });
    runtime.onMessage('parseEpubChapter', (dynamic args) async {
      final bytes = await _toBytesResponse(client(), "GET", args);
      final book = await parseEpubFromBytes(epubBytes: bytes, fullData: true);
      final chapter = book.chapters.firstWhereOrNull(
        (element) => element.name == args[3],
      );
      return chapter?.content;
    });

    runtime.evaluate('''
function _consoleFormat(args) {
    return Array.from(args).map(function(a) {
        return (a !== null && typeof a === "object") ? JSON.stringify(a) : String(a);
    }).join(" ");
}
console.log = function () {
    sendMessage("log", JSON.stringify(["log", _consoleFormat(arguments)]));
};
console.debug = function () {
    sendMessage("log", JSON.stringify(["debug", _consoleFormat(arguments)]));
};
console.info = function () {
    sendMessage("log", JSON.stringify(["info", _consoleFormat(arguments)]));
};
console.warn = function () {
    sendMessage("log", JSON.stringify(["warn", _consoleFormat(arguments)]));
};
console.error = function () {
    sendMessage("log", JSON.stringify(["error", _consoleFormat(arguments)]));
};
String.prototype.substringAfter = function(pattern) {
    const startIndex = this.indexOf(pattern);
    if (startIndex === -1) return this.substring(0);

    const start = startIndex + pattern.length;
    return this.substring(start);
}

String.prototype.substringAfterLast = function(pattern) {
    return this.split(pattern).pop();
}

String.prototype.substringBefore = function(pattern) {
    const endIndex = this.indexOf(pattern);
    if (endIndex === -1) return this.substring(0);

    return this.substring(0, endIndex);
}

String.prototype.substringBeforeLast = function(pattern) {
    const endIndex = this.lastIndexOf(pattern);
    if (endIndex === -1) return this.substring(0);
    return this.substring(0, endIndex);
}

String.prototype.substringBetween = function(left, right) {
    let startIndex = 0;
    let index = this.indexOf(left, startIndex);
    if (index === -1) return "";
    let leftIndex = index + left.length;
    let rightIndex = this.indexOf(right, leftIndex);
    if (rightIndex === -1) return "";
    startIndex = rightIndex + right.length;
    return this.substring(leftIndex, rightIndex);
}

function cryptoHandler(text, iv, secretKeyString, encrypt) {
    return sendMessage(
        "cryptoHandler",
        JSON.stringify([text, iv, secretKeyString, encrypt])
    );
}
function encryptAESCryptoJS(plainText, passphrase) {
    return sendMessage(
        "encryptAESCryptoJS",
        JSON.stringify([plainText, passphrase])
    );
}
function decryptAESCryptoJS(encrypted, passphrase) {
    return sendMessage(
        "decryptAESCryptoJS",
        JSON.stringify([encrypted, passphrase])
    );
}
function deobfuscateJsPassword(inputString) {
    return sendMessage(
        "deobfuscateJsPassword",
        JSON.stringify([inputString])
    );
}
function unpackJsAndCombine(scriptBlock) {
    return sendMessage(
        "unpackJsAndCombine",
        JSON.stringify([scriptBlock])
    );
}
function unpackJs(packedJS) {
    return sendMessage(
        "unpackJs",
        JSON.stringify([packedJS])
    );
}
function parseDates(value, dateFormat, dateFormatLocale) {
    return sendMessage(
        "parseDates",
        JSON.stringify([value, dateFormat, dateFormatLocale])
    );
}
async function evaluateJavascriptViaWebview(url, headers, scripts) {
    return await sendMessage(
        "evaluateJavascriptViaWebview",
        JSON.stringify([url, headers, scripts])
    );
}
async function parseEpub(bookName, url, headers) {
    return JSON.parse(await sendMessage(
        "parseEpub",
        JSON.stringify([bookName, url, headers])
    ));
}
async function parseEpubChapter(bookName, url, headers, chapterTitle) {
    return await sendMessage(
        "parseEpubChapter",
        JSON.stringify([bookName, url, headers, chapterTitle])
    );
}
''');
  }

  Future<Uint8List> _toBytesResponse(
    http.Client client,
    String method,
    List args,
  ) async {
    final bookName = args[0] as String;
    final url = args[1] as String;
    final headers = (args[2] as Map?)?.toMapStringString;
    final body = args.length >= 4
        ? args[3] is List
              ? args[3] as List
              : args[3] is String
              ? args[3] as String
              : (args[3] as Map?)?.toMapStringDynamic
        : null;

    final tmpDirectory = (await StorageProvider().getTmpDirectory())!;
    if (!kIsWeb && Platform.isAndroid) {
      if (!(await File(p.join(tmpDirectory.path, ".nomedia")).exists())) {
        await File(p.join(tmpDirectory.path, ".nomedia")).create();
      }
    }
    final file = File(p.join(tmpDirectory.path, "$bookName.epub"));
    if (await file.exists()) {
      return await file.readAsBytes();
    }

    var request = http.Request(method, Uri.parse(url));
    request.headers.addAll(headers ?? {});
    final future = switch (method) {
      "GET" => client.get(Uri.parse(url), headers: headers),
      "POST" => client.post(Uri.parse(url), headers: headers, body: body),
      "PUT" => client.put(Uri.parse(url), headers: headers, body: body),
      "DELETE" => client.delete(Uri.parse(url), headers: headers, body: body),
      _ => client.patch(Uri.parse(url), headers: headers, body: body),
    };
    final bytes = (await future).bodyBytes;
    await file.writeAsBytes(bytes);
    return bytes;
  }
}
