import 'package:chunkdiff_core/chunkdiff_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/app_settings.dart';
import 'services/git_service.dart';
import 'services/settings_repository.dart';

const bool kForceMockData = false;

const String kSampleDartCode = '''
import 'dart:math';

class ChunkDiffExample {
  final String name;

  const ChunkDiffExample(this.name);

  String greet() {
    return 'Hello, \$name from core!';
  }
}

String main() {
  final ChunkDiffExample example = ChunkDiffExample('Developer');
  return example.greet();
}
''';

final Provider<String> helloFromCoreProvider =
    Provider<String>((Ref ref) => helloFromCore());

final StateProvider<String> codeContentProvider =
    StateProvider<String>((Ref ref) => kSampleDartCode);

final Provider<SettingsRepository> settingsRepositoryProvider =
    Provider<SettingsRepository>((Ref ref) => SettingsRepository());

final Provider<GitService> gitServiceProvider =
    Provider<GitService>((Ref ref) => const GitService());

class SettingsController extends AutoDisposeAsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() async {
    final SettingsRepository repo = ref.read(settingsRepositoryProvider);
    return repo.load();
  }

  Future<void> setGitFolder(String path) async {
    final SettingsRepository repo = ref.read(settingsRepositoryProvider);
    final AppSettings next = (state.value ?? const AppSettings())
        .copyWith(gitFolder: path);
    await repo.save(next);
    state = AsyncData(next);
    ref.invalidate(repoValidationProvider);
  }

  Future<void> setSelectedChunkIndex(int index) async {
    final SettingsRepository repo = ref.read(settingsRepositoryProvider);
    final AppSettings next = (state.value ?? const AppSettings())
        .copyWith(selectedChunkIndex: index);
    await repo.save(next);
    state = AsyncData(next);
  }
}

final AutoDisposeAsyncNotifierProvider<SettingsController, AppSettings>
    settingsControllerProvider =
    AutoDisposeAsyncNotifierProvider<SettingsController, AppSettings>(
        SettingsController.new);

final FutureProvider<GitValidationResult> repoValidationProvider =
    FutureProvider<GitValidationResult>((Ref ref) async {
  final AppSettings settings =
      await ref.watch(settingsControllerProvider.future);
  final String? path = settings.gitFolder;
  if (kForceMockData) {
    return const GitValidationResult(
      isRepo: false,
      message: 'Mock mode (git disabled)',
    );
  }
  if (path == null || path.isEmpty) {
    return const GitValidationResult(
      isRepo: false,
      message: 'No Git folder selected',
    );
  }
  final GitService git = ref.read(gitServiceProvider);
  return git.validateRepo(path);
});

final StateProvider<int> selectedChangeIndexProvider =
    StateProvider<int>((Ref ref) {
  final AsyncValue<AppSettings> settings = ref.watch(settingsControllerProvider);
  return settings.maybeWhen(
    data: (AppSettings s) => s.selectedChunkIndex,
    orElse: () => 0,
  );
});

final Provider<SymbolChange?> selectedChangeProvider =
    Provider<SymbolChange?>((Ref ref) {
  final List<SymbolChange> changes = ref.watch(symbolChangesProvider);
  final int index = ref.watch(selectedChangeIndexProvider);
  if (index < 0 || index >= changes.length) {
    return null;
  }
  return changes[index];
});

const List<String> kStubRefs = <String>['HEAD', 'HEAD~1', 'main'];

final FutureProvider<List<String>> refOptionsProvider =
    FutureProvider<List<String>>((Ref ref) async {
  if (kForceMockData) {
    return <String>{...kStubRefs, kWorktreeRef}.toList();
  }
  final AppSettings settings =
      await ref.watch(settingsControllerProvider.future);
  final String? path = settings.gitFolder;
  if (path == null || path.isEmpty) {
    return <String>{...kStubRefs, kWorktreeRef}.toList();
  }
  try {
    final List<String> refs = await listGitRefs(path);
    if (refs.isNotEmpty) {
      return <String>{...refs, kWorktreeRef}.toList();
    }
  } catch (_) {
    // fall back to stub refs
  }
  return <String>{...kStubRefs, kWorktreeRef}.toList();
});

final StateProvider<String> leftRefProvider =
    StateProvider<String>((Ref ref) => 'HEAD');

final StateProvider<String> rightRefProvider =
    StateProvider<String>((Ref ref) => kWorktreeRef);

final FutureProvider<bool> gitAccessProvider =
    FutureProvider<bool>((Ref ref) async {
  if (kForceMockData) {
    return false;
  }
  final AppSettings settings =
      await ref.watch(settingsControllerProvider.future);
  final String? path = settings.gitFolder;
  if (path == null || path.isEmpty) {
    return false;
  }
  try {
    final bool repoOk = await isGitRepo(path);
    if (!repoOk) {
      return false;
    }
    final List<String> refs = await listGitRefs(path);
    return refs.isNotEmpty;
  } catch (_) {
    return false;
  }
});

final FutureProvider<List<SymbolDiff>> symbolDiffsProvider =
    FutureProvider<List<SymbolDiff>>((Ref ref) async {
  if (kForceMockData) {
    return dummySymbolDiffs();
  }
  final AppSettings settings =
      await ref.watch(settingsControllerProvider.future);
  final String? repo = settings.gitFolder;
  final String left = ref.watch(leftRefProvider);
  final String right = ref.watch(rightRefProvider);
  if (repo == null || repo.isEmpty) {
    return <SymbolDiff>[];
  }
  try {
    final List<SymbolDiff> diffs = await loadSymbolDiffs(repo, left, right);
    return diffs;
  } catch (_) {
    return <SymbolDiff>[];
  }
});

final FutureProvider<List<CodeChunk>> chunkDiffsProvider =
    FutureProvider<List<CodeChunk>>((Ref ref) async {
  if (kForceMockData) {
    return dummyCodeChunks();
  }
  final AppSettings settings =
      await ref.watch(settingsControllerProvider.future);
  final String? repo = settings.gitFolder;
  final String left = ref.watch(leftRefProvider);
  final String right = ref.watch(rightRefProvider);
  if (repo == null || repo.isEmpty) {
    return <CodeChunk>[];
  }
  try {
    return await loadChunkDiffs(repo, left, right);
  } catch (_) {
    return <CodeChunk>[];
  }
});

final FutureProvider<List<CodeHunk>> hunkDiffsProvider =
    FutureProvider<List<CodeHunk>>((Ref ref) async {
  if (kForceMockData) {
    return dummyCodeHunks();
  }
  final AppSettings settings =
      await ref.watch(settingsControllerProvider.future);
  final String? repo = settings.gitFolder;
  final String left = ref.watch(leftRefProvider);
  final String right = ref.watch(rightRefProvider);
  if (repo == null || repo.isEmpty) {
    return <CodeHunk>[];
  }
  try {
    return await loadHunkDiffs(repo, left, right);
  } catch (_) {
    return <CodeHunk>[];
  }
});

final Provider<List<SymbolChange>> symbolChangesProvider =
    Provider<List<SymbolChange>>((Ref ref) {
  final AsyncValue<List<SymbolDiff>> diffs = ref.watch(symbolDiffsProvider);
  return diffs.maybeWhen(
    data: (List<SymbolDiff> d) => d.map((SymbolDiff s) => s.change).toList(),
    orElse: () => kForceMockData
        ? dummySymbolDiffs().map((SymbolDiff s) => s.change).toList()
        : <SymbolChange>[],
  );
});

final Provider<SymbolDiff?> selectedDiffProvider =
    Provider<SymbolDiff?>((Ref ref) {
  final AsyncValue<List<SymbolDiff>> asyncDiffs = ref.watch(symbolDiffsProvider);
  final int index = ref.watch(selectedChangeIndexProvider);
  return asyncDiffs.maybeWhen(
    data: (List<SymbolDiff> diffs) {
      if (index >= 0 && index < diffs.length) {
        return diffs[index];
      }
      return null;
    },
    orElse: () {
      if (kForceMockData) {
        final List<SymbolDiff> fallback = dummySymbolDiffs();
        if (index >= 0 && index < fallback.length) {
          return fallback[index];
        }
      }
      return null;
    },
  );
});

enum ChangesTab { files, hunks, chunks }

final StateProvider<ChangesTab> changesTabProvider =
    StateProvider<ChangesTab>((Ref ref) => ChangesTab.hunks);

final StateProvider<int> selectedChunkIndexProvider =
    StateProvider<int>((Ref ref) {
  final AsyncValue<AppSettings> settings = ref.watch(settingsControllerProvider);
  return settings.maybeWhen(
    data: (AppSettings s) => s.selectedChunkIndex,
    orElse: () => 0,
  );
});
