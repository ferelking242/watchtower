/// JavaScript globals the QuickJS runtime does not ship but ported extensions
/// (Mihon / Aidoku contract) rely on.
///
/// `URL` is the one that bites: almost every ported extension builds its
/// request URLs with `new URL(path, baseUrl)`, and QuickJS has no URL class, so
/// those extensions died with `ReferenceError: 'URL' is not defined` — e.g.
/// 123AV on any home section. [kJsUrlPolyfill] adds `URL` and
/// `URLSearchParams` when they are missing and never shadows a native one.
const String kJsUrlPolyfill = r'''
(function () {
  var g = (typeof globalThis !== 'undefined') ? globalThis : this;

  function plusEncode(value) {
    return encodeURIComponent(String(value)).replace(/%20/g, '+');
  }

  function plusDecode(value) {
    try {
      return decodeURIComponent(String(value).replace(/\+/g, ' '));
    } catch (e) {
      return String(value);
    }
  }

  if (typeof g.URLSearchParams === 'undefined') {
    function URLSearchParams(init) {
      this._list = [];
      if (init === undefined || init === null) return;
      if (typeof init === 'string') {
        var query = init.charAt(0) === '?' ? init.slice(1) : init;
        if (!query) return;
        var parts = query.split('&');
        for (var i = 0; i < parts.length; i++) {
          var part = parts[i];
          if (!part) continue;
          var eq = part.indexOf('=');
          var name = eq === -1 ? part : part.slice(0, eq);
          var value = eq === -1 ? '' : part.slice(eq + 1);
          this._list.push([plusDecode(name), plusDecode(value)]);
        }
        return;
      }
      if (init instanceof URLSearchParams) {
        for (var j = 0; j < init._list.length; j++) {
          this._list.push([init._list[j][0], init._list[j][1]]);
        }
        return;
      }
      if (typeof init.length === 'number' && typeof init !== 'function') {
        for (var k = 0; k < init.length; k++) {
          this._list.push([String(init[k][0]), String(init[k][1])]);
        }
        return;
      }
      for (var key in init) {
        if (!Object.prototype.hasOwnProperty.call(init, key)) continue;
        this._list.push([String(key), String(init[key])]);
      }
    }

    URLSearchParams.prototype.append = function (name, value) {
      this._list.push([String(name), String(value)]);
    };
    URLSearchParams.prototype.get = function (name) {
      for (var i = 0; i < this._list.length; i++) {
        if (this._list[i][0] === String(name)) return this._list[i][1];
      }
      return null;
    };
    URLSearchParams.prototype.getAll = function (name) {
      var out = [];
      for (var i = 0; i < this._list.length; i++) {
        if (this._list[i][0] === String(name)) out.push(this._list[i][1]);
      }
      return out;
    };
    URLSearchParams.prototype.has = function (name) {
      return this.get(name) !== null;
    };
    URLSearchParams.prototype.set = function (name, value) {
      var found = false;
      for (var i = 0; i < this._list.length; i++) {
        if (this._list[i][0] !== String(name)) continue;
        if (!found) {
          this._list[i][1] = String(value);
          found = true;
        } else {
          this._list.splice(i, 1);
          i--;
        }
      }
      if (!found) this._list.push([String(name), String(value)]);
    };
    URLSearchParams.prototype['delete'] = function (name) {
      for (var i = 0; i < this._list.length; i++) {
        if (this._list[i][0] === String(name)) {
          this._list.splice(i, 1);
          i--;
        }
      }
    };
    URLSearchParams.prototype.forEach = function (callback) {
      for (var i = 0; i < this._list.length; i++) {
        callback(this._list[i][1], this._list[i][0], this);
      }
    };
    URLSearchParams.prototype.toString = function () {
      var out = [];
      for (var i = 0; i < this._list.length; i++) {
        out.push(
          plusEncode(this._list[i][0]) + '=' + plusEncode(this._list[i][1])
        );
      }
      return out.join('&');
    };

    g.URLSearchParams = URLSearchParams;
  }

  if (typeof g.URL === 'undefined') {
    var URL_PATTERN =
      /^([a-zA-Z][a-zA-Z0-9+.\-]*:)(\/\/([^\/?#]*))?([^?#]*)(\?[^#]*)?(#.*)?$/;

    function splitAbsolute(raw) {
      var m = URL_PATTERN.exec(String(raw));
      if (!m) throw new TypeError("Invalid URL: '" + raw + "'");
      var protocol = m[1].toLowerCase();
      var hasAuthority = m[2] !== undefined;
      var authority = m[3] || '';
      var host = authority;
      var username = '';
      var password = '';
      var at = authority.lastIndexOf('@');
      if (at !== -1) {
        var credentials = authority.slice(0, at);
        host = authority.slice(at + 1);
        var colon = credentials.indexOf(':');
        username = colon === -1 ? credentials : credentials.slice(0, colon);
        password = colon === -1 ? '' : credentials.slice(colon + 1);
      }
      var hostname = host;
      var port = '';
      var match = /^(\[[^\]]*\]|[^:]*)(?::(\d*))?$/.exec(host);
      if (match) {
        hostname = match[1];
        port = match[2] || '';
      }
      var path = m[4] || '';
      if (hasAuthority && !path) path = '/';
      return {
        protocol: protocol,
        authority: hasAuthority,
        username: username,
        password: password,
        hostname: hostname.toLowerCase(),
        port: port,
        pathname: path,
        search: m[5] || '',
        hash: m[6] || ''
      };
    }

    function removeDotSegments(path) {
      var absolute = path.charAt(0) === '/';
      var segments = path.split('/');
      var out = [];
      for (var i = 0; i < segments.length; i++) {
        var segment = segments[i];
        if (segment === '' || segment === '.') continue;
        if (segment === '..') {
          if (out.length) out.pop();
          continue;
        }
        out.push(segment);
      }
      var joined = out.join('/');
      var trailing = path.charAt(path.length - 1) === '/';
      return (absolute ? '/' : '') + joined + (trailing && joined ? '/' : '');
    }

    function format(parts) {
      var out = parts.protocol;
      if (parts.authority) {
        out += '//';
        if (parts.username || parts.password) {
          out += parts.username + (parts.password ? ':' + parts.password : '') + '@';
        }
        out += parts.hostname + (parts.port ? ':' + parts.port : '');
      }
      out += parts.pathname || '';
      out += parts.search || '';
      out += parts.hash || '';
      return out;
    }

    function resolveRelative(reference, baseRaw) {
      var ref = String(reference);
      if (/^[a-zA-Z][a-zA-Z0-9+.\-]*:/.test(ref)) return ref;
      var base = splitAbsolute(baseRaw);
      var result = {
        protocol: base.protocol,
        authority: base.authority,
        username: base.username,
        password: base.password,
        hostname: base.hostname,
        port: base.port,
        pathname: base.pathname,
        search: base.search,
        hash: ''
      };
      if (ref.charAt(0) === '#') {
        result.hash = ref;
        return format(result);
      }
      if (ref.charAt(0) === '?') {
        result.search = ref;
        return format(result);
      }
      var hashIndex = ref.indexOf('#');
      var hash = '';
      if (hashIndex !== -1) {
        hash = ref.slice(hashIndex);
        ref = ref.slice(0, hashIndex);
      }
      var queryIndex = ref.indexOf('?');
      var query = '';
      if (queryIndex !== -1) {
        query = ref.slice(queryIndex);
        ref = ref.slice(0, queryIndex);
      }
      result.search = query;
      result.hash = hash;
      var basePath = base.pathname || '/';
      var directory =
        ref.charAt(0) === '/'
          ? ''
          : basePath.slice(0, basePath.lastIndexOf('/') + 1);
      result.pathname = removeDotSegments(directory + ref) || '/';
      return format(result);
    }

    function URL(url, base) {
      if (!(this instanceof URL)) {
        throw new TypeError(
          "Failed to construct 'URL': Please use the 'new' operator."
        );
      }
      var raw =
        base === undefined
          ? String(url)
          : resolveRelative(String(url), String(base));
      var parts = splitAbsolute(raw);
      this.protocol = parts.protocol;
      this.username = parts.username;
      this.password = parts.password;
      this.hostname = parts.hostname;
      this.port = parts.port;
      this.host = parts.hostname + (parts.port ? ':' + parts.port : '');
      this.pathname = parts.pathname || '/';
      this.search = parts.search || '';
      this.hash = parts.hash || '';
      this.origin =
        parts.protocol === 'http:' || parts.protocol === 'https:'
          ? parts.protocol + '//' + this.host
          : 'null';
      this.searchParams = new g.URLSearchParams(this.search);
      this.href = format({
        protocol: parts.protocol,
        authority: parts.authority,
        username: parts.username,
        password: parts.password,
        hostname: parts.hostname,
        port: parts.port,
        pathname: this.pathname,
        search: this.search,
        hash: this.hash
      });
    }

    URL.prototype.toString = function () {
      return this.href;
    };
    URL.prototype.toJSON = function () {
      return this.href;
    };

    g.URL = URL;
  }
})();
''';
