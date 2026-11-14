import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flora_sense_ai/main.dart';

import 'support/mock_api_client.dart';

void main() {
  testWidgets('dashboard shell renders', (tester) async {
    await tester.pumpWidget(FloraSenseApp(api: MockFloraApiClient()));
    expect(find.text('Dashboard'), findsWidgets);
    await tester.pumpAndSettle();
    expect(find.text('ความเสี่ยงการขาดน้ำ'), findsOneWidget);
  });

  testWidgets('profile can sign out and sign in', (tester) async {
    await tester.pumpWidget(FloraSenseApp(api: MockFloraApiClient()));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.person));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ออกจากระบบ'));
    await tester.pumpAndSettle();

    expect(find.text('ออกจากระบบแล้ว'), findsOneWidget);
    expect(find.text('เข้าสู่ระบบ'), findsOneWidget);

    await tester.tap(find.text('เข้าสู่ระบบ'));
    await tester.pumpAndSettle();
    expect(find.text('Dashboard'), findsWidgets);
  });
}
