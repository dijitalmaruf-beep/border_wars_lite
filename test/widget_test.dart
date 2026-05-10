// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:chroma_conquest/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the home screen title', (WidgetTester tester) async {
    await tester.pumpWidget(const ChromaConquestApp());

    await tester.pump();

    expect(find.text('CHROMA'), findsOneWidget);
    expect(find.text('CONQUEST'), findsOneWidget);
  });
}
