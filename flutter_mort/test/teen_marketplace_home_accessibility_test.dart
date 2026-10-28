import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mort/data/models/job.dart';
import 'package:flutter_mort/data/repositories/providers.dart';
import 'package:flutter_mort/features/teen/teen_marketplace_home.dart';

const _quickJob = Job(
  id: 'quick-job-accessibility',
  posterId: 'poster-accessibility',
  title: 'Help tidy a small community garden',
  description: 'A short neighborhood task.',
  category: 'Community help',
  locationText: 'General area',
  city: 'Indianapolis',
  state: 'IN',
  status: 'open',
  requiresGuardianApproval: false,
  payAmountCents: 2500,
  estimatedDurationMinutes: 20,
);

void main() {
  testWidgets(
    'Quick Jobs keeps pay and duration readable at 200 percent text',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentProfileProvider.overrideWithValue(
              const AsyncValue.data(null),
            ),
            openJobsProvider.overrideWith2(_FixtureOpenJobsController.new),
          ],
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(360, 800),
                textScaler: TextScaler.linear(2),
              ),
              child: const TeenMarketplaceHomeScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final payAndDuration = find.text(r'$25.00  ·  20 min');
      expect(payAndDuration, findsOneWidget);
      expect(
        tester.renderObject<RenderParagraph>(payAndDuration).didExceedMaxLines,
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

class _FixtureOpenJobsController extends OpenJobsController {
  _FixtureOpenJobsController(super.filters);

  @override
  Future<JobFeedState> build() async =>
      const JobFeedState(items: [_quickJob], hasMore: false);
}
