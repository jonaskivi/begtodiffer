import 'package:flutter/material.dart';
import 'package:code_text_field/code_text_field.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:highlight/languages/dart.dart';

import '../providers.dart';

class CodeEditorPane extends ConsumerStatefulWidget {
  const CodeEditorPane({super.key});

  @override
  ConsumerState<CodeEditorPane> createState() => _CodeEditorPaneState();
}

class _CodeEditorPaneState extends ConsumerState<CodeEditorPane> {
  late final CodeController _controller;

  @override
  void initState() {
    super.initState();
    _controller = CodeController(
      text: ref.read(codeContentProvider),
      language: dart,
    );
    _controller.addListener(_handleTextChanged);
  }

  void _handleTextChanged() {
    ref.read(codeContentProvider.notifier).state = _controller.text;
  }

  @override
  void dispose() {
    _controller.removeListener(_handleTextChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: CodeTheme(
          data: CodeThemeData(styles: githubTheme),
          child: CodeField(
            controller: _controller,
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
    );
  }
}
