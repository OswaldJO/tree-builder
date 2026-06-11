import 'package:flutter_test/flutter_test.dart';
import 'package:tree_builder/models/tree_node.dart';
import 'package:tree_builder/utils/map_cast.dart';

void main() {
  test('deepCastMap parses nested platform channel maps', () {
    final raw = <Object?, Object?>{
      'name': 'root',
      'isDirectory': true,
      'children': <Object?>[
        <Object?, Object?>{
          'name': 'game.iso',
          'isDirectory': false,
          'children': <Object?>[],
        },
      ],
    };

    final node = TreeNode.fromJson(deepCastMap(raw));
    expect(node.name, 'root');
    expect(node.children.single.name, 'game.iso');
    expect(node.children.single.isDirectory, isFalse);
  });
}
