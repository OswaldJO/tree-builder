import '../models/tree_node.dart';

class TreeRenderer {
  static String pathKey(List<String> segments) => segments.join('/');

  static Set<String> allFolderPaths(TreeNode root) {
    return allFolderPathsFromChildren(root.children);
  }

  static Set<String> allFolderPathsFromChildren(List<TreeNode> children) {
    final paths = <String>{};
    void walk(List<TreeNode> nodes, List<String> prefix) {
      for (final child in nodes) {
        if (!child.isDirectory) continue;
        final segments = [...prefix, child.name];
        paths.add(pathKey(segments));
        walk(child.children, segments);
      }
    }

    walk(children, const []);
    return paths;
  }

  static String renderFull(String rootName, List<TreeNode> children) {
    return renderVisible(
      rootName,
      children,
      allFolderPathsFromChildren(children),
    );
  }

  static String renderVisible(
    String rootName,
    List<TreeNode> children,
    Set<String> expandedPaths,
  ) {
    final buffer = StringBuffer('$rootName/\n');
    _renderChildren(buffer, children, const [], expandedPaths, '');
    return buffer.toString().trimRight();
  }

  static void _renderChildren(
    StringBuffer buffer,
    List<TreeNode> children,
    List<String> pathSegments,
    Set<String> expandedPaths,
    String prefix,
  ) {
    for (var i = 0; i < children.length; i++) {
      final child = children[i];
      final isLast = i == children.length - 1;
      final connector = isLast ? '└── ' : '├── ';
      final childPrefix = isLast ? '    ' : '│   ';
      final displayName = child.isDirectory ? '${child.name}/' : child.name;

      buffer.write('$prefix$connector$displayName\n');

      if (child.isDirectory) {
        final segments = [...pathSegments, child.name];
        if (expandedPaths.contains(pathKey(segments))) {
          _renderChildren(
            buffer,
            child.children,
            segments,
            expandedPaths,
            prefix + childPrefix,
          );
        }
      }
    }
  }
}
