import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('ChunkDiff'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
