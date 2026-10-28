import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mort/data/models/trust_safety.dart';
import 'package:flutter_mort/data/repositories/providers.dart';
import 'package:flutter_mort/data/repositories/trust_safety_repository.dart';
import 'package:flutter_mort/features/trust/teen_verification_screens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class _RuntimeVerificationRepository extends TrustSafetyRepository {
  _RuntimeVerificationRepository(this.status);

  final IdentityVerificationStatus status;

  @override
  Future<IdentityVerificationStatus> getIdentityStatus() async => status;
}

IdentityVerificationStatus _status({
  required bool submissionsEnabled,
  required bool productionProviderAvailable,
  required bool documentsCollectedByMort,
}) => IdentityVerificationStatus.fromMap({
  'status': 'unverified',
  'verification_mode': 'production',
  'submissions_enabled': submissionsEnabled,
  'production_provider_available': productionProviderAvailable,
  'documents_collected_by_mort': documentsCollectedByMort,
});

void main() {
  testWidgets('does not offer capture when production provider is unavailable', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trustSafetyRepositoryProvider.overrideWithValue(
            _RuntimeVerificationRepository(
              _status(
                submissionsEnabled: false,
                productionProviderAvailable: false,
                documentsCollectedByMort: false,
              ),
            ),
          ),
        ],
        child: const MaterialApp(
          home: TeenVerificationCapturePreparationScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Use camera'), findsNothing);
    expect(
      find.text('Production verification is not available yet.'),
      findsOneWidget,
    );
    expect(
      find.textContaining('MORT is not accepting real identity documents'),
      findsOneWidget,
    );
  });
}
