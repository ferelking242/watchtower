import 'dart:typed_data';
import 'package:watchtower/src/rust/api/rhttp/client.dart' as rust_client;

export 'package:watchtower/src/rust/api/rhttp/client.dart' show TlsVersion;

const _keepBaseUrl = '__rhttp_keep__';
const _keepDuration = Duration(microseconds: -9999);
const _keepProxySettings = ProxySettings.noProxy();
const _keepRedirectSettings = RedirectSettings.limited(-9999);
const _keepDnsSettings = DnsSettings.static();
const _keepTlsSettings = TlsSettings();
const _keepTimeoutSettings = TimeoutSettings();

class ClientSettings {
  /// Base URL to be prefixed to all requests.
  final String? baseUrl;

  /// The timeout for the request including time to establish a connection.
  final Duration? timeout;

  /// Timeout and keep alive settings.
  final TimeoutSettings? timeoutSettings;

  /// Throws an exception if the status code is 4xx or 5xx.
  final bool throwOnStatusCode;

  /// Proxy settings.
  final ProxySettings? proxySettings;

  /// Redirect settings.
  /// By default, the client will follow maximum 10 redirects.
  /// See: https://docs.rs/reqwest/latest/reqwest/redirect/struct.Policy.html
  final RedirectSettings? redirectSettings;

  /// TLS settings.
  final TlsSettings? tlsSettings;

  /// DNS settings and resolver overrides.
  final DnsSettings? dnsSettings;

  const ClientSettings({
    this.baseUrl,
    this.timeout,
    this.timeoutSettings,
    this.throwOnStatusCode = true,
    this.proxySettings,
    this.redirectSettings,
    this.tlsSettings,
    this.dnsSettings,
  });

  ClientSettings copyWith({
    String? baseUrl = _keepBaseUrl,
    Duration? timeout = _keepDuration,
    TimeoutSettings? timeoutSettings = _keepTimeoutSettings,
    bool? throwOnStatusCode,
    ProxySettings? proxySettings = _keepProxySettings,
    RedirectSettings? redirectSettings = _keepRedirectSettings,
    TlsSettings? tlsSettings = _keepTlsSettings,
    DnsSettings? dnsSettings = _keepDnsSettings,
  }) {
    return ClientSettings(
      baseUrl: identical(baseUrl, _keepBaseUrl) ? this.baseUrl : baseUrl,
      timeout: identical(timeout, _keepDuration) ? this.timeout : timeout,
      timeoutSettings: identical(timeoutSettings, _keepTimeoutSettings)
          ? this.timeoutSettings
          : timeoutSettings,
      throwOnStatusCode: throwOnStatusCode ?? this.throwOnStatusCode,
      proxySettings: identical(proxySettings, _keepProxySettings)
          ? this.proxySettings
          : proxySettings,
      redirectSettings: identical(redirectSettings, _keepRedirectSettings)
          ? this.redirectSettings
          : redirectSettings,
      tlsSettings: identical(tlsSettings, _keepTlsSettings)
          ? this.tlsSettings
          : tlsSettings,
      dnsSettings: identical(dnsSettings, _keepDnsSettings)
          ? this.dnsSettings
          : dnsSettings,
    );
  }

  /// Value equality over the fields that actually reach the native client.
  ///
  /// `MClient` pools one native HTTP client per [ClientSettings]. Without this
  /// every call built a fresh instance, the identity-keyed pool missed, and a
  /// new reqwest client (with its own connection pool, TLS config and DNS
  /// cache) was registered in Rust for **every** request — an unbounded native
  /// leak that also defeated connection reuse.
  ///
  /// [timeout] and [baseUrl] are deliberately excluded: neither is part of
  /// `toRustType()` (`baseUrl` is prefixed per request and `timeout` is unused
  /// by the native path), so including them would split the pool again on
  /// every distinct per-request timeout.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClientSettings &&
          other.timeoutSettings == timeoutSettings &&
          other.throwOnStatusCode == throwOnStatusCode &&
          other.proxySettings == proxySettings &&
          other.redirectSettings == redirectSettings &&
          other.tlsSettings == tlsSettings &&
          other.dnsSettings == dnsSettings;

  @override
  int get hashCode => Object.hash(
    timeoutSettings,
    throwOnStatusCode,
    proxySettings,
    redirectSettings,
    tlsSettings,
    dnsSettings,
  );
}

sealed class ProxySettings {
  const ProxySettings();

  /// Disables any proxy settings including system settings.
  const factory ProxySettings.noProxy() = NoProxy._;
}

class NoProxy extends ProxySettings {
  const NoProxy._();

  @override
  bool operator ==(Object other) => other is NoProxy;

  @override
  int get hashCode => (NoProxy).hashCode;
}

sealed class RedirectSettings {
  const RedirectSettings();

  /// Disables any redirects and exceptions related to redirects.
  const factory RedirectSettings.none() = NoRedirectSetting._;

  /// Limits the number of redirects.
  const factory RedirectSettings.limited(int maxRedirects) = LimitedRedirects._;
}

/// Disables any redirects.
class NoRedirectSetting extends RedirectSettings {
  const NoRedirectSetting._();

  @override
  bool operator ==(Object other) => other is NoRedirectSetting;

  @override
  int get hashCode => (NoRedirectSetting).hashCode;
}

/// Limits the number of redirects.
class LimitedRedirects extends RedirectSettings {
  final int maxRedirects;

  const LimitedRedirects._(this.maxRedirects);

  @override
  bool operator ==(Object other) =>
      other is LimitedRedirects && other.maxRedirects == maxRedirects;

  @override
  int get hashCode => Object.hash(LimitedRedirects, maxRedirects);
}

/// TLS settings for the client.
/// Used to configure HTTPS connections.
class TlsSettings {
  /// Trust the root certificates that are pre-installed on the system.
  final bool trustRootCertificates;

  /// The trusted root certificates in PEM format.
  /// Either specify the root certificate or the full
  /// certificate chain.
  /// The Rust API currently doesn't support trusting a single leaf certificate.
  /// Hint: PEM format starts with `-----BEGIN CERTIFICATE-----`.
  final List<String> trustedRootCertificates;

  /// Verify the server's certificate.
  /// If set to `false`, the client will accept any certificate.
  /// This is insecure and should only be used for testing.
  final bool verifyCertificates;

  /// The client certificate to use.
  /// This is used for client authentication / mutual TLS.
  final ClientCertificate? clientCertificate;

  /// The minimum TLS version to use.
  final rust_client.TlsVersion? minTlsVersion;

  /// The maximum TLS version to use.
  final rust_client.TlsVersion? maxTlsVersion;

  const TlsSettings({
    this.trustRootCertificates = true,
    this.trustedRootCertificates = const [],
    this.verifyCertificates = true,
    this.clientCertificate,
    this.minTlsVersion,
    this.maxTlsVersion,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! TlsSettings ||
        other.trustRootCertificates != trustRootCertificates ||
        other.verifyCertificates != verifyCertificates ||
        other.clientCertificate != clientCertificate ||
        other.minTlsVersion != minTlsVersion ||
        other.maxTlsVersion != maxTlsVersion ||
        other.trustedRootCertificates.length !=
            trustedRootCertificates.length) {
      return false;
    }
    for (var i = 0; i < trustedRootCertificates.length; i++) {
      if (other.trustedRootCertificates[i] != trustedRootCertificates[i]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    TlsSettings,
    trustRootCertificates,
    verifyCertificates,
    clientCertificate,
    minTlsVersion,
    maxTlsVersion,
    Object.hashAll(trustedRootCertificates),
  );
}

/// A client certificate for client authentication / mutual TLS.
class ClientCertificate {
  /// The certificate in PEM format.
  final String certificate;

  /// The private key in PEM format.
  final String privateKey;

  const ClientCertificate({
    required this.certificate,
    required this.privateKey,
  });

  @override
  bool operator ==(Object other) =>
      other is ClientCertificate &&
      other.certificate == certificate &&
      other.privateKey == privateKey;

  @override
  int get hashCode => Object.hash(ClientCertificate, certificate, privateKey);
}

sealed class CustomProxy extends ProxySettings {
  const CustomProxy._();
}

class StaticProxy extends CustomProxy {
  /// The URL of the proxy server.
  final String url;

  /// Which requests to proxy.
  final ProxyCondition condition;

  const StaticProxy({required this.url, required this.condition}) : super._();

  const StaticProxy.http(String url)
    : this(url: url, condition: ProxyCondition.onlyHttp);

  const StaticProxy.https(String url)
    : this(url: url, condition: ProxyCondition.onlyHttps);

  const StaticProxy.all(String url)
    : this(url: url, condition: ProxyCondition.all);

  @override
  bool operator ==(Object other) =>
      other is StaticProxy && other.url == url && other.condition == condition;

  @override
  int get hashCode => Object.hash(StaticProxy, url, condition);
}

class CustomProxyList extends ProxySettings {
  /// A list of custom proxies.
  /// The first proxy that matches the request will be used.
  final List<CustomProxy> proxies;

  const CustomProxyList(this.proxies);

  @override
  bool operator ==(Object other) {
    if (other is! CustomProxyList) return false;
    if (other.proxies.length != proxies.length) return false;
    for (var i = 0; i < proxies.length; i++) {
      if (other.proxies[i] != proxies[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll([CustomProxyList, ...proxies]);
}

enum ProxyCondition {
  /// Proxy only HTTP requests.
  onlyHttp,

  /// Proxy only HTTPS requests.
  onlyHttps,

  /// Proxy all requests.
  all,
}

/// General timeout settings for the client.
class TimeoutSettings {
  /// The timeout for the request including time to establish a connection.
  final Duration? timeout;

  /// The timeout for establishing a connection.
  /// See [timeout] for the total timeout.
  final Duration? connectTimeout;

  /// Keep alive idle timeout. If not set, keep alive is disabled.
  final Duration? keepAliveTimeout;

  /// Keep alive ping interval.
  /// Only valid if keepAliveTimeout is set and HTTP/2 is used.
  final Duration keepAlivePing;

  const TimeoutSettings({
    this.timeout,
    this.connectTimeout,
    this.keepAliveTimeout,
    this.keepAlivePing = const Duration(seconds: 30),
  });

  TimeoutSettings copyWith({
    Duration? timeout,
    Duration? connectTimeout,
    Duration? keepAliveTimeout,
    Duration? keepAlivePing,
  }) {
    return TimeoutSettings(
      timeout: timeout ?? this.timeout,
      connectTimeout: connectTimeout ?? this.connectTimeout,
      keepAliveTimeout: keepAliveTimeout ?? this.keepAliveTimeout,
      keepAlivePing: keepAlivePing ?? this.keepAlivePing,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TimeoutSettings &&
      other.timeout == timeout &&
      other.connectTimeout == connectTimeout &&
      other.keepAliveTimeout == keepAliveTimeout &&
      other.keepAlivePing == keepAlivePing;

  @override
  int get hashCode =>
      Object.hash(TimeoutSettings, timeout, connectTimeout, keepAliveTimeout,
          keepAlivePing);
}

sealed class DnsSettings {
  const DnsSettings();

  /// Static DNS settings and resolver overrides
  /// for simple use cases.
  const factory DnsSettings.static({
    Map<String, List<String>> overrides,
    String? fallback,
  }) = StaticDnsSettings._;

  /// Dynamic DNS settings and resolver for more complex use cases.
  const factory DnsSettings.dynamic({
    required Future<List<String>> Function(String host) resolver,
  }) = DynamicDnsSettings._;
}

/// Static DNS settings and resolver overrides.
class StaticDnsSettings extends DnsSettings {
  /// Overrides the DNS resolver for specific hosts.
  /// The key is the host and the value is a list of IP addresses.
  final Map<String, List<String>> overrides;

  /// If set, the client will use this IP address for
  /// all requests that don't match any override.
  final String? fallback;

  const StaticDnsSettings._({this.overrides = const {}, this.fallback});

  @override
  bool operator ==(Object other) {
    if (other is! StaticDnsSettings ||
        other.fallback != fallback ||
        other.overrides.length != overrides.length) {
      return false;
    }
    for (final entry in overrides.entries) {
      final otherIps = other.overrides[entry.key];
      if (otherIps == null || otherIps.length != entry.value.length) {
        return false;
      }
      for (var i = 0; i < entry.value.length; i++) {
        if (otherIps[i] != entry.value[i]) return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    StaticDnsSettings,
    fallback,
    Object.hashAll([
      for (final entry in overrides.entries)
        Object.hash(entry.key, Object.hashAll(entry.value)),
    ]),
  );
}

/// Dynamic DNS settings and resolver.
class DynamicDnsSettings extends DnsSettings {
  /// The function to resolve the IP address for a host.
  final Future<List<String>> Function(String host) resolver;

  const DynamicDnsSettings._({required this.resolver});

  // The resolver is a closure, so two instances are only interchangeable when
  // they share it. `MClient` caches one instance per DoH provider so the pool
  // key stays stable across requests.
  @override
  bool operator ==(Object other) =>
      other is DynamicDnsSettings && identical(other.resolver, resolver);

  @override
  int get hashCode => Object.hash(DynamicDnsSettings, identityHashCode(resolver));
}

extension ClientSettingsExt on ClientSettings {
  rust_client.ClientSettings toRustType() {
    return rust_client.ClientSettings(
      timeoutSettings: timeoutSettings?._toRustType(),
      throwOnStatusCode: throwOnStatusCode,
      proxySettings: proxySettings?._toRustType(),
      redirectSettings: redirectSettings?._toRustType(),
      tlsSettings: tlsSettings?._toRustType(),
      dnsSettings: dnsSettings?._toRustType(),
    );
  }
}

extension on ProxySettings {
  rust_client.ProxySettings _toRustType() {
    return switch (this) {
      NoProxy() => const rust_client.ProxySettings.noProxy(),
      CustomProxy proxy => rust_client.ProxySettings.customProxyList([
        proxy._toRustType(),
      ]),
      CustomProxyList list => rust_client.ProxySettings.customProxyList(
        list.proxies.map((e) => e._toRustType()).toList(),
      ),
    };
  }
}

extension on CustomProxy {
  rust_client.CustomProxy _toRustType() {
    return switch (this) {
      StaticProxy s => rust_client.CustomProxy(
        url: s.url,
        condition: switch (s.condition) {
          ProxyCondition.onlyHttp => rust_client.ProxyCondition.http,
          ProxyCondition.onlyHttps => rust_client.ProxyCondition.https,
          ProxyCondition.all => rust_client.ProxyCondition.all,
        },
      ),
    };
  }
}

extension on TimeoutSettings {
  rust_client.TimeoutSettings _toRustType() {
    return rust_client.TimeoutSettings(
      timeout: timeout,
      connectTimeout: connectTimeout,
      keepAliveTimeout: keepAliveTimeout,
      keepAlivePing: keepAlivePing,
    );
  }
}

extension on RedirectSettings {
  rust_client.RedirectSettings _toRustType() {
    return switch (this) {
      NoRedirectSetting() => const rust_client.RedirectSettings.noRedirect(),
      LimitedRedirects r => rust_client.RedirectSettings.limitedRedirects(
        r.maxRedirects,
      ),
    };
  }
}

extension on TlsSettings {
  rust_client.TlsSettings _toRustType() {
    return rust_client.TlsSettings(
      trustRootCertificates: trustRootCertificates,
      trustedRootCertificates: trustedRootCertificates
          .map((e) => Uint8List.fromList(e.codeUnits))
          .toList(),
      verifyCertificates: verifyCertificates,
      clientCertificate: clientCertificate?._toRustType(),
      minTlsVersion: minTlsVersion,
      maxTlsVersion: maxTlsVersion,
    );
  }
}

extension on ClientCertificate {
  rust_client.ClientCertificate _toRustType() {
    return rust_client.ClientCertificate(
      certificate: Uint8List.fromList(certificate.codeUnits),
      privateKey: Uint8List.fromList(privateKey.codeUnits),
    );
  }
}

extension on DnsSettings {
  rust_client.DnsSettings _toRustType() {
    return switch (this) {
      StaticDnsSettings s => rust_client.createStaticResolverSync(
        settings: rust_client.StaticDnsSettings(
          overrides: s.overrides,
          fallback: s.fallback,
        ),
      ),
      DynamicDnsSettings d => rust_client.createDynamicResolverSync(
        resolver: d.resolver,
      ),
    };
  }
}
