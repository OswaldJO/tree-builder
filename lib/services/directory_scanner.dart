import 'dart:io';

import 'package:uuid/uuid.dart';

import '../models/scan_progress.dart';
import '../models/tree_build.dart';
import '../models/tree_node.dart';
import '../utils/map_cast.dart';
import '../utils/tree_renderer.dart';
import 'android_tree_scanner.dart';
import 'ios_tree_scanner.dart';
import 'scan_counters.dart';

class DirectoryScanner {
  const DirectoryScanner();

  static const _uuid = Uuid();

  /// [maxDepth] limits how many folder levels below the root are expanded.
  /// 1 = only immediate children, 2 = grandchildren folders, etc.
  /// Pass null for unlimited depth.
  Future<TreeBuild?> pickAndScan({
    int? maxDepth,
    String? path,
    void Function(ScanProgress progress)? onProgress,
  }) async {
    if (Platform.isAndroid) {
      final uri = await AndroidTreeScanner.pickDirectory();
      if (uri == null) return null;

      return AndroidTreeScanner.scanDirectory(
        uri,
        maxDepth: maxDepth,
        onProgress: onProgress,
      );
    }

    if (Platform.isIOS) {
      final picked = await IosTreeScanner.pickDirectory();
      if (picked == null) return null;

      return IosTreeScanner.scanDirectory(
        picked,
        maxDepth: maxDepth,
        onProgress: onProgress,
      );
    }

    if (path == null) {
      throw DirectoryScannerException('Directory path is required.');
    }

    return _scanWithIo(path, maxDepth: maxDepth, onProgress: onProgress);
  }

  Future<TreeBuild> _scanWithIo(
    String path, {
    int? maxDepth,
    void Function(ScanProgress progress)? onProgress,
  }) async {
    final directory = Directory(path);
    if (!await directory.exists()) {
      throw DirectoryScannerException('Directory does not exist: $path');
    }

    final rootName = _basename(path);
    final counters = ScanCounters();
    onProgress?.call(const ScanProgress(folders: 0, files: 0));

    final root = await _buildNode(
      directory,
      rootName,
      currentDepth: 1,
      maxDepth: maxDepth,
      counters: counters,
      onProgress: onProgress,
    );

    onProgress?.call(
      counters.toProgress().copyWith(phase: ScanPhase.building),
    );
    final treeText = TreeRenderer.renderFull(rootName, root.children);

    return TreeBuild(
      id: _uuid.v4(),
      rootPath: path,
      rootName: rootName,
      root: root,
      treeText: treeText,
      createdAt: DateTime.now(),
      maxDepth: maxDepth,
    );
  }

  static TreeBuild fromScanResult(
    Map<dynamic, dynamic> data, {
    int? maxDepth,
  }) {
    final rootName = data['rootName'] as String;
    final rootPath = data['rootPath'] as String;
    final root = TreeNode.fromJson(
      deepCastMap(Map<dynamic, dynamic>.from(data['root'] as Map)),
    );

    return TreeBuild(
      id: _uuid.v4(),
      rootPath: rootPath,
      rootName: rootName,
      root: root,
      treeText: TreeRenderer.renderFull(rootName, root.children),
      createdAt: DateTime.now(),
      maxDepth: maxDepth,
    );
  }

  Future<TreeNode> _buildNode(
    Directory directory,
    String name, {
    required int currentDepth,
    int? maxDepth,
    ScanCounters? counters,
    void Function(ScanProgress progress)? onProgress,
  }) async {
    final children = <TreeNode>[];

    try {
      final entities = await directory.list(followLinks: false).toList();
      entities.sort((a, b) {
        final aIsDir = _isDirectoryEntity(a);
        final bIsDir = _isDirectoryEntity(b);
        if (aIsDir != bIsDir) return aIsDir ? -1 : 1;
        return _basename(a.path).toLowerCase().compareTo(
              _basename(b.path).toLowerCase(),
            );
      });

      for (final entity in entities) {
        final childName = _basename(entity.path);
        if (await _isDirectory(entity)) {
          counters?.folders++;
          if (counters != null) {
            await counters.maybeReport(childName, onProgress);
          }

          if (maxDepth != null && currentDepth >= maxDepth) {
            children.add(
              TreeNode(name: childName, isDirectory: true, children: const []),
            );
          } else {
            children.add(
              await _buildNode(
                Directory(entity.path),
                childName,
                currentDepth: currentDepth + 1,
                maxDepth: maxDepth,
                counters: counters,
                onProgress: onProgress,
              ),
            );
          }
        } else {
          counters?.files++;
          if (counters != null) {
            await counters.maybeReport(childName, onProgress);
          }
          children.add(TreeNode(name: childName, isDirectory: false));
        }
      }
    } on FileSystemException catch (e) {
      children.add(
        TreeNode(
          name: '[permission denied: ${e.message}]',
          isDirectory: false,
        ),
      );
    }

    return TreeNode(name: name, isDirectory: true, children: children);
  }

  Future<bool> _isDirectory(FileSystemEntity entity) async {
    if (entity is Directory) return true;
    if (entity is File) return false;

    final type = await FileSystemEntity.type(entity.path, followLinks: false);
    return type == FileSystemEntityType.directory;
  }

  bool _isDirectoryEntity(FileSystemEntity entity) {
    if (entity is Directory) return true;
    if (entity is File) return false;
    return FileSystemEntity.typeSync(entity.path, followLinks: false) ==
        FileSystemEntityType.directory;
  }

  static String _basename(String path) {
    if (path.endsWith(Platform.pathSeparator)) {
      path = path.substring(0, path.length - 1);
    }
    return path.split(Platform.pathSeparator).last;
  }
}

class DirectoryScannerException implements Exception {
  DirectoryScannerException(this.message);

  final String message;

  @override
  String toString() => message;
}
