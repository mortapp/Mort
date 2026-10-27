import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_mort/core/theme/mort_theme.dart';
import 'package:flutter_mort/core/atmosphere/mort_atmospheric_background.dart';
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
            savedJobIdsProvider.overrideWith((ref) async => <String>{}),
          ],
          child: MaterialApp(
            theme: MortTheme.light(),
            home: const TeenMarketplaceHomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Jobs near you'), findsOneWidget);
      expect(find.text('Quick picks'), findsOneWidget);
      expect(find.text('All nearby jobs'), findsOneWidget);
      expect(find.text('Yard cleanup'), findsOneWidget);
      expect(find.textContaining(r'$25.00'), findsWidgets);
      expect(find.text('Janet'), findsOneWidget);
      expect(find.byTooltip('Verified poster'), findsOneWidget);
      expect(
        find.text('Browse local work. Exact addresses stay private.'),
        findsNothing,
      );
      expect(find.text('Broad Ripple area'), findsWidgets);
      expect(find.text('View job'), findsOneWidget);
      expect(find.byTooltip('Save job'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('123 Exact Street'), findsNothing);
    },
  );

  testMortWidgets('teen Home remains readable with large text', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          openJobsProvider.overrideWith2(_PreviewJobsController.new),
          savedJobIdsProvider.overrideWith((ref) async => <String>{}),
        ],
        child: MaterialApp(
          theme: MortTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const TeenMarketplaceHomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Quick picks'), findsOneWidget);
    expect(find.text('View job'), findsWidgets);
  });

  testMortWidgets('dark teen Home follows the monochrome product theme', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          openJobsProvider.overrideWith2(_PreviewJobsController.new),
          savedJobIdsProvider.overrideWith((ref) async => <String>{}),
        ],
        child: MaterialApp(
          theme: MortTheme.dark(),
          home: const TeenMarketplaceHomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MortAtmosphericBackground), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _PreviewJobsController extends OpenJobsController {
  _PreviewJobsController(super.filters);

  @override
  Future<JobFeedState> build() async =>
      const JobFeedState(items: [_previewJob, _longerJob], hasMore: false);
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

const _longerJob = Job(
  id: 'longer-preview-job',
  posterId: 'preview-poster-2',
  title: 'Help organize a garage',
  description: 'Sort boxes and sweep the floor.',
  category: 'Organization',
  locationText: 'Meridian-Kessler area',
  city: 'Indianapolis',
  state: 'IN',
  status: 'open',
  requiresGuardianApproval: false,
  posterName: 'Morgan',
  estimatedDurationMinutes: 45,
  payAmountCents: 3200,
  scheduleType: 'flexible',
);
