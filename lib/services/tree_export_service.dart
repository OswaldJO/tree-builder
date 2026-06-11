import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';

import '../models/tree_build.dart';

class TreeExportService {
  Future<String?> exportAsJson(TreeBuild build) async {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Export Tree as JSON',
      fileName: '${build.rootName}_tree.json',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (path == null) return null;

    final file = File(path);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(build.toJson()),
    );
    return path;
  }

  Future<String?> exportAsText(TreeBuild build) async {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Export Tree as Text',
      fileName: '${build.rootName}_tree.txt',
      type: FileType.custom,
      allowedExtensions: ['txt'],
    );
    if (path == null) return null;

    final file = File(path);
    await file.writeAsString(build.treeText);
    return path;
  }

  Future<String?> exportLibraryAsJson(List<TreeBuild> builds) async {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Export Library as JSON',
      fileName: 'tree_library.json',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (path == null) return null;

    final file = File(path);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(
        builds.map((b) => b.toJson()).toList(),
      ),
    );
    return path;
  }

  Future<List<TreeBuild>> importFromFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      dialogTitle: 'Import Tree(s)',
    );
    if (result == null || result.files.single.path == null) {
      return [];
    }

    final file = File(result.files.single.path!);
    final contents = await file.readAsString();
    final decoded = jsonDecode(contents);

    if (decoded is List<dynamic>) {
      return decoded
          .map((item) => TreeBuild.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    if (decoded is Map<String, dynamic>) {
      return [TreeBuild.fromJson(decoded)];
    }

    throw TreeExportException('Invalid import file format.');
  }
}

class TreeExportException implements Exception {
  TreeExportException(this.message);

  final String message;

  @override
  String toString() => message;
}
