import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:begtodiffer_core/begtodiffer_core.dart';
import 'package:flutter/scheduler.dart';

class FilesList extends StatelessWidget {
  const FilesList({
    super.key,
    required this.changes,
    required this.selectedIndex,
    required this.onSelect,
    this.conflictFiles = const <String>{},
    this.focusNode,
    this.onArrowUp,
    this.onArrowDown,
    this.debugSearch = '',
  });

  final List<SymbolChange> changes;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final Set<String> conflictFiles;
  final FocusNode? focusNode;
  final VoidCallback? onArrowUp;
  final VoidCallback? onArrowDown;
  final String debugSearch;

  @override
  Widget build(BuildContext context) {
    // Keep focus after rebuilds (e.g., when data refreshes).
    if (focusNode?.hasFocus == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        focusNode?.requestFocus();
      });
    }

    if (changes.isEmpty) {
      return Center(
        child: Text(
          'No files to display.',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: Colors.grey[400]),
        ),
      );
    }
    return Focus(
      focusNode: focusNode,
      onKey: (FocusNode node, RawKeyEvent event) {
        if (event is! RawKeyDownEvent) return KeyEventResult.ignored;
        final LogicalKeyboardKey key = event.logicalKey;
        if (key == LogicalKeyboardKey.arrowUp) {
          onArrowUp?.call();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowDown) {
          onArrowDown?.call();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: ListView.separated(
        itemCount: changes.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (BuildContext _, int index) {
          final SymbolChange change = changes[index];
          final bool selected = index == selectedIndex;
          final bool debugHit = debugSearch.isNotEmpty &&
              (change.name.toLowerCase().contains(debugSearch.toLowerCase()) ||
                  (change.beforePath ?? '').toLowerCase().contains(debugSearch.toLowerCase()));
          final bool isNew = change.beforePath == null || (change.beforePath?.isEmpty ?? true);
          final bool isRemoved = change.afterPath == null || (change.afterPath?.isEmpty ?? true);
          final String keyPath = change.beforePath ?? change.afterPath ?? '';
          final bool hasConflict = conflictFiles.contains(keyPath);
          Widget? trailing;
          if (debugHit) {
            trailing = Chip(
              label: const Text('Debug'),
              visualDensity: VisualDensity.compact,
            );
          } else if (isNew) {
            trailing = Chip(
              label: const Text('New'),
              backgroundColor: Colors.green.shade800,
              labelStyle: const TextStyle(color: Colors.white),
              visualDensity: VisualDensity.compact,
            );
          } else if (isRemoved) {
            trailing = Chip(
              label: const Text('Removed'),
              backgroundColor: Colors.red.shade800,
              labelStyle: const TextStyle(color: Colors.white),
              visualDensity: VisualDensity.compact,
            );
          } else if (hasConflict) {
            trailing = Chip(
              label: const Text('Conflict'),
              backgroundColor: Colors.pink.shade600,
              labelStyle: const TextStyle(color: Colors.white),
              visualDensity: VisualDensity.compact,
            );
          }
          final Color tileColor = selected ? Colors.indigo.withOpacity(0.15) : Colors.transparent;
          final Color hoverColor = Colors.indigo.withOpacity(0.08);
          return Material(
            color: tileColor,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              hoverColor: hoverColor,
              onTap: () {
                focusNode?.requestFocus();
                onSelect(index);
              },
              child: ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                selected: selected,
                selectedTileColor: tileColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                title: Text(
                  change.name,
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                subtitle: Text(
                  change.kind.name,
                  style: TextStyle(
                    color: Colors.grey[700],
                  ),
                ),
                trailing: trailing,
              ),
            ),
          );
        },
      ),
    );
  }
}
