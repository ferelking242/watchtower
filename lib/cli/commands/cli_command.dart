import 'package:watchtower/cli/output/cli_output.dart';
import 'package:watchtower/cli/runtime/cli_arguments.dart';
import 'package:watchtower/cli/runtime/cli_runtime.dart';

/// Thrown by a command when the caller passed invalid input. Produces a clean
/// `error:` message and a non-zero exit code instead of a stack trace.
class CliUsageException implements Exception {
  CliUsageException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Result of running a command.
class CliResult {
  const CliResult(this.exitCode);

  const CliResult.ok() : exitCode = 0;
  const CliResult.failure([this.exitCode = 1]);

  final int exitCode;
}

/// Everything a command needs to run.
class CliContext {
  CliContext({
    required this.runtime,
    required this.invocation,
    required this.output,
  });

  final CliRuntime runtime;
  final CliInvocation invocation;
  final CliOutput output;

  String requireOption(String name) {
    final value = invocation.option(name);
    if (value == null || value.isEmpty) {
      throw CliUsageException('Missing required option --$name');
    }
    return value;
  }

  String requireArgument(int index, String description) {
    final args = invocation.arguments;
    if (index >= args.length || args[index].isEmpty) {
      throw CliUsageException('Missing required argument: $description');
    }
    return args[index];
  }
}

/// A single CLI command (verb) with its sub-operations.
abstract class CliCommand {
  /// Primary token, e.g. `sources`.
  String get name;

  /// One-line description used by `help`.
  String get summary;

  /// Usage lines shown by `help <command>`.
  List<String> get usage => const [];

  /// Executes the command. Implementations may dispatch on `subcommand`.
  Future<CliResult> run(CliContext context);
}

/// Registry of all top-level commands, preserving insertion order for help.
class CliCommandRegistry {
  CliCommandRegistry(this._commands);

  final List<CliCommand> _commands;

  List<CliCommand> get commands => List.unmodifiable(_commands);

  CliCommand? find(String name) {
    for (final command in _commands) {
      if (command.name == name) return command;
    }
    return null;
  }
}
