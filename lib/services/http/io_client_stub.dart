// Web stub for package:http/io_client.dart
// On web we just use a standard BaseClient that delegates to http.Client().
import 'package:http/http.dart';

class IOClient extends BaseClient {
  final Client _inner;
  IOClient([dynamic httpClient]) : _inner = Client();

  @override
  Future<StreamedResponse> send(BaseRequest request) => _inner.send(request);

  @override
  void close() => _inner.close();
}
