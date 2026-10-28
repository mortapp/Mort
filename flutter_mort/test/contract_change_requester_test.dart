import 'package:flutter/material.dart';
import 'package:flutter_mort/core/theme/mort_theme.dart';
import 'package:flutter_mort/data/models/profile.dart';
import 'package:flutter_mort/data/repositories/legal_contract_repository.dart';
import 'package:flutter_mort/data/repositories/providers.dart';
import 'package:flutter_mort/features/legal/contract_payment_screens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _ContractRepository extends LegalContractRepository {
  @override
  Future<List<Map<String, dynamic>>> contractChanges(String contractId) async =>
      [
        {
          'id': 'change-1',
          'contract_id': contractId,
          'requested_by': 'teen-user',
          'change_categories': ['scope'],
          'proposed_terms': {'agreed_scope': 'Updated task'},
          'proposed_content_hash': 'a' * 64,
          'reason': 'The original scope needs clarification.',
          'status': 'pending_both_parties',
          'requested_at': '2026-10-28T12:00:00Z',
        },
      ];
}

void main() {
  testWidgets('requester waits for the other party instead of responding', (
    tester,
  ) async {
    const profile = Profile(
      id: 'teen-user',
      role: UserRole.teen,
      displayName: 'Teen',
      username: 'teen_user',
      dob: null,
      city: null,
      state: null,
      onboardingCompleted: true,
      accountStatus: 'active',
      verificationStatus: 'verified',
      paymentPreference: 'flexible',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          legalContractRepositoryProvider.overrideWithValue(
            _ContractRepository(),
          ),
          currentProfileProvider.overrideWith((ref) async => profile),
        ],
        child: MaterialApp(
          theme: MortTheme.dark(),
          home: const ContractChangeScreen(contractId: 'contract-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Waiting for the other party to respond.'),
      findsOneWidget,
    );
    expect(find.text('Accept exact proposal'), findsNothing);
    expect(find.text('Decline proposal'), findsNothing);
  });

  testWidgets('other party can respond to a pending proposal', (tester) async {
    const profile = Profile(
      id: 'adult-user',
      role: UserRole.adult,
      displayName: 'Adult',
      username: 'adult_user',
      dob: null,
      city: null,
      state: null,
      onboardingCompleted: true,
      accountStatus: 'active',
      verificationStatus: 'verified',
      paymentPreference: 'flexible',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          legalContractRepositoryProvider.overrideWithValue(
            _ContractRepository(),
          ),
          currentProfileProvider.overrideWith((ref) async => profile),
        ],
        child: MaterialApp(
          theme: MortTheme.dark(),
          home: const ContractChangeScreen(contractId: 'contract-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Accept exact proposal'), findsOneWidget);
    expect(find.text('Decline proposal'), findsOneWidget);
    expect(find.text('Waiting for the other party to respond.'), findsNothing);
  });
}
