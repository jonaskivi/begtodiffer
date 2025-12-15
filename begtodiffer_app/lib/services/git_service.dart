import 'dart:io';

class GitValidationResult {
  final bool isRepo;
  final String? message;

  const GitValidationResult({
    required this.isRepo,
    this.message,
  });

  static GitValidationResult ok(String path) =>
      GitValidationResult(isRepo: true, message: 'Git repo: $path');

  static GitValidationResult notRepo(String path) => GitValidationResult(
        isRepo: false,
        message: 'Not a Git repo: $path',
      );

  static GitValidationResult error(String? message) =>
      GitValidationResult(isRepo: false, message: message);
}

class GitService {
  const GitService();

  Future<GitValidationResult> validateRepo(String path) async {
    try {
      final ProcessResult result = await Process.run(
        'git',
        <String>['rev-parse', '--is-inside-work-tree'],
        workingDirectory: path,
      );
      if (result.exitCode == 0 &&
          (result.stdout as String?)?.trim() == 'true') {
        return GitValidationResult.ok(path);
      }
      return GitValidationResult.notRepo(path);
    } catch (e) {
      return GitValidationResult.error('Git check failed: $e');
    }
  }
}
