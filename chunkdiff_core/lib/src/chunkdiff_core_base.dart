import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'log.dart';

bool _parserChecksRun = false;

enum SymbolKind { function, method, classType, enumType, other }

/// Special ref string to indicate the working tree instead of a named ref.
const String kWorktreeRef = 'WORKTREE';

class CodeChunk {
  final int id;
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
  final ChunkCategory category;
  final List<DiffLine> lines;
  final bool hasConflict;

  const CodeChunk({
    required this.id,
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
    this.category = ChunkCategory.changed,
    this.ignored = false,
    this.hasConflict = false,
  });
}

enum ChunkCategory {
  moved,
  changed,
  importOnly,
  punctuationOnly,
  usageOrUnresolved,
  unreadable,
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
  final bool hasConflict;

  const CodeHunk({
    required this.filePath,
    required this.oldStart,
    required this.oldCount,
    required this.newStart,
    required this.newCount,
    required this.leftText,
    required this.rightText,
    required this.lines,
    this.hasConflict = false,
  });

  int get oldEnd => oldStart + oldCount - 1;
  int get newEnd => newStart + newCount - 1;
}

enum DiffLineStatus {
  context,
  added,
  removed,
  changed,
  conflictLeft,
  conflictRight,
  conflictStart,
  conflictEnd
}

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
      id: 0,
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
      category: ChunkCategory.changed,
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
      id: 1,
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
      category: ChunkCategory.changed,
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
      hasConflict: false,
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
  _runParserSelfChecksOnce();
  final Map<String, SymbolChange> changes = <String, SymbolChange>{};

  final List<String> statusArgs = <String>['diff', '--name-status', '--no-color'];
  if (rightRef == kWorktreeRef) {
    statusArgs.add(leftRef);
  } else {
    statusArgs.addAll(<String>[leftRef, rightRef]);
  }
  final ProcessResult statusResult = await _runGit(repo, statusArgs);
  if (statusResult.exitCode != 0) {
    return <SymbolDiff>[];
  }
  final List<String> statusLines = _decodeOutput(statusResult.stdout)
      .split('\n')
      .where((String l) => l.trim().isNotEmpty)
      .toList();

  for (final String line in statusLines) {
    // Formats:
    // A\tpath
    // D\tpath
    // M\tpath
    // R100\told\tnew
    final List<String> parts = line.split('\t');
    if (parts.isEmpty) continue;
    final String status = parts.first.trim();
    if (status.isEmpty) continue;
    if (status.startsWith('R') && parts.length >= 3) {
      final String before = parts[1];
      final String after = parts[2];
      changes[after] = SymbolChange(
        name: after,
        kind: SymbolKind.other,
        beforePath: before,
        afterPath: after,
      );
      continue;
    }
    if (parts.length < 2) continue;
    final String path = parts[1];
    switch (status[0]) {
      case 'A':
        changes[path] = SymbolChange(
          name: path,
          kind: SymbolKind.other,
          beforePath: null,
          afterPath: path,
        );
        break;
      case 'D':
        changes[path] = SymbolChange(
          name: path,
          kind: SymbolKind.other,
          beforePath: path,
          afterPath: null,
        );
        break;
      default:
        changes[path] = SymbolChange(
          name: path,
          kind: SymbolKind.other,
          beforePath: path,
          afterPath: path,
        );
        break;
    }
  }

  return changes.values
      .map(
        (SymbolChange change) => SymbolDiff(
          change: change,
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
  List<CodeHunk> hunks = _parseGitHunks(output);
  final _ConflictBundle bundle =
      await _buildConflictHunks(repo, rightRef, hunks);
  if (bundle.hunks.isNotEmpty) {
    final List<CodeHunk> merged = <CodeHunk>[];
    for (final CodeHunk h in hunks) {
      final List<_ConflictRange>? ranges = bundle.ranges[h.filePath];
      if (ranges == null || ranges.isEmpty) {
        merged.add(h);
        continue;
      }
      final List<CodeHunk> parts = _splitHunkOutsideConflicts(h, ranges);
      merged.addAll(parts);
    }
    merged.addAll(bundle.hunks);
    merged.sort((CodeHunk a, CodeHunk b) {
      final int cmp = a.filePath.compareTo(b.filePath);
      if (cmp != 0) return cmp;
      return a.oldStart.compareTo(b.oldStart);
    });
    hunks = merged;
  }
  return hunks;
}

Future<List<CodeChunk>> loadChunkDiffs(
  String repo,
  String leftRef,
  String rightRef, {
  String? debugFilter,
}) async {
  logVerbose('[chunks] Start loadChunkDiffs for $repo ($leftRef -> $rightRef)');
  final List<CodeHunk> hunks = await loadHunkDiffs(repo, leftRef, rightRef);
  logVerbose('[chunks] Parsed ${hunks.length} hunks');
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

  // Precompute added-only parent candidates (same-kind matches for move/rename).
  final List<_ParentCandidate> addedParents = <_ParentCandidate>[];
  for (final CodeHunk h in hunks) {
    if (!_isAddedOnly(h.lines)) continue;
    final String? rightText = await readFile(h.filePath, rightRef);
    if (rightText == null || rightText.isEmpty) continue;
    final List<String> lines = rightText.split('\n');
    final _ParentInfo? p = _findParent(lines, h.newStart == 0 ? 1 : h.newStart);
    if (p == null) continue;
    final List<String> body =
        lines.sublist(p.startLine - 1, p.endLine).toList();
    addedParents.add(_ParentCandidate(
      filePath: h.filePath,
      info: p,
      lines: body,
    ));
  }

  final List<CodeChunk> chunks = <CodeChunk>[];
  int chunkId = 0;
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
      id: chunkId++,
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
      category: ChunkCategory.unreadable,
      lines: hunk.lines,
      hasConflict: hunk.hasConflict || _hasConflictLines(hunk.lines),
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

    final bool removalOnly = _isRemovalOnly(hunk.lines);
    final bool meaningful = _hasMeaningfulChanges(hunk.lines);
    final bool isImportOnlyHunk = _isImportOnly(hunk.lines);

    if (parent == null) {
      final ChunkCategory cat = isImportOnlyHunk
          ? ChunkCategory.importOnly
          : ChunkCategory.usageOrUnresolved;
      chunks.add(CodeChunk(
        id: chunkId++,
        filePath: hunk.filePath,
        rightFilePath: hunk.filePath,
        oldStart: hunk.oldStart,
        oldEnd: hunk.oldEnd,
        newStart: hunk.newStart,
        newEnd: hunk.newEnd,
        leftText: hunk.leftText,
        rightText: hunk.rightText,
        name: '',
        kind: SymbolKind.other,
        ignored: true,
        category: cat,
        lines: hunk.lines,
        hasConflict: hunk.hasConflict || _hasConflictLines(hunk.lines),
      ));
      continue;
    }

    final int startIdx = parent.startLine - 1;
    final int endIdx = parent.endLine - 1;
    final List<String> parentLines =
        fileLines.sublist(startIdx, endIdx + 1).toList();
    final String leftText = parentLines.join('\n');

    _ParentMatch? moved;
    if (removalOnly && meaningful) {
      moved = await _findMovedParent(
        repo: repo,
        rightRef: rightRef,
        parentName: parent.name,
        hunks: hunks,
        rightCache: rightCache,
        debugFilter: debugFilter,
      );
      // If no direct name match, try structure-based match against added-only parents.
      if (moved == null) {
        final String sigLeft = _structureSignature(parentLines);
        for (final _ParentCandidate cand in addedParents) {
          if (cand.info.kind != parent.kind) continue;
          final double sim = _structureSimilarity(sigLeft, _structureSignature(cand.lines));
          if (sim >= 0.5) {
            moved = _ParentMatch(
              filePath: cand.filePath,
              info: cand.info,
              rightLines: cand.lines,
              rightText: cand.lines.join('\n'),
            );
            logVerbose('[move] Structure match ${parent.name} -> ${cand.info.name} sim=$sim');
            break;
          }
        }
      }
    }

    if (isImportOnlyHunk && !meaningful && moved == null) {
      chunks.add(CodeChunk(
        id: chunkId++,
        filePath: hunk.filePath,
        rightFilePath: hunk.filePath,
        oldStart: parent.startLine,
        oldEnd: parent.endLine,
        newStart: hunk.newStart,
        newEnd: hunk.newEnd,
        leftText: leftText,
        rightText: leftText,
        name: parent.name,
        kind: parent.kind,
        ignored: true,
        category: ChunkCategory.importOnly,
        lines: hunk.lines,
        hasConflict: hunk.hasConflict || _hasConflictLines(hunk.lines),
      ));
      continue;
    }

    if (!meaningful && moved == null) {
      chunks.add(CodeChunk(
        id: chunkId++,
        filePath: hunk.filePath,
        rightFilePath: hunk.filePath,
        oldStart: parent.startLine,
        oldEnd: parent.endLine,
        newStart: hunk.newStart,
        newEnd: hunk.newEnd,
        leftText: leftText,
        rightText: leftText,
        name: parent.name,
        kind: parent.kind,
        ignored: true,
        category: isImportOnlyHunk
            ? ChunkCategory.importOnly
            : ChunkCategory.punctuationOnly,
        lines: hunk.lines,
        hasConflict: hunk.hasConflict || _hasConflictLines(hunk.lines),
      ));
      continue;
    }

    final List<DiffLine> chunkLines = moved == null
        ? _buildChunkLines(parentLines, parent.startLine, hunk.lines)
        : _alignMovedLines(
            leftLines: parentLines,
            leftStart: parent.startLine,
            rightLines: moved.rightLines,
            rightStart: moved.info.startLine,
          );

    chunks.add(CodeChunk(
      id: chunkId++,
      filePath: hunk.filePath,
      rightFilePath: moved?.filePath ?? hunk.filePath,
      oldStart: parent.startLine,
      oldEnd: parent.endLine,
      newStart: moved?.info.startLine ?? hunk.newStart,
      newEnd: moved?.info.endLine ?? hunk.newEnd,
      leftText: leftText,
      rightText:
          moved == null ? (usedRef == leftRef ? '' : leftText) : moved.rightText,
      name: parent.name,
      kind: parent.kind,
      ignored: false,
      category: moved != null ? ChunkCategory.moved : ChunkCategory.changed,
      lines: chunkLines,
      hasConflict:
          hunk.hasConflict || _hasConflictLines(chunkLines) || _hasConflictLines(hunk.lines),
    ));
  }
  logVerbose('[chunks] Built ${chunks.length} chunks');
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
    final List<DiffLine> normalizedLines =
        _alignHunkLinesSimple(List<DiffLine>.from(currentLines));
    final _ConflictResult conflictResult = _markConflicts(normalizedLines);
    final List<DiffLine> finalLines = conflictResult.lines;
    final String leftJoined = normalizedLines
        .where((DiffLine l) => l.leftText.isNotEmpty)
        .map((DiffLine l) => l.leftText)
        .join('\n');
    final String rightJoined = normalizedLines
        .where((DiffLine l) => l.rightText.isNotEmpty)
        .map((DiffLine l) => l.rightText)
        .join('\n');
    hunks.add(CodeHunk(
      filePath: currentFile!,
      oldStart: oldStart!,
      oldCount: oldCount!,
      newStart: newStart!,
      newCount: newCount!,
      leftText: leftJoined,
      rightText: rightJoined,
      lines: finalLines,
      hasConflict: conflictResult.hasConflict,
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
  String? debugFilter,
}) async {
  final String coreName = parentName.replaceFirst(RegExp(r'^_'), '');
  final RegExp nameRe = RegExp(
    r'\b_?' + RegExp.escape(coreName) + r'\b',
    caseSensitive: false,
  );
  final String coreNameLower = coreName.toLowerCase();
  final Set<String> candidates =
      hunks.map((CodeHunk h) => h.filePath).toSet();

  final bool filterMatches = debugFilter != null &&
      debugFilter.isNotEmpty &&
      coreName.toLowerCase() == debugFilter.toLowerCase();

  if (debugFilter != null &&
      debugFilter.isNotEmpty &&
      !filterMatches) {
    logVerbose('[move] Skipping "$coreName" because filter="$debugFilter"');
    // Only log if filter matches; still return null quickly.
    return null;
  }
  logVerbose('[move] Searching for "$coreName" in ${candidates.length} files...');
  if (filterMatches && candidates.isNotEmpty) {
    for (final String path in candidates) {
      logVerbose('[move] $path');
    }
  }

  for (final String path in candidates) {
    logVerbose('[move] Inspecting $path');
    String? text = rightCache[path];
    text ??= await _readFileForRef(repo, rightRef, path);
    if (text == null || text.isEmpty) {
      logVerbose('[move] Skipping $path (empty or unreadable)');
      continue;
    }
    rightCache[path] = text;
    final List<String> lines = text.split('\n');
    logVerbose('[move] $path has ${lines.length} lines to scan');
    for (int i = 0; i < lines.length; i++) {
      final String line = lines[i];
      // Extra diagnostics: note when the substring exists but regex fails.
      final bool containsLower =
          line.toLowerCase().contains(coreNameLower);
      final bool regexMatch = nameRe.hasMatch(line);
      if (containsLower && !regexMatch) {
        logVerbose('[move] Substring hit but regex miss at $path:${i + 1} -> "${line.trim()}"');
      }
      if (!regexMatch) {
        continue;
      }
      logVerbose('[move] Potential match at $path:${i + 1} -> "${line.trim()}"');
      final _ParentInfo? info = _findParent(lines, i + 1);
      if (info == null) {
        logVerbose('[move] Parent not found at $path:${i + 1}');
        continue;
      }
      if (info.name.toLowerCase() != coreNameLower) {
        logVerbose(
            '[move] Skipping usage at $path:${i + 1} (parent=${info.name})');
        continue;
      }
      final List<String> rightLines =
          lines.sublist(info.startLine - 1, info.endLine);
      logVerbose(
        '[move] Found in $path lines ${info.startLine}-${info.endLine}',

      );
      return _ParentMatch(
        filePath: path,
        info: info,
        rightLines: rightLines,
        rightText: rightLines.join('\n'),
      );
    }
  }

  logVerbose('[move] No match found for "' + coreName + '".');
  return null;
}

class _ParentCandidate {
  final String filePath;
  final _ParentInfo info;
  final List<String> lines;

  const _ParentCandidate({
    required this.filePath,
    required this.info,
    required this.lines,
  });
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

List<DiffLine> _alignMovedLines({
  required List<String> leftLines,
  required int leftStart,
  required List<String> rightLines,
  required int rightStart,
}) {
  int i = 0;
  int j = 0;
  final int leftLen = leftLines.length;
  final int rightLen = rightLines.length;
  final List<DiffLine> out = <DiffLine>[];

  double sim(String a, String b) {
    if (a.isEmpty || b.isEmpty) return 0.0;
    final List<String> ta =
        a.split(RegExp(r'\\W+')).where((String s) => s.isNotEmpty).toList();
    final List<String> tb =
        b.split(RegExp(r'\\W+')).where((String s) => s.isNotEmpty).toList();
    if (ta.isEmpty || tb.isEmpty) return 0.0;
    final Set<String> sa = ta.toSet();
    final Set<String> sb = tb.toSet();
    final int inter = sa.intersection(sb).length;
    final int union = sa.union(sb).length;
    return union == 0 ? 0.0 : inter / union;
  }

  int leftNum(int idx) => leftStart + idx;
  int rightNum(int idx) => rightStart + idx;

  const int window = 8;

  while (i < leftLen || j < rightLen) {
    if (i < leftLen && j < rightLen && leftLines[i] == rightLines[j]) {
      out.add(DiffLine(
        leftNumber: leftNum(i),
        rightNumber: rightNum(j),
        leftText: leftLines[i],
        rightText: rightLines[j],
        status: DiffLineStatus.context,
      ));
      i++;
      j++;
      continue;
    }

    // Try to match left[i] somewhere ahead in right (windowed).
    int bestR = -1;
    double bestSim = 0.0;
    int bestDist = 9999;
    if (i < leftLen) {
      final int rMax = rightLen < j + window ? rightLen : j + window;
      for (int rIdx = j; rIdx < rMax; rIdx++) {
        final double s = sim(leftLines[i], rightLines[rIdx]);
        final int dist = (rIdx - j).abs();
        if (s > bestSim || (s == bestSim && dist < bestDist)) {
          bestSim = s;
          bestDist = dist;
          bestR = rIdx;
        }
      }
    }

    if (bestR != -1 && (bestSim >= 0.2 || bestDist <= 2)) {
      // Add any intervening right-side additions before the match.
      for (int k = j; k < bestR; k++) {
        out.add(DiffLine(
          leftNumber: null,
          rightNumber: rightNum(k),
          leftText: '',
          rightText: rightLines[k],
          status: DiffLineStatus.added,
        ));
      }
      out.add(DiffLine(
        leftNumber: leftNum(i),
        rightNumber: rightNum(bestR),
        leftText: leftLines[i],
        rightText: rightLines[bestR],
        status:
            leftLines[i] == rightLines[bestR] ? DiffLineStatus.context : DiffLineStatus.changed,
      ));
      i++;
      j = bestR + 1;
      continue;
    }

    // Try to match right[j] somewhere ahead in left (windowed).
    int bestL = -1;
    bestSim = 0.0;
    bestDist = 9999;
    if (j < rightLen) {
      final int lMax = leftLen < i + window ? leftLen : i + window;
      for (int lIdx = i; lIdx < lMax; lIdx++) {
        final double s = sim(leftLines[lIdx], rightLines[j]);
        final int dist = (lIdx - i).abs();
        if (s > bestSim || (s == bestSim && dist < bestDist)) {
          bestSim = s;
          bestDist = dist;
          bestL = lIdx;
        }
      }
    }

    if (bestL != -1 && (bestSim >= 0.2 || bestDist <= 2)) {
      for (int k = i; k < bestL; k++) {
        out.add(DiffLine(
          leftNumber: leftNum(k),
          rightNumber: null,
          leftText: leftLines[k],
          rightText: '',
          status: DiffLineStatus.removed,
        ));
      }
      out.add(DiffLine(
        leftNumber: leftNum(bestL),
        rightNumber: rightNum(j),
        leftText: leftLines[bestL],
        rightText: rightLines[j],
        status:
            leftLines[bestL] == rightLines[j] ? DiffLineStatus.context : DiffLineStatus.changed,
      ));
      j++;
      i = bestL + 1;
      continue;
    }

    // Fallback: pair current lines if both exist.
    if (i < leftLen && j < rightLen) {
      out.add(DiffLine(
        leftNumber: leftNum(i),
        rightNumber: rightNum(j),
        leftText: leftLines[i],
        rightText: rightLines[j],
        status: leftLines[i] == rightLines[j]
            ? DiffLineStatus.context
            : DiffLineStatus.changed,
      ));
      i++;
      j++;
      continue;
    }

    if (i < leftLen) {
      out.add(DiffLine(
        leftNumber: leftNum(i),
        rightNumber: null,
        leftText: leftLines[i],
        rightText: '',
        status: DiffLineStatus.removed,
      ));
      i++;
      continue;
    }

    if (j < rightLen) {
      out.add(DiffLine(
        leftNumber: null,
        rightNumber: rightNum(j),
        leftText: '',
        rightText: rightLines[j],
        status: DiffLineStatus.added,
      ));
      j++;
      continue;
    }
  }

  return _markConflicts(out).lines;
}

class _ConflictResult {
  final List<DiffLine> lines;
  final bool hasConflict;

  _ConflictResult(this.lines, this.hasConflict);
}

_ConflictResult _markConflicts(List<DiffLine> lines) {
  final List<DiffLine> out = <DiffLine>[];
  bool inConflict = false;
  bool inRight = false;
  bool hasConflict = false;

  bool isMarker(String text, String marker) => text.trimLeft().startsWith(marker);

  for (final DiffLine line in lines) {
    final String text = line.leftText.isNotEmpty ? line.leftText : line.rightText;
    if (isMarker(text, '<<<<<<<')) {
      inConflict = true;
      inRight = false;
      hasConflict = true;
      out.add(DiffLine(
        leftNumber: null,
        rightNumber: null,
        leftText: 'Conflict start',
        rightText: 'Conflict start',
        status: DiffLineStatus.conflictStart,
      ));
      continue;
    }
    if (isMarker(text, '=======')) {
      inRight = true;
      out.add(DiffLine(
        leftNumber: line.leftNumber,
        rightNumber: line.rightNumber,
        leftText: '---',
        rightText: '---',
        status: DiffLineStatus.context,
      ));
      continue;
    }
    if (isMarker(text, '>>>>>>>')) {
      inConflict = false;
      inRight = false;
      out.add(DiffLine(
        leftNumber: null,
        rightNumber: null,
        leftText: 'Conflict end',
        rightText: 'Conflict end',
        status: DiffLineStatus.conflictEnd,
      ));
      continue;
    }

    if (inConflict) {
      out.add(DiffLine(
        leftNumber: inRight ? null : line.leftNumber,
        rightNumber: inRight ? line.rightNumber : null,
        leftText: inRight ? '' : text,
        rightText: inRight ? text : '',
        status: inRight ? DiffLineStatus.conflictRight : DiffLineStatus.conflictLeft,
      ));
      continue;
    }

    out.add(line);
  }

  return _ConflictResult(out, hasConflict);
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

bool _isAddedOnly(List<DiffLine> lines) {
  bool hasAdded = false;
  for (final DiffLine line in lines) {
    if (line.status == DiffLineStatus.removed ||
        line.status == DiffLineStatus.changed) {
      return false;
    }
    if (line.status == DiffLineStatus.added) {
      hasAdded = true;
    }
  }
  return hasAdded;
}

bool _hasMeaningfulChanges(List<DiffLine> lines) {
  final RegExp alnum = RegExp(r'[A-Za-z0-9]');
  bool foundImport = false;
  for (final DiffLine line in lines) {
    if (line.status == DiffLineStatus.context) {
      continue;
    }
    final String text = line.leftText.isNotEmpty ? line.leftText : line.rightText;
    if (_isImportLine(text)) {
      foundImport = true;
      continue;
    }
    if (alnum.hasMatch(text)) {
      return true;
    }
  }
  // If we only saw imports (and no other alnum text), treat as non-meaningful.
  return false;
}

bool _hasImportLikeChange(List<DiffLine> lines) {
  bool sawImport = false;
  for (final DiffLine line in lines) {
    if (line.status == DiffLineStatus.context) continue;
    final String text = line.leftText.isNotEmpty ? line.leftText : line.rightText;
    if (_isImportLine(text)) {
      sawImport = true;
    }
  }
  return sawImport;
}

bool _isImportOnly(List<DiffLine> lines) {
  bool sawChange = false;
  bool sawImport = false;
  for (final DiffLine line in lines) {
    if (line.status == DiffLineStatus.context) continue;
    sawChange = true;
    final String text = line.leftText.isNotEmpty ? line.leftText : line.rightText;
    if (_isImportLine(text)) {
      sawImport = true;
    } else {
      return false;
    }
  }
  return sawChange && sawImport;
}

bool _isImportLine(String text) {
  final String t = text.trimLeft().toLowerCase();
  return t.startsWith('import ') ||
      t.startsWith('export ') ||
      t.startsWith('include ');
}

void _runParserSelfChecksOnce() {
  if (_parserChecksRun || !isDebugBuild()) {
    return;
  }
  _parserChecksRun = true;

  logVerbose('[selfcheck] Running parser helpers self-checks');

  DiffLine _changed(String text) => DiffLine(
        leftNumber: null,
        rightNumber: 1,
        leftText: '',
        rightText: text,
        status: DiffLineStatus.added,
      );

  const String codeLine = 'RaidingService.instance.setHostEndLiveFlowInProgress(true);';
  final List<DiffLine> codeLines = <DiffLine>[_changed(codeLine)];
  final bool codeIsImport = _isImportLine(codeLine);
  final bool codeIsImportOnly = _isImportOnly(codeLines);
  logVerbose('[selfcheck][${(!codeIsImport && !codeIsImportOnly) ? 'PASS' : 'FAIL'}] '
      'codeLine isImportLine=$codeIsImport, isImportOnly=$codeIsImportOnly');

  const String importLineText = 'import \"foo.dart\";';
  final List<DiffLine> importLines = <DiffLine>[_changed(importLineText)];
  final bool importIsImport = _isImportLine(importLineText);
  final bool importIsImportOnly = _isImportOnly(importLines);
  logVerbose('[selfcheck][${(importIsImport && importIsImportOnly) ? 'PASS' : 'FAIL'}] '
      'importLine isImportLine=$importIsImport, isImportOnly=$importIsImportOnly');

  final List<DiffLine> mixed = <DiffLine>[
    _changed(importLineText),
    _changed(codeLine),
  ];
  final bool mixedImportOnly = _isImportOnly(mixed);
  final bool mixedMeaningful = _hasMeaningfulChanges(mixed);
  logVerbose('[selfcheck][${(!mixedImportOnly && mixedMeaningful) ? 'PASS' : 'FAIL'}] '
      'mixed isImportOnly=$mixedImportOnly, hasMeaningful=$mixedMeaningful');
}

String _structureSignature(List<String> lines) {
  final String joined = lines.join('\n');
  final List<String> tokens = <String>[];
  final RegExp tokenRe = RegExp(r'[A-Za-z_][A-Za-z0-9_]*|\\d+|\\S');
  final Iterable<RegExpMatch> matches = tokenRe.allMatches(joined);
  for (final RegExpMatch m in matches) {
    final String t = m.group(0) ?? '';
    if (t.isEmpty) continue;
    if (RegExp(r'^[A-Za-z_]').hasMatch(t)) {
      tokens.add('ID');
    } else if (RegExp(r'^\\d+$').hasMatch(t)) {
      tokens.add('NUM');
    } else {
      tokens.add(t);
    }
  }
  return tokens.join(' ');
}

double _structureSimilarity(String a, String b) {
  if (a.isEmpty || b.isEmpty) return 0.0;
  final List<String> ta = a.split(' ');
  final List<String> tb = b.split(' ');
  final Set<String> sa = ta.toSet();
  final Set<String> sb = tb.toSet();
  final int inter = sa.intersection(sb).length;
  final int union = sa.union(sb).length;
  if (union == 0) return 0.0;
  return inter / union;
}

bool _hasConflictLines(List<DiffLine> lines) {
  for (final DiffLine line in lines) {
    if (line.status == DiffLineStatus.conflictLeft ||
        line.status == DiffLineStatus.conflictRight ||
        line.status == DiffLineStatus.conflictStart ||
        line.status == DiffLineStatus.conflictEnd) {
      return true;
    }
  }
  return false;
}

bool _hunkOverlaps(CodeHunk h, _ConflictRange r) {
  if (h.filePath.isEmpty) return false;
  final bool oldOverlap = !(h.oldEnd < r.start || h.oldStart > r.end);
  final bool newOverlap = !(h.newEnd < r.start || h.newStart > r.end);
  return oldOverlap || newOverlap;
}

List<CodeHunk> _splitHunkOutsideConflicts(
    CodeHunk h, List<_ConflictRange> ranges) {
  final List<_ConflictRange> sortedRanges = List<_ConflictRange>.from(ranges)
    ..sort((a, b) => a.start.compareTo(b.start));

  bool inConflictLine(DiffLine line) {
    if (line.status == DiffLineStatus.conflictLeft ||
        line.status == DiffLineStatus.conflictRight ||
        line.status == DiffLineStatus.conflictStart ||
        line.status == DiffLineStatus.conflictEnd) {
      return true;
    }
    for (final _ConflictRange r in sortedRanges) {
      final int? l = line.leftNumber;
      final int? rr = line.rightNumber;
      if ((l != null && l >= r.start && l <= r.end) ||
          (rr != null && rr >= r.start && rr <= r.end)) {
        return true;
      }
    }
    return false;
  }

  bool segmentHasChange(List<DiffLine> seg) {
    for (final DiffLine l in seg) {
      if (l.status == DiffLineStatus.conflictLeft ||
          l.status == DiffLineStatus.conflictRight ||
          l.status == DiffLineStatus.conflictStart ||
          l.status == DiffLineStatus.conflictEnd) {
        return false;
      }
      if (l.status != DiffLineStatus.context) return true;
    }
    return false;
  }

  final List<CodeHunk> parts = <CodeHunk>[];
  List<DiffLine> buffer = <DiffLine>[];

  void flushBuffer() {
    if (buffer.isEmpty) return;
    if (!segmentHasChange(buffer)) {
      buffer = <DiffLine>[];
      return;
    }
    final int? minLeft = buffer
        .map((DiffLine d) => d.leftNumber)
        .where((int? n) => n != null)
        .cast<int>()
        .fold<int?>(null, (int? a, int b) => a == null ? b : (b < a ? b : a));
    final int? maxLeft = buffer
        .map((DiffLine d) => d.leftNumber)
        .where((int? n) => n != null)
        .cast<int>()
        .fold<int?>(null, (int? a, int b) => a == null ? b : (b > a ? b : a));
    final int? minRight = buffer
        .map((DiffLine d) => d.rightNumber)
        .where((int? n) => n != null)
        .cast<int>()
        .fold<int?>(null, (int? a, int b) => a == null ? b : (b < a ? b : a));
    final int? maxRight = buffer
        .map((DiffLine d) => d.rightNumber)
        .where((int? n) => n != null)
        .cast<int>()
        .fold<int?>(null, (int? a, int b) => a == null ? b : (b > a ? b : a));

    final int oldStart = minLeft ?? (minRight ?? 0);
    final int newStart = minRight ?? (minLeft ?? 0);
    final int oldEnd = maxLeft ?? (maxRight ?? oldStart);
    final int newEnd = maxRight ?? (maxLeft ?? newStart);
    final int oldCount = (oldEnd - oldStart + 1).clamp(0, 1 << 30);
    final int newCount = (newEnd - newStart + 1).clamp(0, 1 << 30);

    String buildText(bool left) {
      final List<String> texts = <String>[];
      for (final DiffLine l in buffer) {
        final String t = left ? l.leftText : l.rightText;
        if (t.isNotEmpty) {
          texts.add(t);
        }
      }
      return texts.join('\n');
    }

    parts.add(CodeHunk(
      filePath: h.filePath,
      oldStart: oldStart,
      oldCount: oldCount,
      newStart: newStart,
      newCount: newCount,
      leftText: buildText(true),
      rightText: buildText(false),
      lines: List<DiffLine>.from(buffer),
      hasConflict: h.hasConflict,
    ));
    buffer = <DiffLine>[];
  }

  for (final DiffLine line in h.lines) {
    if (inConflictLine(line)) {
      flushBuffer();
      continue;
    }
    buffer.add(line);
  }
  flushBuffer();
  return parts;
}

List<DiffLine> _alignHunkLinesSimple(List<DiffLine> lines) {
  final List<DiffLine> result = <DiffLine>[];
  final List<DiffLine> removedBuf = <DiffLine>[];
  final List<DiffLine> addedBuf = <DiffLine>[];

  void flushBuffers() {
    if (removedBuf.isEmpty && addedBuf.isEmpty) {
      return;
    }
    final List<_LineWithPos> temp = <_LineWithPos>[];
    final List<bool> matchedRemoved =
        List<bool>.filled(removedBuf.length, false);
    final List<bool> matchedAdded =
        List<bool>.filled(addedBuf.length, false);

    double sim(String a, String b) {
      if (a.isEmpty || b.isEmpty) return 0.0;
      final List<String> ta = a
          .split(RegExp(r'\\W+'))
          .where((String s) => s.isNotEmpty)
          .toList();
      final List<String> tb = b
          .split(RegExp(r'\\W+'))
          .where((String s) => s.isNotEmpty)
          .toList();
      if (ta.isEmpty || tb.isEmpty) return 0.0;
      final Set<String> sa = ta.toSet();
      final Set<String> sb = tb.toSet();
      final int inter = sa.intersection(sb).length;
      final int union = sa.union(sb).length;
      return union == 0 ? 0.0 : inter / union;
    }

    for (int i = 0; i < removedBuf.length; i++) {
      final DiffLine rem = removedBuf[i];
      double best = 0.0;
      int bestDist = 9999;
      int bestIdx = -1;
      for (int j = 0; j < addedBuf.length; j++) {
        if (matchedAdded[j]) continue;
        final int leftNum = rem.leftNumber ?? 0;
        final int rightNum = addedBuf[j].rightNumber ?? leftNum;
        final int distance = (leftNum - rightNum).abs();
        if (distance > 8) continue; // consider a slightly wider window
        final double s = sim(rem.leftText, addedBuf[j].rightText);
        if (s > best || (s == best && distance < bestDist)) {
          best = s;
          bestDist = distance;
          bestIdx = j;
        }
      }
      // Fallback: if similarity low but line numbers are close, still pair.
      final bool closeLineNumbers = bestIdx != -1 && bestDist <= 2;
      if (bestIdx != -1 && (best >= 0.2 || closeLineNumbers)) {
        matchedRemoved[i] = true;
        matchedAdded[bestIdx] = true;
        final DiffLine add = addedBuf[bestIdx];
        temp.add(_LineWithPos(
          pos: _linePos(rem.leftNumber, add.rightNumber),
          line: DiffLine(
            leftNumber: rem.leftNumber,
            rightNumber: add.rightNumber,
            leftText: rem.leftText,
            rightText: add.rightText,
            status: DiffLineStatus.changed,
          ),
        ));
      }
    }

    for (int i = 0; i < removedBuf.length; i++) {
      if (matchedRemoved[i]) continue;
      temp.add(_LineWithPos(
        pos: _linePos(removedBuf[i].leftNumber, null),
        line: removedBuf[i],
      ));
    }
    for (int j = 0; j < addedBuf.length; j++) {
      if (matchedAdded[j]) continue;
      temp.add(_LineWithPos(
        pos: _linePos(null, addedBuf[j].rightNumber),
        line: addedBuf[j],
      ));
    }

    temp.sort((a, b) => a.pos.compareTo(b.pos));
    result.addAll(temp.map((e) => e.line));
    removedBuf.clear();
    addedBuf.clear();
  }

  for (final DiffLine line in lines) {
    if (line.status == DiffLineStatus.context) {
      flushBuffers();
      result.add(line);
      continue;
    }
    if (line.status == DiffLineStatus.removed) {
      removedBuf.add(line);
      continue;
    }
    if (line.status == DiffLineStatus.added) {
      addedBuf.add(line);
      continue;
    }
    // changed lines are kept as-is
    flushBuffers();
    result.add(line);
  }
  flushBuffers();

  return result;
}

int _linePos(int? left, int? right) {
  const int large = 1000000;
  final int l = left ?? large;
  final int r = right ?? large;
  return l < r ? l : r;
}

class _LineWithPos {
  final int pos;
  final DiffLine line;

  _LineWithPos({required this.pos, required this.line});
}
class _ConflictRange {
  final int start;
  final int end;
  const _ConflictRange(this.start, this.end);
}

class _ConflictBundle {
  final List<CodeHunk> hunks;
  final Map<String, List<_ConflictRange>> ranges;
  const _ConflictBundle(this.hunks, this.ranges);
}

Future<_ConflictBundle> _buildConflictHunks(
  String repo,
  String ref,
  List<CodeHunk> hunks,
) async {
  final Map<String, List<CodeHunk>> hunksByFile = <String, List<CodeHunk>>{};
  for (final CodeHunk h in hunks) {
    hunksByFile.putIfAbsent(h.filePath, () => <CodeHunk>[]).add(h);
  }

  final List<CodeHunk> conflictHunks = <CodeHunk>[];
  final Map<String, List<_ConflictRange>> rangesByFile = <String, List<_ConflictRange>>{};

  for (final MapEntry<String, List<CodeHunk>> entry in hunksByFile.entries) {
    final String path = entry.key;
    String? text = await _readFileForRef(repo, kWorktreeRef, path);
    text ??= await _readFileForRef(repo, ref, path);
    if (text == null || text.isEmpty) continue;
    final List<String> lines = text.split('\n');
    int idx = 0;
    while (idx < lines.length) {
      if (!lines[idx].trimLeft().startsWith('<<<<<<<')) {
        idx++;
        continue;
      }
      final int start = idx;
      int middle = -1;
      int end = -1;
      int scan = idx + 1;
      while (scan < lines.length && middle == -1) {
        if (lines[scan].trimLeft().startsWith('=======')) {
          middle = scan;
        }
        scan++;
      }
      while (scan < lines.length && end == -1) {
        if (lines[scan].trimLeft().startsWith('>>>>>>>')) {
          end = scan;
        }
        scan++;
      }
      if (middle == -1 || end == -1) {
        idx++;
        continue;
      }

      final List<String> leftSection =
          lines.sublist(start + 1, middle).toList();
      final List<String> rightSection =
          lines.sublist(middle + 1, end).toList();

      final int leftLen = leftSection.length;
      final int rightLen = rightSection.length;
      final int maxLen = leftLen > rightLen ? leftLen : rightLen;

      final List<DiffLine> conflictLines = <DiffLine>[];

      // Start marker line.
      conflictLines.add(DiffLine(
        leftNumber: null,
        rightNumber: null,
        leftText: 'Conflict start',
        rightText: 'Conflict start',
        status: DiffLineStatus.conflictStart,
      ));

      for (int i = 0; i < maxLen; i++) {
        final String lText = i < leftLen ? leftSection[i] : '';
        final String rText = i < rightLen ? rightSection[i] : '';
        final int? lNum = i < leftLen ? (start + 2 + i) : null;
        final int? rNum = i < rightLen ? (middle + 2 + i) : null;
        if (lText.isNotEmpty && rText.isNotEmpty) {
          conflictLines.add(DiffLine(
            leftNumber: lNum,
            rightNumber: rNum,
            leftText: lText,
            rightText: rText,
            status: DiffLineStatus.changed,
          ));
        } else if (lText.isNotEmpty) {
          conflictLines.add(DiffLine(
            leftNumber: lNum,
            rightNumber: null,
            leftText: lText,
            rightText: '',
            status: DiffLineStatus.conflictLeft,
          ));
        } else if (rText.isNotEmpty) {
          conflictLines.add(DiffLine(
            leftNumber: null,
            rightNumber: rNum,
            leftText: '',
            rightText: rText,
            status: DiffLineStatus.conflictRight,
          ));
        }
      }

      // End marker line.
      conflictLines.add(DiffLine(
        leftNumber: null,
        rightNumber: null,
        leftText: 'Conflict end',
        rightText: 'Conflict end',
        status: DiffLineStatus.conflictEnd,
      ));

      final int oldStart = start + 1;
      final int newStart = start + 1;
      final int oldCount = conflictLines.length;
      final int newCount = conflictLines.length;

      conflictHunks.add(CodeHunk(
        filePath: path,
        oldStart: oldStart,
        oldCount: oldCount,
        newStart: newStart,
        newCount: newCount,
        leftText: lines.sublist(oldStart - 1, oldStart - 1 + oldCount).join('\n'),
        rightText: lines.sublist(newStart - 1, newStart - 1 + newCount).join('\n'),
        lines: conflictLines,
        hasConflict: true,
      ));
      logVerbose('[conflict] Detected conflict in $path lines ${start + 1}-${end + 1}');

      rangesByFile.putIfAbsent(path, () => <_ConflictRange>[]).add(
            _ConflictRange(oldStart, oldStart + oldCount - 1),
          );

      idx = end + 1;
    }
  }

  return _ConflictBundle(conflictHunks, rangesByFile);
}
