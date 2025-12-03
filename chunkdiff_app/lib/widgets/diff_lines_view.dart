import 'package:flutter/material.dart';

import 'package:chunkdiff_core/chunkdiff_core.dart';

/// Reusable, per-line diff renderer used by both Hunks and Chunks.
class DiffLinesView extends StatelessWidget {
  const DiffLinesView({
    super.key,
    required this.lines,
    this.header,
    this.subtitle,
    this.scrollable = true,
  });

  final List<DiffLine> lines;
  final String? header;
  final String? subtitle;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) {
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

    final Widget? headerWidget = header == null
        ? null
        : Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    header!,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.grey[400]),
                  ),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      subtitle!,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.grey[500]),
                    ),
                  ),
              ],
            ),
          );

    if (scrollable) {
      return ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: lines.length + (headerWidget == null ? 0 : 1),
        itemBuilder: (BuildContext context, int index) {
          if (headerWidget != null && index == 0) {
            return headerWidget;
          }
          final int lineIndex = headerWidget == null ? index : index - 1;
          return _DiffLineRow(line: lines[lineIndex]);
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (headerWidget != null) headerWidget,
        ListView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: lines.length,
          itemBuilder: (BuildContext context, int index) {
            return _DiffLineRow(line: lines[index]);
          },
        ),
      ],
    );
  }
}

class _DiffLineRow extends StatelessWidget {
  const _DiffLineRow({required this.line});

  final DiffLine line;

  Color _bgLeft() {
    switch (line.status) {
      case DiffLineStatus.removed:
        return const Color(0xFF3b1f1f);
      case DiffLineStatus.changed:
        return const Color(0xFF2f2424);
      default:
        return Colors.transparent;
    }
  }

  Color _bgRight() {
    switch (line.status) {
      case DiffLineStatus.added:
        return const Color(0xFF1f3b1f);
      case DiffLineStatus.changed:
        return const Color(0xFF243b24);
      default:
        return Colors.transparent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextStyle textStyle = const TextStyle(
      fontFamily: 'SourceCodePro',
      fontSize: 13,
      color: Colors.white,
    );
    final TextStyle numberStyle = TextStyle(
      fontFamily: 'SourceCodePro',
      fontSize: 12,
      color: Colors.grey[500],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 48,
            child: Text(
              line.leftNumber?.toString() ?? '',
              textAlign: TextAlign.right,
              style: numberStyle,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: _bgLeft(),
                borderRadius: BorderRadius.circular(6),
              ),
              padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 6),
              child: SelectableText(
                line.leftText,
                style: textStyle,
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 48,
            child: Text(
              line.rightNumber?.toString() ?? '',
              textAlign: TextAlign.right,
              style: numberStyle,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: _bgRight(),
                borderRadius: BorderRadius.circular(6),
              ),
              padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 6),
              child: SelectableText(
                line.rightText,
                style: textStyle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
