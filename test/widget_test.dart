import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth_2048/main.dart';

void main() {
  testWidgets('Rebirth 2048 app loads', (WidgetTester tester) async {
    await tester.pumpWidget(const Rebirth2048App());

    expect(find.byType(Rebirth2048App), findsOneWidget);
  });
}