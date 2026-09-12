import 'package:flutter_test/flutter_test.dart';

import 'package:cafe_and_brews/main.dart';

void main() {
  testWidgets('renders the POS shell', (tester) async {
    await tester.pumpWidget(const CoffeePosApp());
    await tester.pumpAndSettle();

    expect(find.text('Firebase is not initialized'), findsOneWidget);
  });
}
