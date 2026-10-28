import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mort/data/repositories/mort_guide_repository.dart';
import 'package:flutter_mort/data/repositories/providers.dart';
import 'package:flutter_mort/features/guide/mort_guide_screens.dart';

class _UnavailableMortGuideRepository extends MortGuideRepository {
  @override
  Future<Map<String, dynamic>> getConfig() async {
    throw StateError('Guide configuration is unavailable.');
  }
}

void main() {
  testWidgets(
    'Guide hides questions and composer when backend is unavailable',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mortGuideRepositoryProvider.overrideWithValue(
              _UnavailableMortGuideRepository(),
            ),
          ],
          child: const MaterialApp(home: MortGuideView()),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('MORT Guide is temporarily unavailable.'),
        findsOneWidget,
      );
      expect(find.text('MORT Guide unavailable'), findsOneWidget);
      expect(find.text('Approved MORT help'), findsNothing);
      expect(find.text('Ask a MORT question'), findsNothing);
      expect(find.text('Send'), findsNothing);
      expect(find.text('Open human support'), findsOneWidget);
    },
  );
}
