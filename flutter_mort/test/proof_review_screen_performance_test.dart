import 'package:flutter/material.dart';
import 'package:flutter_mort/data/models/application.dart';
import 'package:flutter_mort/data/models/proof.dart';
import 'package:flutter_mort/data/repositories/applications_repository.dart';
import 'package:flutter_mort/data/repositories/providers.dart';
import 'package:flutter_mort/data/repositories/uploads_repository.dart';
import 'package:flutter_mort/features/jobs/proof_review_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/mort_widget_harness.dart';

class _FakeApplicationsRepository extends ApplicationsRepository {
  _FakeApplicationsRepository({this.proofStatus = 'submitted'});

  final String proofStatus;
  final List<String> statusUpdates = [];

  @override
  Future<List<ProofUpload>> listProofs(String applicationId) async {
    return [
      ProofUpload(
        id: 'proof-1',
        applicationId: applicationId,
        uploadedBy: 'teen-1',
        storagePath: 'teen-1/proof-1.jpg',
        status: proofStatus,
        createdAt: DateTime(2026, 1, 1),
      ),
    ];
  }

  @override
  Future<MortApplication> updateStatus(
    String applicationId,
    String action, {
    String? clientRequestId,
    DateTime? expectedUpdatedAt,
  }) {
    statusUpdates.add(action);
    throw StateError('Proof review must not update application lifecycle');
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
  testMortWidgets('rebuilds do not request duplicate signed proof URLs', (
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

    await tester.ensureVisible(find.text('Retry signed image'));
    await tester.tap(find.text('Retry signed image').hitTestable());
    await tester.pumpAndSettle();

    expect(uploads.signedUrlCalls, 2);
  });

  testMortWidgets(
    'approved proof continues through canonical finish progress without completing',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final applications = _FakeApplicationsRepository(proofStatus: 'approved');
      final uploads = _FailingUploadsRepository();
      final router = GoRouter(
        initialLocation: '/proof-review',
        routes: [
          GoRoute(
            path: '/proof-review',
            builder: (_, _) => const MediaQuery(
              data: MediaQueryData(
                size: Size(320, 568),
                disableAnimations: true,
                textScaler: TextScaler.linear(2),
              ),
              child: ProofReviewScreen(applicationId: 'application-1'),
            ),
          ),
          GoRoute(
            path: '/jobs/progress/:applicationId',
            builder: (_, state) => Scaffold(
              body: Text(
                'Progress destination ${state.pathParameters['applicationId']}',
              ),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            applicationsRepositoryProvider.overrideWithValue(applications),
            uploadsRepositoryProvider.overrideWithValue(uploads),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Open job progress'), findsOneWidget);
      expect(find.text('Mark job complete'), findsNothing);

      await tester.ensureVisible(find.text('Open job progress'));
      await tester.pumpAndSettle();
      expect(find.text('Open job progress').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Open job progress').hitTestable());
      await tester.pumpAndSettle();

      expect(find.text('Progress destination application-1'), findsOneWidget);
      expect(applications.statusUpdates, isEmpty);
    },
  );
}
