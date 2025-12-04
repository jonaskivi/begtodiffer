import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

enum SymbolKind { function, method, classType, enumType, other }

/// Special ref string to indicate the working tree instead of a named ref.
const String kWorktreeRef = 'WORKTREE';

class CodeChunk {
  final String filePath;
  final String rightFilePath;
  final int oldStart;
  final int oldEnd;
  final int newStart;
  final int newEnd;
  final String leftText;
  final String rightText;
  final String name;
  final SymbolKind kind;
  final bool ignored;
  final List<DiffLine> lines;

  const CodeChunk({
    required this.filePath,
    required this.rightFilePath,
    required this.oldStart,
    required this.oldEnd,
    required this.newStart,
    required this.newEnd,
    required this.leftText,
    required this.rightText,
    required this.name,
    required this.kind,
    required this.lines,
    this.ignored = false,
  });
}

class CodeHunk {
  final String filePath;
  final int oldStart;
  final int oldCount;
  final int newStart;
  final int newCount;
  final String leftText;
  final String rightText;
  final List<DiffLine> lines;

  const CodeHunk({
    required this.filePath,
    required this.oldStart,
    required this.oldCount,
    required this.newStart,
    required this.newCount,
    required this.leftText,
    required this.rightText,
    required this.lines,
  });

  int get oldEnd => oldStart + oldCount - 1;
  int get newEnd => newStart + newCount - 1;
}

enum DiffLineStatus { context, added, removed, changed }

class DiffLine {
  final int? leftNumber;
  final int? rightNumber;
  final String leftText;
  final String rightText;
  final DiffLineStatus status;

  const DiffLine({
    required this.leftNumber,
    required this.rightNumber,
    required this.leftText,
    required this.rightText,
    required this.status,
  });
}

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

List<CodeChunk> dummyCodeChunks() {
  return <CodeChunk>[
    CodeChunk(
      filePath: 'lib/src/example.dart',
      rightFilePath: 'lib/src/example.dart',
      oldStart: 3,
      oldEnd: 8,
      newStart: 3,
      newEnd: 9,
      leftText: r'''
class Greeter {
  String greet(String name) {
    return 'Hello, $name';
  }
}''',
      rightText: '',
      name: 'Greeter.greet',
      kind: SymbolKind.method,
      ignored: false,
      lines: const <DiffLine>[
        DiffLine(
          leftNumber: 3,
          rightNumber: null,
          leftText: 'class Greeter {',
          rightText: '',
          status: DiffLineStatus.context,
        ),
        DiffLine(
          leftNumber: 4,
          rightNumber: null,
          leftText: '  String greet(String name) {',
          rightText: '',
          status: DiffLineStatus.changed,
        ),
        DiffLine(
          leftNumber: 5,
          rightNumber: null,
          leftText: "    return 'Hello, \$name';",
          rightText: '',
          status: DiffLineStatus.changed,
        ),
        DiffLine(
          leftNumber: 6,
          rightNumber: null,
          leftText: '  }',
          rightText: '',
          status: DiffLineStatus.context,
        ),
        DiffLine(
          leftNumber: 7,
          rightNumber: null,
          leftText: '}',
          rightText: '',
          status: DiffLineStatus.context,
        ),
      ],
    ),
    CodeChunk(
      filePath: 'lib/main.dart',
      rightFilePath: 'lib/main.dart',
      oldStart: 1,
      newStart: 1,
      oldEnd: 5,
      newEnd: 6,
      leftText: r'''
void main() {
  final Greeter greeter = Greeter();
  print(greeter.greet('World'));
}''',
      rightText: '',
      name: 'main',
      kind: SymbolKind.function,
      ignored: false,
      lines: const <DiffLine>[
        DiffLine(
          leftNumber: 1,
          rightNumber: null,
          leftText: 'void main() {',
          rightText: '',
          status: DiffLineStatus.context,
        ),
        DiffLine(
          leftNumber: 2,
          rightNumber: null,
          leftText: '  final Greeter greeter = Greeter();',
          rightText: '',
          status: DiffLineStatus.context,
        ),
        DiffLine(
          leftNumber: 3,
          rightNumber: null,
          leftText: "  print(greeter.greet('World'));",
          rightText: '',
          status: DiffLineStatus.changed,
        ),
        DiffLine(
          leftNumber: 4,
          rightNumber: null,
          leftText: '}',
          rightText: '',
          status: DiffLineStatus.context,
        ),
      ],
    ),
  ];
}

List<CodeHunk> dummyCodeHunks() {
  return <CodeHunk>[
    CodeHunk(
      filePath: 'lib/src/example.dart',
      oldStart: 3,
      oldCount: 4,
      newStart: 3,
      newCount: 6,
      leftText: r'''
class Greeter {
  String greet(String name) {
    return 'Hello, $name';
  }
}''',
      rightText: r'''
class Greeter {
  String greet(String name, {bool excited = false}) {
    final String msg = 'Hello, $name';
    return excited ? '$msg!' : msg;
  }
}''',
      lines: const <DiffLine>[
        DiffLine(
          leftNumber: 3,
          rightNumber: 3,
          leftText: 'class Greeter {',
          rightText: 'class Greeter {',
          status: DiffLineStatus.context,
        ),
        DiffLine(
          leftNumber: 4,
          rightNumber: 4,
          leftText: '  String greet(String name) {',
          rightText: '  String greet(String name, {bool excited = false}) {',
          status: DiffLineStatus.changed,
        ),
        DiffLine(
          leftNumber: null,
          rightNumber: 5,
          leftText: '',
          rightText: "    final String msg = 'Hello, \$name';",
          status: DiffLineStatus.added,
        ),
        DiffLine(
          leftNumber: 5,
          rightNumber: 6,
          leftText: "    return 'Hello, \$name';",
          rightText: "    return excited ? '\$msg!' : msg;",
          status: DiffLineStatus.changed,
        ),
        DiffLine(
          leftNumber: 6,
          rightNumber: 7,
          leftText: '  }',
          rightText: '  }',
          status: DiffLineStatus.context,
        ),
        DiffLine(
          leftNumber: 7,
          rightNumber: 8,
          leftText: '}',
          rightText: '}',
          status: DiffLineStatus.context,
        ),
      ],
    ),
    CodeHunk(
      filePath: 'lib/main.dart',
      oldStart: 1,
      oldCount: 5,
      newStart: 1,
      newCount: 6,
      leftText: r'''
void main() {
  final Greeter greeter = Greeter();
  print(greeter.greet('World'));
}''',
      rightText: r'''
void main() {
  final Greeter greeter = Greeter();
  print(greeter.greet('World', excited: true));
}''',
      lines: const <DiffLine>[
        DiffLine(
          leftNumber: 1,
          rightNumber: 1,
          leftText: 'void main() {',
          rightText: 'void main() {',
          status: DiffLineStatus.context,
        ),
        DiffLine(
          leftNumber: 2,
          rightNumber: 2,
          leftText: '  final Greeter greeter = Greeter();',
          rightText: '  final Greeter greeter = Greeter();',
          status: DiffLineStatus.context,
        ),
        DiffLine(
          leftNumber: 3,
          rightNumber: 3,
          leftText: "  print(greeter.greet('World'));",
          rightText: "  print(greeter.greet('World', excited: true));",
          status: DiffLineStatus.removed,
        ),
        DiffLine(
          leftNumber: 4,
          rightNumber: 4,
          leftText: '}',
          rightText: '}',
          status: DiffLineStatus.context,
        ),
      ],
    ),
  ];
}

Future<bool> isGitRepo(String path) async {
  final ProcessResult result =
      await _runGit(path, <String>['rev-parse', '--is-inside-work-tree']);
  final String out = _decodeOutput(result.stdout).trim();
  return result.exitCode == 0 && out == 'true';
}

Future<List<String>> listGitRefs(String repoPath) async {
  final ProcessResult result = await _runGit(repoPath, <String>[
    'for-each-ref',
    '--format=%(refname:short)',
    'refs/heads',
    'refs/remotes',
  ]);
  if (result.exitCode != 0) {
    return <String>[];
  }
  final List<String> lines =
      _decodeOutput(result.stdout).split('\n').where((String l) => l.isNotEmpty).toList();
  lines.sort();
  return lines;
}

Future<List<SymbolDiff>> loadSymbolDiffs(
  String repo,
  String leftRef,
  String rightRef,
) async {
  final List<String> args = <String>['diff', '--name-only', '--no-color'];
  if (rightRef == kWorktreeRef) {
    args.add(leftRef);
  } else {
    args.addAll(<String>[leftRef, rightRef]);
  }
  final ProcessResult result = await _runGit(repo, args);
  if (result.exitCode != 0) {
    return <SymbolDiff>[];
  }
  final List<String> files = _decodeOutput(result.stdout)
      .split('\n')
      .where((String l) => l.trim().isNotEmpty)
      .toList();
  return files
      .map(
        (String path) => SymbolDiff(
          change: SymbolChange(
            name: path,
            kind: SymbolKind.other,
            beforePath: path,
            afterPath: path,
          ),
          leftSnippet: '',
          rightSnippet: '',
        ),
      )
      .toList();
}

Future<List<CodeHunk>> loadHunkDiffs(
  String repo,
  String leftRef,
  String rightRef,
) async {
  final List<String> args = <String>['diff', '--no-color'];
  if (rightRef == kWorktreeRef) {
    args.add(leftRef);
  } else {
    args.addAll(<String>[leftRef, rightRef]);
  }
  final ProcessResult result = await _runGit(repo, args);
  if (result.exitCode != 0) {
    return <CodeHunk>[];
  }
  final String output = _decodeOutput(result.stdout);
  return _parseGitHunks(output);
}

Future<List<CodeChunk>> loadChunkDiffs(
  String repo,
  String leftRef,
  String rightRef,
) async {
  final List<CodeHunk> hunks = await loadHunkDiffs(repo, leftRef, rightRef);
  final Map<String, String?> leftCache = <String, String?>{};
  final Map<String, String?> rightCache = <String, String?>{};

  Future<String?> readFile(String path, String ref) async {
    final Map<String, String?> cache =
        ref == rightRef ? rightCache : leftCache;
    if (cache.containsKey(path)) {
      return cache[path];
    }
    final String? text = await _readFileForRef(repo, ref, path);
    cache[path] = text;
    return text;
  }

  final List<CodeChunk> chunks = <CodeChunk>[];
  for (final CodeHunk hunk in hunks) {
    int lookupLine = hunk.oldStart > 0 ? hunk.oldStart : hunk.newStart;
    for (final DiffLine line in hunk.lines) {
      if (line.status != DiffLineStatus.context) {
        lookupLine = line.leftNumber ?? line.rightNumber ?? lookupLine;
        break;
      }
    }
    String? fileText = await readFile(hunk.filePath, leftRef);
    String usedRef = leftRef;
    if (fileText == null || fileText.isEmpty) {
      fileText = await readFile(hunk.filePath, rightRef);
      usedRef = rightRef;
    }
    if (fileText == null || fileText.isEmpty) {
      chunks.add(CodeChunk(
        filePath: hunk.filePath,
        rightFilePath: hunk.filePath,
        oldStart: hunk.oldStart,
        oldEnd: hunk.oldEnd,
        newStart: hunk.newStart,
        newEnd: hunk.newEnd,
        leftText: hunk.leftText,
        rightText: hunk.rightText,
        name: 'Ignored',
        kind: SymbolKind.other,
        ignored: true,
        lines: hunk.lines,
      ));
      continue;
    }

    final List<String> fileLines = fileText.split('\n');
    _ParentInfo? parent =
        _findParent(fileLines, lookupLine == 0 ? 1 : lookupLine);

    // If nothing found, scan forward within the hunk for a definition line and retry.
    if (parent == null) {
      final RegExp classRe = RegExp(r'^\s*class\s+(\w+)');
      final RegExp enumRe = RegExp(r'^\s*enum\s+(\w+)');
      final RegExp funcRe = RegExp(r'^\s*[A-Za-z0-9_<>\[\]\?]+\s+(\w+)\s*\(');
      for (final DiffLine line in hunk.lines) {
        final String candidate =
            line.leftText.isNotEmpty ? line.leftText : line.rightText;
        if (candidate.isEmpty) {
          continue;
        }
        final bool looksLikeDecl =
            classRe.hasMatch(candidate) || enumRe.hasMatch(candidate) || funcRe.hasMatch(candidate);
        if (!looksLikeDecl) {
          continue;
        }
        final int? lineNumber = line.leftNumber ?? line.rightNumber;
        if (lineNumber != null) {
          final _ParentInfo? candidateParent = _findParent(fileLines, lineNumber);
          if (candidateParent != null &&
              _containsAnyChange(candidateParent, hunk.lines)) {
            parent = candidateParent;
            break;
          }
        }
      }
    }

    if (parent == null) {
      chunks.add(CodeChunk(
        filePath: hunk.filePath,
        rightFilePath: hunk.filePath,
        oldStart: hunk.oldStart,
        oldEnd: hunk.oldEnd,
        newStart: hunk.newStart,
        newEnd: hunk.newEnd,
        leftText: hunk.leftText,
        rightText: hunk.rightText,
        name: 'Ignored',
        kind: SymbolKind.other,
        ignored: true,
        lines: hunk.lines,
      ));
      continue;
    }

    final int startIdx = parent.startLine - 1;
    final int endIdx = parent.endLine - 1;
    final List<String> parentLines =
        fileLines.sublist(startIdx, endIdx + 1).toList();
    final String leftText = parentLines.join('\n');
    final bool removalOnly = _isRemovalOnly(hunk.lines);

    _ParentMatch? moved;
    if (removalOnly) {
      moved = await _findMovedParent(
        repo: repo,
        rightRef: rightRef,
        parentName: parent.name,
        hunks: hunks,
        rightCache: rightCache,
      );
    }

    final List<DiffLine> chunkLines = moved == null
        ? _buildChunkLines(parentLines, parent.startLine, hunk.lines)
        : _alignParentLines(
            leftLines: parentLines,
            leftStart: parent.startLine,
            rightLines: moved.rightLines,
            rightStart: moved.info.startLine,
          );

    chunks.add(CodeChunk(
      filePath: hunk.filePath,
      rightFilePath: moved?.filePath ?? hunk.filePath,
      oldStart: parent.startLine,
      oldEnd: parent.endLine,
      newStart: moved?.info.startLine ?? hunk.newStart,
      newEnd: moved?.info.endLine ?? hunk.newEnd,
      leftText: leftText,
      rightText: moved == null ? (usedRef == leftRef ? '' : leftText) : moved.rightText,
      name: parent.name,
      kind: parent.kind,
      ignored: false,
      lines: chunkLines,
    ));
  }
  return chunks;
}

// --- Internal helpers ---

Future<ProcessResult> _runGit(String repo, List<String> args) async {
  print('[chunkdiff_core] RUN git ${args.join(' ')} (cwd: $repo)');
  final ProcessResult result = await Process.run(
    'git',
    args,
    workingDirectory: repo,
    stdoutEncoding: utf8,
    stderrEncoding: utf8,
  );
  final String stdoutStr = _decodeOutput(result.stdout);
  final String stderrStr = _decodeOutput(result.stderr);
  print(
      '[chunkdiff_core] EXIT ${result.exitCode} for git ${args.join(' ')} (cwd: $repo)');
  if (stdoutStr.isNotEmpty) {
    print('[chunkdiff_core] STDOUT:\n$stdoutStr');
  }
  if (stderrStr.isNotEmpty) {
    print('[chunkdiff_core] STDERR:\n$stderrStr');
  }
  return result;
}

String _decodeOutput(dynamic data) {
  if (data == null) {
    return '';
  }
  if (data is String) {
    return data;
  }
  if (data is List<int>) {
    return utf8.decode(data, allowMalformed: true);
  }
  return data.toString();
}

List<CodeHunk> _parseGitHunks(String diffOutput) {
  final List<CodeHunk> hunks = <CodeHunk>[];
  final List<String> lines = diffOutput.split('\n');

  String? currentFile;
  int? oldStart;
  int? oldCount;
  int? newStart;
  int? newCount;
  final List<DiffLine> currentLines = <DiffLine>[];
  final List<String> leftCollector = <String>[];
  final List<String> rightCollector = <String>[];
  int currentOldLine = 0;
  int currentNewLine = 0;

  void flushHunk() {
    if (currentFile == null ||
        oldStart == null ||
        oldCount == null ||
        newStart == null ||
        newCount == null ||
        currentLines.isEmpty) {
      currentLines.clear();
      leftCollector.clear();
      rightCollector.clear();
      return;
    }
    hunks.add(CodeHunk(
      filePath: currentFile!,
      oldStart: oldStart!,
      oldCount: oldCount!,
      newStart: newStart!,
      newCount: newCount!,
      leftText: leftCollector.join('\n'),
      rightText: rightCollector.join('\n'),
      lines: List<DiffLine>.from(currentLines),
    ));
    currentLines.clear();
    leftCollector.clear();
    rightCollector.clear();
  }

  for (int i = 0; i < lines.length; i++) {
    final String line = lines[i];
    if (line.startsWith('diff --git')) {
      flushHunk();
      final List<String> parts = line.split(' ');
      if (parts.length >= 4) {
        final String bPath = parts[3];
        currentFile = bPath.replaceFirst('b/', '');
      }
      continue;
    }
    // Skip file headers and index metadata.
    if (line.startsWith('+++ ') || line.startsWith('--- ') || line.startsWith('index ')) {
      continue;
    }
    if (line.startsWith('@@')) {
      flushHunk();
      final RegExpMatch? match =
          RegExp(r'@@ -(\d+),?(\d*) \+(\d+),?(\d*) @@').firstMatch(line);
      if (match != null) {
        oldStart = int.parse(match.group(1)!);
        oldCount = match.group(2)!.isEmpty ? 1 : int.parse(match.group(2)!);
        newStart = int.parse(match.group(3)!);
        newCount = match.group(4)!.isEmpty ? 1 : int.parse(match.group(4)!);
        currentOldLine = oldStart!;
        currentNewLine = newStart!;
      }
      continue;
    }
    if (line.startsWith('+') ||
        line.startsWith('-') ||
        line.startsWith(' ') ||
        line.isEmpty ||
        line.startsWith('\\ No newline at end of file')) {
      if (line.startsWith('\\')) {
        continue;
      }

      if (line.startsWith('-') && i + 1 < lines.length && lines[i + 1].startsWith('+')) {
        // Treat a -/+ pair as a single changed line.
        final String left = line.substring(1);
        final String right = lines[i + 1].substring(1);
        currentLines.add(DiffLine(
          leftNumber: currentOldLine,
          rightNumber: currentNewLine,
          leftText: left,
          rightText: right,
          status: DiffLineStatus.changed,
        ));
        leftCollector.add(left);
        rightCollector.add(right);
        currentOldLine++;
        currentNewLine++;
        i++; // consume the added line
        continue;
      }

      if (line.startsWith('-')) {
        final String text = line.substring(1);
        currentLines.add(DiffLine(
          leftNumber: currentOldLine,
          rightNumber: null,
          leftText: text,
          rightText: '',
          status: DiffLineStatus.removed,
        ));
        leftCollector.add(text);
        currentOldLine++;
      } else if (line.startsWith('+')) {
        final String text = line.substring(1);
        currentLines.add(DiffLine(
          leftNumber: null,
          rightNumber: currentNewLine,
          leftText: '',
          rightText: text,
          status: DiffLineStatus.added,
        ));
        rightCollector.add(text);
        currentNewLine++;
      } else {
        final String text = line.isEmpty ? '' : line.substring(1);
        currentLines.add(DiffLine(
          leftNumber: currentOldLine,
          rightNumber: currentNewLine,
          leftText: text,
          rightText: text,
          status: DiffLineStatus.context,
        ));
        leftCollector.add(text);
        rightCollector.add(text);
        currentOldLine++;
        currentNewLine++;
      }
    }
  }
  flushHunk();
  return hunks;
}

class _ParentInfo {
  final String name;
  final SymbolKind kind;
  final int startLine;
  final int endLine;

  const _ParentInfo({
    required this.name,
    required this.kind,
    required this.startLine,
    required this.endLine,
  });
}

_ParentInfo? _findParent(List<String> lines, int startLine) {
  final int startIdx = (startLine - 1).clamp(0, lines.length - 1);
  int foundIdx = startIdx;
  String? name;
  SymbolKind kind = SymbolKind.other;

  final RegExp classRe = RegExp(r'^\s*class\s+(\w+)');
  final RegExp enumRe = RegExp(r'^\s*enum\s+(\w+)');
  final RegExp funcRe = RegExp(r'^\s*[A-Za-z0-9_<>\[\]\?]+\s+(\w+)\s*\(');

  // If the starting line itself declares a parent, use it immediately.
  final String startLineText = lines[startIdx];
  final RegExpMatch? startClass = classRe.firstMatch(startLineText);
  final RegExpMatch? startEnum = enumRe.firstMatch(startLineText);
  final RegExpMatch? startFunc = funcRe.firstMatch(startLineText);
  if (startClass != null) {
    name = startClass.group(1)!;
    kind = SymbolKind.classType;
    foundIdx = startIdx;
  } else if (startEnum != null) {
    name = startEnum.group(1)!;
    kind = SymbolKind.enumType;
    foundIdx = startIdx;
  } else if (startFunc != null) {
    name = startFunc.group(1)!;
    kind = SymbolKind.function;
    foundIdx = startIdx;
  } else {
    for (int i = startIdx; i >= 0; i--) {
      final String line = lines[i];
      final RegExpMatch? classMatch = classRe.firstMatch(line);
      final RegExpMatch? enumMatch = enumRe.firstMatch(line);
      final RegExpMatch? funcMatch = funcRe.firstMatch(line);
      if (classMatch != null) {
        name = classMatch.group(1)!;
        kind = SymbolKind.classType;
        foundIdx = i;
        break;
      }
      if (enumMatch != null) {
        name = enumMatch.group(1)!;
        kind = SymbolKind.enumType;
        foundIdx = i;
        break;
      }
      if (funcMatch != null) {
        name = funcMatch.group(1)!;
        kind = SymbolKind.function;
        foundIdx = i;
        break;
      }
    }
  }

  if (name == null) {
    return null;
  }

  int braceBalance = 0;
  int endIdx = lines.length - 1;
  for (int i = foundIdx; i < lines.length; i++) {
    final String line = lines[i];
    for (final String char in line.split('')) {
      if (char == '{') braceBalance++;
      if (char == '}') braceBalance--;
    }
    if (braceBalance <= 0 && i > foundIdx) {
      endIdx = i;
      break;
    }
  }

  return _ParentInfo(
    name: name,
    kind: kind,
    startLine: foundIdx + 1,
    endLine: endIdx + 1,
  );
}

List<DiffLine> _buildChunkLines(
  List<String> parentLines,
  int parentStart,
  List<DiffLine> hunkLines,
) {
  final List<DiffLine> result = <DiffLine>[];
  int currentLeft = parentStart;

  for (final DiffLine line in hunkLines) {
    final int? leftNumber = line.leftNumber;
    if (leftNumber != null) {
      while (currentLeft < leftNumber &&
          currentLeft <= parentStart + parentLines.length - 1) {
        final String text = parentLines[currentLeft - parentStart];
        result.add(DiffLine(
          leftNumber: currentLeft,
          rightNumber: currentLeft,
          leftText: text,
          rightText: text,
          status: DiffLineStatus.context,
        ));
        currentLeft++;
      }
      result.add(line);
      currentLeft = leftNumber + 1;
    } else {
      result.add(line);
    }
  }

  final int parentEnd = parentStart + parentLines.length - 1;
  while (currentLeft <= parentEnd) {
    final String text = parentLines[currentLeft - parentStart];
    result.add(DiffLine(
      leftNumber: currentLeft,
      rightNumber: currentLeft,
      leftText: text,
      rightText: text,
      status: DiffLineStatus.context,
    ));
    currentLeft++;
  }
  return result;
}

bool _containsAnyChange(_ParentInfo parent, List<DiffLine> lines) {
  for (final DiffLine line in lines) {
    final int? left = line.leftNumber;
    final int? right = line.rightNumber;
    final bool inRange = (left != null &&
            left >= parent.startLine &&
            left <= parent.endLine) ||
        (right != null && right >= parent.startLine && right <= parent.endLine);
    if (!inRange) {
      continue;
    }
    if (line.status != DiffLineStatus.context) {
      return true;
    }
  }
  return false;
}

Future<String?> _readFileForRef(
  String repo,
  String ref,
  String path,
) async {
  try {
    if (ref == kWorktreeRef) {
      final File file = File(p.join(repo, path));
      if (!await file.exists()) {
        return null;
      }
      final List<int> bytes = await file.readAsBytes();
      return utf8.decode(bytes, allowMalformed: true);
    }
    final ProcessResult result =
        await _runGit(repo, <String>['show', '$ref:$path']);
    if (result.exitCode != 0) {
      return null;
    }
    return _decodeOutput(result.stdout);
  } catch (_) {
    return null;
  }
}

class _ParentMatch {
  final String filePath;
  final _ParentInfo info;
  final List<String> rightLines;
  final String rightText;

  const _ParentMatch({
    required this.filePath,
    required this.info,
    required this.rightLines,
    required this.rightText,
  });
}

Future<_ParentMatch?> _findMovedParent({
  required String repo,
  required String rightRef,
  required String parentName,
  required List<CodeHunk> hunks,
  required Map<String, String?> rightCache,
}) async {
  final String coreName = parentName.replaceFirst(RegExp(r'^_'), '');
  final RegExp nameRe = RegExp(r'\b_?${RegExp.escape(coreName)}\b');
  final Set<String> candidates =
      hunks.map((CodeHunk h) => h.filePath).toSet();

  for (final String path in candidates) {
    String? text = rightCache[path];
    text ??= await _readFileForRef(repo, rightRef, path);
    if (text == null || text.isEmpty) {
      continue;
    }
    rightCache[path] = text;
    final List<String> lines = text.split('\n');
    for (int i = 0; i < lines.length; i++) {
      if (!nameRe.hasMatch(lines[i])) {
        continue;
      }
      final _ParentInfo? info = _findParent(lines, i + 1);
      if (info == null) {
        continue;
      }
      final List<String> rightLines =
          lines.sublist(info.startLine - 1, info.endLine);
      return _ParentMatch(
        filePath: path,
        info: info,
        rightLines: rightLines,
        rightText: rightLines.join('\n'),
      );
    }
  }

  return null;
}

List<DiffLine> _alignParentLines({
  required List<String> leftLines,
  required int leftStart,
  required List<String> rightLines,
  required int rightStart,
}) {
  final List<DiffLine> result = <DiffLine>[];
  final int leftLen = leftLines.length;
  final int rightLen = rightLines.length;
  final int maxLen = leftLen > rightLen ? leftLen : rightLen;

  for (int i = 0; i < maxLen; i++) {
    final bool hasLeft = i < leftLen;
    final bool hasRight = i < rightLen;
    final int? leftNum = hasLeft ? leftStart + i : null;
    final int? rightNum = hasRight ? rightStart + i : null;
    final String leftText = hasLeft ? leftLines[i] : '';
    final String rightText = hasRight ? rightLines[i] : '';
    DiffLineStatus status;
    if (hasLeft && hasRight) {
      status = leftText == rightText
          ? DiffLineStatus.context
          : DiffLineStatus.changed;
    } else if (hasLeft) {
      status = DiffLineStatus.removed;
    } else {
      status = DiffLineStatus.added;
    }
    result.add(DiffLine(
      leftNumber: leftNum,
      rightNumber: rightNum,
      leftText: leftText,
      rightText: rightText,
      status: status,
    ));
  }
  return result;
}

bool _isRemovalOnly(List<DiffLine> lines) {
  bool hasRemoved = false;
  for (final DiffLine line in lines) {
    if (line.status == DiffLineStatus.added ||
        line.status == DiffLineStatus.changed) {
      return false;
    }
    if (line.status == DiffLineStatus.removed) {
      hasRemoved = true;
    }
  }
  return hasRemoved;
}
