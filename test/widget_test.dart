import 'package:flutter_test/flutter_test.dart';
import 'package:pantry/main.dart';

void main() {
  testWidgets('Pantry app builds', (WidgetTester tester) async {
    await tester.pumpWidget(const PantryApp());
    await tester.pump();
    expect(find.byType(PantryApp), findsOneWidget);
  });
}
