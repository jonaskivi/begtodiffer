import 'package:code_text_field/code_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_highlight/themes/monokai-sublime.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:highlight/languages/dart.dart';

import 'package:chunkdiff_core/chunkdiff_core.dart';
import '../providers.dart';

class DiffView extends ConsumerStatefulWidget {
  const DiffView({super.key});

  @override
  ConsumerState<DiffView> createState() => _DiffViewState();
}

class _DiffViewState extends ConsumerState<DiffView>
    with SingleTickerProviderStateMixin {
  late final CodeController _leftController;
  late final CodeController _rightController;
  late final AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    final SymbolDiff? initialDiff = ref.read(selectedDiffProvider);
    final String initialLeft = initialDiff?.leftSnippet ?? '';
    final String initialRight = initialDiff?.rightSnippet ?? '';
    _leftController = CodeController(
      text: initialLeft,
      language: dart,
    );
    _rightController = CodeController(
      text: initialRight,
      language: dart,
    );
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _leftController.dispose();
    _rightController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<SymbolDiff>> asyncDiffs =
        ref.watch(symbolDiffsProvider);
    final AsyncValue<List<CodeChunk>> asyncChunks =
        ref.watch(chunkDiffsProvider);
    final SymbolDiff? diff = ref.watch(selectedDiffProvider);
    final String left = _sanitizeText(diff?.leftSnippet ?? _leftController.text);
    final String right =
        _sanitizeText(diff?.rightSnippet ?? _rightController.text);
    if (_leftController.text != left) {
      _leftController.text = left;
    }
    if (_rightController.text != right) {
      _rightController.text = right;
    }

    final List<SymbolChange> changes = ref.watch(symbolChangesProvider);
    final int selectedIndex = ref.watch(selectedChangeIndexProvider);
    final String leftRef = ref.watch(leftRefProvider);
    final String rightRef = ref.watch(rightRefProvider);
    final SymbolChange? selectedChange = ref.watch(selectedChangeProvider);
    final bool hasChunkData =
        asyncChunks.hasValue && (asyncChunks.value?.isNotEmpty ?? false);
    final bool isLoading = (asyncDiffs.isLoading || asyncChunks.isLoading) &&
        !hasChunkData &&
        changes.isEmpty;
    final bool hasChanges = (changes.isNotEmpty && !isLoading) || hasChunkData;
    final ChangesTab activeTab = ref.watch(changesTabProvider);
    final int selectedChunkIndex = ref.watch(selectedChunkIndexProvider);
    final SymbolChange? selectedFileChange =
        activeTab == ChangesTab.files ? selectedChange : null;

    return Row(
      children: [
        SizedBox(
          width: 260,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TabSwitcher(
                activeTab: activeTab,
                onChanged: (ChangesTab tab) =>
                    ref.read(changesTabProvider.notifier).state = tab,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: isLoading
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          _SkeletonListItem(animation: _shimmerController),
                          const SizedBox(height: 12),
                          _SkeletonListItem(animation: _shimmerController),
                          const SizedBox(height: 12),
                          _SkeletonListItem(animation: _shimmerController),
                        ],
                      )
                        : hasChanges
                        ? (activeTab == ChangesTab.files
                            ? ListView.separated(
                                itemCount: changes.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (BuildContext _, int index) {
                                  final SymbolChange change = changes[index];
                                  final bool selected = index == selectedIndex;
                                  return ListTile(
                                    dense: true,
                                    selected: selected,
                                    title: Text(
                                      change.name,
                                      style: TextStyle(
                                        fontWeight: selected
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                      ),
                                    ),
                                    subtitle: Text(
                                      change.kind.name,
                                      style: TextStyle(
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                    onTap: () => ref
                                        .read(selectedChangeIndexProvider
                                            .notifier)
                                        .state = index,
                                  );
                                },
                              )
                            : _ChunkList(
                                asyncChunks: asyncChunks,
                                selectedChunkIndex: selectedChunkIndex,
                                onSelect: (int idx) {
                                  ref
                                      .read(selectedChunkIndexProvider.notifier)
                                      .state = idx;
                                  ref
                                      .read(
                                          settingsControllerProvider.notifier)
                                      .setSelectedChunkIndex(idx);
                                },
                              ))
                        : Center(
                            child: Text(
                              'No changes for $leftRef → $rightRef',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: Colors.grey[400]),
                              textAlign: TextAlign.center,
                            ),
                          ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            children: [
              _DiffMetaBar(
                change: selectedChange,
                leftRef: leftRef,
                rightRef: rightRef,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: isLoading
                    ? Row(
                        children: [
                          Expanded(
                            child: _SkeletonPane(
                              animation: _shimmerController,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _SkeletonPane(
                              animation: _shimmerController,
                            ),
                          ),
                        ],
                      )
                    : _ChunkDiffView(
                        asyncChunks: asyncChunks,
                        selectedChunkIndex: selectedChunkIndex,
                        selectedFileChange: selectedChange,
                        activeTab: activeTab,
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DiffMetaBar extends StatelessWidget {
  const _DiffMetaBar({
    required this.change,
    required this.leftRef,
    required this.rightRef,
    this.alignEnd = false,
  });

  final SymbolChange? change;
  final String leftRef;
  final String rightRef;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final TextStyle labelStyle =
        Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[400]) ??
            const TextStyle(fontSize: 12, color: Colors.grey);
    final TextStyle valueStyle =
        Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600) ??
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w600);

    return Row(
      mainAxisAlignment:
          alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        if (change != null) ...[
          Text('Symbol: ', style: labelStyle),
          Text(change!.name, style: valueStyle),
          const SizedBox(width: 12),
          Text('Kind: ', style: labelStyle),
          Text(change!.kind.name, style: valueStyle),
          const SizedBox(width: 12),
        ],
        Text('Left: ', style: labelStyle),
        Text(leftRef, style: valueStyle),
        const SizedBox(width: 8),
        Text('Right: ', style: labelStyle),
        Text(rightRef, style: valueStyle),
      ],
    );
  }
}

class _DiffPane extends StatelessWidget {
  const _DiffPane({
    required this.text,
    required this.backgroundColor,
  });

  final String text;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: SizedBox(
              height: 240,
              child: SingleChildScrollView(
                child: SelectableText(
                  text,
                  style: const TextStyle(
                    fontFamily: 'SourceCodePro',
                    fontSize: 13,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SkeletonPane extends StatelessWidget {
  const _SkeletonPane({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SkeletonBox(
        height: double.infinity,
        animation: animation,
      ),
    );
  }
}

class _TabSwitcher extends StatelessWidget {
  const _TabSwitcher({
    required this.activeTab,
    required this.onChanged,
  });

  final ChangesTab activeTab;
  final ValueChanged<ChangesTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        _TabChip(
          label: 'Files',
          selected: activeTab == ChangesTab.files,
          onTap: () => onChanged(ChangesTab.files),
        ),
        _TabChip(
          label: 'Chunks',
          selected: activeTab == ChangesTab.chunks,
          onTap: () => onChanged(ChangesTab.chunks),
        ),
      ],
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: Colors.indigo.withOpacity(0.2),
      labelStyle: TextStyle(
        color: selected ? Colors.indigo[100] : Colors.grey[300],
        fontWeight: FontWeight.w600,
      ),
      backgroundColor: Colors.grey.shade900,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}

class _ChunkList extends StatelessWidget {
  const _ChunkList({
    required this.asyncChunks,
    required this.selectedChunkIndex,
    required this.onSelect,
  });

  final AsyncValue<List<CodeChunk>> asyncChunks;
  final int selectedChunkIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final List<CodeChunk> chunks =
        asyncChunks.value ?? const <CodeChunk>[];

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

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: chunks.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (BuildContext context, int index) {
        final CodeChunk chunk = chunks[index];
        final bool selected = index == selectedChunkIndex;
        return ListTile(
          dense: true,
          selected: selected,
          title: Text(chunk.filePath),
          subtitle: Text('Old ${chunk.oldStart}-${chunk.oldEnd} → '
              'New ${chunk.newStart}-${chunk.newEnd}'),
          onTap: () => onSelect(index),
        );
      },
    );
  }
}

class _ChunkDiffView extends StatelessWidget {
  const _ChunkDiffView({
    required this.asyncChunks,
    required this.selectedChunkIndex,
    required this.selectedFileChange,
    required this.activeTab,
  });

  final AsyncValue<List<CodeChunk>> asyncChunks;
  final int selectedChunkIndex;
  final SymbolChange? selectedFileChange;
  final ChangesTab activeTab;

  @override
  Widget build(BuildContext context) {
    final List<CodeChunk> all = asyncChunks.value ?? const <CodeChunk>[];
    if (all.isEmpty) {
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
    if (activeTab == ChangesTab.chunks) {
      final int clampedIndex = selectedChunkIndex.clamp(0, all.length - 1);
      final CodeChunk chunk = all[clampedIndex];
      final String leftText = _sanitizeText(chunk.leftText);
      final String rightText = _sanitizeText(chunk.rightText);
      return Row(
        children: [
          Expanded(
            child: _DiffPane(
              text: leftText,
              backgroundColor: const Color(0xFF272822),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _DiffPane(
              text: rightText,
              backgroundColor: const Color(0xFF272822),
            ),
          ),
        ],
      );
    }

    final String? targetFile =
        selectedFileChange?.beforePath ?? selectedFileChange?.afterPath;
    final List<CodeChunk> filtered = targetFile == null
        ? all
        : all.where((CodeChunk c) => c.filePath == targetFile).toList();
    if (filtered.isEmpty) {
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

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (BuildContext context, int index) {
        final CodeChunk chunk = filtered[index];
        final String leftText = _sanitizeText(chunk.leftText);
        final String rightText = _sanitizeText(chunk.rightText);
        return Row(
          children: [
            Expanded(
              child: _DiffPane(
                text: leftText,
                backgroundColor: const Color(0xFF272822),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _DiffPane(
                text: rightText,
                backgroundColor: const Color(0xFF272822),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SkeletonListItem extends StatelessWidget {
  const _SkeletonListItem({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, _) {
        return SizedBox(
          height: 80,
          child: Row(
            children: [
              Expanded(
                child: SkeletonBox(
                  height: 70,
                  animation: animation,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    required this.height,
    required this.animation,
    this.width,
    this.borderRadius = const BorderRadius.all(Radius.circular(10)),
  });

  final double height;
  final double? width;
  final BorderRadius borderRadius;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final Color baseColor = Colors.grey.shade800;
    final Color highlightColor = Colors.grey.shade700;
    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, _) {
        final double t = animation.value;
        final double dx = (t * 2.0) - 1.0; // -1 to 1
        return Container(
          height: height,
          width: width,
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            gradient: LinearGradient(
              begin: Alignment(dx, 0),
              end: Alignment(dx + 1, 0),
              colors: <Color>[
                baseColor,
                highlightColor,
                baseColor,
              ],
              stops: const <double>[0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

String _sanitizeText(String input) {
  final StringBuffer buffer = StringBuffer();
  for (final int rune in input.runes) {
    if (rune >= 0 && rune <= 0x10FFFF) {
      buffer.writeCharCode(rune);
    }
  }
  return buffer.toString();
}
