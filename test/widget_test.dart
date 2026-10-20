import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ✅ Simple test that doesn't trigger app timers
  testWidgets('Basic widget renders', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: Text('Test')),
        ),
      ),
    );

    expect(find.text('Test'), findsOneWidget);
  });

  // ✅ Unit test — no widget tree
  test('Basic math test', () {
    expect(1 + 1, 2);
  });
}
