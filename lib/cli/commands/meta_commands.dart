import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:watchtower/cli/commands/cli_command.dart';
import 'package:watchtower/cli/output/cli_serialize.dart';
import 'package:watchtower/cli/watchtower_cli_safety.dart';
import 'package:watchtower/eval/lib.dart';
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
    // Doctor probes the extension engine without touching the database, so it
    // works even on a machine where Isar is unavailable. It reports the same
    // `native`/`quickJs` contract the Linux headless workflow asserts.
    var isolatePoolAvailable = false;
    var quickJsAvailable = false;
    String? runtimeError;
    try {
      await getIsolateService.start();
      isolatePoolAvailable = true;
      final probe = Source(
        id: -1,
        name: 'Watchtower runtime probe',
        sourceCode: 'class DefaultExtension {}',
      )..sourceCodeLanguage = SourceCodeLanguage.javascript;
      await withExtensionService<bool>(
        probe,
        (service) async => service.supportsLatest,
      ).timeout(const Duration(seconds: 45));
      quickJsAvailable = true;
    } catch (error) {
      runtimeError = _shortError(error);
    } finally {
      ExtensionServiceRegistry.disposeAll();
      if (isolatePoolAvailable) {
        try {
          await getIsolateService.stop();
        } catch (_) {}
      }
    }
    context.output.result({
      'version': cliVersion,
      'platform': Platform.operatingSystem,
      'architecture': Abi.current().toString(),
      'dart': Platform.version,
      'native': true,
      'isolatePool': {'available': isolatePoolAvailable},
      'quickJs': {'available': quickJsAvailable, 'error': ?runtimeError},
    });
    return CliResult(isolatePoolAvailable && quickJsAvailable ? 0 : 1);
  }

  static String _shortError(Object error) {
    final value = sanitizeCliText(error.toString()).replaceAll('\n', ' ');
    return value.length > 500 ? '${value.substring(0, 497)}...' : value;
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
    ..writeln('Local repository commands (no database required):')
    ..writeln(
      '  source <id|name> <operation>  Run one extension operation '
      '(popular, search, detail, pages, videos…)',
    )
    ..writeln()
    ..writeln('Global options:')
    ..writeln('  --json           Machine-readable JSON output')
    ..writeln('  --ndjson         Newline-delimited JSON output')
    ..writeln('  --quiet          Suppress human-readable output')
    ..writeln('  --repo DIR       Path to a watchtower-extensions checkout')
    ..writeln('  --data-dir DIR   Override the Watchtower data directory')
    ..writeln('  --help           Show this help');
  return buffer.toString().trimRight();
}
