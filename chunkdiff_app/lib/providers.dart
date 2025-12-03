import 'package:chunkdiff_core/chunkdiff_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/app_settings.dart';
import 'services/git_service.dart';
import 'services/settings_repository.dart';

class DiffTextPair {
  final String left;
  final String right;

  const DiffTextPair({required this.left, required this.right});
}

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

const Map<String, DiffTextPair> _sampleDiffs = <String, DiffTextPair>{
  'ChunkDiffExample.greet': DiffTextPair(
    left: '''
class ChunkDiffExample {
  String greet(String name) {
    return 'Hello, \$name from v1';
  }
}

void main() {
  final ChunkDiffExample example = ChunkDiffExample();
  print(example.greet('Developer'));
}
''',
    right: '''
class ChunkDiffExample {
  String greet(String name, {bool excited = false}) {
    final String base = 'Hello, \$name from v2';
    return excited ? '\$base!' : base;
  }
}

void main() {
  final ChunkDiffExample example = ChunkDiffExample();
  print(example.greet('Developer', excited: true));
}
''',
  ),
  'ChunkDiffExample': DiffTextPair(
    left: '''
class ChunkDiffExample {
  final String name;

  const ChunkDiffExample(this.name);
}
''',
    right: '''
class ChunkDiffExample {
  final String name;
  final int version;

  const ChunkDiffExample(this.name, {this.version = 2});
}
''',
  ),
  'main': DiffTextPair(
    left: '''
void main() {
  final ChunkDiffExample example = ChunkDiffExample('Developer');
  print(example.name);
}
''',
    right: '''
void main() {
  final ChunkDiffExample example = ChunkDiffExample('Developer', version: 2);
  print('\${example.name} v\${example.version}');
}
''',
  ),
};

final Provider<DiffTextPair> selectedDiffTextProvider =
    Provider<DiffTextPair>((Ref ref) {
  final SymbolChange? change = ref.watch(selectedChangeProvider);
  if (change == null) {
    return const DiffTextPair(left: kSampleDartCode, right: kSampleDartCode);
  }
  final DiffTextPair? pair = _sampleDiffs[change.name];
  if (pair != null) {
    return pair;
  }
  return const DiffTextPair(left: kSampleDartCode, right: kSampleDartCode);
});
