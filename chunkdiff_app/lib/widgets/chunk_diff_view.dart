import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chunkdiff_core/chunkdiff_core.dart';
import 'diff_lines_view.dart';
import 'package:path/path.dart' as p;

class ChunkDiffView extends StatelessWidget {
  const ChunkDiffView({
    super.key,
    required this.asyncChunks,
    required this.selectedIndex,
    this.controller,
  });

  final AsyncValue<List<CodeChunk>> asyncChunks;
  final int selectedIndex;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final List<CodeChunk> chunks = asyncChunks.value ?? const <CodeChunk>[];
    if (chunks.isEmpty) {
      return Center(
        child: Text(
          'No diff content to display.',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: Colors.grey[400]),
        ),
      );
    }
    final int clamped = selectedIndex.clamp(0, chunks.length - 1);
    final CodeChunk chunk = chunks[clamped];
    final String shortLeft = p.basename(chunk.filePath);
    final String shortRight = p.basename(chunk.rightFilePath);
    final bool moved = chunk.filePath != chunk.rightFilePath;
    final String header = moved
        ? '#${chunk.id} • ${chunk.name} • ${chunk.filePath} → ${chunk.rightFilePath}'
        : '#${chunk.id} • ${chunk.name} • ${chunk.filePath} (lines ${chunk.oldStart}-${chunk.oldEnd})';
    return DiffLinesView(
      lines: chunk.lines,
      header: header,
      subtitle: chunk.ignored
          ? 'Ignored'
          : moved
              ? 'Moved'
              : null,
      leftLabel: '#${chunk.id} • $shortLeft',
      rightLabel: '#${chunk.id} • $shortRight',
      scrollable: true,
      controller: controller,
    );
  }
}
