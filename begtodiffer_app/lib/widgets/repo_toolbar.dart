import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_settings.dart';
import '../providers.dart';
import '../services/git_service.dart';

class RepoToolbar extends ConsumerStatefulWidget {
  const RepoToolbar({super.key});

  @override
  ConsumerState<RepoToolbar> createState() => _RepoToolbarState();
}

class _RepoToolbarState extends ConsumerState<RepoToolbar> {
  final TextEditingController _manualPathController = TextEditingController();

  @override
  void dispose() {
    _manualPathController.dispose();
    super.dispose();
  }

  Future<void> _selectFolder(BuildContext context) async {
    debugPrint(
        '[RepoToolbar] Open folder clicked. Platform: ${defaultTargetPlatform.toString()}');
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final String? initialDirectory = ref.read(settingsControllerProvider).maybeWhen(
          data: (AppSettings data) => data.gitFolder,
          orElse: () => null,
        );
    messenger.showSnackBar(
      const SnackBar(content: Text('Opening folder picker...')),
    );
    try {
      final String? directoryPath =
          await getDirectoryPath(initialDirectory: initialDirectory);
      debugPrint('[RepoToolbar] getDirectoryPath result: $directoryPath');
      if (directoryPath != null) {
        await ref
            .read(settingsControllerProvider.notifier)
            .setGitFolder(directoryPath);
        _manualPathController
          ..text = directoryPath
          ..selection = TextSelection.collapsed(
              offset: _manualPathController.text.length);
        debugPrint('[RepoToolbar] Saved git folder: $directoryPath');
        messenger.showSnackBar(
          SnackBar(content: Text('Git folder saved: $directoryPath')),
        );
      } else {
        debugPrint('[RepoToolbar] Folder selection cancelled');
      }
    } catch (e, st) {
      debugPrint('[RepoToolbar] Folder selection error: $e\n$st');
      messenger.showSnackBar(
        SnackBar(content: Text('Folder picker error: $e')),
      );
    }
  }

  Future<void> _applyManualPath(BuildContext context) async {
    final String path = _manualPathController.text.trim();
    if (path.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a path first')),
      );
      return;
    }
    await ref.read(settingsControllerProvider.notifier).setGitFolder(path);
    _manualPathController.selection =
        TextSelection.collapsed(offset: _manualPathController.text.length);
    debugPrint('[RepoToolbar] Manual git folder saved: $path');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Git folder saved: $path')),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<AppSettings>>(settingsControllerProvider,
        (AsyncValue<AppSettings>? _, AsyncValue<AppSettings> next) {
      next.whenData((AppSettings data) {
        final String? path = data.gitFolder;
        if (path != null &&
            path.isNotEmpty &&
            _manualPathController.text != path) {
          _manualPathController
            ..text = path
            ..selection = TextSelection.collapsed(
                offset: _manualPathController.text.length);
        }
      });
    });

    final AsyncValue<AppSettings> settings = ref.watch(settingsControllerProvider);
    final AsyncValue<GitValidationResult> validation =
        ref.watch(repoValidationProvider);
    final AsyncValue<List<String>> refOptions = ref.watch(refOptionsProvider);
    final String leftRef = ref.watch(leftRefProvider);
    final String rightRef = ref.watch(rightRefProvider);

    return Row(
      children: [
        ElevatedButton.icon(
          onPressed: () => _selectFolder(context),
          icon: const Icon(Icons.folder_open),
          label: const Text('Open folder...'),
        ),
        const SizedBox(width: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: TextField(
            controller: _manualPathController,
            decoration: const InputDecoration(
              labelText: 'Git folder',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            textInputAction: TextInputAction.done,
            scrollPhysics: const AlwaysScrollableScrollPhysics(),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: () => _applyManualPath(context),
          child: const Text('Use path'),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 160,
          child: refOptions.when(
            data: (List<String> refs) {
              final List<String> distinct = refs.toSet().toList();
              final String? value =
                  distinct.contains(leftRef) ? leftRef : (distinct.isNotEmpty ? distinct.first : null);
              return DropdownButtonFormField<String>(
                value: value,
                decoration: const InputDecoration(
                  labelText: 'Left ref',
                  isDense: true,
                ),
                items: distinct
                    .map((String refItem) => DropdownMenuItem<String>(
                          value: refItem,
                          child: Text(refItem),
                        ))
                    .toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    ref.read(leftRefProvider.notifier).state = newValue;
                  }
                },
              );
            },
            loading: () => const Center(
              child: SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (_, __) => DropdownButtonFormField<String>(
              value: leftRef,
              decoration: const InputDecoration(
                labelText: 'Left ref',
                isDense: true,
              ),
              items: const [],
              onChanged: null,
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 160,
          child: refOptions.when(
            data: (List<String> refs) {
              final List<String> distinct = refs.toSet().toList();
              final String? value =
                  distinct.contains(rightRef) ? rightRef : (distinct.isNotEmpty ? distinct.first : null);
              return DropdownButtonFormField<String>(
                value: value,
                decoration: const InputDecoration(
                  labelText: 'Right ref',
                  isDense: true,
                ),
                items: distinct
                    .map((String refItem) => DropdownMenuItem<String>(
                          value: refItem,
                          child: Text(refItem),
                        ))
                    .toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    ref.read(rightRefProvider.notifier).state = newValue;
                  }
                },
              );
            },
            loading: () => const Center(
              child: SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (_, __) => DropdownButtonFormField<String>(
              value: rightRef,
              decoration: const InputDecoration(
                labelText: 'Right ref',
                isDense: true,
              ),
              items: const [],
              onChanged: null,
            ),
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: () => _refreshAll(ref),
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh'),
        ),
      ],
    );
  }

  void _refreshAll(WidgetRef ref) {
    ref.read(selectedChangeIndexProvider.notifier).state = 0;
    ref.read(selectedChunkIndexProvider.notifier).state = 0;
    ref.invalidate(repoValidationProvider);
    ref.invalidate(refOptionsProvider);
    ref.invalidate(symbolDiffsProvider);
    ref.invalidate(gitAccessProvider);
    ref.invalidate(hunkDiffsProvider);
    ref.invalidate(chunkDiffsProvider);
  }
}
