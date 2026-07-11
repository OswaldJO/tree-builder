import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/tree_build.dart';

class TreeStorageService {
  static const _fileName = 'tree_library.json';

  Future<File> _libraryFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<List<TreeBuild>> loadAll() async {
    final file = await _libraryFile();
    if (!await file.exists()) return [];

    final contents = await file.readAsString();
    if (contents.trim().isEmpty) return [];

    final decoded = jsonDecode(contents) as List<dynamic>;
    return decoded
        .map((item) => TreeBuild.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> save(TreeBuild build) async {
    final builds = await loadAll();
    final index = builds.indexWhere((b) => b.id == build.id);
    if (index >= 0) {
      builds[index] = build;
    } else {
      builds.insert(0, build);
    }
    await _persist(builds);
  }

  Future<void> delete(String id) async {
    final builds = await loadAll();
    builds.removeWhere((b) => b.id == id);
    await _persist(builds);
  }

  Future<void> importBuilds(List<TreeBuild> imported) async {
    final builds = await loadAll();
    final existingIds = builds.map((b) => b.id).toSet();

    for (final build in imported) {
      if (!existingIds.contains(build.id)) {
        builds.add(build);
        existingIds.add(build.id);
      }
    }

    await _persist(builds);
  }

  Future<void> _persist(List<TreeBuild> builds) async {
    final file = await _libraryFile();
    final encoded = jsonEncode(builds.map((b) => b.toJson()).toList());
    await file.writeAsString(encoded);
  }
}
