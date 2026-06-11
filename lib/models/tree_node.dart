class TreeNode {
  const TreeNode({
    required this.name,
    required this.isDirectory,
    this.children = const [],
  });

  final String name;
  final bool isDirectory;
  final List<TreeNode> children;

  int get fileCount {
    if (!isDirectory) return 1;
    return children.fold(0, (sum, child) => sum + child.fileCount);
  }

  int get folderCount {
    if (!isDirectory) return 0;
    return 1 + children.fold(0, (sum, child) => sum + child.folderCount);
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'isDirectory': isDirectory,
        'children': children.map((c) => c.toJson()).toList(),
      };

  factory TreeNode.fromJson(Map<String, dynamic> json) {
    return TreeNode(
      name: json['name'] as String,
      isDirectory: json['isDirectory'] as bool,
      children: (json['children'] as List<dynamic>? ?? [])
          .map((c) => TreeNode.fromJson(c as Map<String, dynamic>))
          .toList(),
    );
  }
}
