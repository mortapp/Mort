import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mort/data/models/trust_safety.dart';
import 'package:flutter_mort/data/repositories/providers.dart';
import 'package:flutter_mort/data/repositories/trust_safety_repository.dart';
import 'package:flutter_mort/features/safety/trust_safety_screens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class _UnavailableIdentityRepository extends TrustSafetyRepository {
  @override
  Future<IdentityVerificationStatus> getIdentityStatus() async =>
      IdentityVerificationStatus.fromMap(const {
        'ok': true,
        'status': 'unverified',
        'verification_level': 0,
        'marketplace_enabled': false,
        'guardian_mode_optional': true,
        'verification_mode': 'disabled',
        'production_verified': false,
        'sandbox_eligible': false,
        'test_mode': false,
        'submissions_enabled': false,
        'production_provider_available': false,
        'can_retry': false,
        'support_escalation_available': false,
        'documents_collected_by_mort': false,
        'failure_code': 'production_provider_unavailable',
      });
}

class _ProviderReadyButSubmissionsDisabledRepository
    extends TrustSafetyRepository {
  @override
  Future<IdentityVerificationStatus> getIdentityStatus() async =>
      IdentityVerificationStatus.fromMap(const {
        'ok': true,
        'status': 'unverified',
        'verification_level': 0,
        'marketplace_enabled': false,
        'guardian_mode_optional': true,
        'verification_mode': 'production',
        'production_verified': false,
        'sandbox_eligible': false,
        'test_mode': false,
        'submissions_enabled': false,
        'production_provider_available': true,
        'can_retry': false,
        'support_escalation_available': true,
        'documents_collected_by_mort': false,
      });
}

void main() {
  testWidgets('identity screen reports unavailable without offering upload', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trustSafetyRepositoryProvider.overrideWithValue(
            _UnavailableIdentityRepository(),
          ),
        ],
        child: const MaterialApp(home: IdentityVerificationScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Marketplace actions locked'), findsOneWidget);
    expect(
      find.text(
        'Identity verification is not accepting public submissions yet.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Do not upload an ID'), findsOneWidget);
    expect(find.text('Continue to provider'), findsNothing);
    expect(find.text('Start simulated verification'), findsNothing);
  });

  testWidgets(
    'identity screen does not start provider while submissions are off',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            trustSafetyRepositoryProvider.overrideWithValue(
              _ProviderReadyButSubmissionsDisabledRepository(),
            ),
          ],
          child: const MaterialApp(home: IdentityVerificationScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Production provider unavailable'), findsOneWidget);
      expect(find.text('Continue to provider'), findsNothing);
    },
  );
}
