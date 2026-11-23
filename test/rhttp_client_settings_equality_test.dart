import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/services/http/rhttp/src/model/settings.dart';

void main() {
  group('ClientSettings equality', () {
    test('two settings with the same native configuration are equal', () {
      final a = ClientSettings(
        throwOnStatusCode: false,
        timeout: const Duration(seconds: 60),
        timeoutSettings: const TimeoutSettings(
          connectTimeout: Duration(seconds: 30),
          keepAliveTimeout: Duration(seconds: 30),
        ),
        tlsSettings: const TlsSettings(verifyCertificates: true),
      );
      final b = ClientSettings(
        throwOnStatusCode: false,
        timeout: const Duration(seconds: 60),
        timeoutSettings: const TimeoutSettings(
          connectTimeout: Duration(seconds: 30),
          keepAliveTimeout: Duration(seconds: 30),
        ),
        tlsSettings: const TlsSettings(verifyCertificates: true),
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('a per-request timeout does not split the pool key', () {
      // `timeout` never reaches the native client, so two requests that only
      // differ by it must share one pooled client instead of registering a new
      // reqwest client each.
      final short = ClientSettings(timeout: const Duration(seconds: 5));
      final long = ClientSettings(timeout: const Duration(seconds: 120));

      expect(short, equals(long));
      expect(short.hashCode, equals(long.hashCode));
    });

    test('a different connect timeout is a different client', () {
      final a = ClientSettings(
        timeoutSettings: const TimeoutSettings(
          connectTimeout: Duration(seconds: 10),
        ),
      );
      final b = ClientSettings(
        timeoutSettings: const TimeoutSettings(
          connectTimeout: Duration(seconds: 60),
        ),
      );

      expect(a, isNot(equals(b)));
    });

    test('proxy and TLS differences are distinct clients', () {
      final plain = ClientSettings();
      final noProxy = ClientSettings(
        proxySettings: const ProxySettings.noProxy(),
      );
      final insecure = ClientSettings(
        tlsSettings: const TlsSettings(verifyCertificates: false),
      );

      expect(plain, isNot(equals(noProxy)));
      expect(plain, isNot(equals(insecure)));
      expect(noProxy, equals(ClientSettings(
        proxySettings: const ProxySettings.noProxy(),
      )));
    });

    test('TLS settings compare their certificate list by value', () {
      final a = ClientSettings(
        tlsSettings: const TlsSettings(
          trustedRootCertificates: ['pem-a', 'pem-b'],
        ),
      );
      final b = ClientSettings(
        tlsSettings: const TlsSettings(
          trustedRootCertificates: ['pem-a', 'pem-b'],
        ),
      );
      final c = ClientSettings(
        tlsSettings: const TlsSettings(
          trustedRootCertificates: ['pem-a'],
        ),
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });

    test('static DNS overrides compare by value', () {
      final a = ClientSettings(
        dnsSettings: const DnsSettings.static(
          overrides: {
            'example.com': ['10.0.0.1'],
          },
        ),
      );
      final b = ClientSettings(
        dnsSettings: const DnsSettings.static(
          overrides: {
            'example.com': ['10.0.0.1'],
          },
        ),
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('dynamic DNS resolvers are compared by identity', () {
      Future<List<String>> resolver(String host) async => const [];
      Future<List<String>> other(String host) async => const [];

      final shared = ClientSettings(
        dnsSettings: DnsSettings.dynamic(resolver: resolver),
      );
      final sameResolver = ClientSettings(
        dnsSettings: DnsSettings.dynamic(resolver: resolver),
      );
      final otherResolver = ClientSettings(
        dnsSettings: DnsSettings.dynamic(resolver: other),
      );

      expect(shared, equals(sameResolver));
      expect(shared, isNot(equals(otherResolver)));
    });
  });
}
