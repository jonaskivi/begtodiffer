import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chunkdiff_core/chunkdiff_core.dart';
import '../providers.dart';
import 'files_list.dart';

class DiffView extends ConsumerStatefulWidget {
  const DiffView({super.key});

  @override
  ConsumerState<DiffView> createState() => _DiffViewState();
}

class _DiffViewState extends ConsumerState<DiffView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<SymbolDiff>> asyncDiffs =
        ref.watch(symbolDiffsProvider);
    final AsyncValue<List<CodeHunk>> asyncHunks =
        ref.watch(hunkDiffsProvider);
    final List<SymbolChange> changes = ref.watch(symbolChangesProvider);
    final int selectedIndex = ref.watch(selectedChangeIndexProvider);
    final String leftRef = ref.watch(leftRefProvider);
    final String rightRef = ref.watch(rightRefProvider);
    final SymbolChange? selectedChange = ref.watch(selectedChangeProvider);
    final bool hasHunkData =
        asyncHunks.hasValue && (asyncHunks.value?.isNotEmpty ?? false);
    final bool isLoading = (asyncDiffs.isLoading || asyncHunks.isLoading) &&
        !hasHunkData &&
        changes.isEmpty;
    final bool hasChanges = (changes.isNotEmpty && !isLoading) || hasHunkData;
    final ChangesTab activeTab = ref.watch(changesTabProvider);
    final int selectedChunkIndex = ref.watch(selectedChunkIndexProvider);

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
                            ? FilesList(
                                changes: changes,
                                selectedIndex: selectedIndex,
                                onSelect: (int idx) => ref
                                    .read(
                                        selectedChangeIndexProvider.notifier)
                                    .state = idx,
                              )
                            : activeTab == ChangesTab.hunks
                                ? _HunkList(
                                    asyncHunks: asyncHunks,
                                    selectedIndex: selectedChunkIndex,
                                    onSelect: (int idx) {
                                      ref
                                          .read(selectedChunkIndexProvider
                                              .notifier)
                                          .state = idx;
                                      ref
                                          .read(settingsControllerProvider
                                              .notifier)
                                          .setSelectedChunkIndex(idx);
                                    },
                                  )
                                : const _ChunksPlaceholder())
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
                    : _HunkDiffView(
                        asyncHunks: asyncHunks,
                        selectedIndex: selectedChunkIndex,
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
          label: 'Hunks',
          selected: activeTab == ChangesTab.hunks,
          onTap: () => onChanged(ChangesTab.hunks),
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

class _HunkList extends StatelessWidget {
  const _HunkList({
    required this.asyncHunks,
    required this.selectedIndex,
    required this.onSelect,
  });

  final AsyncValue<List<CodeHunk>> asyncHunks;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final List<CodeHunk> chunks = asyncHunks.value ?? const <CodeHunk>[];

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
        final CodeHunk chunk = chunks[index];
        final bool selected = index == selectedIndex;
        return ListTile(
          dense: true,
          selected: selected,
          title: Text(chunk.filePath),
          subtitle: Text(
            'Old ${chunk.oldStart}-${chunk.oldStart + chunk.oldCount - 1} → '
            'New ${chunk.newStart}-${chunk.newStart + chunk.newCount - 1}',
          ),
          onTap: () => onSelect(index),
        );
      },
    );
  }
}

class _ChunksPlaceholder extends StatelessWidget {
  const _ChunksPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Chunks view coming soon.',
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: Colors.grey[400]),
      ),
    );
  }
}

class _HunkDiffView extends StatelessWidget {
  const _HunkDiffView({
    required this.asyncHunks,
    required this.selectedIndex,
    required this.selectedFileChange,
    required this.activeTab,
  });

  final AsyncValue<List<CodeHunk>> asyncHunks;
  final int selectedIndex;
  final SymbolChange? selectedFileChange;
  final ChangesTab activeTab;

  @override
  Widget build(BuildContext context) {
    final List<CodeHunk> all = asyncHunks.value ?? const <CodeHunk>[];
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

    if (activeTab == ChangesTab.hunks) {
      final int clampedIndex = selectedIndex.clamp(0, all.length - 1);
      final CodeHunk hunk = all[clampedIndex];
      return _buildPanePair(hunk.leftText, hunk.rightText);
    }

    if (activeTab == ChangesTab.files) {
      final String? targetFile =
          selectedFileChange?.beforePath ?? selectedFileChange?.afterPath;
      final List<CodeHunk> filtered = targetFile == null
          ? all
          : all.where((CodeHunk h) => h.filePath == targetFile).toList();
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
          final CodeHunk hunk = filtered[index];
          return _buildPanePair(hunk.leftText, hunk.rightText);
        },
      );
    }

    return const _ChunksPlaceholder();
  }

  Widget _buildPanePair(String left, String right) {
    final String leftText = _sanitizeText(left);
    final String rightText = _sanitizeText(right);
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
