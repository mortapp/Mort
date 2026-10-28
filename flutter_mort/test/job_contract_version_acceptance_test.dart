import 'package:flutter/material.dart';
import 'package:flutter_mort/core/theme/mort_theme.dart';
import 'package:flutter_mort/data/repositories/legal_contract_repository.dart';
import 'package:flutter_mort/data/repositories/providers.dart';
import 'package:flutter_mort/features/legal/contract_payment_screens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _ContractRepository extends LegalContractRepository {
  @override
  Future<List<Map<String, dynamic>>> contractVersions(
    String contractId,
  ) async => [
    {
      'id': 'version-current',
      'content_hash': 'b' * 64,
      'version_number': 2,
      'status': 'active',
      'teen_public_identifier': 'teen_user',
      'adult_public_identifier': 'adult_user',
      'agreed_scope': 'Current scope',
      'excluded_work': <String>[],
      'completion_requirements': 'Complete the work',
      'proof_requirements': 'No proof required',
      'service_date': null,
      'start_window': null,
      'expected_end_window': null,
      'location_type': 'public_place',
      'exact_location_release_state': 'accepted_not_released',
      'amount_type': 'fixed',
      'fixed_total_cents': 1000,
      'currency_code': 'USD',
      'payment_preference': 'flexible',
      'payment_due_rule': 'after_completion',
      'authorized_expenses': <String>[],
      'equipment': null,
      'hazards': null,
      'expected_people_present': null,
      'supervision': null,
      'cancellation_terms': 'Contact the other party before cancelling.',
      'material_change_process': 'Both parties must confirm changes.',
      'dispute_process': 'Use private support.',
      'safety_agreement_version': 'job-safety-v1',
    },
  ];

  @override
  Future<List<Map<String, dynamic>>> contractAcceptances(
    String contractId,
  ) async => [
    {
      'id': 'old-teen-acceptance',
      'contract_version_id': 'version-old',
      'user_id': 'teen-user',
      'party_role': 'teen',
      'content_hash': 'a' * 64,
      'accepted_at': '2026-10-27T12:00:00Z',
    },
    {
      'id': 'current-adult-acceptance',
      'contract_version_id': 'version-current',
      'user_id': 'adult-user',
      'party_role': 'adult',
      'content_hash': 'b' * 64,
      'accepted_at': '2026-10-28T12:00:00Z',
    },
  ];
}

void main() {
  testWidgets('only confirmations for the displayed version are shown', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          legalContractRepositoryProvider.overrideWithValue(
            _ContractRepository(),
          ),
        ],
        child: MaterialApp(
          theme: MortTheme.dark(),
          home: const JobContractScreen(contractId: 'contract-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Adult confirmed'), findsOneWidget);
    expect(find.text('Teen confirmed'), findsNothing);
    expect(
      find.text('No party has confirmed this exact version yet.'),
      findsNothing,
    );
  });
}
