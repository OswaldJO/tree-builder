import 'package:flutter_test/flutter_test.dart';
import 'package:tree_builder/models/library_sort_option.dart';
import 'package:tree_builder/models/tree_build.dart';
import 'package:tree_builder/models/tree_node.dart';

TreeBuild _build(String name, DateTime createdAt) {
  return TreeBuild(
    id: name,
    rootPath: '/$name',
    rootName: name,
    root: TreeNode(name: name, isDirectory: true),
    treeText: name,
    createdAt: createdAt,
  );
}

void main() {
  final older = _build('Alpha', DateTime(2024, 1, 1));
  final newer = _build('Zeta', DateTime(2025, 1, 1));
  final middle = _build('Middle', DateTime(2024, 6, 1));
  final builds = [older, newer, middle];

  test('sorts alphabetically', () {
    final sorted = sortTreeBuilds(builds, LibrarySortOption.alphabetical);
    expect(sorted.map((b) => b.rootName).toList(), ['Alpha', 'Middle', 'Zeta']);
  });

  test('sorts reverse alphabetically', () {
    final sorted =
        sortTreeBuilds(builds, LibrarySortOption.reverseAlphabetical);
    expect(sorted.map((b) => b.rootName).toList(), ['Zeta', 'Middle', 'Alpha']);
  });

  test('sorts by newest', () {
    final sorted = sortTreeBuilds(builds, LibrarySortOption.newest);
    expect(sorted.map((b) => b.rootName).toList(), ['Zeta', 'Middle', 'Alpha']);
  });

  test('sorts by oldest', () {
    final sorted = sortTreeBuilds(builds, LibrarySortOption.oldest);
    expect(sorted.map((b) => b.rootName).toList(), ['Alpha', 'Middle', 'Zeta']);
  });
}
