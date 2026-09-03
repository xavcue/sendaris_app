import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/app/app.dart';

void main() {
  testWidgets('Sendaris inicia correctamente', (tester) async {
    await tester.pumpWidget(const SendarisApp());
    await tester.pumpAndSettle();

    expect(find.text('Sendaris'), findsOneWidget);
  });
}
