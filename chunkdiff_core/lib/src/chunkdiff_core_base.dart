import 'dart:io';

enum SymbolKind { function, method, classType, enumType, other }

class SymbolChange {
  final String name;
  final SymbolKind kind;
  final String? beforePath;
  final String? afterPath;

  const SymbolChange({
    required this.name,
    required this.kind,
    this.beforePath,
    this.afterPath,
  });
}

class SymbolDiff {
  final SymbolChange change;
  final String leftSnippet;
  final String rightSnippet;

  const SymbolDiff({
    required this.change,
    required this.leftSnippet,
    required this.rightSnippet,
  });
}

List<SymbolChange> dummySymbolChanges() {
  return const <SymbolChange>[
    SymbolChange(
      name: 'ChunkDiffExample.greet',
      kind: SymbolKind.method,
      beforePath: 'lib/src/example.dart',
      afterPath: 'lib/src/example.dart',
    ),
    SymbolChange(
      name: 'ChunkDiffExample',
      kind: SymbolKind.classType,
      beforePath: 'lib/src/example.dart',
      afterPath: 'lib/src/example.dart',
    ),
    SymbolChange(
      name: 'main',
      kind: SymbolKind.function,
      beforePath: 'lib/main.dart',
      afterPath: 'lib/main.dart',
    ),
  ];
}

List<SymbolDiff> dummySymbolDiffs() {
  final List<SymbolChange> changes = dummySymbolChanges();
  return <SymbolDiff>[
    SymbolDiff(
      change: changes[0],
      leftSnippet: '''
class ChunkDiffExample {
  String greet(String name) {
    return 'Hello, \$name from v1';
  }
}

void main() {
  final ChunkDiffExample example = ChunkDiffExample();
  print(example.greet('Developer'));
}
''',
      rightSnippet: '''
class ChunkDiffExample {
  String greet(String name, {bool excited = false}) {
    final String base = 'Hello, \$name from v2';
    return excited ? '\$base!' : base;
  }
}

void main() {
  final ChunkDiffExample example = ChunkDiffExample();
  print(example.greet('Developer', excited: true));
}
''',
    ),
    SymbolDiff(
      change: changes[1],
      leftSnippet: '''
class ChunkDiffExample {
  final String name;

  const ChunkDiffExample(this.name);
}
''',
      rightSnippet: '''
class ChunkDiffExample {
  final String name;
  final int version;

  const ChunkDiffExample(this.name, {this.version = 2});
}
''',
    ),
    SymbolDiff(
      change: changes[2],
      leftSnippet: '''
void main() {
  final ChunkDiffExample example = ChunkDiffExample('Developer');
  print(example.name);
}
''',
      rightSnippet: '''
void main() {
  final ChunkDiffExample example = ChunkDiffExample('Developer', version: 2);
  print('\${example.name} v\${example.version}');
}
''',
    ),
  ];
}

Future<bool> isGitRepo(String path) async {
  try {
    final ProcessResult result = await Process.run(
      'git',
      <String>['rev-parse', '--is-inside-work-tree'],
      workingDirectory: path,
    );
    return result.exitCode == 0 &&
        (result.stdout as String?)?.trim().toLowerCase() == 'true';
  } catch (_) {
    // In sandboxed environments, process execution may be blocked.
    return false;
  }
}

Future<List<String>> listGitRefs(
  String path, {
  int limit = 20,
  bool strict = false,
}) async {
  try {
    final ProcessResult result = await Process.run(
      'git',
      <String>[
        'for-each-ref',
        '--format=%(refname:short)',
        '--count=$limit',
        'refs/heads',
        'refs/remotes',
      ],
      workingDirectory: path,
    );
    if (result.exitCode != 0) {
      if (strict) {
        throw ProcessException(
          'git',
          <String>['for-each-ref'],
          result.stderr,
          result.exitCode,
        );
      }
      return <String>[];
    }
    final String stdout = (result.stdout as String?) ?? '';
    return stdout
        .split('\n')
        .map((String line) => line.trim())
        .where((String line) => line.isNotEmpty)
        .toList();
  } catch (e) {
    if (strict) {
      rethrow;
    }
    // In sandboxed environments, process execution may be blocked.
    return <String>[];
  }
}

Future<List<String>> listChangedFiles(
  String path,
  String leftRef,
  String rightRef,
) async {
  try {
    final ProcessResult result = await Process.run(
      'git',
      <String>['diff', '--name-only', leftRef, rightRef],
      workingDirectory: path,
    );
    if (result.exitCode != 0) {
      return <String>[];
    }
    final String stdout = (result.stdout as String?) ?? '';
    return stdout
        .split('\n')
        .map((String line) => line.trim())
        .where((String line) => line.isNotEmpty)
        .toList();
  } catch (_) {
    return <String>[];
  }
}

Future<String?> fileContentAtRef(
  String path,
  String ref,
  String filePath,
) async {
  try {
    final ProcessResult result = await Process.run(
      'git',
      <String>['show', '$ref:$filePath'],
      workingDirectory: path,
    );
    if (result.exitCode != 0) {
      return null;
    }
    return (result.stdout as String?) ?? '';
  } catch (_) {
    return null;
  }
}

Future<List<SymbolDiff>> loadSymbolDiffs(
  String repoPath,
  String leftRef,
  String rightRef, {
  bool dartOnly = true,
}) async {
  final bool repoOk = await isGitRepo(repoPath);
  if (!repoOk) {
    return <SymbolDiff>[];
  }

  final List<String> files =
      await listChangedFiles(repoPath, leftRef, rightRef);
  final Iterable<String> filtered = dartOnly
      ? files.where((String f) => f.endsWith('.dart'))
      : files;

  final List<SymbolDiff> diffs = <SymbolDiff>[];
  for (final String file in filtered) {
    final String? left = await fileContentAtRef(repoPath, leftRef, file);
    final String? right = await fileContentAtRef(repoPath, rightRef, file);
    diffs.add(
      SymbolDiff(
        change: SymbolChange(
          name: file,
          kind: SymbolKind.other,
          beforePath: file,
          afterPath: file,
        ),
        leftSnippet: left ?? '',
        rightSnippet: right ?? '',
      ),
    );
  }

  return diffs;
}
