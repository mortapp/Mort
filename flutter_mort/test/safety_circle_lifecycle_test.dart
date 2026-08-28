import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_mort/data/models/profile.dart';
import 'package:flutter_mort/data/models/trust_safety.dart';
import 'package:flutter_mort/data/repositories/providers.dart';
import 'package:flutter_mort/data/repositories/trust_safety_repository.dart';
import 'package:flutter_mort/features/safety/trust_safety_screens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _DeferredSafetyCircleRepository extends TrustSafetyRepository {
  final acceptCompleter = Completer<void>();
  int listCalls = 0;

  @override
  Future<List<SafetyCircleContact>> listSafetyCircle() async {
    listCalls += 1;
    return const [];
  }

  @override
  Future<void> acceptSafetyCircleInvite(String code) {
    return acceptCompleter.future;
  }
}

Profile _guardianProfile() => Profile(
  id: 'guardian-qa',
  role: UserRole.guardian,
  displayName: 'Guardian QA',
  username: 'guardian_qa',
  dob: DateTime(1985, 1, 1),
  city: 'Test City',
  state: 'TS',
  onboardingCompleted: true,
  accountStatus: 'active',
  verificationStatus: 'not_started',
  paymentPreference: 'none',
);

void main() {
  testWidgets('leaving Safety Circle during invite acceptance is safe', (
    tester,
  ) async {
    final repository = _DeferredSafetyCircleRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trustSafetyRepositoryProvider.overrideWithValue(repository),
          currentProfileProvider.overrideWithValue(
            AsyncValue.data(_guardianProfile()),
          ),
        ],
        child: const MaterialApp(home: SafetyCircleScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'SAFE-CODE');
    await tester.tap(find.text('Accept invitation'));
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));

    repository.acceptCompleter.complete();
    await tester.pump();

    expect(repository.listCalls, 1);
    expect(tester.takeException(), isNull);
  });
}
