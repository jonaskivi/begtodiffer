import 'package:chunkdiff_core/chunkdiff_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/app_settings.dart';
import 'services/git_service.dart';
import 'services/settings_repository.dart';

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
  if (path == null || path.isEmpty) {
    return const GitValidationResult(
      isRepo: false,
      message: 'No Git folder selected',
    );
  }
  final GitService git = ref.read(gitServiceProvider);
  return git.validateRepo(path);
});

final Provider<List<SymbolChange>> symbolChangesProvider =
    Provider<List<SymbolChange>>((Ref ref) => dummySymbolChanges());

final StateProvider<int> selectedChangeIndexProvider =
    StateProvider<int>((Ref ref) => 0);

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
  final AppSettings settings =
      await ref.watch(settingsControllerProvider.future);
  final String? path = settings.gitFolder;
  if (path == null || path.isEmpty) {
    return kStubRefs;
  }
  try {
    final List<String> refs = await listGitRefs(path);
    if (refs.isNotEmpty) {
      return refs;
    }
  } catch (_) {
    // fall back to stub refs
  }
  return kStubRefs;
});

final StateProvider<String> leftRefProvider =
    StateProvider<String>((Ref ref) => 'HEAD~1');

final StateProvider<String> rightRefProvider =
    StateProvider<String>((Ref ref) => 'HEAD');

final FutureProvider<bool> gitAccessProvider =
    FutureProvider<bool>((Ref ref) async {
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

final Provider<List<SymbolDiff>> symbolDiffsProvider =
    Provider<List<SymbolDiff>>((Ref ref) => dummySymbolDiffs());

final Provider<SymbolDiff?> selectedDiffProvider =
    Provider<SymbolDiff?>((Ref ref) {
  final SymbolChange? change = ref.watch(selectedChangeProvider);
  if (change == null) {
    return null;
  }
  final List<SymbolDiff> diffs = ref.watch(symbolDiffsProvider);
  return diffs.firstWhere(
    (SymbolDiff d) => d.change.name == change.name,
    orElse: () => SymbolDiff(
      change: change,
      leftSnippet: kSampleDartCode,
      rightSnippet: kSampleDartCode,
    ),
  );
});
