import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/app_settings.dart';

class SettingsRepository {
  Future<File> _settingsFile() async {
    final Directory dir = await getApplicationSupportDirectory();
    final String path = p.join(dir.path, 'begtodiffer_settings.json');
    return File(path);
  }

  Future<AppSettings> load() async {
    try {
      final File file = await _settingsFile();
      if (!await file.exists()) {
        return const AppSettings();
      }
      final String contents = await file.readAsString();
      final Map<String, Object?> data =
          jsonDecode(contents) as Map<String, Object?>;
      return AppSettings.fromJson(data);
    } catch (_) {
      return const AppSettings();
    }
  }

  Future<void> save(AppSettings settings) async {
    final File file = await _settingsFile();
    final Directory parent = file.parent;
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }
    await file.writeAsString(jsonEncode(settings.toJson()));
  }
}
