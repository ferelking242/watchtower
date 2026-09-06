// Web stub for dartssh2 — SSH/SFTP client never used on Flutter Web.
import 'dart:async';
import 'dart:typed_data';

class SSHSocket {
  static Future<SSHSocket> connect(String host, int port,
          {Duration? timeout}) async =>
      throw UnsupportedError('dartssh2 not available on Flutter Web');
}

class SSHClient {
  SSHClient(SSHSocket socket,
      {String? username, String? Function()? onPasswordRequest});

  Future<SftpClient> sftp() async =>
      throw UnsupportedError('dartssh2 not available on Flutter Web');
  void close() {}
  Future<void> get done async {}
  Future<SSHSession> execute(String command) async =>
      throw UnsupportedError('dartssh2 not available on Flutter Web');
}

class SSHSession {
  Stream<Uint8List> get stdout => const Stream.empty();
  Stream<Uint8List> get stderr => const Stream.empty();
  Future<int?> get exitCode async => null;
  void close() {}
}

class SftpClient {
  Future<List<SftpName>> listdir(String path) async =>
      throw UnsupportedError('dartssh2 not available on Flutter Web');
  Future<SftpFile> open(String path, {SftpFileOpenMode? mode}) async =>
      throw UnsupportedError('dartssh2 not available on Flutter Web');
  Future<void> remove(String path) async =>
      throw UnsupportedError('dartssh2 not available on Flutter Web');
  Future<void> rmdir(String path) async =>
      throw UnsupportedError('dartssh2 not available on Flutter Web');
  Future<void> mkdir(String path) async =>
      throw UnsupportedError('dartssh2 not available on Flutter Web');
  Future<void> rename(String oldPath, String newPath) async =>
      throw UnsupportedError('dartssh2 not available on Flutter Web');
  Future<SftpFileAttr> stat(String path) async =>
      throw UnsupportedError('dartssh2 not available on Flutter Web');
  Future<void> setStat(String path, SftpFileAttr attr) async =>
      throw UnsupportedError('dartssh2 not available on Flutter Web');
  void close() {}
}

class SftpName {
  final String filename;
  final String longname;
  final SftpFileAttr attr;
  SftpName({required this.filename, required this.longname, required this.attr});
}

class SftpFileAttr {
  final bool isDirectory;
  final bool isFile;
  final int? size;
  final int? modifyTime;
  final int? permissions;
  SftpFileAttr({
    this.isDirectory = false,
    this.isFile = false,
    this.size,
    this.modifyTime,
    this.permissions,
  });
}

class SftpFile {
  Future<Uint8List> readBytes({int? length, int? offset}) async =>
      throw UnsupportedError('dartssh2 not available on Flutter Web');
  Future<void> writeBytes(Uint8List data, {int? offset}) async =>
      throw UnsupportedError('dartssh2 not available on Flutter Web');
  Future<SftpFileAttr> stat() async =>
      throw UnsupportedError('dartssh2 not available on Flutter Web');
  Future<void> close() async {}
}

class SftpFileOpenMode {
  final int value;
  const SftpFileOpenMode._(this.value);
  static const SftpFileOpenMode read = SftpFileOpenMode._(1);
  static const SftpFileOpenMode write = SftpFileOpenMode._(2);
  static const SftpFileOpenMode append = SftpFileOpenMode._(4);
  static const SftpFileOpenMode create = SftpFileOpenMode._(8);
  static const SftpFileOpenMode truncate = SftpFileOpenMode._(16);
  static const SftpFileOpenMode exclusive = SftpFileOpenMode._(32);

  SftpFileOpenMode operator |(SftpFileOpenMode other) =>
      SftpFileOpenMode._(value | other.value);
  SftpFileOpenMode operator &(SftpFileOpenMode other) =>
      SftpFileOpenMode._(value & other.value);
}
