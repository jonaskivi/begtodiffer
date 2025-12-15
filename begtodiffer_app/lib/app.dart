import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'providers.dart';
import 'widgets/diff_view.dart';
import 'widgets/repo_toolbar.dart';

class ChunkDiffApp extends StatelessWidget {
  const ChunkDiffApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChunkDiff',
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
      ),
      home: const WindowStateWatcher(child: HomeScreen()),
    );
  }
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<bool> gitAccess = ref.watch(gitAccessProvider);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            gitAccess.maybeWhen(
              data: (bool ok) => ok
                  ? const SizedBox.shrink()
                  : Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded,
                              color: Colors.amber),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Git commands are unavailable. The app is using stub data.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: Colors.amber[200]),
                            ),
                          ),
                        ],
                      ),
                    ),
              orElse: () => const SizedBox.shrink(),
            ),
            if (gitAccess.hasValue) const SizedBox(height: 12),
            const RepoToolbar(),
            const SizedBox(height: 16),
            Expanded(
              child: const DiffView(),
            ),
          ],
        ),
      ),
    );
  }
}

class WindowStateWatcher extends ConsumerStatefulWidget {
  const WindowStateWatcher({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<WindowStateWatcher> createState() => _WindowStateWatcherState();
}

class _WindowStateWatcherState extends ConsumerState<WindowStateWatcher>
    with WindowListener {
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      windowManager.addListener(this);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  void _scheduleSave() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      if (!mounted) return;
      try {
        final bool maximized = await windowManager.isMaximized();
        final Size size = await windowManager.getSize();
        await ref.read(settingsControllerProvider.notifier).setWindowState(
              width: size.width,
              height: size.height,
              maximized: maximized,
            );
      } catch (_) {}
    });
  }

  @override
  void onWindowResize() => _scheduleSave();

  @override
  void onWindowUnmaximize() => _scheduleSave();

  @override
  void onWindowMaximize() => _scheduleSave();

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
