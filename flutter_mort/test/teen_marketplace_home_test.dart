import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_mort/core/theme/mort_theme.dart';
import 'package:flutter_mort/core/atmosphere/mort_atmospheric_background.dart';
import 'package:flutter_mort/data/models/job.dart';
import 'package:flutter_mort/data/repositories/jobs_repository.dart';
import 'package:flutter_mort/data/repositories/providers.dart';
import 'package:flutter_mort/features/teen/teen_marketplace_home_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/mort_widget_harness.dart';

void main() {
  testMortWidgets('quick jobs use the light editorial surface treatment', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          openJobsProvider.overrideWith2(_PreviewJobsController.new),
          savedJobIdsProvider.overrideWith((ref) async => <String>{}),
          interestedJobIdsProvider.overrideWith((ref) async => <String>{}),
        ],
        child: MaterialApp(
          theme: MortTheme.light(),
          home: const TeenMarketplaceHomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final quickCard = find.byKey(const ValueKey('quick-job-preview-job'));
    expect(quickCard, findsOneWidget);
    expect(
      tester.widget<Material>(quickCard).color,
      MortTheme.light().colorScheme.surface,
    );
    expect(find.text('M'), findsNothing);
  });

  testMortWidgets(
    'teen Home starts with local jobs and keeps search in Explore',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            openJobsProvider.overrideWith2(_PreviewJobsController.new),
            savedJobIdsProvider.overrideWith((ref) async => <String>{}),
            interestedJobIdsProvider.overrideWith((ref) async => <String>{}),
          ],
          child: MaterialApp(
            theme: MortTheme.light(),
            home: const TeenMarketplaceHomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Quick Jobs'), findsOneWidget);
      expect(find.text('Nearby work'), findsOneWidget);
      expect(find.text('MORT'), findsNothing);
      expect(find.text('Yard cleanup'), findsOneWidget);
      expect(find.textContaining(r'$25.00'), findsWidgets);
      expect(find.text('Janet'), findsOneWidget);
      expect(find.byTooltip('Verified poster'), findsOneWidget);
      expect(
        find.text('Browse local work. Exact addresses stay private.'),
        findsNothing,
      );
      expect(find.text('Broad Ripple area'), findsWidgets);
      expect(find.text('Apply'), findsOneWidget);
      expect(find.byTooltip('Save job'), findsOneWidget);
      expect(find.byTooltip('Show interest'), findsOneWidget);
      final nearbyCard = find.byKey(
        const ValueKey('nearby-job-longer-preview-job'),
      );
      expect(nearbyCard, findsOneWidget);
      final poster = find.descendant(
        of: nearbyCard,
        matching: find.text('Morgan'),
      );
      final category = find.descendant(
        of: nearbyCard,
        matching: find.text('Organization'),
      );
      expect(
        tester.getTopLeft(poster).dy,
        lessThanOrEqualTo(tester.getTopLeft(category).dy),
      );
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
          interestedJobIdsProvider.overrideWith((ref) async => <String>{}),
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
    expect(find.text('Quick Jobs'), findsOneWidget);
    expect(find.text('Apply'), findsWidgets);
  });

  testMortWidgets('teen Home stores interest on the backend', (tester) async {
    final repository = _PreviewJobsRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          openJobsProvider.overrideWith2(_PreviewJobsController.new),
          jobsRepositoryProvider.overrideWithValue(repository),
          savedJobIdsProvider.overrideWith((ref) async => <String>{}),
        ],
        child: MaterialApp(
          theme: MortTheme.light(),
          home: const TeenMarketplaceHomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Show interest'));
    await tester.pumpAndSettle();

    expect(repository.interestedJobIds, contains(_longerJob.id));
    expect(find.byTooltip('Remove interest'), findsOneWidget);
  });

  testMortWidgets('teen Home supports right-swipe dismissal with undo', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          openJobsProvider.overrideWith2(_PreviewJobsController.new),
          savedJobIdsProvider.overrideWith((ref) async => <String>{}),
          interestedJobIdsProvider.overrideWith((ref) async => <String>{}),
        ],
        child: MaterialApp(
          theme: MortTheme.light(),
          home: const TeenMarketplaceHomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final card = find.byKey(const ValueKey('nearby-job-longer-preview-job'));
    await tester.ensureVisible(card);
    await tester.drag(card, const Offset(-400, 0));
    await tester.pumpAndSettle();
    expect(card, findsOneWidget);

    await tester.drag(card, const Offset(400, 0));
    await tester.pumpAndSettle();
    expect(card, findsNothing);
    expect(find.text('Not interested'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
    expect(
      tester.widget<SnackBar>(find.byType(SnackBar)).duration,
      const Duration(seconds: 6),
    );

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(card, findsOneWidget);
  });

  testMortWidgets('dark teen Home follows the monochrome product theme', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          openJobsProvider.overrideWith2(_PreviewJobsController.new),
          savedJobIdsProvider.overrideWith((ref) async => <String>{}),
          interestedJobIdsProvider.overrideWith((ref) async => <String>{}),
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

class _PreviewJobsRepository extends JobsRepository {
  final Set<String> interestedJobIds = {};

  @override
  Future<Set<String>> listInterestedJobIds() async => interestedJobIds;

  @override
  Future<void> setJobInterest(String jobId, {required bool interested}) async {
    if (interested) {
      interestedJobIds.add(jobId);
    } else {
      interestedJobIds.remove(jobId);
    }
  }
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
