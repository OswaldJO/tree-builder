import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/remote_settings.dart';

class RemoteSettingsService {
  static const _fileName = 'remote_settings.json';

  Future<File> _settingsFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<RemoteSettings> load() async {
    final file = await _settingsFile();
    if (!await file.exists()) return const RemoteSettings();

    final contents = await file.readAsString();
    if (contents.trim().isEmpty) return const RemoteSettings();

    final decoded = jsonDecode(contents) as Map<String, dynamic>;
    return RemoteSettings.fromJson(decoded);
  }

  Future<void> save(RemoteSettings settings) async {
    final file = await _settingsFile();
    final encoded = jsonEncode(settings.toJson());
    await file.writeAsString(encoded);
  }
}
