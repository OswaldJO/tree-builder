import 'package:smb_connect/smb_connect.dart';
import 'package:uuid/uuid.dart';

import '../models/remote_settings.dart';
import '../models/scan_progress.dart';
import '../models/scan_source_type.dart';
import '../models/tree_build.dart';
import '../models/tree_node.dart';
import '../utils/tree_renderer.dart';
import 'directory_scanner.dart';
import 'scan_counters.dart';

class SmbDirectoryScanner {
  const SmbDirectoryScanner({
    required this.settings,
    required this.remotePath,
  });

  final SmbSettings settings;
  final String remotePath;

  static const _uuid = Uuid();

  Future<TreeBuild> scan({
    int? maxDepth,
    void Function(ScanProgress progress)? onProgress,
  }) async {
    final connect = await SmbConnect.connectAuth(
      host: settings.host.trim(),
      username: settings.username.trim(),
      password: settings.password,
      domain: settings.domain.trim(),
    );

    try {
      final path = RemotePath.normalize(remotePath);
      final folder = await connect.file(path);
      if (!folder.isExists) {
        throw DirectoryScannerException('Path does not exist: $path');
      }
      if (!folder.isDirectory()) {
        throw DirectoryScannerException('Path is not a directory: $path');
      }

      final rootName = RemotePath.basename(path);
      final counters = ScanCounters();
      onProgress?.call(const ScanProgress(folders: 0, files: 0));

      final root = await _buildNode(
        connect,
        folder,
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
        rootPath: settings.displayUriForPath(path),
        rootName: rootName,
        root: root,
        treeText: treeText,
        createdAt: DateTime.now(),
        maxDepth: maxDepth,
        scanSourceType: ScanSourceType.smb,
      );
    } finally {
      await connect.close();
    }
  }

  Future<TreeNode> _buildNode(
    SmbConnect connect,
    SmbFile folder,
    String name, {
    required int currentDepth,
    int? maxDepth,
    ScanCounters? counters,
    void Function(ScanProgress progress)? onProgress,
  }) async {
    final children = <TreeNode>[];

    try {
      final entities = await connect.listFiles(folder);
      entities.sort((a, b) {
        final aIsDir = a.isDirectory();
        final bIsDir = b.isDirectory();
        if (aIsDir != bIsDir) return aIsDir ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      for (final entity in entities) {
        if (entity.name == SmbFile.NAME_DOT ||
            entity.name == SmbFile.NAME_DOT_DOT) {
          continue;
        }

        if (entity.isDirectory()) {
          counters?.folders++;
          if (counters != null) {
            await counters.maybeReport(entity.name, onProgress);
          }

          if (maxDepth != null && currentDepth >= maxDepth) {
            children.add(
              TreeNode(
                name: entity.name,
                isDirectory: true,
                children: const [],
              ),
            );
          } else {
            children.add(
              await _buildNode(
                connect,
                entity,
                entity.name,
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
            await counters.maybeReport(entity.name, onProgress);
          }
          children.add(TreeNode(name: entity.name, isDirectory: false));
        }
      }
    } catch (e) {
      children.add(
        TreeNode(
          name: '[error: $e]',
          isDirectory: false,
        ),
      );
    }

    return TreeNode(name: name, isDirectory: true, children: children);
  }
}
