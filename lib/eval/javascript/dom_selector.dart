import 'dart:convert';
  import 'package:flutter/foundation.dart';
  import 'package:watchtower/stubs/js_runtime_exports.dart';
  import 'package:html/dom.dart';
  import 'package:html/parser.dart';
  import 'package:watchtower/utils/extensions/dom_extensions.dart';

  class JsDomSelector {
    late JavascriptRuntime runtime;
    JsDomSelector(this.runtime);
    final Map<int, Element?> _elements = {};
    int _elementKey = 0;

    void init() {
      // ── Web: browser-native DOM (DOMParser) — no bridge calls needed ─────────
      if (kIsWeb) {
        runtime.evaluate(_kBrowserDocumentJs);
        return;
      }

      // ── Native (QuickJS): Dart-side bridge handlers + bridge-based JS classes ─
      runtime.onMessage('get_doc_element', (dynamic args) {
        final input = args[0];
        final type = args[1];
        final doc = parse(input);
        final element = switch (type) {
          'body' => doc.body,
          'documentElement' => doc.documentElement,
          'head' => doc.head,
          _ => doc.parent,
        };
        _elementKey++;
        _elements[_elementKey] = element;
        return _elementKey;
      });
      runtime.onMessage('get_doc_string', (dynamic args) {
        final input = args[0];
        final type = args[1];
        final doc = parse(input);
        final res = switch (type) {
          'text' => doc.text,
          _ => doc.outerHtml,
        };
        return res ?? "";
      });
      runtime.onMessage('get_element_string', (dynamic args) {
        final type = args[0];
        final key = args[1];
        final element = _elements[key];
        final res = switch (type) {
          'text' => element?.text,
          'innerHtml' => element?.innerHtml,
          'outerHtml' => element?.outerHtml,
          'className' => element?.className,
          'localName' => element?.localName,
          'namespaceUri' => element?.namespaceUri,
          'getSrc' => element?.getSrc,
          'getImg' => element?.getImg,
          'getHref' => element?.getHref,
          _ => element?.getDataSrc,
        };
        return res ?? "";
      });
      runtime.onMessage('doc_select_first', (dynamic args) {
        final input = args[0];
        final selector = args[1];
        _elementKey++;
        _elements[_elementKey] = parse(input).selectFirst(selector);
        return _elementKey;
      });
      runtime.onMessage('ele_selectFirst', (dynamic args) {
        final selector = args[0];
        final key = args[1];
        _elementKey++;
        _elements[_elementKey] = _elements[key]?.selectFirst(selector);
        return _elementKey;
      });
      runtime.onMessage('ele_element_sibling', (dynamic args) {
        final type = args[0];
        final key = args[1];
        final ele = _elements[key];
        final element = switch (type) {
          'nextElementSibling' => ele?.nextElementSibling,
          _ => ele?.previousElementSibling,
        };
        _elementKey++;
        _elements[_elementKey] = element;
        return _elementKey;
      });
      runtime.onMessage('ele_attr', (dynamic args) {
        final attr = args[0];
        final key = args[1];
        return _elements[key]?.attr(attr) ?? "";
      });
      runtime.onMessage('doc_attr', (dynamic args) {
        final input = args[0];
        final attr = args[1];
        return parse(input).attr(attr) ?? "";
      });
      runtime.onMessage('ele_has_attr', (dynamic args) {
        final attr = args[0];
        final key = args[1];
        return _elements[key]?.hasAtr(attr) ?? false;
      });
      runtime.onMessage('doc_has_attr', (dynamic args) {
        final input = args[0];
        final attr = args[1];
        return parse(input).hasAtr(attr);
      });
      runtime.onMessage('doc_xpath_first', (dynamic args) {
        final input = args[0];
        final xpath = args[1];
        return parse(input).xpathFirst(xpath) ?? "";
      });
      runtime.onMessage('ele_xpathFirst', (dynamic args) {
        final xpath = args[0];
        final key = args[1];
        return _elements[key]?.xpathFirst(xpath) ?? "";
      });
      runtime.onMessage('doc_xpath', (dynamic args) {
        final input = args[0];
        final xpath = args[1];
        return jsonEncode(parse(input).xpath(xpath));
      });
      runtime.onMessage('ele_xpath', (dynamic args) {
        final xpath = args[0];
        final key = args[1];
        return jsonEncode(_elements[key]?.xpath(xpath));
      });
      runtime.onMessage('doc_get_elements_by', (dynamic args) {
        final input = args[0];
        final type = args[1];
        final name = args[2];
        final doc = parse(input);
        final elements = switch (type) {
          'children' => doc.children,
          'getElementsByTagName' => doc.getElementsByTagName(name),
          _ => doc.getElementsByClassName(name),
        };
        List<int> elementKeys = [];
        for (var element in elements) {
          _elementKey++;
          _elements[_elementKey] = element;
          elementKeys.add(_elementKey);
        }
        return jsonEncode(elementKeys);
      });
      runtime.onMessage('ele_get_elements_by', (dynamic args) {
        final type = args[0];
        final name = args[1];
        final key = args[2];
        final element = _elements[key];
        final elements = switch (type) {
          'children' => element?.children,
          'getElementsByTagName' => element?.getElementsByTagName(name),
          _ => element?.getElementsByClassName(name),
        };
        List<int> elementKeys = [];
        for (var element in elements ?? []) {
          _elementKey++;
          _elements[_elementKey] = element;
          elementKeys.add(_elementKey);
        }
        return jsonEncode(elementKeys);
      });
      runtime.onMessage('doc_get_element_by_id', (dynamic args) {
        final input = args[0];
        final id = args[1];
        _elementKey++;
        _elements[_elementKey] = parse(input).getElementById(id);
        return _elementKey;
      });
      runtime.onMessage('doc_select', (dynamic args) {
        final input = args[0];
        final selector = args[1];
        final elements = parse(input).select(selector);
        List<int> elementKeys = [];
        for (var element in elements ?? []) {
          _elementKey++;
          _elements[_elementKey] = element;
          elementKeys.add(_elementKey);
        }
        return jsonEncode(elementKeys);
      });
      runtime.onMessage('ele_select', (dynamic args) {
        final selector = args[0];
        final key = args[1];
        final elements = _elements[key]?.select(selector);
        List<int> elementKeys = [];
        for (var element in elements ?? []) {
          _elementKey++;
          _elements[_elementKey] = element;
          elementKeys.add(_elementKey);
        }
        return jsonEncode(elementKeys);
      });

      runtime.evaluate(_kNativeDocumentJs);
    }

    void dispose() {
      if (_elements.isEmpty) return;
      _elements.clear();
      _elementKey = 0;
    }
  }

  // ── Browser-native Document/Element — uses DOMParser, fully synchronous ──────
  // On web, sendMessage() returns Promises, so the bridge-based implementation
  // breaks (JSON.parse(Promise) → "[object Promise]"). Instead we use the
  // browser's built-in DOMParser and querySelector APIs which are synchronous.
  const String _kBrowserDocumentJs = r"""
  function _wtXpathFirst(ctx, xp) {
      try {
          var doc = ctx.ownerDocument || ctx;
          var r = doc.evaluate(xp, ctx, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null);
          var n = r.singleNodeValue;
          return n ? (n.textContent || "") : "";
      } catch(e) { return ""; }
  }
  function _wtXpathAll(ctx, xp) {
      try {
          var doc = ctx.ownerDocument || ctx;
          var r = doc.evaluate(xp, ctx, null, XPathResult.ORDERED_NODE_ITERATOR_TYPE, null);
          var nodes = []; var n;
          while ((n = r.iterateNext())) nodes.push(n.textContent || "");
          return nodes;
      } catch(e) { return []; }
  }
  class Document {
      constructor(html) {
          this._doc = (new DOMParser()).parseFromString(
              typeof html === 'string' ? html : '', 'text/html');
      }
      get body() { return new Element(this._doc.body); }
      get documentElement() { return new Element(this._doc.documentElement); }
      get head() { return new Element(this._doc.head); }
      get parent() { return new Element(this._doc.documentElement); }
      get text() {
          return this._doc.documentElement ? this._doc.documentElement.textContent : "";
      }
      get outerHtml() {
          return this._doc.documentElement ? this._doc.documentElement.outerHTML : "";
      }
      selectFirst(selector) {
          try { return new Element(this._doc.querySelector(selector) || null); }
          catch(e) { return new Element(null); }
      }
      select(selector) {
          try { return Array.from(this._doc.querySelectorAll(selector)).map(function(el){ return new Element(el); }); }
          catch(e) { return []; }
      }
      attr(attr) {
          var el = this._doc.documentElement;
          return el ? (el.getAttribute(attr) || "") : "";
      }
      hasAttr(attr) {
          var el = this._doc.documentElement;
          return el ? el.hasAttribute(attr) : false;
      }
      getElementById(id) {
          return new Element(this._doc.getElementById(id) || null);
      }
      getElementsByTagName(name) {
          return Array.from(this._doc.getElementsByTagName(name)).map(function(el){ return new Element(el); });
      }
      getElementsByClassName(name) {
          return Array.from(this._doc.getElementsByClassName(name)).map(function(el){ return new Element(el); });
      }
      get children() {
          var body = this._doc.body;
          return body ? Array.from(body.children).map(function(el){ return new Element(el); }) : [];
      }
      xpathFirst(xpath) { return _wtXpathFirst(this._doc, xpath); }
      xpath(xpath) { return _wtXpathAll(this._doc, xpath); }
  }
  class Element {
      constructor(node) { this._node = node || null; }
      get text() { return this._node ? (this._node.textContent || "") : ""; }
      get outerHtml() { return this._node ? (this._node.outerHTML || "") : ""; }
      get innerHtml() { return this._node ? (this._node.innerHTML || "") : ""; }
      get className() { return this._node ? (this._node.className || "") : ""; }
      get localName() { return this._node ? (this._node.localName || "") : ""; }
      get namespaceUri() { return this._node ? (this._node.namespaceURI || "") : ""; }
      get getSrc() {
          if (!this._node) return "";
          return this._node.getAttribute('src') || this._node.getAttribute('data-src') || "";
      }
      get getImg() {
          if (!this._node) return "";
          var img = (this._node.tagName || '').toUpperCase() === 'IMG'
              ? this._node
              : this._node.querySelector('img');
          if (!img) return "";
          return img.getAttribute('src') || img.getAttribute('data-src') || "";
      }
      get getHref() {
          return this._node ? (this._node.getAttribute('href') || "") : "";
      }
      get getDataSrc() {
          return this._node ? (this._node.getAttribute('data-src') || "") : "";
      }
      get previousElementSibling() {
          return new Element(this._node ? this._node.previousElementSibling : null);
      }
      get nextElementSibling() {
          return new Element(this._node ? this._node.nextElementSibling : null);
      }
      get children() {
          if (!this._node) return [];
          return Array.from(this._node.children).map(function(el){ return new Element(el); });
      }
      getElementsByTagName(name) {
          if (!this._node) return [];
          return Array.from(this._node.getElementsByTagName(name)).map(function(el){ return new Element(el); });
      }
      getElementsByClassName(name) {
          if (!this._node) return [];
          return Array.from(this._node.getElementsByClassName(name)).map(function(el){ return new Element(el); });
      }
      selectFirst(selector) {
          if (!this._node) return new Element(null);
          try { return new Element(this._node.querySelector(selector) || null); }
          catch(e) { return new Element(null); }
      }
      select(selector) {
          if (!this._node) return [];
          try { return Array.from(this._node.querySelectorAll(selector)).map(function(el){ return new Element(el); }); }
          catch(e) { return []; }
      }
      attr(attr) {
          return this._node ? (this._node.getAttribute(attr) || "") : "";
      }
      hasAttr(attr) {
          return this._node ? this._node.hasAttribute(attr) : false;
      }
      xpathFirst(xpath) { return _wtXpathFirst(this._node, xpath); }
      xpath(xpath) { return _wtXpathAll(this._node, xpath); }
  }
  """;

  // ── QuickJS-native Document/Element — bridge-based (sendMessage synchronous) ─
  const String _kNativeDocumentJs = r"""
  class Document {
      constructor(html) {
          this.html = html;
      }
      getElement(type) {
          const key = sendMessage(
              "get_doc_element",
              JSON.stringify([this.html, type])
          );
          return new Element(key);
      }
      get body() {
          return this.getElement('body');
      }
      get documentElement() {
          return this.getElement('documentElement');
      }
      get head() {
          return this.getElement('head');
      }
      get parent() {
          return this.getElement('parent');
      }
      getString(type) {
          return sendMessage(
              "get_doc_string",
              JSON.stringify([this.html, type]));
      }
      get text() {
          return this.getString('text');
      }
      get outerHtml() {
          return this.getString('outerHtml');
      }
      selectFirst(selector) {
          const key = sendMessage(
              "doc_select_first",
              JSON.stringify([this.html, selector])
          );
          return new Element(key);
      }
      select(selector) {
          let elements = [];
          JSON.parse(
              sendMessage("doc_select", JSON.stringify([this.html, selector]))
          ).forEach((key) => {
              elements.push(new Element(key));
          });
          return elements;
      }
      xpathFirst(xpath) {
          return sendMessage(
              "doc_xpath_first",
              JSON.stringify([this.html, xpath])
          );
      }
      xpath(xpath) {
          return JSON.parse(sendMessage(
              "doc_xpath",
              JSON.stringify([this.html, xpath]))
          );
      }
      getElementsListBy(type, name) {
          name = name || '';
          let elements = [];
          JSON.parse(sendMessage(
              "doc_get_elements_by",
              JSON.stringify([this.html, type, name]))
          ).forEach((key) => {
              elements.push(new Element(key));
          });
          return elements;
      }
      get children() {
          return this.getElementsListBy('children');
      }
      getElementsByTagName(name) {
          return this.getElementsListBy('getElementsByTagName', name);
      }
      getElementsByClassName(name) {
          return this.getElementsListBy('getElementsByClassName', name);
      }
      getElementById(id) {
          const key = sendMessage(
              "doc_get_element_by_id",
              JSON.stringify([this.html, id])
          );
          return new Element(key);
      }
      attr(attr) {
          return sendMessage(
              "doc_attr",
              JSON.stringify([this.key, attr])
          );
      }
      hasAttr(attr) {
          return sendMessage(
              "doc_has_attr",
              JSON.stringify([this.html, attr])
          );
      }
  }

  class Element {
      constructor(key) {
          this.key = key;
      }
      getString(type) {
          return sendMessage(
              "get_element_string",
              JSON.stringify([type, this.key])
          );
      }
      get text() {
          return this.getString("text");
      }
      get outerHtml() {
          return this.getString("outerHtml");
      }
      get innerHtml() {
          return this.getString("innerHtml");
      }
      get className() {
          return this.getString("className");
      }
      get localName() {
          return this.getString("localName");
      }
      get namespaceUri() {
          return this.getString("namespaceUri");
      }
      get getSrc() {
          return this.getString("getSrc");
      }
      get getImg() {
          return this.getString("getImg");
      }
      get getHref() {
          return this.getString("getHref");
      }
      get getDataSrc() {
          return this.getString("getDataSrc");
      }
      getElementSibling(type) {
          const key = sendMessage(
              "ele_element_sibling",
              JSON.stringify([type, this.key])
          );
          return new Element(key);
      }
      get previousElementSibling() {
          return this.getElementSibling("previousElementSibling");
      }
      get nextElementSibling() {
          return this.getElementSibling("nextElementSibling");
      }
      getElementsListBy(type, name) {
          name = name || '';
          let elements = [];
          JSON.parse(sendMessage(
              "ele_get_elements_by",
              JSON.stringify([type, name, this.key]))
          ).forEach((key) => {
              elements.push(new Element(key));
          });
          return elements;
      }
      get children() {
          return this.getElementsListBy('children');
      }
      getElementsByTagName(name) {
          return this.getElementsListBy('getElementsByTagName', name);
      }
      getElementsByClassName(name) {
          return this.getElementsListBy('getElementsByClassName', name);
      }
      xpath(xpath) {
          return JSON.parse(sendMessage(
              "ele_xpath",
              JSON.stringify([xpath, this.key]))
          );
      }
      attr(attr) {
          return sendMessage(
              "ele_attr",
              JSON.stringify([attr, this.key])
          );
      }
      xpathFirst(xpath) {
          return sendMessage(
              "ele_xpathFirst",
              JSON.stringify([xpath, this.key])
          );
      }
      selectFirst(selector) {
          const key = sendMessage(
              "ele_selectFirst",
              JSON.stringify([selector, this.key])
          );
          return new Element(key);
      }
      select(selector) {
          let elements = [];
          JSON.parse(
              sendMessage("ele_select", JSON.stringify([selector, this.key]))
          ).forEach((key) => {
              elements.push(new Element(key));
          });
          return elements;
      }
      hasAttr(attr) {
          return sendMessage(
              "ele_has_attr",
              JSON.stringify([this.html, attr])
          );
      }
  }
  """;
  