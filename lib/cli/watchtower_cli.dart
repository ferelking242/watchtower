import 'dart:async';

import 'package:watchtower/cli/commands/cli_command.dart';
import 'package:watchtower/cli/commands/downloads_command.dart';
import 'package:watchtower/cli/commands/extensions_command.dart';
import 'package:watchtower/cli/commands/library_command.dart';
import 'package:watchtower/cli/commands/meta_commands.dart';
import 'package:watchtower/cli/commands/plugins_command.dart';
import 'package:watchtower/cli/commands/sources_command.dart';
import 'package:watchtower/cli/commands/trackers_command.dart';
import 'package:watchtower/cli/output/cli_output.dart';
import 'package:watchtower/cli/runtime/cli_arguments.dart';
import 'package:watchtower/cli/runtime/cli_runtime.dart';

/// Entry point for `watchtower --cli …`.
///
/// Boots the real application runtime (database, settings, extension workers,
/// download pool) and dispatches to a command. Because every command reuses
/// the app's own providers and services, the CLI is a faithful headless client
/// — and a faithful bug reproducer.
Future<int> runWatchtowerCli(List<String> args) async {
  final invocation = parseCliInvocation(args);
  final output = CliOutput(format: invocation.format, quiet: invocation.quiet);
  final registry = CliCommandRegistry([
    ExtensionsCommand(),
    SourcesCommand(),
    LibraryCommand(),
    DownloadsCommand(),
    TrackersCommand(),
    PluginsCommand(),
    DoctorCommand(),
    SettingsCommand(),
    VersionCommand(),
    HelpCommand(),
  ]);
  for (final command in registry.commands) {
    if (command is HelpCommand) command.registry = registry;
  }

  final commandName = invocation.command;

  // Help and version are answered without touching the database so they work
  // even when the data directory is unavailable.
  if (commandName == null || invocation.help || commandName == 'help') {
    final topic = commandName == 'help'
        ? (invocation.subcommand ?? invocation.arguments.firstOrNull)
        : commandName;
    output.info(buildCliHelp(registry, commandName: topic));
    return 0;
  }
  if (commandName == 'version') {
    output.result({'version': cliVersion});
    return 0;
  }

  final command = registry.find(commandName);
  if (command == null) {
    output.error('Unknown command: $commandName');
    output.info(buildCliHelp(registry));
    return 64;
  }

  CliRuntime runtime;
  try {
    runtime = await CliRuntime.boot(
      dataDirectory: invocation.option('data-dir'),
      mock: invocation.hasFlag('mock'),
      verbose: invocation.hasFlag('verbose'),
    );
  } catch (error, stackTrace) {
    output.error('Failed to initialise Watchtower runtime: $error');
    if (invocation.hasFlag('verbose')) output.warn('$stackTrace');
    return 2;
  }

  final context = CliContext(
    runtime: runtime,
    invocation: invocation,
    output: output,
  );

  try {
    final result = await command.run(context);
    return result.exitCode;
  } on CliUsageException catch (error) {
    output.error(error.message);
    return 64;
  } catch (error, stackTrace) {
    output.error('$error');
    if (invocation.hasFlag('verbose')) output.warn('$stackTrace');
    return 1;
  } finally {
    await output.flush();
    await runtime.dispose();
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
