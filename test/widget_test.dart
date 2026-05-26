import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soyyo/features/splash/presentation/splash_page.dart';

void main() {
  testWidgets('SplashPage renderiza sem Firebase', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: SplashPage()),
    );
    await tester.pump();
    expect(find.text('Garantir'), findsOneWidget);
  });
}
