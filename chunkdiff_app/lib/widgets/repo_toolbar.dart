import 'package:chunkdiff_app/models/app_settings.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    try {
      final String? directoryPath = await getDirectoryPath().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('[RepoToolbar] getDirectoryPath timed out');
          messenger.showSnackBar(
            const SnackBar(content: Text('Folder picker timed out')),
          );
          return null;
        },
      );
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

    final String repoPath = settings.maybeWhen(
      data: (AppSettings data) => data.gitFolder ?? 'No Git folder selected',
      orElse: () => 'Loading settings...',
    );

    final String statusText = validation.maybeWhen(
      data: (GitValidationResult result) => result.message ?? '',
      loading: () => 'Validating Git folder...',
      orElse: () => 'No Git folder selected',
    );

    final bool isRepo = validation.maybeWhen(
      data: (GitValidationResult result) => result.isRepo,
      orElse: () => false,
    );

    return Row(
      children: [
        ElevatedButton.icon(
          onPressed: () => _selectFolder(context),
          icon: const Icon(Icons.folder_open),
          label: const Text('Open folder...'),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                repoPath,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 4),
              Text(
                statusText,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isRepo ? Colors.green[700] : Colors.red[700],
                    ),
              ),
            ],
          ),
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
        OutlinedButton.icon(
          onPressed: () => ref.invalidate(repoValidationProvider),
          icon: const Icon(Icons.refresh),
          label: const Text('Re-validate'),
        ),
      ],
    );
  }
}
