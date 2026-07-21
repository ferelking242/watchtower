// Web stub for ftpconnect — NFile FTP client never used on Flutter Web.

enum FTPEntryType { dir, file, link, unknown }

class FTPEntry {
  final String name;
  final FTPEntryType type;
  final int? size;
  final DateTime? modifyTime;
  FTPEntry({required this.name, required this.type, this.size, this.modifyTime});
}

class FTPConnect {
  final String host;
  final int port;
  final String user;
  final String pass;
  final int timeout;

  FTPConnect(
    this.host, {
    this.port = 21,
    this.user = 'anonymous',
    this.pass = 'anonymous@',
    this.timeout = 30,
  });

  Future<bool> connect() async =>
      throw UnsupportedError('FTP not available on Flutter Web');
  Future<bool> disconnect() async => true;
  Future<bool> changeDirectory(String path) async =>
      throw UnsupportedError('FTP not available on Flutter Web');
  Future<List<FTPEntry>> listDirectoryContent() async =>
      throw UnsupportedError('FTP not available on Flutter Web');
  Future<bool> downloadFile(String remoteFile, dynamic localFile) async =>
      throw UnsupportedError('FTP not available on Flutter Web');
  Future<bool> uploadFile(dynamic localFile, {String? remoteFileName}) async =>
      throw UnsupportedError('FTP not available on Flutter Web');
  Future<bool> deleteFile(String fileName) async =>
      throw UnsupportedError('FTP not available on Flutter Web');
  Future<bool> makeDirectory(String dir) async =>
      throw UnsupportedError('FTP not available on Flutter Web');
  Future<bool> deleteDirectory(String dir) async =>
      throw UnsupportedError('FTP not available on Flutter Web');
  Future<bool> rename(String oldName, String newName) async =>
      throw UnsupportedError('FTP not available on Flutter Web');
  Future<int> sizeFile(String fileName) async =>
      throw UnsupportedError('FTP not available on Flutter Web');
}
