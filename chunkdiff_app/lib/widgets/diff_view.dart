import 'package:chunkdiff_app/models/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'dart:math' as math;
import 'dart:async';
import 'dart:io';

import 'package:chunkdiff_core/chunkdiff_core.dart';
import '../providers.dart';
import 'files_list.dart';
import 'chunk_diff_view.dart';
import 'diff_lines_view.dart';

class DiffView extends ConsumerStatefulWidget {
  const DiffView({super.key});

  @override
  ConsumerState<DiffView> createState() => _DiffViewState();
}

class _DiffViewState extends ConsumerState<DiffView>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _shimmerController;
  late final FocusNode _filesFocus;
  late final FocusNode _hunksFocus;
  late final FocusNode _rootFocus;
  StreamSubscription<FileSystemEvent>? _fsSub;
  Timer? _debounce;
  String? _watchedPath;
  final ScrollController _conflictScroll = ScrollController();
  final Map<String, List<GlobalKey>> _hunkKeysByFile = <String, List<GlobalKey>>{};
  final Map<String, int> _conflictPointerByFile = <String, int>{};
  final Map<String, int> _hunkPointerByFile = <String, int>{};
  List<CodeHunk> _latestHunks = const <CodeHunk>[];
  late ScrollController _contentScroll;
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>?
      _snackController;
  String? _pendingSnack;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _contentScroll = ScrollController();
    _filesFocus = FocusNode(debugLabel: 'filesFocus');
    _hunksFocus = FocusNode(debugLabel: 'hunksFocus');
    _rootFocus = FocusNode(debugLabel: 'rootFocus');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_isTextFieldFocused()) {
        _rootFocus.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _cancelWatcher();
    _debounce?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _shimmerController.dispose();
    _contentScroll.dispose();
    _filesFocus.dispose();
    _hunksFocus.dispose();
    _rootFocus.dispose();
    _conflictScroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _refresh('App resumed – refreshing repo');
      _restartWatcher();
    }
  }

  void _debouncedRefresh() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _refresh('Detected file changes – refreshing');
    });
  }

  void _cancelWatcher() {
    _fsSub?.cancel();
    _fsSub = null;
    _watchedPath = null;
  }

  void _resetHunkPointer(String? filePath) {
    if (filePath == null) return;
    _hunkPointerByFile.remove(filePath);
  }

  void _restartWatcher() {
    final AppSettings? settings =
        ref.read(settingsControllerProvider).maybeWhen(
              data: (AppSettings s) => s,
              orElse: () => null,
            );
    final String? repo = settings?.gitFolder;
    if (repo == null || repo.isEmpty) {
      _cancelWatcher();
      return;
    }
    if (_watchedPath == repo && _fsSub != null) {
      return; // already watching
    }
    _cancelWatcher();
    try {
      final Directory dir = Directory(repo);
      if (!dir.existsSync()) {
        return;
      }
      _watchedPath = repo;
      _fsSub = dir
          .watch(recursive: true)
          .listen((FileSystemEvent event) {
        final String path = event.path;
        if (!_isInterestingFile(path)) return;
        _debouncedRefresh();
      }, onError: (Object err, StackTrace st) {
        // ignore: avoid_print
        print('File watcher error: $err');
      });
    } catch (e, st) {
      // ignore: avoid_print
      print('Unable to start watcher: $e\n$st');
    }
  }

  String? _filePathForChange(SymbolChange change) =>
      change.beforePath ?? change.afterPath;

  void _resetConflictPointer(String? filePath) {
    if (filePath == null) return;
    _conflictPointerByFile.remove(filePath);
  }

  GlobalKey _hunkKeyFor(String filePath, int index, CodeHunk hunk) {
    final List<GlobalKey> list =
        _hunkKeysByFile.putIfAbsent(filePath, () => <GlobalKey>[]);
    while (list.length <= index) {
      list.add(GlobalKey());
    }
    return list[index];
  }

  void _showSnack(BuildContext context, String message) {
    // If a snackbar is currently visible, replace any pending message and wait
    // until the current one closes before showing the latest request.
    if (_snackController != null) {
      _pendingSnack = message;
      return;
    }
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    _snackController = messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 900),
      ),
    );
    _snackController?.closed.then((_) {
      _snackController = null;
      if (!mounted) return;
      if (_pendingSnack != null) {
        final String next = _pendingSnack!;
        _pendingSnack = null;
        _showSnack(context, next);
      }
    });
  }

  void _jumpToConflict(BuildContext context, Set<String> conflictFiles,
      {required bool up}) {
    final String? filePath = _currentFilePath();
    if (filePath == null || !conflictFiles.contains(filePath)) {
      return;
    }
    final List<CodeHunk> filtered = _latestHunks
        .where((CodeHunk h) => h.filePath == filePath)
        .toList();
    final List<int> conflictIndices = <int>[];
    for (int i = 0; i < filtered.length; i++) {
      if (filtered[i].hasConflict) conflictIndices.add(i);
    }
    if (conflictIndices.isEmpty) {
      return;
    }

    final _ConflictAnchors anchors =
        _buildConflictAnchors(filePath, conflictIndices);
    if (anchors.points.isEmpty || !_conflictScroll.hasClients) return;

    const double epsilon = 0.5;
    final double currentOffset = _conflictScroll.offset;
    int currentIdx = 0;
    for (int i = 0; i < anchors.points.length; i++) {
      if (anchors.points[i].offset <= currentOffset + epsilon) {
        currentIdx = i;
      } else {
        break;
      }
    }
    int targetIdx = up ? currentIdx - 1 : currentIdx + 1;
    if (targetIdx < 0) {
      targetIdx = 0;
      _showSnack(context, 'Reached the top conflict');
    }
    if (targetIdx >= anchors.points.length) {
      targetIdx = anchors.points.length - 1;
      _showSnack(context, 'Reached the bottom conflict');
    }
    final _AnchorPoint target = anchors.points[targetIdx];
    final List<GlobalKey>? keys = _hunkKeysByFile[filePath];
    if (keys != null &&
        target.hunkIndex < keys.length &&
        keys[target.hunkIndex].currentContext != null) {
      Scrollable.ensureVisible(
        keys[target.hunkIndex].currentContext!,
        alignment: target.isStart ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
      return;
    }
    _conflictScroll.animateTo(
      target.offset,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  _ConflictAnchors _buildConflictAnchors(
      String filePath, List<int> conflictIndices) {
    final List<_AnchorPoint> points = <_AnchorPoint>[];
    if (!_conflictScroll.hasClients) return _ConflictAnchors(points);
    final List<GlobalKey>? keys = _hunkKeysByFile[filePath];
    if (keys != null) {
      for (final int idx in conflictIndices) {
        if (idx >= keys.length) continue;
        final BuildContext? ctx = keys[idx].currentContext;
        if (ctx == null) continue;
        final RenderObject? renderObject = ctx.findRenderObject();
        if (renderObject == null || renderObject is! RenderBox) continue;
        final RenderAbstractViewport? viewport =
            RenderAbstractViewport.of(renderObject);
        if (viewport == null) continue;
        final double top =
            viewport.getOffsetToReveal(renderObject, 0.0).offset;
        final double bottom =
            viewport.getOffsetToReveal(renderObject, 1.0).offset;
        points.add(_AnchorPoint(offset: top, hunkIndex: idx, isStart: true));
        points.add(
            _AnchorPoint(offset: math.max(top, bottom), hunkIndex: idx, isStart: false));
      }
    }
    points.add(_AnchorPoint(
        offset: _conflictScroll.position.minScrollExtent,
        hunkIndex: 0,
        isStart: true));
    points.add(_AnchorPoint(
        offset: _conflictScroll.position.maxScrollExtent,
        hunkIndex: keys == null ? 0 : math.max(0, keys.length - 1),
        isStart: false));
    points.sort((_AnchorPoint a, _AnchorPoint b) => a.offset.compareTo(b.offset));
    final List<_AnchorPoint> deduped = <_AnchorPoint>[];
    for (final _AnchorPoint p in points) {
      if (deduped.isEmpty || (p.offset - deduped.last.offset).abs() > 1.0) {
        deduped.add(p);
      }
    }
    return _ConflictAnchors(deduped);
  }

  void _jumpHunk(BuildContext context, bool up) {
    final String? filePath = _currentFilePath();
    if (filePath == null) return;
    final List<GlobalKey>? keys = _hunkKeysByFile[filePath];
    if (keys == null || keys.isEmpty) return;
    final double frac = (_conflictScroll.hasClients &&
            _conflictScroll.position.maxScrollExtent > 0)
        ? (_conflictScroll.offset /
            _conflictScroll.position.maxScrollExtent)
        : 0.0;
    final int scrollBased =
        (frac * (keys.length - 1)).round().clamp(0, keys.length - 1);
    final int current = _hunkPointerByFile.containsKey(filePath)
        ? (_hunkPointerByFile[filePath] ?? scrollBased)
            .clamp(0, keys.length - 1)
        : scrollBased;
    final int last = keys.length - 1;
    int next = up ? current - 1 : current + 1;
    if (next < 0) {
      next = 0;
      _showSnack(context, 'Reached the top');
    }
    if (next > last) {
      next = last;
      _showSnack(context, 'Reached the bottom');
    }
    _hunkPointerByFile[filePath] = next;
    final BuildContext? ctx = keys[next].currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.2,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
      return;
    }
    if (_conflictScroll.hasClients) {
      final double fraction = next / keys.length.clamp(1, keys.length);
      final double targetOffset =
          _conflictScroll.position.maxScrollExtent * fraction;
      _conflictScroll.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    }
  }

  void _pageScroll(
    BuildContext context,
    ScrollController controller, {
    required bool up,
  }) {
    if (!controller.hasClients) return;
    final double delta = controller.position.viewportDimension * 0.75;
    final double target = up
        ? (controller.offset - delta).clamp(
            controller.position.minScrollExtent,
            controller.position.maxScrollExtent,
          )
        : (controller.offset + delta).clamp(
            controller.position.minScrollExtent,
            controller.position.maxScrollExtent,
          );
    if ((up && target == controller.offset) ||
        (!up && target == controller.offset)) {
      _showSnack(context, up ? 'Reached the top' : 'Reached the bottom');
      return;
    }
    controller.animateTo(
      target,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  String? _currentFilePath() {
    final SymbolChange? change = ref.read(selectedChangeProvider);
    return change == null ? null : _filePathForChange(change);
  }

  bool _isInterestingFile(String path) {
    final String lower = path.toLowerCase();
    if (lower.contains('/.git/') || lower.endsWith('.lock') || lower.endsWith('.tmp')) {
      return false;
    }
    const List<String> exts = <String>[
      '.dart',
      '.js',
      '.jsx',
      '.ts',
      '.tsx',
      '.java',
      '.kt',
      '.kts',
      '.swift',
      '.m',
      '.mm',
      '.c',
      '.cc',
      '.cpp',
      '.h',
      '.hpp',
      '.cxx',
      '.xml',
      '.cs',
      '.py',
      '.rb',
      '.go',
      '.rs',
      '.php',
      '.scala',
      '.groovy',
      '.sh',
      '.bash',
      '.zsh',
      '.fish',
      '.yaml',
      '.yml',
      '.json',
      '.md',
      '.css',
      '.scss',
      '.less',
      '.sql',
      '.pl',
      '.pm',
      '.lua',
      '.r',
      '.jl',
      '.hs',
      '.erl',
      '.ex',
      '.exs',
      '.clj',
      '.cljs',
      '.coffee',
      '.vb',
      '.f90',
      '.f95',
      '.fs',
      '.fsi',
      '.fsx',
      '.ml',
      '.mli',
      '.nim',
      '.tf',
      '.lock',
      '.txt',
      '.toml',
      '.ini',
      '.cfg',
      '.conf',
      '.cmake',
      '.mak',
      '.mk',
      'makefile',
      'cmakelists.txt',
    ];
    return exts.any((String ext) => lower.endsWith(ext));
  }

  bool _isTextFieldFocused() {
    final FocusNode? node = FocusManager.instance.primaryFocus;
    final Widget? w = node?.context?.widget;
    return w is EditableText;
  }

  void _refresh(String reason) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(reason),
        duration: const Duration(seconds: 1),
      ),
    );
    ref.invalidate(symbolDiffsProvider);
    ref.invalidate(hunkDiffsProvider);
    ref.invalidate(chunkDiffsProvider);
  }

  List<CodeChunk> _sortChunks(List<CodeChunk> raw) {
    int rank(ChunkCategory cat) {
      switch (cat) {
        case ChunkCategory.moved:
          return 0;
        case ChunkCategory.changed:
          return 1;
        case ChunkCategory.usageOrUnresolved:
          return 2;
        case ChunkCategory.punctuationOnly:
          return 3;
        case ChunkCategory.unreadable:
          return 4;
        case ChunkCategory.importOnly:
          return 5;
      }
    }

    final List<CodeChunk> copy = List<CodeChunk>.from(raw);
    copy.sort((CodeChunk a, CodeChunk b) {
      final int ra = rank(a.category);
      final int rb = rank(b.category);
      if (ra != rb) return ra.compareTo(rb);
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return copy;
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<SymbolDiff>> asyncDiffs =
        ref.watch(symbolDiffsProvider);
  final AsyncValue<List<CodeHunk>> asyncHunks =
      ref.watch(hunkDiffsProvider);
  final AsyncValue<List<CodeChunk>> asyncChunks =
      ref.watch(chunkDiffsProvider);
  final List<SymbolChange> changes = ref.watch(symbolChangesProvider);
    final String leftRef = ref.watch(leftRefProvider);
    final String rightRef = ref.watch(rightRefProvider);
    final SymbolChange? selectedChange = ref.watch(selectedChangeProvider);
    final List<CodeHunk> allHunks = asyncHunks.value ?? const <CodeHunk>[];
    _latestHunks = allHunks;
    _hunkKeysByFile.clear();
    final bool hasHunkData =
        asyncHunks.hasValue && allHunks.isNotEmpty;
    final bool hasChunkData =
        asyncChunks.hasValue && (asyncChunks.value?.isNotEmpty ?? false);
    final bool filesLoading =
        asyncDiffs.isLoading && changes.isEmpty && !asyncDiffs.hasError;
    final bool hunksLoading =
        asyncHunks.isLoading && (asyncHunks.value?.isEmpty ?? true);
    final bool movedLoading =
        asyncChunks.isLoading && (asyncChunks.value?.isEmpty ?? true);
    final bool isLoading =
        (asyncDiffs.isLoading || asyncHunks.isLoading || asyncChunks.isLoading) &&
            (!hasHunkData && !hasChunkData && changes.isEmpty);
    final bool hasChanges =
        (changes.isNotEmpty && !isLoading) || hasHunkData || hasChunkData;
    final ChangesTab activeTab = ref.watch(changesTabProvider);
    final int selectedFileIndex = ref.watch(selectedChangeIndexProvider);
    final int selectedHunkIndex = ref.watch(selectedHunkIndexProvider);
    final int selectedChunkIndex = ref.watch(selectedChunkIndexProvider);
    final Set<String> conflictFiles = {
      for (final CodeHunk h in allHunks)
        if (h.hasConflict) h.filePath
    };
    final List<CodeChunk> sortedChunks =
        _sortChunks(asyncChunks.value ?? const <CodeChunk>[]);
    final int clampedChunkIndex = sortedChunks.isEmpty
        ? 0
        : selectedChunkIndex.clamp(0, sortedChunks.length - 1);
    final int? selectedChunkId =
        sortedChunks.isEmpty ? null : sortedChunks[clampedChunkIndex].id;
    final String? selectedFilePath =
        selectedChange?.beforePath ?? selectedChange?.afterPath;
    final bool selectedFileHasConflict = selectedFilePath != null &&
        allHunks.any(
          (CodeHunk h) => h.filePath == selectedFilePath && h.hasConflict,
        );
    final AppSettings? settings =
        ref.watch(settingsControllerProvider).maybeWhen(
              data: (AppSettings s) => s,
              orElse: () => null,
            );
    final bool showDebug = kDebugMode && (settings?.showDebugInfo ?? false);
    final String debugSearch = settings?.debugSearch ?? '';
    final List<String> debugLog = ref.watch(debugLogProvider);

    return Focus(
      focusNode: _rootFocus,
      onKey: (FocusNode node, RawKeyEvent event) {
        if (event is! RawKeyDownEvent) return KeyEventResult.ignored;
        if (_isTextFieldFocused()) return KeyEventResult.ignored;
        final LogicalKeyboardKey key = event.logicalKey;
        int delta = 0;
        if (key == LogicalKeyboardKey.arrowUp) delta = -1;
        if (key == LogicalKeyboardKey.arrowDown) delta = 1;
        if (delta == 0) return KeyEventResult.ignored;

        switch (activeTab) {
          case ChangesTab.files:
            final int len = changes.length;
            if (len == 0) return KeyEventResult.ignored;
            final int next =
                (selectedFileIndex + delta).clamp(0, len - 1);
            if (next != selectedFileIndex) {
              final String? nextPath = _filePathForChange(changes[next]);
              _resetConflictPointer(nextPath);
              _resetHunkPointer(nextPath);
              ref.read(selectedChangeIndexProvider.notifier).state = next;
              ref.read(settingsControllerProvider.notifier).setSelectedFileIndex(next);
              return KeyEventResult.handled;
            }
            break;
          case ChangesTab.hunks:
            final int len = asyncHunks.value?.length ?? 0;
            if (len == 0) return KeyEventResult.ignored;
            final int next =
                (selectedHunkIndex + delta).clamp(0, len - 1);
            if (next != selectedHunkIndex) {
              ref.read(selectedHunkIndexProvider.notifier).state = next;
              ref.read(settingsControllerProvider.notifier).setSelectedHunkIndex(next);
              return KeyEventResult.handled;
            }
            break;
          case ChangesTab.moved:
            final int len = sortedChunks.length;
            if (len == 0) return KeyEventResult.ignored;
            final int next =
                (clampedChunkIndex + delta).clamp(0, len - 1);
            if (next != clampedChunkIndex) {
              ref.read(selectedChunkIndexProvider.notifier).state = next;
              ref.read(settingsControllerProvider.notifier).setSelectedChunkIndex(next);
              return KeyEventResult.handled;
            }
            break;
        }
        return KeyEventResult.ignored;
      },
      child: Row(
        children: [
          SizedBox(
            width: 320,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TabSwitcher(
                activeTab: activeTab,
                onChanged: (ChangesTab tab) {
                  ref.read(changesTabProvider.notifier).state = tab;
                  ref.read(settingsControllerProvider.notifier).setSelectedTab(tab);
                },
              ),
              const SizedBox(height: 8),
              _SelectionToolbar(
                tab: activeTab,
                onUp: () {
                  switch (activeTab) {
                    case ChangesTab.files:
                      if (changes.isEmpty) return;
                      if (selectedFileIndex > 0) {
                        _resetConflictPointer(
                            _filePathForChange(changes[selectedFileIndex - 1]));
                        _resetHunkPointer(
                            _filePathForChange(changes[selectedFileIndex - 1]));
                        ref.read(selectedChangeIndexProvider.notifier).state =
                            selectedFileIndex - 1;
                        ref
                            .read(settingsControllerProvider.notifier)
                            .setSelectedFileIndex(selectedFileIndex - 1);
                      }
                      break;
                    case ChangesTab.hunks:
                      final int len = asyncHunks.value?.length ?? 0;
                      if (len == 0) return;
                      if (selectedHunkIndex > 0) {
                        ref.read(selectedHunkIndexProvider.notifier).state =
                            selectedHunkIndex - 1;
                        ref
                            .read(settingsControllerProvider.notifier)
                            .setSelectedHunkIndex(selectedHunkIndex - 1);
                      }
                      break;
                    case ChangesTab.moved:
                      final int len = sortedChunks.length;
                      if (len == 0) return;
                      final int clamped =
                          selectedChunkIndex.clamp(0, len - 1);
                      if (clamped > 0) {
                        ref.read(selectedChunkIndexProvider.notifier).state =
                            clamped - 1;
                        ref
                            .read(settingsControllerProvider.notifier)
                            .setSelectedChunkIndex(clamped - 1);
                      }
                      break;
                  }
                },
                onDown: () {
                  switch (activeTab) {
                    case ChangesTab.files:
                      if (selectedFileIndex < changes.length - 1) {
                        _resetConflictPointer(
                            _filePathForChange(changes[selectedFileIndex + 1]));
                        _resetHunkPointer(
                            _filePathForChange(changes[selectedFileIndex + 1]));
                        ref.read(selectedChangeIndexProvider.notifier).state =
                            selectedFileIndex + 1;
                        ref
                            .read(settingsControllerProvider.notifier)
                            .setSelectedFileIndex(selectedFileIndex + 1);
                      }
                      break;
                    case ChangesTab.hunks:
                      final int len = asyncHunks.value?.length ?? 0;
                      if (len == 0) return;
                      final int maxIndex = len - 1;
                      if (selectedHunkIndex < maxIndex) {
                        ref.read(selectedHunkIndexProvider.notifier).state =
                            selectedHunkIndex + 1;
                        ref
                            .read(settingsControllerProvider.notifier)
                            .setSelectedHunkIndex(selectedHunkIndex + 1);
                      }
                      break;
                    case ChangesTab.moved:
                      final int len = sortedChunks.length;
                      if (len == 0) return;
                      final int clamped =
                          selectedChunkIndex.clamp(0, len - 1);
                      if (clamped < len - 1) {
                        ref.read(selectedChunkIndexProvider.notifier).state =
                            clamped + 1;
                        ref
                            .read(settingsControllerProvider.notifier)
                            .setSelectedChunkIndex(clamped + 1);
                      }
                      break;
                  }
                },
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Builder(
                  builder: (BuildContext context) {
                    if (activeTab == ChangesTab.files) {
                      if (filesLoading) {
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            _SkeletonListItem(animation: _shimmerController),
                            const SizedBox(height: 12),
                            _SkeletonListItem(animation: _shimmerController),
                            const SizedBox(height: 12),
                            _SkeletonListItem(animation: _shimmerController),
                          ],
                        );
                      }
                      if (changes.isEmpty) {
                        return Center(
                          child: Text(
                            'No changes for $leftRef → $rightRef',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: Colors.grey[400]),
                            textAlign: TextAlign.center,
                          ),
                        );
                      }
                      return FilesList(
                        changes: changes,
                        selectedIndex: selectedFileIndex,
                        onSelect: (int idx) {
                          _resetConflictPointer(_filePathForChange(changes[idx]));
                          _resetHunkPointer(_filePathForChange(changes[idx]));
                          ref
                              .read(selectedChangeIndexProvider.notifier)
                              .state = idx;
                          ref
                              .read(settingsControllerProvider.notifier)
                              .setSelectedFileIndex(idx);
                        },
                        onArrowUp: () {
                          if (selectedFileIndex > 0) {
                            _resetConflictPointer(
                                _filePathForChange(changes[selectedFileIndex - 1]));
                            _resetHunkPointer(
                                _filePathForChange(changes[selectedFileIndex - 1]));
                            ref
                                .read(selectedChangeIndexProvider.notifier)
                                .state = selectedFileIndex - 1;
                            ref
                                .read(settingsControllerProvider.notifier)
                                .setSelectedFileIndex(selectedFileIndex - 1);
                          }
                        },
                        onArrowDown: () {
                          if (selectedFileIndex < changes.length - 1) {
                            _resetConflictPointer(
                                _filePathForChange(changes[selectedFileIndex + 1]));
                            _resetHunkPointer(
                                _filePathForChange(changes[selectedFileIndex + 1]));
                            ref
                                .read(selectedChangeIndexProvider.notifier)
                                .state = selectedFileIndex + 1;
                            ref
                                .read(settingsControllerProvider.notifier)
                                .setSelectedFileIndex(selectedFileIndex + 1);
                          }
                        },
                        conflictFiles: conflictFiles,
                        focusNode: _filesFocus,
                        debugSearch: debugSearch,
                      );
                    }

                    if (activeTab == ChangesTab.hunks) {
                      if (hunksLoading) {
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            _SkeletonListItem(animation: _shimmerController),
                            const SizedBox(height: 12),
                            _SkeletonListItem(animation: _shimmerController),
                            const SizedBox(height: 12),
                            _SkeletonListItem(animation: _shimmerController),
                          ],
                        );
                      }
                      return _HunkList(
                        asyncHunks: asyncHunks,
                        selectedIndex: selectedHunkIndex,
                        onSelect: (int idx) {
                          ref
                              .read(selectedHunkIndexProvider.notifier)
                              .state = idx;
                          ref
                              .read(settingsControllerProvider.notifier)
                              .setSelectedHunkIndex(idx);
                        },
                        onArrowUp: () {
                          if (selectedHunkIndex > 0) {
                            ref
                                .read(selectedHunkIndexProvider.notifier)
                                .state = selectedHunkIndex - 1;
                            ref
                                .read(settingsControllerProvider.notifier)
                                .setSelectedHunkIndex(selectedHunkIndex - 1);
                          }
                        },
                        onArrowDown: () {
                          final int maxIndex =
                              (asyncHunks.value?.length ?? 0) - 1;
                          if (selectedHunkIndex < maxIndex) {
                            ref
                                .read(selectedHunkIndexProvider.notifier)
                                .state = selectedHunkIndex + 1;
                            ref
                                .read(settingsControllerProvider.notifier)
                                .setSelectedHunkIndex(selectedHunkIndex + 1);
                          }
                        },
                        focusNode: _hunksFocus,
                        debugSearch: debugSearch,
                      );
                    }

                    // moved tab
                    if (movedLoading) {
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          _SkeletonListItem(animation: _shimmerController),
                          const SizedBox(height: 12),
                          _SkeletonListItem(animation: _shimmerController),
                          const SizedBox(height: 12),
                          _SkeletonListItem(animation: _shimmerController),
                        ],
                      );
                    }
                    if (asyncChunks.value?.isEmpty ?? true) {
                      return Center(
                        child: Text(
                          'No moved symbols for $leftRef → $rightRef',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: Colors.grey[400]),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }
                    return _ChunksList(
                      asyncChunks: AsyncValue.data(sortedChunks),
                      selectedIndex: clampedChunkIndex,
                      onSelect: (int idx) {
                        ref.read(selectedChunkIndexProvider.notifier).state =
                            idx;
                        ref
                            .read(settingsControllerProvider.notifier)
                            .setSelectedChunkIndex(idx);
                      },
                      debugSearch: debugSearch,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            children: [
              if (showDebug) ...[
                _DebugPanel(
                  initialText: debugSearch,
                  onSubmit: (String value) async {
                    await ref
                        .read(settingsControllerProvider.notifier)
                        .setDebugSearch(value);
                    ref.invalidate(chunkDiffsProvider);
                  },
                  logLines: debugLog,
                ),
                const SizedBox(height: 8),
              ],
              if (activeTab == ChangesTab.moved && selectedChunkId != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Center(
                        child: Text(
                          'Chunk #$selectedChunkId',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (kDebugMode)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () {
                              final bool next = !(settings?.showDebugInfo ?? false);
                              ref
                                  .read(settingsControllerProvider.notifier)
                                  .setShowDebugInfo(next);
                            },
                            icon: const Icon(Icons.bug_report, size: 18),
                            label: Text(
                              (settings?.showDebugInfo ?? false)
                                  ? 'Hide debug info'
                                  : 'Show debug info',
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              _DiffMetaBar(
                change: selectedChange,
                leftRef: leftRef,
                rightRef: rightRef,
                hasConflicts: false,
                onPrevConflict: null,
                onNextConflict: null,
                onPrev: () {
                  if (activeTab == ChangesTab.files) {
                    _pageScroll(context, _conflictScroll, up: true);
                  } else {
                    _pageScroll(context, _contentScroll, up: true);
                  }
                },
                onNext: () {
                  if (activeTab == ChangesTab.files) {
                    _pageScroll(context, _conflictScroll, up: false);
                  } else {
                    _pageScroll(context, _contentScroll, up: false);
                  }
                },
              ),
            Expanded(
              child: isLoading
                  ? Row(
                      children: [
                        Expanded(
                          child: _SkeletonPane(
                            animation: _shimmerController,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _SkeletonPane(
                            animation: _shimmerController,
                          ),
                        ),
                      ],
                    )
                    : activeTab == ChangesTab.moved
                        ? ChunkDiffView(
                            asyncChunks: AsyncValue.data(sortedChunks),
                            selectedIndex: clampedChunkIndex,
                            controller: _contentScroll,
                          )
                    : _HunkDiffView(
                        asyncHunks: asyncHunks,
                        selectedIndex: selectedHunkIndex,
                        selectedFileChange: selectedChange,
                        activeTab: activeTab,
                        scrollController:
                            activeTab == ChangesTab.files ? _conflictScroll : _contentScroll,
                        hunkKeyBuilder: activeTab == ChangesTab.files
                            ? _hunkKeyFor
                            : null,
                      ),
              ),
            ],
          ),
        ),
      ],
    ),
    );
  }
}

class _DiffMetaBar extends StatelessWidget {
  const _DiffMetaBar({
    required this.change,
    required this.leftRef,
    required this.rightRef,
    this.onPrev,
    this.onNext,
    this.alignEnd = false,
    this.hasConflicts = false,
    this.onPrevConflict,
    this.onNextConflict,
  });

  final SymbolChange? change;
  final bool hasConflicts;
  final VoidCallback? onPrevConflict;
  final VoidCallback? onNextConflict;
  final String leftRef;
  final String rightRef;
  final bool alignEnd;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final TextStyle labelStyle =
        Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[400]) ??
            const TextStyle(fontSize: 12, color: Colors.grey);
    final TextStyle valueStyle =
        Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600) ??
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w600);

    return Row(
      mainAxisAlignment:
          alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Jump up',
              icon: const Icon(Icons.arrow_upward),
              onPressed: onPrev,
            ),
            IconButton(
              tooltip: 'Jump down',
              icon: const Icon(Icons.arrow_downward),
              onPressed: onNext,
            ),
            const SizedBox(width: 8),
            if (hasConflicts) ...[
              TextButton.icon(
                icon: const Icon(Icons.arrow_upward, size: 16),
                label: const Text('Prev conflict'),
                onPressed: onPrevConflict,
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                icon: const Icon(Icons.arrow_downward, size: 16),
                label: const Text('Next conflict'),
                onPressed: onNextConflict,
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
        if (change != null) ...[
          Text('Symbol: ', style: labelStyle),
          Text(change!.name, style: valueStyle),
          const SizedBox(width: 12),
          Text('Kind: ', style: labelStyle),
          Text(change!.kind.name, style: valueStyle),
          const SizedBox(width: 12),
        ],
        Text('Left: ', style: labelStyle),
        Text(leftRef, style: valueStyle),
        const SizedBox(width: 8),
        Text('Right: ', style: labelStyle),
        Text(rightRef, style: valueStyle),
      ],
    );
  }
}

class _SkeletonPane extends StatelessWidget {
  const _SkeletonPane({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SkeletonBox(
        height: double.infinity,
        animation: animation,
      ),
    );
  }
}

class _TabSwitcher extends StatelessWidget {
  const _TabSwitcher({
    required this.activeTab,
    required this.onChanged,
  });

  final ChangesTab activeTab;
  final ValueChanged<ChangesTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        _TabChip(
          label: 'Files',
          selected: activeTab == ChangesTab.files,
          onTap: () => onChanged(ChangesTab.files),
        ),
        _TabChip(
          label: 'Hunks',
          selected: activeTab == ChangesTab.hunks,
          onTap: () => onChanged(ChangesTab.hunks),
        ),
        _TabChip(
          label: 'Moved',
          selected: activeTab == ChangesTab.moved,
          onTap: () => onChanged(ChangesTab.moved),
        ),
      ],
    );
  }
}

class _SelectionToolbar extends StatelessWidget {
  const _SelectionToolbar({
    required this.tab,
    required this.onUp,
    required this.onDown,
  });

  final ChangesTab tab;
  final VoidCallback onUp;
  final VoidCallback onDown;

  @override
  Widget build(BuildContext context) {
    final String label = switch (tab) {
      ChangesTab.files => 'Files',
      ChangesTab.hunks => 'Hunks',
      ChangesTab.moved => 'Moved',
    };
    return Row(
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const Spacer(),
        IconButton(
          tooltip: 'Select previous $label item',
          icon: const Icon(Icons.keyboard_arrow_up),
          onPressed: onUp,
        ),
        IconButton(
          tooltip: 'Select next $label item',
          icon: const Icon(Icons.keyboard_arrow_down),
          onPressed: onDown,
        ),
      ],
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: Colors.indigo.withOpacity(0.2),
      labelStyle: TextStyle(
        color: selected ? Colors.indigo[100] : Colors.grey[300],
        fontWeight: FontWeight.w600,
      ),
      backgroundColor: Colors.grey.shade900,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}

class _HunkList extends StatelessWidget {
  const _HunkList({
    required this.asyncHunks,
    required this.selectedIndex,
    required this.onSelect,
    this.focusNode,
    this.onArrowUp,
    this.onArrowDown,
    this.debugSearch = '',
  });

  final AsyncValue<List<CodeHunk>> asyncHunks;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final FocusNode? focusNode;
  final VoidCallback? onArrowUp;
  final VoidCallback? onArrowDown;
  final String debugSearch;

  @override
  Widget build(BuildContext context) {
    final List<CodeHunk> chunks =
        asyncHunks.value ?? const <CodeHunk>[];

    if (chunks.isEmpty) {
      return Center(
        child: Text(
          'No diff content to display.',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: Colors.grey[400]),
        ),
      );
    }

        return Focus(
      focusNode: focusNode,
      onKey: (FocusNode node, RawKeyEvent event) {
        if (event is! RawKeyDownEvent) return KeyEventResult.ignored;
        final LogicalKeyboardKey key = event.logicalKey;
        if (key == LogicalKeyboardKey.arrowUp) {
          onArrowUp?.call();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowDown) {
          onArrowDown?.call();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: chunks.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (BuildContext context, int index) {
          final CodeHunk chunk = chunks[index];
          final bool selected = index == selectedIndex;
          final String needle = debugSearch.toLowerCase();
          final bool debugHit = needle.isNotEmpty &&
              (chunk.filePath.toLowerCase().contains(needle) ||
                  chunk.lines.any((DiffLine l) =>
                      l.leftText.toLowerCase().contains(needle) ||
                      l.rightText.toLowerCase().contains(needle)));
          final Color tileColor =
              selected ? Colors.indigo.withOpacity(0.15) : Colors.transparent;
          final Color hoverColor = Colors.indigo.withOpacity(0.08);
          final bool hasConflict = chunk.hasConflict;
          return Material(
            color: tileColor,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              hoverColor: hoverColor,
              onTap: () {
                focusNode?.requestFocus();
                onSelect(index);
              },
              child: ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                selected: selected,
                selectedTileColor: tileColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                title: Text(chunk.filePath),
                subtitle: Text(
                  'Old ${chunk.oldStart}-${chunk.oldStart + chunk.oldCount - 1} → '
                  'New ${chunk.newStart}-${chunk.newStart + chunk.newCount - 1}',
                ),
                trailing: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (hasConflict)
                      Chip(
                        label: const Text('Conflict'),
                        backgroundColor: Colors.pink.shade600,
                        labelStyle: const TextStyle(color: Colors.white),
                        visualDensity: VisualDensity.compact,
                      ),
                    if (debugHit)
                      const Chip(
                        label: Text('Debug'),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ChunksPlaceholder extends StatelessWidget {
  const _ChunksPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

class _HunkDiffView extends StatelessWidget {
  const _HunkDiffView({
    required this.asyncHunks,
    required this.selectedIndex,
    required this.selectedFileChange,
    required this.activeTab,
    this.scrollController,
    this.hunkKeyBuilder,
  });

  final AsyncValue<List<CodeHunk>> asyncHunks;
  final int selectedIndex;
  final SymbolChange? selectedFileChange;
  final ChangesTab activeTab;
  final ScrollController? scrollController;
  final GlobalKey Function(String filePath, int index, CodeHunk hunk)?
      hunkKeyBuilder;

  @override
  Widget build(BuildContext context) {
    final List<CodeHunk> all = asyncHunks.value ?? const <CodeHunk>[];
    if (all.isEmpty) {
      return Center(
        child: Text(
          'No diff content to display.',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: Colors.grey[400]),
        ),
      );
    }

    if (activeTab == ChangesTab.hunks) {
      final int clampedIndex = selectedIndex.clamp(0, all.length - 1);
      final CodeHunk hunk = all[clampedIndex];
      return DiffLinesView(
        lines: hunk.lines,
        header:
            '${hunk.filePath}  (Old ${hunk.oldStart}-${hunk.oldStart + hunk.oldCount - 1} → '
            'New ${hunk.newStart}-${hunk.newStart + hunk.newCount - 1})',
        scrollable: true,
        controller: scrollController,
      );
    }

    if (activeTab == ChangesTab.files) {
      final String? targetFile =
          selectedFileChange?.beforePath ?? selectedFileChange?.afterPath;
      final List<CodeHunk> filtered = targetFile == null
          ? all
          : all.where((CodeHunk h) => h.filePath == targetFile).toList();
      if (filtered.isEmpty) {
        return Center(
          child: Text(
            'No diff content to display.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Colors.grey[400]),
          ),
        );
      }
      return ListView.separated(
        controller: scrollController,
        padding: EdgeInsets.zero,
        itemCount: filtered.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (BuildContext context, int index) {
          final CodeHunk hunk = filtered[index];
          final GlobalKey? key =
              hunkKeyBuilder?.call(hunk.filePath, index, hunk);
          return DiffLinesView(
            key: key,
            lines: hunk.lines,
            header:
                '${hunk.filePath}  (Old ${hunk.oldStart}-${hunk.oldStart + hunk.oldCount - 1} → '
                'New ${hunk.newStart}-${hunk.newStart + hunk.newCount - 1})',
            scrollable: false,
          );
        },
      );
    }

    return const _ChunksPlaceholder();
  }
}

class _ChunksList extends StatelessWidget {
  const _ChunksList({
    required this.asyncChunks,
    required this.selectedIndex,
    required this.onSelect,
    this.debugSearch = '',
  });

  final AsyncValue<List<CodeChunk>> asyncChunks;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final String debugSearch;

  @override
  Widget build(BuildContext context) {
    final List<CodeChunk> chunks = asyncChunks.value ?? const <CodeChunk>[];
    int categoryRank(ChunkCategory cat) {
      switch (cat) {
        case ChunkCategory.moved:
          return 0;
        case ChunkCategory.changed:
          return 1;
        case ChunkCategory.usageOrUnresolved:
          return 2;
        case ChunkCategory.punctuationOnly:
          return 3;
        case ChunkCategory.unreadable:
          return 4;
        case ChunkCategory.importOnly:
          return 5;
      }
    }

    if (chunks.isEmpty) {
      return Center(
        child: Text(
          'No diff content to display.',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: Colors.grey[400]),
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: chunks.length,
      separatorBuilder: (_, int index) {
        if (index >= chunks.length - 1) {
          return const SizedBox(height: 12);
        }
        final int currentRank = categoryRank(chunks[index].category);
        final int nextRank = categoryRank(chunks[index + 1].category);
        if (currentRank != nextRank) {
          return Column(
            children: <Widget>[
              const SizedBox(height: 8),
              Divider(color: Colors.grey.shade700, height: 1),
              const SizedBox(height: 8),
            ],
          );
        }
        return const SizedBox(height: 12);
      },
      itemBuilder: (BuildContext context, int index) {
        final CodeChunk chunk = chunks[index];
        final bool selected = index == selectedIndex;
        final String needle = debugSearch.toLowerCase();
        final bool debugHit = needle.isNotEmpty &&
            (chunk.name.toLowerCase().contains(needle) ||
                chunk.filePath.toLowerCase().contains(needle) ||
                chunk.rightFilePath.toLowerCase().contains(needle));
          final String categoryLabel = switch (chunk.category) {
            ChunkCategory.moved => 'Moved',
            ChunkCategory.changed => 'Changed',
            ChunkCategory.importOnly => 'Import',
            ChunkCategory.punctuationOnly => 'Punctuation',
            ChunkCategory.usageOrUnresolved => 'Usage',
            ChunkCategory.unreadable => 'Unreadable',
          };
        final Color categoryColor = switch (chunk.category) {
          ChunkCategory.moved => Colors.blue.shade800,
          ChunkCategory.changed => Colors.grey.shade700,
          ChunkCategory.importOnly => Colors.teal.shade800,
          ChunkCategory.punctuationOnly => Colors.brown.shade700,
          ChunkCategory.usageOrUnresolved => Colors.purple.shade700,
          ChunkCategory.unreadable => Colors.red.shade800,
        };
          final List<Widget> chips = <Widget>[
            Chip(
              label: Text(categoryLabel),
              backgroundColor: categoryColor,
              labelStyle: const TextStyle(color: Colors.white),
              visualDensity: VisualDensity.compact,
            ),
          if (chunk.hasConflict)
            Chip(
              label: const Text('Conflict'),
              backgroundColor: Colors.pink.shade600,
              labelStyle: const TextStyle(color: Colors.white),
              visualDensity: VisualDensity.compact,
            ),
          if (debugHit)
            const Chip(
              label: Text('Debug'),
              visualDensity: VisualDensity.compact,
            ),
          ];
        final Color tileColor =
            selected ? Colors.indigo.withOpacity(0.15) : Colors.transparent;
        final Color hoverColor = Colors.indigo.withOpacity(0.08);
        return Material(
          color: tileColor,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            hoverColor: hoverColor,
            onTap: () => onSelect(index),
            child: ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              selected: selected,
              selectedTileColor: tileColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              title: Text('${chunk.id}: ${chunk.name}'),
              subtitle: Text(
                '${chunk.filePath} | lines ${chunk.oldStart}-${chunk.oldEnd}',
              ),
              trailing: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: chips,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SkeletonListItem extends StatelessWidget {
  const _SkeletonListItem({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, _) {
        return SizedBox(
          height: 80,
          child: Row(
            children: [
              Expanded(
                child: SkeletonBox(
                  height: 70,
                  animation: animation,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    required this.height,
    required this.animation,
    this.width,
    this.borderRadius = const BorderRadius.all(Radius.circular(10)),
  });

  final double height;
  final double? width;
  final BorderRadius borderRadius;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final Color baseColor = Colors.grey.shade800;
    final Color highlightColor = Colors.grey.shade700;
    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, _) {
        final double t = animation.value;
        final double dx = (t * 2.0) - 1.0; // -1 to 1
        return Container(
          height: height,
          width: width,
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            gradient: LinearGradient(
              begin: Alignment(dx, 0),
              end: Alignment(dx + 1, 0),
              colors: <Color>[
                baseColor,
                highlightColor,
                baseColor,
              ],
              stops: const <double>[0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

class _DebugPanel extends StatefulWidget {
  const _DebugPanel({
    required this.initialText,
    required this.onSubmit,
    required this.logLines,
  });

  final String initialText;
  final ValueChanged<String> onSubmit;
  final List<String> logLines;

  @override
  State<_DebugPanel> createState() => _DebugPanelState();
}

class _DebugPanelState extends State<_DebugPanel> {
  late TextEditingController _controller;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              labelText: 'Debug search string',
              isDense: true,
            ),
            onSubmitted: widget.onSubmit,
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 240,
            child: Scrollbar(
              thumbVisibility: true,
              controller: _scrollController,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                controller: _scrollController,
                child: SelectableText(
                  widget.logLines.isEmpty
                      ? '(no debug log yet)'
                      : widget.logLines.join('\n'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey[300],
                    fontFamily: 'SourceCodePro',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnchorPoint {
  const _AnchorPoint({
    required this.offset,
    required this.hunkIndex,
    required this.isStart,
  });

  final double offset;
  final int hunkIndex;
  final bool isStart;
}

class _ConflictAnchors {
  const _ConflictAnchors(this.points);
  final List<_AnchorPoint> points;
}
