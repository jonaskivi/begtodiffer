import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'models/app_settings.dart';
import 'services/settings_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  AppSettings? initialSettings;
  if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
    final SettingsRepository repo = SettingsRepository();
    initialSettings = await repo.load();
    await windowManager.ensureInitialized();
    final Size targetSize = (initialSettings.windowWidth != null &&
            initialSettings.windowHeight != null)
        ? Size(initialSettings.windowWidth!, initialSettings.windowHeight!)
        : const Size(1400, 900);
    final bool maximizeByDefault =
        initialSettings.windowWidth == null || initialSettings.windowHeight == null;
    await windowManager.waitUntilReadyToShow(
      WindowOptions(
        size: targetSize,
        center: true,
        title: 'ChunkDiff',
      ),
      () async {
        if (maximizeByDefault ||
            (initialSettings?.windowMaximized ?? false)) {
          await windowManager.maximize();
        }
        await windowManager.show();
      },
    );
  }

  runApp(const ProviderScope(child: ChunkDiffApp()));
}
