class AppSettings {
  final String? gitFolder;

  const AppSettings({this.gitFolder});

  AppSettings copyWith({String? gitFolder}) {
    return AppSettings(gitFolder: gitFolder ?? this.gitFolder);
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'gitFolder': gitFolder,
      };

  static AppSettings fromJson(Map<String, Object?> json) {
    final Object? pathValue = json['gitFolder'];
    return AppSettings(gitFolder: pathValue as String?);
  }
}
