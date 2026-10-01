import 'package:flutter_test/flutter_test.dart';

import 'package:gushi_helper/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const GushiHelperApp());
    expect(find.text('古诗背诵'), findsOneWidget);
  });
}
