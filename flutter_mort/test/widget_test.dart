import 'package:flutter_mort/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('MORT app renders without Supabase secrets', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MortApp()));
    await tester.pumpAndSettle();

    expect(find.text('MORT cannot start securely'), findsOneWidget);
    expect(find.text('Secure startup stopped'), findsOneWidget);
    expect(find.text('Sign in'), findsNothing);
  });
}
