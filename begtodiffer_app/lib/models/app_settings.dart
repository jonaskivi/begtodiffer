class AppSettings {
  final String? gitFolder;
  final int selectedFileIndex;
  final int selectedHunkIndex;
  final int selectedChunkIndex;
  final String selectedTab;
  final bool showDebugInfo;
  final String debugSearch;
  final bool verboseDebugLog;
  final double? windowWidth;
  final double? windowHeight;
  final bool? windowMaximized;

  const AppSettings({
    this.gitFolder,
    this.selectedFileIndex = 0,
    this.selectedHunkIndex = 0,
    this.selectedChunkIndex = 0,
    this.selectedTab = 'moved',
    this.showDebugInfo = false,
    this.debugSearch = '',
    this.verboseDebugLog = !_kIsProd,
    this.windowWidth,
    this.windowHeight,
    this.windowMaximized,
  });

  static const bool _kIsProd = bool.fromEnvironment('dart.vm.product');

  AppSettings copyWith({
    String? gitFolder,
    int? selectedFileIndex,
    int? selectedHunkIndex,
    int? selectedChunkIndex,
    String? selectedTab,
    bool? showDebugInfo,
    String? debugSearch,
    bool? verboseDebugLog,
    double? windowWidth,
    double? windowHeight,
    bool? windowMaximized,
  }) {
    return AppSettings(
      gitFolder: gitFolder ?? this.gitFolder,
      selectedFileIndex: selectedFileIndex ?? this.selectedFileIndex,
      selectedHunkIndex: selectedHunkIndex ?? this.selectedHunkIndex,
      selectedChunkIndex: selectedChunkIndex ?? this.selectedChunkIndex,
      selectedTab: selectedTab ?? this.selectedTab,
      showDebugInfo: showDebugInfo ?? this.showDebugInfo,
      debugSearch: debugSearch ?? this.debugSearch,
      verboseDebugLog: verboseDebugLog ?? this.verboseDebugLog,
      windowWidth: windowWidth ?? this.windowWidth,
      windowHeight: windowHeight ?? this.windowHeight,
      windowMaximized: windowMaximized ?? this.windowMaximized,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'gitFolder': gitFolder,
        'selectedFileIndex': selectedFileIndex,
        'selectedHunkIndex': selectedHunkIndex,
        'selectedChunkIndex': selectedChunkIndex,
        'selectedTab': selectedTab,
        'showDebugInfo': showDebugInfo,
        'debugSearch': debugSearch,
        'verboseDebugLog': verboseDebugLog,
        'windowWidth': windowWidth,
        'windowHeight': windowHeight,
        'windowMaximized': windowMaximized,
      };

  static AppSettings fromJson(Map<String, Object?> json) {
    final Object? pathValue = json['gitFolder'];
    final Object? fileIndex = json['selectedFileIndex'];
    final Object? hunkIndex = json['selectedHunkIndex'];
    final Object? chunkIndex = json['selectedChunkIndex'];
    final Object? tabValue = json['selectedTab'];
    final Object? showDebugValue = json['showDebugInfo'];
    final Object? debugSearchValue = json['debugSearch'];
    final Object? verboseValue = json['verboseDebugLog'];
    final Object? widthValue = json['windowWidth'];
    final Object? heightValue = json['windowHeight'];
    final Object? maxValue = json['windowMaximized'];
    return AppSettings(
      gitFolder: pathValue as String?,
      selectedFileIndex: fileIndex is int ? fileIndex : 0,
      selectedHunkIndex: hunkIndex is int ? hunkIndex : 0,
      selectedChunkIndex: chunkIndex is int ? chunkIndex : 0,
      selectedTab: tabValue is String ? tabValue : 'moved',
      showDebugInfo: showDebugValue is bool ? showDebugValue : false,
      debugSearch: debugSearchValue is String ? debugSearchValue : '',
      verboseDebugLog: verboseValue is bool
          ? verboseValue
          : (showDebugValue is bool ? showDebugValue : !_kIsProd),
      windowWidth: widthValue is num ? widthValue.toDouble() : null,
      windowHeight: heightValue is num ? heightValue.toDouble() : null,
      windowMaximized: maxValue is bool ? maxValue : null,
    );
  }
}
