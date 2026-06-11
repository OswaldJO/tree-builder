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
  });

  final String id;
  final String rootPath;
  final String rootName;
  final TreeNode root;
  final String treeText;
  final DateTime createdAt;
  final int? maxDepth;

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
  }) {
    return TreeBuild(
      id: id ?? this.id,
      rootPath: rootPath ?? this.rootPath,
      rootName: rootName ?? this.rootName,
      root: root ?? this.root,
      treeText: treeText ?? this.treeText,
      createdAt: createdAt ?? this.createdAt,
      maxDepth: maxDepth ?? this.maxDepth,
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
    );
  }
}
