import 'scan_source_type.dart';
import 'tree_node.dart';

class TreeBuild {
  const TreeBuild({
    required this.id,
    required this.rootPath,
    required this.rootName,
    required this.root,
    required this.treeText,
    required this.createdAt,
    this.maxDepth,
    this.expandAllFolders = false,
    this.scanSourceType = ScanSourceType.local,
  });

  final String id;
  final String rootPath;
  final String rootName;
  final TreeNode root;
  final String treeText;
  final DateTime createdAt;
  final int? maxDepth;
  final bool expandAllFolders;
  final ScanSourceType scanSourceType;

  int get fileCount => root.fileCount;
  int get folderCount => root.folderCount;

  TreeBuild copyWith({
    String? id,
    String? rootPath,
    String? rootName,
    TreeNode? root,
    String? treeText,
    DateTime? createdAt,
    int? maxDepth,
    bool? expandAllFolders,
    ScanSourceType? scanSourceType,
  }) {
    return TreeBuild(
      id: id ?? this.id,
      rootPath: rootPath ?? this.rootPath,
      rootName: rootName ?? this.rootName,
      root: root ?? this.root,
      treeText: treeText ?? this.treeText,
      createdAt: createdAt ?? this.createdAt,
      maxDepth: maxDepth ?? this.maxDepth,
      expandAllFolders: expandAllFolders ?? this.expandAllFolders,
      scanSourceType: scanSourceType ?? this.scanSourceType,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'rootPath': rootPath,
        'rootName': rootName,
        'root': root.toJson(),
        'treeText': treeText,
        'createdAt': createdAt.toIso8601String(),
        if (maxDepth != null) 'maxDepth': maxDepth,
        if (expandAllFolders) 'expandAllFolders': expandAllFolders,
        if (scanSourceType != ScanSourceType.local)
          'scanSourceType': scanSourceType.name,
      };

  factory TreeBuild.fromJson(Map<String, dynamic> json) {
    return TreeBuild(
      id: json['id'] as String,
      rootPath: json['rootPath'] as String,
      rootName: json['rootName'] as String,
      root: TreeNode.fromJson(json['root'] as Map<String, dynamic>),
      treeText: json['treeText'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      maxDepth: json['maxDepth'] as int?,
      expandAllFolders: json['expandAllFolders'] as bool? ?? false,
      scanSourceType: _parseScanSourceType(json['scanSourceType'] as String?),
    );
  }

  static ScanSourceType _parseScanSourceType(String? value) {
    if (value == null) return ScanSourceType.local;
    return ScanSourceType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => ScanSourceType.local,
    );
  }
}
