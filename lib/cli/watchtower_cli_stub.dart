/// Web stub for the Watchtower CLI.
///
/// The CLI relies on `dart:io`, isolates and a native extension runtime, none
/// of which exist on Flutter web. When the app is compiled for web the CLI is
/// never a valid invocation, so this entry point simply reports that.
Future<int> runWatchtowerCli(List<String> args) async {
  throw UnsupportedError('The Watchtower CLI is not available on the web.');
}
