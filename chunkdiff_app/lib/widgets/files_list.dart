import 'package:flutter/material.dart';
import 'package:chunkdiff_core/chunkdiff_core.dart';

class FilesList extends StatelessWidget {
  const FilesList({
    super.key,
    required this.changes,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<SymbolChange> changes;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
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
    return ListView.separated(
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
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          subtitle: Text(
            change.kind.name,
            style: TextStyle(
              color: Colors.grey[700],
            ),
          ),
          onTap: () => onSelect(index),
        );
      },
    );
  }
}
