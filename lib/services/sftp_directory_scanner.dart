import 'package:dartssh2/dartssh2.dart';
import 'package:uuid/uuid.dart';

import '../models/remote_settings.dart';
import '../models/scan_progress.dart';
import '../models/scan_source_type.dart';
import '../models/tree_build.dart';
import '../models/tree_node.dart';
import '../utils/tree_renderer.dart';
import 'scan_counters.dart';

class SftpDirectoryScanner {
  const SftpDirectoryScanner({
    required this.settings,
    required this.remotePath,
  });

  final SftpSettings settings;
  final String remotePath;

  static const _uuid = Uuid();

  Future<TreeBuild> scan({
    int? maxDepth,
    void Function(ScanProgress progress)? onProgress,
  }) async {
    final socket = await SSHSocket.connect(
      settings.host.trim(),
      settings.port,
    );
    final client = SSHClient(
      socket,
      username: settings.username.trim(),
      onPasswordRequest: () => settings.password,
    );

    try {
      final sftp = await client.sftp();
      final path = RemotePath.normalize(remotePath);
      final rootName = RemotePath.basename(path);
      final counters = ScanCounters();
      onProgress?.call(const ScanProgress(folders: 0, files: 0));

      final root = await _buildNode(
        sftp,
        path,
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
        scanSourceType: ScanSourceType.sftp,
      );
    } finally {
      client.close();
    }
  }

  Future<TreeNode> _buildNode(
    SftpClient sftp,
    String path,
    String name, {
    required int currentDepth,
    int? maxDepth,
    ScanCounters? counters,
    void Function(ScanProgress progress)? onProgress,
  }) async {
    final children = <TreeNode>[];

    try {
      final entities = await sftp.listdir(path);
      entities.sort((a, b) {
        final aIsDir = a.attr.isDirectory;
        final bIsDir = b.attr.isDirectory;
        if (aIsDir != bIsDir) return aIsDir ? -1 : 1;
        return a.filename.toLowerCase().compareTo(b.filename.toLowerCase());
      });

      for (final entity in entities) {
        if (entity.filename == '.' || entity.filename == '..') continue;

        if (entity.attr.isDirectory) {
          counters?.folders++;
          if (counters != null) {
            await counters.maybeReport(entity.filename, onProgress);
          }

          if (maxDepth != null && currentDepth >= maxDepth) {
            children.add(
              TreeNode(
                name: entity.filename,
                isDirectory: true,
                children: const [],
              ),
            );
          } else {
            final childPath = RemotePath.join(path, entity.filename);
            children.add(
              await _buildNode(
                sftp,
                childPath,
                entity.filename,
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
            await counters.maybeReport(entity.filename, onProgress);
          }
          children.add(TreeNode(name: entity.filename, isDirectory: false));
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
