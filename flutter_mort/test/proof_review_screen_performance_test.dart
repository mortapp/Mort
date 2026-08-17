import 'package:flutter/material.dart';
import 'package:flutter_mort/data/models/proof.dart';
import 'package:flutter_mort/data/repositories/applications_repository.dart';
import 'package:flutter_mort/data/repositories/providers.dart';
import 'package:flutter_mort/data/repositories/uploads_repository.dart';
import 'package:flutter_mort/features/jobs/proof_review_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeApplicationsRepository extends ApplicationsRepository {
  @override
  Future<List<ProofUpload>> listProofs(String applicationId) async {
    return [
      ProofUpload(
        id: 'proof-1',
        applicationId: applicationId,
        uploadedBy: 'teen-1',
        storagePath: 'teen-1/proof-1.jpg',
        status: 'submitted',
        createdAt: DateTime(2026, 1, 1),
      ),
    ];
  }
}

class _FailingUploadsRepository extends UploadsRepository {
  int signedUrlCalls = 0;

  @override
  Future<String> signedUrl(String bucket, String path, {int expiresIn = 600}) {
    signedUrlCalls += 1;
    return Future<String>.error(StateError('Synthetic signed URL failure'));
  }
}

Widget _app({
  required ApplicationsRepository applications,
  required UploadsRepository uploads,
  required Brightness brightness,
}) {
  return ProviderScope(
    overrides: [
      applicationsRepositoryProvider.overrideWithValue(applications),
      uploadsRepositoryProvider.overrideWithValue(uploads),
    ],
    child: MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: const ProofReviewScreen(applicationId: 'application-1'),
    ),
  );
}

void main() {
  testWidgets('rebuilds do not request duplicate signed proof URLs', (
    tester,
  ) async {
    final applications = _FakeApplicationsRepository();
    final uploads = _FailingUploadsRepository();

    await tester.pumpWidget(
      _app(
        applications: applications,
        uploads: uploads,
        brightness: Brightness.dark,
      ),
    );
    await tester.pumpAndSettle();

    expect(uploads.signedUrlCalls, 1);
    expect(find.text('Private image unavailable'), findsOneWidget);

    await tester.pumpWidget(
      _app(
        applications: applications,
        uploads: uploads,
        brightness: Brightness.light,
      ),
    );
    await tester.pumpAndSettle();

    expect(uploads.signedUrlCalls, 1);

    await tester.tap(find.text('Retry signed image'));
    await tester.pumpAndSettle();

    expect(uploads.signedUrlCalls, 2);
  });
}
