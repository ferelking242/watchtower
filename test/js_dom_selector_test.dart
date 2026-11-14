import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/eval/javascript/dom_selector.dart';
import 'package:watchtower/stubs/js_runtime_exports.dart';

void main() {
  test('native document root supports descendant selectors', () {
    final runtime = _RecordingJavascriptRuntime();
    JsDomSelector(runtime).init();

    const html =
        '<html><body><div class="thumb-container">XNXX result</div></body></html>';
    final getDocumentElement = runtime.handlers['get_doc_element']!;
    final selectFirst = runtime.handlers['ele_selectFirst']!;
    final selectAll = runtime.handlers['ele_select']!;
    final getElementString = runtime.handlers['get_element_string']!;

    for (final rootType in ['documentElement', 'parent']) {
      final rootKey = getDocumentElement([html, rootType]) as int;
      final rootText = getElementString(['text', rootKey]) as String;
      expect(
        rootText,
        contains('XNXX result'),
        reason: 'The $rootType bridge root did not retain the parsed HTML.',
      );
      final resultKey = selectFirst(['.thumb-container', rootKey]) as int;

      expect(
        getElementString(['text', resultKey]),
        'XNXX result',
        reason: 'Descendant selector failed from the $rootType bridge root.',
      );

      final resultKeys =
          (jsonDecode(selectAll(['.thumb-container', rootKey]) as String) as List)
              .cast<int>();
      expect(resultKeys, hasLength(1), reason: 'root type: $rootType');
      expect(getElementString(['text', resultKeys.single]), 'XNXX result');
    }
  });

  test('bridge exposes exactly the element-keyed handlers', () {
    final runtime = _RecordingJavascriptRuntime();
    JsDomSelector(runtime).init();

    // The old doc_* handlers re-ran parse(input) on every call. The native JS
    // Document now keeps an element key, so get_doc_element is the only handler
    // allowed to parse the HTML; everything else works off that key.
    expect(
      runtime.handlers.keys.toSet(),
      {
        'get_doc_element',
        'get_element_string',
        'ele_selectFirst',
        'ele_select',
        'ele_element_sibling',
        'ele_attr',
        'ele_has_attr',
        'ele_xpathFirst',
        'ele_xpath',
        'ele_get_elements_by',
      },
      reason: 'a doc_* handler reparses the whole document on every selector',
    );
  });
}

class _RecordingJavascriptRuntime implements JavascriptRuntime {
  final handlers = <String, dynamic Function(dynamic args)>{};

  @override
  void onMessage(String channelName, dynamic Function(dynamic args) fn) {
    handlers[channelName] = fn;
  }

  @override
  JsEvalResult evaluate(String code, {String? sourceUrl}) =>
      JsEvalResult('', null);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
