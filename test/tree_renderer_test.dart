import 'package:flutter_test/flutter_test.dart';
import 'package:tree_builder/models/tree_node.dart';
import 'package:tree_builder/utils/tree_renderer.dart';

void main() {
  final root = TreeNode(
    name: 'root',
    isDirectory: true,
    children: [
      TreeNode(
        name: 'folder',
        isDirectory: true,
        children: [
          const TreeNode(name: 'inner.txt', isDirectory: false),
        ],
      ),
      const TreeNode(name: 'top.txt', isDirectory: false),
    ],
  );

  test('renderFull includes nested files', () {
    final text = TreeRenderer.renderFull('root', root.children);
    expect(text, contains('inner.txt'));
    expect(text, contains('top.txt'));
  });

  test('renderVisible collapses nested folders by default', () {
    final text = TreeRenderer.renderVisible('root', root.children, {});
    expect(text, contains('folder/'));
    expect(text, isNot(contains('inner.txt')));
    expect(text, contains('top.txt'));
  });

  test('renderVisible expands selected folder', () {
    final text = TreeRenderer.renderVisible(
      'root',
      root.children,
      {'folder'},
    );
    expect(text, contains('inner.txt'));
  });
}
