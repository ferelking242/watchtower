'use strict';
const cheerio = require('cheerio');

// ── Element store (mimics Dart's _elements map) ──────────────────────────────
// Each loaded document or selected element gets a numeric key.

class ElementStore {
  constructor() {
    this._store = new Map();
    this._counter = 0;
  }
  set(el, $) {
    this._counter++;
    this._store.set(this._counter, { el, $ });
    return this._counter;
  }
  get(key) { return this._store.get(key); }
  clear() { this._store.clear(); this._counter = 0; }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

function cheerioLoad(html) {
  return cheerio.load(html, { xmlMode: false, decodeEntities: false });
}

function elText(el, $) {
  if (!el || !el.length) return '';
  return $.text(el).trim();
}

function elAttr(el, $, attr) {
  if (!el || !el.length) return '';
  return el.attr(attr) || '';
}

function elHtml(el, $) {
  if (!el || !el.length) return '';
  return $.html(el) || '';
}

function elOuterHtml(el, $) {
  if (!el || !el.length) return '';
  // cheerio doesn't have outerHtml directly; wrap in a dummy container
  const wrap = cheerio.load('<div id="_w_"></div>');
  wrap('#_w_').append(el.clone());
  return wrap('#_w_').html() || '';
}

function getSrc(el, $) {
  if (!el || !el.length) return '';
  return el.attr('src') || el.attr('data-src') || el.attr('data-original') || '';
}

function getImg(el, $) { return getSrc(el, $); }

function getHref(el, $) {
  if (!el || !el.length) return '';
  return el.attr('href') || '';
}

function getDataSrc(el, $) {
  if (!el || !el.length) return '';
  return el.attr('data-src') || el.attr('data-lazy') || el.attr('data-original') || '';
}

// XPath — basic support via xpath + xmldom
let xpathLib, xmldomLib;
function xpathQuery(html, xpathExpr) {
  try {
    if (!xpathLib) xpathLib = require('xpath');
    if (!xmldomLib) xmldomLib = require('@xmldom/xmldom');
    const DOMParser = new xmldomLib.DOMParser({
      errorHandler: { warning: () => {}, error: () => {}, fatalError: () => {} },
    });
    const doc = DOMParser.parseFromString(html, 'text/html');
    const nodes = xpathLib.select(xpathExpr, doc);
    return (Array.isArray(nodes) ? nodes : [nodes])
      .map(n => (n && n.nodeValue != null ? n.nodeValue : n && n.toString ? n.toString() : ''))
      .filter(Boolean);
  } catch (e) {
    return [];
  }
}

// ── DOM Bridge factory — called once per JS runtime instance ─────────────────
// Returns the JS string that defines Document and Element classes,
// and also registers native handlers on the runtime.

function registerDomBridge(runtime, store) {
  // Native handlers
  runtime.onMessage('get_doc_element', ([input, type]) => {
    const $ = cheerioLoad(input);
    let el;
    if (type === 'body') el = $('body');
    else if (type === 'head') el = $('head');
    else if (type === 'documentElement') el = $('html');
    else el = $.root();
    return store.set(el, $);
  });

  runtime.onMessage('get_doc_string', ([input, type]) => {
    const $ = cheerioLoad(input);
    if (type === 'text') return $.text() || '';
    return $.html() || '';
  });

  runtime.onMessage('get_element_string', ([type, key]) => {
    const entry = store.get(key);
    if (!entry) return '';
    const { el, $ } = entry;
    switch (type) {
      case 'text':       return elText(el, $);
      case 'innerHtml':  return elHtml(el, $);
      case 'outerHtml':  return elOuterHtml(el, $);
      case 'className':  return el.attr('class') || '';
      case 'localName':  return el.get(0)?.tagName || '';
      case 'namespaceUri': return '';
      case 'getSrc':     return getSrc(el, $);
      case 'getImg':     return getImg(el, $);
      case 'getHref':    return getHref(el, $);
      default:           return getDataSrc(el, $);
    }
  });

  runtime.onMessage('doc_select_first', ([input, selector]) => {
    const $ = cheerioLoad(input);
    const el = $(selector).first();
    return store.set(el, $);
  });

  runtime.onMessage('ele_selectFirst', ([selector, key]) => {
    const entry = store.get(key);
    if (!entry) return store.set(cheerio(''), cheerioLoad(''));
    const el = entry.el.find(selector).first();
    return store.set(el, entry.$);
  });

  runtime.onMessage('ele_select', ([selector, key]) => {
    const entry = store.get(key);
    if (!entry) return '[]';
    const results = [];
    entry.el.find(selector).each((_, node) => {
      const child = entry.$(node);
      results.push(store.set(child, entry.$));
    });
    return JSON.stringify(results);
  });

  runtime.onMessage('doc_select', ([input, selector]) => {
    const $ = cheerioLoad(input);
    const results = [];
    $(selector).each((_, node) => {
      results.push(store.set($(node), $));
    });
    return JSON.stringify(results);
  });

  runtime.onMessage('ele_element_sibling', ([type, key]) => {
    const entry = store.get(key);
    if (!entry) return store.set(cheerio(''), cheerioLoad(''));
    let el;
    if (type === 'nextElementSibling') el = entry.el.next();
    else el = entry.el.prev();
    return store.set(el, entry.$);
  });

  runtime.onMessage('ele_attr', ([attr, key]) => {
    const entry = store.get(key);
    if (!entry) return '';
    return elAttr(entry.el, entry.$, attr);
  });

  runtime.onMessage('doc_attr', ([input, attr]) => {
    const $ = cheerioLoad(input);
    return $('[' + attr + ']').first().attr(attr) || '';
  });

  runtime.onMessage('ele_has_attr', ([attr, key]) => {
    const entry = store.get(key);
    if (!entry) return false;
    return entry.el.is('[' + attr + ']');
  });

  runtime.onMessage('doc_has_attr', ([input, attr]) => {
    const $ = cheerioLoad(input);
    return $('[' + attr + ']').length > 0;
  });

  runtime.onMessage('doc_xpath_first', ([input, xpath]) => {
    const results = xpathQuery(input, xpath);
    return results[0] || '';
  });

  runtime.onMessage('doc_xpath', ([input, xpath]) => {
    return JSON.stringify(xpathQuery(input, xpath));
  });

  runtime.onMessage('ele_xpath', ([xpath, key]) => {
    const entry = store.get(key);
    if (!entry) return '[]';
    const html = elOuterHtml(entry.el, entry.$);
    return JSON.stringify(xpathQuery(html, xpath));
  });

  runtime.onMessage('ele_xpathFirst', ([xpath, key]) => {
    const entry = store.get(key);
    if (!entry) return '';
    const html = elOuterHtml(entry.el, entry.$);
    const results = xpathQuery(html, xpath);
    return results[0] || '';
  });

  runtime.onMessage('ele_parent', ([key]) => {
    const entry = store.get(key);
    if (!entry) return store.set(cheerio(''), cheerioLoad(''));
    return store.set(entry.el.parent(), entry.$);
  });

  runtime.onMessage('ele_children', ([key]) => {
    const entry = store.get(key);
    if (!entry) return '[]';
    const results = [];
    entry.el.children().each((_, node) => {
      results.push(store.set(entry.$(node), entry.$));
    });
    return JSON.stringify(results);
  });

  runtime.onMessage('ele_getElementsByTag', ([tag, key]) => {
    const entry = store.get(key);
    if (!entry) return '[]';
    const results = [];
    entry.el.find(tag).each((_, node) => {
      results.push(store.set(entry.$(node), entry.$));
    });
    return JSON.stringify(results);
  });

  runtime.onMessage('ele_getElementsByClass', ([cls, key]) => {
    const entry = store.get(key);
    if (!entry) return '[]';
    const results = [];
    entry.el.find('.' + cls).each((_, node) => {
      results.push(store.set(entry.$(node), entry.$));
    });
    return JSON.stringify(results);
  });

  // Return the JS class definitions that mirror the Flutter bridge
  return `
class Document {
  constructor(html) { this.html = html; }
  get body() {
    const k = sendMessage('get_doc_element', JSON.stringify([this.html, 'body']));
    return new Element(k);
  }
  get head() {
    const k = sendMessage('get_doc_element', JSON.stringify([this.html, 'head']));
    return new Element(k);
  }
  get documentElement() {
    const k = sendMessage('get_doc_element', JSON.stringify([this.html, 'documentElement']));
    return new Element(k);
  }
  get text() { return sendMessage('get_doc_string', JSON.stringify([this.html, 'text'])); }
  get outerHtml() { return sendMessage('get_doc_string', JSON.stringify([this.html, 'outerHtml'])); }
  selectFirst(selector) {
    const k = sendMessage('doc_select_first', JSON.stringify([this.html, selector]));
    return new Element(k);
  }
  select(selector) {
    const keys = JSON.parse(sendMessage('doc_select', JSON.stringify([this.html, selector])));
    return keys.map(k => new Element(k));
  }
  attr(attr) { return sendMessage('doc_attr', JSON.stringify([this.html, attr])); }
  hasAttr(attr) { return sendMessage('doc_has_attr', JSON.stringify([this.html, attr])); }
  xpath(xp) { return JSON.parse(sendMessage('doc_xpath', JSON.stringify([this.html, xp]))); }
  xpathFirst(xp) { return sendMessage('doc_xpath_first', JSON.stringify([this.html, xp])); }
}

class Element {
  constructor(key) { this.key = key; }
  get text() { return sendMessage('get_element_string', JSON.stringify(['text', this.key])); }
  get innerHtml() { return sendMessage('get_element_string', JSON.stringify(['innerHtml', this.key])); }
  get outerHtml() { return sendMessage('get_element_string', JSON.stringify(['outerHtml', this.key])); }
  get className() { return sendMessage('get_element_string', JSON.stringify(['className', this.key])); }
  get localName() { return sendMessage('get_element_string', JSON.stringify(['localName', this.key])); }
  get src() { return sendMessage('get_element_string', JSON.stringify(['getSrc', this.key])); }
  get dataSrc() { return sendMessage('get_element_string', JSON.stringify(['getDataSrc', this.key])); }
  get href() { return sendMessage('get_element_string', JSON.stringify(['getHref', this.key])); }
  get nextElementSibling() {
    const k = sendMessage('ele_element_sibling', JSON.stringify(['nextElementSibling', this.key]));
    return new Element(k);
  }
  get previousElementSibling() {
    const k = sendMessage('ele_element_sibling', JSON.stringify(['previousElementSibling', this.key]));
    return new Element(k);
  }
  get parent() {
    const k = sendMessage('ele_parent', JSON.stringify([this.key]));
    return new Element(k);
  }
  get children() {
    const keys = JSON.parse(sendMessage('ele_children', JSON.stringify([this.key])));
    return keys.map(k => new Element(k));
  }
  attr(attr) { return sendMessage('ele_attr', JSON.stringify([attr, this.key])); }
  hasAttr(attr) { return sendMessage('ele_has_attr', JSON.stringify([attr, this.key])); }
  selectFirst(selector) {
    const k = sendMessage('ele_selectFirst', JSON.stringify([selector, this.key]));
    return new Element(k);
  }
  select(selector) {
    const keys = JSON.parse(sendMessage('ele_select', JSON.stringify([selector, this.key])));
    return keys.map(k => new Element(k));
  }
  xpath(xp) { return JSON.parse(sendMessage('ele_xpath', JSON.stringify([xp, this.key]))); }
  xpathFirst(xp) { return sendMessage('ele_xpathFirst', JSON.stringify([xp, this.key])); }
  getElementsByTagName(tag) {
    const keys = JSON.parse(sendMessage('ele_getElementsByTag', JSON.stringify([tag, this.key])));
    return keys.map(k => new Element(k));
  }
  getElementsByClassName(cls) {
    const keys = JSON.parse(sendMessage('ele_getElementsByClass', JSON.stringify([cls, this.key])));
    return keys.map(k => new Element(k));
  }
}

function parse(html) { return new Document(html); }
`;
}

module.exports = { registerDomBridge, ElementStore };
