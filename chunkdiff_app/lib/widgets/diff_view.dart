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
    final DiffTextPair initialPair = ref.read(selectedDiffTextProvider);
    _leftController = CodeController(
      text: initialPair.left,
      language: dart,
    );
    _rightController = CodeController(
      text: initialPair.right,
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
    final DiffTextPair pair = ref.watch(selectedDiffTextProvider);
    if (_leftController.text != pair.left) {
      _leftController.text = pair.left;
    }
    if (_rightController.text != pair.right) {
      _rightController.text = pair.right;
    }

    final List<SymbolChange> changes = ref.watch(symbolChangesProvider);
    final int selectedIndex = ref.watch(selectedChangeIndexProvider);

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
                    onPressed: selectedIndex > 0
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
                    onPressed: selectedIndex < changes.length - 1
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
                child: ListView.separated(
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
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w400,
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
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: _DiffPane(
                  title: 'Left (old)',
                  controller: _leftController,
                  backgroundColor: const Color(0xFFFFF3F3),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: _DiffPane(
                  title: 'Right (new)',
                  controller: _rightController,
                  backgroundColor: const Color(0xFFF2FFF4),
                ),
              ),
            ],
          ),
        ),
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
