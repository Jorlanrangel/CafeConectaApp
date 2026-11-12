import 'package:flutter_test/flutter_test.dart';
import 'package:cafeconecta_aplication/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const CafeConectaApp());
    expect(find.byType(CafeConectaApp), findsOneWidget);
  });
}