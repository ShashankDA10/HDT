import 'package:flutter_test/flutter_test.dart';
import 'package:bodyclone/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Just verify the widget tree can be built without throwing.
    await tester.pumpWidget(const BodyCloneApp());
  });
}
