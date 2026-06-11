import 'package:flutter_test/flutter_test.dart';
import 'package:tree_builder/main.dart';

void main() {
  testWidgets('App loads home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const TreeBuilderApp());
    expect(find.text('Tree Builder'), findsOneWidget);
    expect(find.text('Choose Directory'), findsOneWidget);
  });
}
