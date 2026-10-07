import 'dart:io';

import 'package:isar_community/isar.dart';
import 'package:watchtower/cli/commands/cli_command.dart';
import 'package:watchtower/cli/output/cli_serialize.dart';
import 'package:watchtower/models/download.dart';
import 'package:watchtower/models/history.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/services/isolate_service.dart';

const cliVersion = '8.1.160';

class VersionCommand extends CliCommand {
  @override
  String get name => 'version';

  @override
  String get summary => 'Print the Watchtower version';

  @override
  Future<CliResult> run(CliContext context) async {
    context.output.result({'version': cliVersion});
    return const CliResult.ok();
  }
}

class HelpCommand extends CliCommand {
  /// Set by the dispatcher after the registry is constructed (the registry
  /// contains this command, so it cannot be passed to the constructor).
  CliCommandRegistry? registry;

  @override
  String get name => 'help';

  @override
  String get summary => 'Show usage for a command';

  @override
  Future<CliResult> run(CliContext context) async {
    final topic = context.invocation.arguments.isNotEmpty
        ? context.invocation.arguments.first
        : context.invocation.subcommand;
    final registry = this.registry;
    context.output.info(
      registry == null
          ? 'Watchtower CLI $cliVersion'
          : buildCliHelp(registry, commandName: topic),
    );
    return const CliResult.ok();
  }
}

/// Environment self-check: verifies the CLI can actually do work (database
/// writable, extension workers running) before an operator trusts it.
class DoctorCommand extends CliCommand {
  @override
  String get name => 'doctor';

  @override
  String get summary => 'Check platform, database and extension workers';

  @override
  Future<CliResult> run(CliContext context) async {
    final runtime = context.runtime;
    final checks = <String, Object?>{
      'version': cliVersion,
      'platform': Platform.operatingSystem,
      'dartVersion': Platform.version,
      'dataDirectory': runtime.dataDirectory.path,
      'dataDirectoryWritable': _isWritable(runtime.dataDirectory),
      'sources': runtime.isar.sources.where().countSync(),
      'installedSources': runtime.installedSources().length,
      'libraryItems': runtime.isar.mangas.where().countSync(),
      'downloads': runtime.isar.downloads.where().countSync(),
      'history': runtime.isar.historys.where().countSync(),
      'settingsId': runtime.readSettings().id,
      'isolateServiceRunning': getIsolateService.isRunning,
      'distinctRepos': runtime
          .installedSources()
          .map((s) => s.repo?.jsonUrl)
          .whereType<String>()
          .toSet()
          .length,
    };
    final ok =
        checks['dataDirectoryWritable'] == true &&
        checks['isolateServiceRunning'] == true;
    context.output.result({'ok': ok, 'checks': checks});
    return CliResult(ok ? 0 : 1);
  }

  static bool _isWritable(Directory directory) {
    try {
      if (!directory.existsSync()) directory.createSync(recursive: true);
      final probe = File('${directory.path}/.watchtower_write_probe');
      probe.writeAsStringSync('ok');
      probe.deleteSync();
      return true;
    } catch (_) {
      return false;
    }
  }
}

class SettingsCommand extends CliCommand {
  @override
  String get name => 'settings';

  @override
  String get summary => 'Dump the app settings record';

  @override
  Future<CliResult> run(CliContext context) async {
    final settings = context.runtime.readSettings();
    context.output.result({'settings': cliSerialize(settings.toJson())});
    return const CliResult.ok();
  }
}

/// Builds the top-level help text from the registry.
String buildCliHelp(CliCommandRegistry registry, {String? commandName}) {
  if (commandName != null) {
    final command = registry.find(commandName);
    if (command == null) {
      return 'Unknown command: $commandName\n\n${buildCliHelp(registry)}';
    }
    final buffer = StringBuffer()
      ..writeln(command.name)
      ..writeln('  ${command.summary}');
    if (command.usage.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Usage:');
      for (final line in command.usage) {
        buffer.writeln('  $line');
      }
    }
    return buffer.toString().trimRight();
  }

  final buffer = StringBuffer()
    ..writeln('Watchtower CLI $cliVersion')
    ..writeln()
    ..writeln('Usage: watchtower --cli <command> [options]')
    ..writeln()
    ..writeln('Commands:');
  for (final command in registry.commands) {
    buffer.writeln('  ${command.name.padRight(12)} ${command.summary}');
  }
  buffer
    ..writeln()
    ..writeln('Global options:')
    ..writeln('  --json           Machine-readable JSON output')
    ..writeln('  --ndjson         Newline-delimited JSON output')
    ..writeln('  --quiet          Suppress human-readable output')
    ..writeln('  --data-dir DIR   Override the Watchtower data directory')
    ..writeln('  --help           Show this help');
  return buffer.toString().trimRight();
}
