import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<bool> gitAccess = ref.watch(gitAccessProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ChunkDiff'),
      ),
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
