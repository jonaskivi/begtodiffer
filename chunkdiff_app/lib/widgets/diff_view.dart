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

class _DiffViewState extends ConsumerState<DiffView> {
  late final CodeController _leftController;
  late final CodeController _rightController;

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
  }

  @override
  void dispose() {
    _leftController.dispose();
    _rightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final SymbolDiff? diff = ref.watch(selectedDiffProvider);
    final String left = diff?.leftSnippet ?? _leftController.text;
    final String right = diff?.rightSnippet ?? _rightController.text;
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
    final bool hasChanges = changes.isNotEmpty;

    return Row(
      children: [
        SizedBox(
          width: 260,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Changes',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_upward),
                    tooltip: 'Previous change',
                    onPressed: hasChanges && selectedIndex > 0
                        ? () {
                            ref
                                .read(selectedChangeIndexProvider.notifier)
                                .state = selectedIndex - 1;
                          }
                        : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_downward),
                    tooltip: 'Next change',
                    onPressed: hasChanges && selectedIndex < changes.length - 1
                        ? () {
                            ref
                                .read(selectedChangeIndexProvider.notifier)
                                .state = selectedIndex + 1;
                          }
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: hasChanges
                    ? ListView.separated(
                        itemCount: changes.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
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
                                .read(selectedChangeIndexProvider.notifier)
                                .state = index,
                          );
                        },
                      )
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
                child: hasChanges
                    ? Row(
                        children: [
                          Expanded(
                            child: _DiffPane(
                              title: 'Left (old)',
                              controller: _leftController,
                              backgroundColor: const Color(0xFFFFF3F3),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _DiffPane(
                              title: 'Right (new)',
                              controller: _rightController,
                              backgroundColor: const Color(0xFFF2FFF4),
                            ),
                          ),
                        ],
                      )
                    : Center(
                        child: Text(
                          'No diff content to display.',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: Colors.grey[400]),
                        ),
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
    required this.title,
    required this.controller,
    required this.backgroundColor,
  });

  final String title;
  final CodeController controller;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 6),
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: CodeTheme(
                data: CodeThemeData(styles: monokaiSublimeTheme),
                child: CodeField(
                  controller: controller,
                  textStyle: const TextStyle(
                    fontFamily: 'SourceCodePro',
                    fontSize: 13,
                  ),
                  expands: true,
                  lineNumberStyle: const LineNumberStyle(
                    width: 40,
                    textStyle: TextStyle(color: Color(0xFF8A8A8A)),
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
