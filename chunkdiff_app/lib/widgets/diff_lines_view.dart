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
    this.leftLabel,
    this.rightLabel,
  });

  final List<DiffLine> lines;
  final String? header;
  final String? subtitle;
  final bool scrollable;
  final String? leftLabel;
  final String? rightLabel;

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

    final Widget? labelsRow =
        leftLabel == null && rightLabel == null ? null : _SideLabels(
          leftLabel: leftLabel,
          rightLabel: rightLabel,
        );

    if (scrollable) {
      return ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: lines.length +
            (headerWidget == null ? 0 : 1) +
            (labelsRow == null ? 0 : 1),
        itemBuilder: (BuildContext context, int index) {
          int offset = 0;
          if (headerWidget != null && index == offset) {
            return headerWidget;
          }
          if (headerWidget != null) offset++;
          if (labelsRow != null && index == offset) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: labelsRow,
            );
          }
          if (labelsRow != null) offset++;

          final int lineIndex = index - offset;
          return _DiffLineRow(line: lines[lineIndex]);
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (headerWidget != null) headerWidget,
        if (labelsRow != null) ...[
          labelsRow,
          const SizedBox(height: 8),
        ],
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

class _SideLabels extends StatelessWidget {
  const _SideLabels({this.leftLabel, this.rightLabel});

  final String? leftLabel;
  final String? rightLabel;

  @override
  Widget build(BuildContext context) {
    final bool differ =
        leftLabel != null && rightLabel != null && leftLabel != rightLabel;
    final Color leftBg = differ ? const Color(0xFF3b1f1f) : Colors.transparent;
    final Color rightBg = differ ? const Color(0xFF1f3b1f) : Colors.transparent;
    final TextStyle style = const TextStyle(
      fontFamily: 'SourceCodePro',
      fontSize: 12,
      color: Colors.white,
    );
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
            decoration: BoxDecoration(
              color: leftBg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(leftLabel ?? '', style: style, overflow: TextOverflow.ellipsis),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
            decoration: BoxDecoration(
              color: rightBg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(rightLabel ?? '', style: style, overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
    );
  }
}

class _DiffLineRow extends StatefulWidget {
  const _DiffLineRow({required this.line});

  final DiffLine line;

  @override
  State<_DiffLineRow> createState() => _DiffLineRowState();
}

class _DiffLineRowState extends State<_DiffLineRow> {
  bool _hovered = false;

  Color _bgLeft() {
    switch (widget.line.status) {
      case DiffLineStatus.removed:
        return const Color(0xFF3b1f1f);
      case DiffLineStatus.changed:
        // Changed: cool tone on left
        return const Color(0xFF243248); // deep blue-gray
      case DiffLineStatus.conflictLeft:
        return const Color(0xFFb3006b); // vibrant pink for conflicts
      default:
        return Colors.transparent;
    }
  }

  Color _bgRight() {
    switch (widget.line.status) {
      case DiffLineStatus.added:
        return const Color(0xFF1f3b1f);
      case DiffLineStatus.changed:
        // Changed: warm tone on right
        return const Color(0xFF8a5c00); // vivid amber/orange, still dark enough for white text
      case DiffLineStatus.conflictRight:
        return const Color(0xFFb3006b); // vibrant pink for conflicts
      default:
        return Colors.transparent;
    }
  }

  Color _withHover(Color base) {
    if (!_hovered) return base;
    const Color highlight = Color(0x33FFFFFF);
    if (base == Colors.transparent) {
      return highlight;
    }
    return Color.alphaBlend(highlight, base);
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
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 48,
              child: Text(
                widget.line.leftNumber?.toString() ?? '',
                textAlign: TextAlign.right,
                style: numberStyle,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: _withHover(_bgLeft()),
                  borderRadius: BorderRadius.circular(6),
                ),
                padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 6),
                child: SelectableText(
                  widget.line.leftText,
                  style: textStyle,
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 48,
              child: Text(
                widget.line.rightNumber?.toString() ?? '',
                textAlign: TextAlign.right,
                style: numberStyle,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: _withHover(_bgRight()),
                  borderRadius: BorderRadius.circular(6),
                ),
                padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 6),
                child: SelectableText(
                  widget.line.rightText,
                  style: textStyle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
