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
