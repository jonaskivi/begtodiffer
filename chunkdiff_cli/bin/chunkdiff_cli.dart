import 'dart:io';

import 'package:chunkdiff_core/chunkdiff_core.dart';

Future<void> main(List<String> arguments) async {
  final Map<String, String> args = _parseArgs(arguments);
  final String gitFolder = args['git-folder'] ?? '(not provided)';
  final String leftRef = args['left'] ?? 'HEAD';
  final String rightRef = args['right'] ?? kWorktreeRef;

  stdout.writeln('ChunkDiff CLI');
  stdout.writeln('  Git folder: $gitFolder');
  stdout.writeln('  Left ref:   $leftRef');
  stdout.writeln('  Right ref:  $rightRef');
  stdout.writeln('');
  stdout.writeln('Hello from core: ${helloFromCore()}');
  stdout.writeln('');
  stdout.writeln('Symbol changes:');
  final bool hasRepo = gitFolder != '(not provided)';
  final List<SymbolDiff> diffs = <SymbolDiff>[];
  if (hasRepo) {
    try {
      diffs.addAll(await loadSymbolDiffs(gitFolder, leftRef, rightRef));
    } catch (e) {
      stdout.writeln('  (failed to load git diffs: $e)');
    }
  }
  if (diffs.isEmpty) {
    diffs.addAll(dummySymbolDiffs());
    stdout.writeln('  (using dummy data)');
  }

  for (final SymbolDiff diff in diffs) {
    final SymbolChange change = diff.change;
    stdout.writeln(
      '- ${change.name} (${change.kind.name}) '
      '[${change.beforePath ?? '-'} -> ${change.afterPath ?? '-'}]',
    );
    stdout.writeln('    left:  ${_firstLine(diff.leftSnippet)}');
    stdout.writeln('    right: ${_firstLine(diff.rightSnippet)}');
  }

  if (args.containsKey('help')) {
    stdout.writeln('');
    stdout.writeln(_usage);
  }
}

Map<String, String> _parseArgs(List<String> args) {
  final Map<String, String> result = <String, String>{};
  for (int i = 0; i < args.length; i++) {
    final String arg = args[i];
    if (arg == '--help' || arg == '-h') {
      result['help'] = 'true';
      continue;
    }
    if (arg.startsWith('--') && arg.contains('=')) {
      final int idx = arg.indexOf('=');
      final String key = arg.substring(2, idx);
      final String value = arg.substring(idx + 1);
      if (value.isNotEmpty) {
        result[key] = value;
      }
      continue;
    }
    if (arg.startsWith('--') && i + 1 < args.length) {
      final String key = arg.substring(2);
      final String value = args[i + 1];
      result[key] = value;
      i++;
      continue;
    }
  }
  return result;
}

String _firstLine(String text) {
  final List<String> lines = text.split('\n');
  return lines.isNotEmpty ? lines.first.trim() : '';
}

const String _usage = '''
Usage: dart run bin/chunkdiff_cli.dart [options]

Options:
  --git-folder <path>   Path to the Git repository root
  --left <ref>          Left Git ref (default: HEAD~1)
  --right <ref>         Right Git ref (default: HEAD)
  -h, --help            Show this help text
''';
