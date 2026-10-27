import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_mort/core/theme/mort_theme.dart';
import 'package:flutter_mort/data/models/job.dart';
import 'package:flutter_mort/data/repositories/providers.dart';
import 'package:flutter_mort/features/teen/teen_marketplace_home_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/mort_widget_harness.dart';

void main() {
  testMortWidgets(
    'teen Home starts with local jobs and keeps search in Explore',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            openJobsProvider.overrideWith2(_PreviewJobsController.new),
          ],
          child: MaterialApp(
            theme: MortTheme.light(),
            home: const TeenMarketplaceHomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Jobs near you'), findsOneWidget);
      expect(find.text('Quick Jobs'), findsOneWidget);
      expect(find.text('Open jobs'), findsOneWidget);
      expect(find.text('Yard cleanup'), findsWidgets);
      expect(find.text(r'$25.00'), findsWidgets);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('123 Exact Street'), findsNothing);
    },
  );
}

class _PreviewJobsController extends OpenJobsController {
  _PreviewJobsController(super.filters);

  @override
  Future<JobFeedState> build() async =>
      const JobFeedState(items: [_previewJob], hasMore: false);
}

const _previewJob = Job(
  id: 'preview-job',
  posterId: 'preview-poster',
  title: 'Yard cleanup',
  description: 'Collect leaves and tidy the front garden.',
  category: 'Yard work',
  locationText: 'Broad Ripple area',
  city: 'Indianapolis',
  state: 'IN',
  status: 'open',
  requiresGuardianApproval: false,
  posterName: 'Janet',
  posterVerificationStatus: 'approved',
  estimatedDurationMinutes: 20,
  payAmountCents: 2500,
  scheduleType: 'flexible',
);
