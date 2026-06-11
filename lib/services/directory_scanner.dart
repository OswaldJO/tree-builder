import 'dart:io';

import 'package:uuid/uuid.dart';

import '../models/tree_build.dart';
import '../models/tree_node.dart';

class DirectoryScanner {
  const DirectoryScanner();

  static const _uuid = Uuid();

  /// [maxDepth] limits how many folder levels below the root are expanded.
  /// 1 = only immediate children, 2 = grandchildren folders, etc.
  /// Pass null for unlimited depth.
  Future<TreeBuild> scanDirectory(
    String path, {
    int? maxDepth,
  }) async {
    final directory = Directory(path);
    if (!await directory.exists()) {
      throw DirectoryScannerException('Directory does not exist: $path');
    }

    final rootName = path.split(Platform.pathSeparator).last;
    final root = await _buildNode(
      directory,
      rootName,
      currentDepth: 1,
      maxDepth: maxDepth,
    );
    final treeText = _renderTree(rootName, root.children);

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

  Future<TreeNode> _buildNode(
    Directory directory,
    String name, {
    required int currentDepth,
    int? maxDepth,
  }) async {
    final children = <TreeNode>[];

    try {
      final entities = await directory.list(followLinks: true).toList();
      entities.sort((a, b) {
        final aIsDir = _isDirectoryEntity(a);
        final bIsDir = _isDirectoryEntity(b);
        if (aIsDir != bIsDir) return aIsDir ? -1 : 1;
        return a.path.toLowerCase().compareTo(b.path.toLowerCase());
      });

      for (final entity in entities) {
        final childName = entity.path.split(Platform.pathSeparator).last;
        final entityType = await FileSystemEntity.type(
          entity.path,
          followLinks: true,
        );

        if (entityType == FileSystemEntityType.directory ||
            _isDirectoryEntity(entity)) {
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
              ),
            );
          }
        } else if (entityType == FileSystemEntityType.file ||
            entityType == FileSystemEntityType.link) {
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

  bool _isDirectoryEntity(FileSystemEntity entity) {
    return entity is Directory ||
        FileSystemEntity.typeSync(entity.path, followLinks: true) ==
            FileSystemEntityType.directory;
  }

  String _renderTree(String rootName, List<TreeNode> children) {
    final buffer = StringBuffer('$rootName/\n');
    for (var i = 0; i < children.length; i++) {
      final isLast = i == children.length - 1;
      buffer.write(_renderNode(children[i], '', isLast));
    }
    return buffer.toString().trimRight();
  }

  String _renderNode(TreeNode node, String prefix, bool isLast) {
    final connector = isLast ? '└── ' : '├── ';
    final childPrefix = isLast ? '    ' : '│   ';
    final displayName = node.isDirectory ? '${node.name}/' : node.name;

    final buffer = StringBuffer('$prefix$connector$displayName\n');

    for (var i = 0; i < node.children.length; i++) {
      final childIsLast = i == node.children.length - 1;
      buffer.write(
        _renderNode(node.children[i], prefix + childPrefix, childIsLast),
      );
    }

    return buffer.toString();
  }
}

class DirectoryScannerException implements Exception {
  DirectoryScannerException(this.message);

  final String message;

  @override
  String toString() => message;
}
