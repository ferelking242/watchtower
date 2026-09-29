import 'remote_client.dart';

/// SFTP remote client — stub.
/// The dartssh2 dependency was removed because it caused CI build failures
/// (pointycastle ^4.0.0 vs encrypt ^3.6.2) and the remote SFTP feature
/// was non-functional. This stub preserves the class interface so callers
/// compile, but every method throws at runtime.
class SftpRemoteClient implements RemoteClient {
  final String host;
  final int port;
  final String username;
  final String password;

  SftpRemoteClient({
    required this.host,
    required this.port,
    required this.username,
    required this.password,
  });

  Never _unsupported() => throw UnsupportedError(
        'SFTP remote access is not available — dartssh2 was removed.',
      );

  @override
  Future<void> connect() async => _unsupported();

  @override
  Future<void> disconnect() async => _unsupported();

  @override
  Future<List<RemoteFileItem>> listDirectory(String path) async =>
      _unsupported();

  @override
  Future<void> createDirectory(String path) async => _unsupported();

  @override
  Future<void> delete(String path, bool isDir) async => _unsupported();

  @override
  Future<void> downloadFile(
    String remotePath,
    String localPath,
    Function(double progress) onProgress,
  ) async =>
      _unsupported();

  @override
  Future<void> uploadFile(
    String localPath,
    String remotePath,
    Function(double progress) onProgress,
  ) async =>
      _unsupported();
}
