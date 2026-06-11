import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../models/tree_build.dart';
import '../utils/map_cast.dart';

class TreeExportService {
  Future<String?> exportAsJson(
    TreeBuild build, {
    String? treeText,
  }) async {
    final exportBuild =
        treeText != null ? build.copyWith(treeText: treeText) : build;
    final contents =
        const JsonEncoder.withIndent('  ').convert(exportBuild.toJson());
    return _saveString(
      dialogTitle: 'Export Tree as JSON',
      fileName: '${build.rootName}_tree.json',
      extension: 'json',
      contents: contents,
    );
  }

  Future<String?> exportAsText(
    TreeBuild build, {
    String? treeText,
  }) async {
    return _saveString(
      dialogTitle: 'Export Tree as Text',
      fileName: '${build.rootName}_tree.txt',
      extension: 'txt',
      contents: treeText ?? build.treeText,
    );
  }

  Future<String?> exportLibraryAsJson(List<TreeBuild> builds) async {
    final contents = const JsonEncoder.withIndent('  ').convert(
      builds.map((b) => b.toJson()).toList(),
    );
    return _saveString(
      dialogTitle: 'Export Library as JSON',
      fileName: 'tree_library.json',
      extension: 'json',
      contents: contents,
    );
  }

  Future<String?> _saveString({
    required String dialogTitle,
    required String fileName,
    required String extension,
    required String contents,
  }) async {
    final bytes = Uint8List.fromList(utf8.encode(contents));
    final isMobile = Platform.isAndroid || Platform.isIOS;

    final path = await FilePicker.platform.saveFile(
      dialogTitle: dialogTitle,
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: [extension],
      bytes: isMobile ? bytes : null,
    );

    if (path == null) return isMobile ? fileName : null;

    if (!isMobile) {
      await File(path).writeAsBytes(bytes);
    }

    return path;
  }

  Future<List<TreeBuild>> importFromFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      dialogTitle: 'Import Tree(s)',
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return [];
    }

    final file = result.files.single;
    final contents = await _readFileContents(file);
    final decoded = jsonDecode(contents);

    if (decoded is List<dynamic>) {
      return decoded
          .map(
            (item) => TreeBuild.fromJson(
              deepCastMap(Map<dynamic, dynamic>.from(item as Map)),
            ),
          )
          .toList();
    }

    if (decoded is Map) {
      return [
        TreeBuild.fromJson(
          deepCastMap(Map<dynamic, dynamic>.from(decoded)),
        ),
      ];
    }

    throw TreeExportException('Invalid import file format.');
  }

  Future<String> _readFileContents(PlatformFile file) async {
    if (file.bytes != null) {
      return utf8.decode(file.bytes!);
    }

    final path = file.path;
    if (path == null) {
      throw TreeExportException('Unable to read selected file.');
    }

    return File(path).readAsString();
  }
}

class TreeExportException implements Exception {
  TreeExportException(this.message);

  final String message;

  @override
  String toString() => message;
}
