const extensionServerFallbackVersion = '1.0.0';
const extensionServerJarPrefix = 'MExtensionServer-';
const extensionServerReleaseApiUrl =
    'https://api.github.com/repos/kodjodevf/M-Extension-Server/releases?page=1&per_page=10';
const apkBridgeReleaseUrl =
    'https://github.com/Schnitzel5/ApkBridge/releases/latest';

String? extensionServerDirectoryFromPaths({
  required String jrePath,
  required String extensionServerPath,
}) => null;

Future<String?> findExtensionServerJavaExecutable(dynamic root) async => null;

Future<String?> findExtensionServerJar(dynamic root) async => null;

String? extensionServerAssetNameForCurrentPlatform() => null;

String resolveInstalledExtensionServerVersion(String extensionServerPath) => '';

String resolveExtensionServerReleaseVersion(Map<String, dynamic> release) =>
    extensionServerFallbackVersion;

String? extractExtensionServerVersion(String value) {
  final match = RegExp(r'v?(\d+(?:\.\d+)+)').firstMatch(value);
  return match?.group(1);
}
