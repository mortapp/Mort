import 'package:flutter_mort/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('MORT app renders without Supabase secrets', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MortApp()));
    await tester.pumpAndSettle();

    expect(find.text('MORT cannot start securely'), findsOneWidget);
    expect(find.text('Secure startup stopped'), findsOneWidget);
    expect(find.text('Sign in'), findsNothing);

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme?.brightness, Brightness.light);
    expect(app.darkTheme?.brightness, Brightness.dark);
    expect(app.themeMode, ThemeMode.system);
  });
}
