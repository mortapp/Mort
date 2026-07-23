import 'package:flutter/material.dart';
import 'package:flutter_mort/data/repositories/job_execution_repository.dart';
import 'package:flutter_mort/features/jobs/job_progress_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('adult job progress shows server state and role actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: JobProgressScreen(
            applicationId: 'synthetic-widget-qa',
            syntheticStatusForTesting: JobExecutionStatus(
              applicationId: 'synthetic-widget-qa',
              jobId: 'job-widget-qa',
              contractId: 'contract-widget-qa',
              role: 'adult',
              state: 'awaiting_start',
              fundingStatus: 'funded',
              startPinActive: false,
              finishPinActive: false,
              livePaymentEnabled: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Job progress'), findsOneWidget);
    expect(find.text('Funds collected'), findsOneWidget);
    expect(find.text('Adult actions'), findsOneWidget);
    expect(find.text('Generate start PIN'), findsOneWidget);
    expect(find.text('Generate finish PIN - Unavailable'), findsOneWidget);
    expect(
      find.textContaining('Live payments remain disabled'),
      findsOneWidget,
    );
  });

  testWidgets(
    'teen finish state exposes safe refusal and mismatch boundaries',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: JobProgressScreen(
              applicationId: 'synthetic-teen-widget-qa',
              syntheticStatusForTesting: JobExecutionStatus(
                applicationId: 'synthetic-teen-widget-qa',
                jobId: 'job-widget-qa',
                contractId: 'contract-widget-qa',
                role: 'teen',
                state: 'finish_pin_active',
                fundingStatus: 'funded',
                startPinActive: false,
                finishPinActive: true,
                livePaymentEnabled: false,
                startedAt: DateTime.utc(2026, 7, 22, 18),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Teen actions'), findsOneWidget);
      expect(find.text('Finish PIN'), findsOneWidget);
      expect(find.text('Confirm job finish'), findsOneWidget);
      expect(find.text('Finish PIN refused'), findsOneWidget);
      expect(find.text('Person mismatch - Unavailable'), findsOneWidget);
    },
  );
}
