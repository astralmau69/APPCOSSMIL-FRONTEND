import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/app.dart';

void main() {
  testWidgets('App launches', (WidgetTester tester) async {
    await tester.pumpWidget(const CossmilApp());
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });
}
