import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_mort/app.dart';

void main() {
  testWidgets('MORT app renders without Supabase secrets', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MortApp()));
    await tester.pumpAndSettle();

    expect(find.text('MORT'), findsWidgets);
    expect(find.text('Earn nearby. Move smart.'), findsOneWidget);
  });
}
