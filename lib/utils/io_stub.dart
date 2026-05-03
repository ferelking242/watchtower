// ignore_for_file: non_constant_identifier_names, constant_identifier_names
// Web stub — imported instead of dart:io when dart.library.js_interop is true.
// Goal: enough for the Flutter web UI to compile and render.

import 'dart:async';
import 'dart:typed_data';

// ─── Re-export stable dart:io classes that exist on Flutter web ───────────────
export 'dart:io'
    show
        File,
        Directory,
        FileMode,
        FileSystemEntity,
        FileSystemEntityType,
        FileStat,
        Link,
        Platform,
        exit;

// ─── IOSink stub (dart:io.IOSink not available on Flutter web) ────────────────
class IOSink implements StringSink {
  @override void write(Object? obj) {}
  @override void writeln([Object? obj = '']) {}
  @override void writeAll(Iterable objects, [String separator = '']) {}
  @override void writeCharCode(int charCode) {}
  void add(List<int> data) {}
  void addError(Object error, [StackTrace? stackTrace]) {}
  Future<void> addStream(Stream<List<int>> stream) async {}
  Future<void> flush() async {}
  Future<void> close() async {}
  Future<void> get done async {}
}

// ─── RandomAccessFile stub (dart:io.RandomAccessFile not available on web) ────
class RandomAccessFile {
  Future<void>             close()                                     async {}
  Future<int>              length()                                    async => 0;
  Future<int>              position()                                  async => 0;
  Future<RandomAccessFile> setPosition(int position)                   async => this;
  Future<List<int>>        read(int count)                             async => [];
  Future<int>              readByte()                                  async => -1;
  Future<RandomAccessFile> writeByte(int value)                        async => this;
  Future<RandomAccessFile> writeFrom(List<int> buf,[int s=0,int? e])   async => this;
  Future<RandomAccessFile> writeString(String string)                  async => this;
  Future<RandomAccessFile> lock([FileLock m=FileLock.exclusive,int s=0,int e=-1]) async => this;
  Future<RandomAccessFile> unlock([int start=0,int end=-1])            async => this;
  Future<void>             flush()                                     async {}
  Future<RandomAccessFile> truncate(int length)                        async => this;
}

// ─── FileLock (needed by some code using RandomAccessFile) ───────────────────
enum FileLock { shared, exclusive, blockingShared, blockingExclusive }

// ─── InternetAddressType ──────────────────────────────────────────────────────
class InternetAddressType {
  static const InternetAddressType IPv4 = InternetAddressType._('IPv4');
  static const InternetAddressType IPv6 = InternetAddressType._('IPv6');
  static const InternetAddressType unix = InternetAddressType._('unix');
  static const InternetAddressType any  = InternetAddressType._('any');
  final String name;
  const InternetAddressType._(this.name);
  @override String toString() => name;
}

// ─── InternetAddress ──────────────────────────────────────────────────────────
class InternetAddress {
  final String address;
  final String host;
  final InternetAddressType type;
  final Uint8List rawAddress;
  InternetAddress(this.address, {this.type = InternetAddressType.IPv4})
      : host = address,
        rawAddress = Uint8List(0);
  static final InternetAddress loopbackIPv4 =
      InternetAddress('127.0.0.1', type: InternetAddressType.IPv4);
  static final InternetAddress loopbackIPv6 =
      InternetAddress('::1', type: InternetAddressType.IPv6);
  static final InternetAddress anyIPv4 =
      InternetAddress('0.0.0.0', type: InternetAddressType.IPv4);
  static final InternetAddress anyIPv6 =
      InternetAddress('::', type: InternetAddressType.IPv6);
  bool get isLinkLocal  => false;
  bool get isLoopback   => address == '127.0.0.1' || address == '::1';
  bool get isMulticast  => false;
  static Future<List<InternetAddress>> lookup(String host,
          {InternetAddressType type = InternetAddressType.any}) async => [];
  static Future<InternetAddress> reverseLookup(InternetAddress address) async =>
      address;
  @override String toString() => address;
}

// ─── ProcessSignal (const constructor so it can be used as default param) ─────
class ProcessSignal {
  final String name;
  const ProcessSignal(this.name);
  static const ProcessSignal sighup  = ProcessSignal('SIGHUP');
  static const ProcessSignal sigint  = ProcessSignal('SIGINT');
  static const ProcessSignal sigquit = ProcessSignal('SIGQUIT');
  static const ProcessSignal sigterm = ProcessSignal('SIGTERM');
  static const ProcessSignal sigusr1 = ProcessSignal('SIGUSR1');
  static const ProcessSignal sigusr2 = ProcessSignal('SIGUSR2');
  static const ProcessSignal sigpipe = ProcessSignal('SIGPIPE');
  static const ProcessSignal sigwinch = ProcessSignal('SIGWINCH');
  static const ProcessSignal sigstop = ProcessSignal('SIGSTOP');
  static const ProcessSignal sigcont = ProcessSignal('SIGCONT');
  static const ProcessSignal sigkill = ProcessSignal('SIGKILL');
  Stream<ProcessSignal> watch() => const Stream.empty();
  @override String toString() => name;
}

// ─── ProcessResult / ProcessStartMode ─────────────────────────────────────────
class ProcessResult {
  final int pid;
  final int exitCode;
  final dynamic stdout;
  final dynamic stderr;
  ProcessResult(this.pid, this.exitCode, this.stdout, this.stderr);
}

class ProcessStartMode {
  static const ProcessStartMode normal           = ProcessStartMode._('normal');
  static const ProcessStartMode detached         = ProcessStartMode._('detached');
  static const ProcessStartMode detachedWithStdio= ProcessStartMode._('detachedWithStdio');
  static const ProcessStartMode inheritStdio     = ProcessStartMode._('inheritStdio');
  final String _name;
  const ProcessStartMode._(this._name);
  @override String toString() => _name;
}

// ─── Process ──────────────────────────────────────────────────────────────────
abstract class Process {
  int get pid;
  Future<int> get exitCode;
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]);
  IOSink get stdin;
  Stream<List<int>> get stdout;
  Stream<List<int>> get stderr;

  static Future<ProcessResult> run(
    String executable, List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
    dynamic stdoutEncoding,
    dynamic stderrEncoding,
  }) async => ProcessResult(0, 0, '', '');

  static Future<Process> start(
    String executable, List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
    ProcessStartMode mode = ProcessStartMode.normal,
  }) async => _ProcessStub();
}

class _ProcessStub extends Process {
  @override Future<int> get exitCode async => 0;
  @override bool kill([ProcessSignal signal = ProcessSignal.sigterm]) => true;
  @override int get pid => 0;
  @override IOSink get stdin => IOSink();
  @override Stream<List<int>> get stdout => const Stream.empty();
  @override Stream<List<int>> get stderr => const Stream.empty();
}

// ─── HTTP stubs (not available on Flutter web) ────────────────────────────────
class HttpHeaders {
  static const String acceptHeader           = 'accept';
  static const String acceptCharsetHeader    = 'accept-charset';
  static const String acceptEncodingHeader   = 'accept-encoding';
  static const String acceptLanguageHeader   = 'accept-language';
  static const String acceptRangesHeader     = 'accept-ranges';
  static const String ageHeader              = 'age';
  static const String allowHeader            = 'allow';
  static const String authorizationHeader    = 'authorization';
  static const String cacheControlHeader     = 'cache-control';
  static const String connectionHeader       = 'connection';
  static const String contentEncodingHeader  = 'content-encoding';
  static const String contentLanguageHeader  = 'content-language';
  static const String contentLengthHeader    = 'content-length';
  static const String contentLocationHeader  = 'content-location';
  static const String contentMD5Header       = 'content-md5';
  static const String contentRangeHeader     = 'content-range';
  static const String contentTypeHeader      = 'content-type';
  static const String cookieHeader           = 'cookie';
  static const String dateHeader             = 'date';
  static const String etagHeader             = 'etag';
  static const String expiresHeader          = 'expires';
  static const String fromHeader             = 'from';
  static const String hostHeader             = 'host';
  static const String lastModifiedHeader     = 'last-modified';
  static const String locationHeader         = 'location';
  static const String serverHeader           = 'server';
  static const String setCookieHeader        = 'set-cookie';
  static const String transferEncodingHeader = 'transfer-encoding';
  static const String userAgentHeader        = 'user-agent';
  static const String varyHeader             = 'vary';

  final Map<String, List<String>> _h = {};
  List<String>? operator [](String name) => _h[name.toLowerCase()];
  void operator []=(String name, Object value) =>
      _h[name.toLowerCase()] = [value.toString()];
  void add(String name, Object value, {bool preserveHeaderCase = false}) =>
      _h.putIfAbsent(name.toLowerCase(), () => []).add(value.toString());
  void set(String name, Object value) =>
      _h[name.toLowerCase()] = [value.toString()];
  void remove(String name, Object value) =>
      _h[name.toLowerCase()]?.remove(value.toString());
  void removeAll(String name) => _h.remove(name.toLowerCase());
  void clear() => _h.clear();
  void forEach(void Function(String, List<String>) f) => _h.forEach(f);
  bool get chunkedTransferEncoding => false;
  set chunkedTransferEncoding(bool _) {}
  int get contentLength => -1;
  set contentLength(int _) {}
  ContentType? get contentType => null;
  set contentType(ContentType? _) {}
  bool get persistentConnection => false;
  set persistentConnection(bool _) {}
  String? host;
  int? port;
}

class ContentType {
  final String primaryType;
  final String subType;
  final String? charset;
  const ContentType(this.primaryType, this.subType, {this.charset});
  static const ContentType text   = ContentType('text', 'plain', charset: 'utf-8');
  static const ContentType html   = ContentType('text', 'html',  charset: 'utf-8');
  static const ContentType json   = ContentType('application', 'json', charset: 'utf-8');
  static const ContentType binary = ContentType('application', 'octet-stream');
  String get mimeType => '$primaryType/$subType';
  @override String toString() => charset != null
      ? '$primaryType/$subType; charset=$charset'
      : '$primaryType/$subType';
  static ContentType parse(String value) {
    final parts = value.split(';');
    final mime  = parts[0].trim().split('/');
    final cs    = parts.length > 1
        ? parts[1].trim().replaceFirst('charset=', '').trim() : null;
    return ContentType(mime[0], mime.length > 1 ? mime[1] : '', charset: cs);
  }
}

class HttpStatus {
  static const int ok                  = 200;
  static const int created             = 201;
  static const int accepted            = 202;
  static const int noContent           = 204;
  static const int movedPermanently    = 301;
  static const int found               = 302;
  static const int notModified         = 304;
  static const int badRequest          = 400;
  static const int unauthorized        = 401;
  static const int forbidden           = 403;
  static const int notFound            = 404;
  static const int methodNotAllowed    = 405;
  static const int conflict            = 409;
  static const int internalServerError = 500;
  static const int notImplemented      = 501;
  static const int badGateway          = 502;
  static const int serviceUnavailable  = 503;
}

class HttpResponse {
  int statusCode = 200;
  String? reasonPhrase;
  final HttpHeaders headers = HttpHeaders();
  ContentType? contentType;
  void write(Object? obj) {}
  void writeln([Object? obj = '']) {}
  void add(List<int> data) {}
  Future<void> close() async {}
  Future<void> get done async {}
}

class HttpRequest extends Stream<List<int>> {
  final String method;
  final Uri uri;
  final HttpHeaders headers = HttpHeaders();
  final HttpResponse response = HttpResponse();
  HttpRequest({this.method = 'GET', Uri? uri})
      : uri = uri ?? Uri.parse('http://localhost/');
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => const Stream<List<int>>.empty().listen(
        onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);
}

class HttpClientRequest {
  final HttpHeaders headers = HttpHeaders();
  Future<HttpClientResponse> close() async => HttpClientResponse();
  void add(List<int> data) {}
  void write(Object? obj) {}
  Future<void> get done async {}
  Future<HttpClientResponse> addStream(Stream<List<int>> s) async =>
      HttpClientResponse();
}

// HttpClientResponse extends Stream<List<int>> — only listen() is required.
// The abstract Stream class provides all other method implementations.
class HttpClientResponse extends Stream<List<int>> {
  int get statusCode       => 200;
  String? get reasonPhrase => 'OK';
  int get contentLength    => 0;
  final HttpHeaders headers = HttpHeaders();

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => const Stream<List<int>>.empty().listen(
        onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);
}

class HttpClient {
  Duration connectionTimeout = const Duration(seconds: 30);
  Duration idleTimeout       = const Duration(seconds: 15);
  int? maxConnectionsPerHost;
  bool autoUncompress = true;
  String? userAgent;
  Future<HttpClientRequest> getUrl(Uri url)    async => HttpClientRequest();
  Future<HttpClientRequest> postUrl(Uri url)   async => HttpClientRequest();
  Future<HttpClientRequest> putUrl(Uri url)    async => HttpClientRequest();
  Future<HttpClientRequest> deleteUrl(Uri url) async => HttpClientRequest();
  Future<HttpClientRequest> patchUrl(Uri url)  async => HttpClientRequest();
  Future<HttpClientRequest> headUrl(Uri url)   async => HttpClientRequest();
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      HttpClientRequest();
  Future<HttpClientRequest> open(String method, String host, int port,
      String path) async => HttpClientRequest();
  void addCredentials(Uri url, String realm, dynamic credentials) {}
  void addProxyCredentials(
      String host, int port, String realm, dynamic credentials) {}
  set authenticate(Future<bool> Function(Uri, String, String?)? f) {}
  set findProxy(String Function(Uri)? f) {}
  set authenticateProxy(
      Future<bool> Function(String, int, String, String?)? f) {}
  set badCertificateCallback(bool Function(dynamic, String, int)? f) {}
  void close({bool force = false}) {}
}

class HttpServer extends Stream<HttpRequest> {
  final InternetAddress address;
  final int port;
  HttpServer._(this.address, this.port);
  static Future<HttpServer> bind(dynamic address, int port,
      {int backlog = 0, bool v6Only = false, bool shared = false}) async =>
      HttpServer._(
          address is InternetAddress
              ? address
              : InternetAddress(address.toString()),
          port);
  Future<void> close({bool force = false}) async {}
  @override
  StreamSubscription<HttpRequest> listen(
    void Function(HttpRequest)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => const Stream<HttpRequest>.empty().listen(
        onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);
}

class ServerSocket {
  final InternetAddress address;
  final int port;
  ServerSocket._(this.address, this.port);
  static Future<ServerSocket> bind(dynamic address, int port,
      {bool v6Only = false, bool shared = false}) async =>
      ServerSocket._(
          address is InternetAddress
              ? address
              : InternetAddress(address.toString()),
          port);
  Future<void> close() async {}
}

class Socket {
  InternetAddress get remoteAddress => InternetAddress.loopbackIPv4;
  int get remotePort => 0;
  InternetAddress get address => InternetAddress.loopbackIPv4;
  int get port => 0;
  void write(Object? obj) {}
  void add(List<int> data) {}
  void destroy() {}
  Future<void> close() async {}
  Future<void> get done async {}
}

class RawSocketEvent {
  static const RawSocketEvent read       = RawSocketEvent._('read');
  static const RawSocketEvent write      = RawSocketEvent._('write');
  static const RawSocketEvent readClosed = RawSocketEvent._('readClosed');
  static const RawSocketEvent closed     = RawSocketEvent._('closed');
  final String _n;
  const RawSocketEvent._(this._n);
  @override String toString() => _n;
}

class Datagram {
  final Uint8List data;
  final InternetAddress address;
  final int port;
  Datagram(this.data, this.address, this.port);
}

class NetworkInterface {
  final String name;
  final int index;
  final List<InternetAddress> addresses;
  NetworkInterface._(this.name, this.index, this.addresses);
  static Future<List<NetworkInterface>> list({
    bool includeLoopback = false,
    bool includeLinkLocal = false,
    InternetAddressType type = InternetAddressType.any,
  }) async => [];
}

class RawDatagramSocket extends Stream<RawSocketEvent> {
  RawDatagramSocket._();
  static Future<RawDatagramSocket> bind(dynamic host, int port,
      {bool reuseAddress = true, bool reusePort = false, int ttl = 1}) async =>
      RawDatagramSocket._();
  InternetAddress get address => InternetAddress.loopbackIPv4;
  int get port => 0;
  void close() {}
  bool send(List<int> buffer, InternetAddress address, int port) => false;
  Datagram? receive() => null;
  bool get multicastLoopback => false;
  set multicastLoopback(bool v) {}
  int get multicastHops => 1;
  set multicastHops(int v) {}
  void joinMulticast(InternetAddress group, [NetworkInterface? interface]) {}
  void leaveMulticast(InternetAddress group, [NetworkInterface? interface]) {}
  @override
  StreamSubscription<RawSocketEvent> listen(
    void Function(RawSocketEvent)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => const Stream<RawSocketEvent>.empty().listen(
        onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);
}

class HttpOverrides {
  static HttpOverrides? global;
  static void runWithHttpOverrides<R>(
      R Function() body, HttpOverrides overrides) => body();
}

// ─── Exception stubs ──────────────────────────────────────────────────────────
class SocketException implements Exception {
  final String message;
  final dynamic osError;
  final InternetAddress? address;
  final int? port;
  const SocketException(this.message,
      {this.osError, this.address, this.port});
  @override String toString() => 'SocketException: $message';
}

class FileSystemException implements Exception {
  final String message;
  final String? path;
  final dynamic osError;
  const FileSystemException([this.message = '', this.path, this.osError]);
  @override String toString() =>
      'FileSystemException: $message${path != null ? ", path=$path" : ""}';
}

class HttpException implements Exception {
  final String message;
  final Uri? uri;
  const HttpException(this.message, {this.uri});
  @override String toString() => 'HttpException: $message';
}

class TlsException implements Exception {
  final String message;
  const TlsException([this.message = '']);
  @override String toString() => 'TlsException: $message';
}
