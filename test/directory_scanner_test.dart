import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tree_builder/services/directory_scanner.dart';

void main() {
  const scanner = DirectoryScanner();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tree_builder_test_');
    await File('${tempDir.path}/game.iso').writeAsString('iso');
    await File('${tempDir.path}/disc.chd').writeAsString('chd');
    final sub = Directory('${tempDir.path}/nested');
    await sub.create();
    await File('${sub.path}/inner.iso').writeAsString('inner');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('includes files with uncommon extensions', () async {
    final build = await scanner.scanDirectory(tempDir.path);
    expect(build.treeText, contains('game.iso'));
    expect(build.treeText, contains('disc.chd'));
    expect(build.treeText, contains('inner.iso'));
    expect(build.fileCount, 3);
  });

  test('respects max depth', () async {
    final build = await scanner.scanDirectory(tempDir.path, maxDepth: 1);
    expect(build.treeText, contains('nested/'));
    expect(build.treeText, isNot(contains('inner.iso')));
    expect(build.fileCount, 2);
  });
}
