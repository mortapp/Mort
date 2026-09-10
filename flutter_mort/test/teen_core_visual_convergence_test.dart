import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_mort/core/theme/mort_theme.dart';
import 'package:flutter_mort/core/widgets/mort_widgets.dart';
import 'package:flutter_mort/data/models/application.dart';
import 'package:flutter_mort/data/models/job.dart';
import 'package:flutter_mort/data/models/leaderboard.dart';
import 'package:flutter_mort/data/models/profile.dart';
import 'package:flutter_mort/data/repositories/providers.dart';
import 'package:flutter_mort/features/mort_screens.dart';
import 'package:flutter_mort/features/teen/teen_shell.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/mort_widget_harness.dart';

void main() {
  testWidgets(
    'teen home uses the canonical header and stays stable at 200 percent text',
    (tester) async {
      await _pumpTeenHome(
        tester,
        size: const Size(320, 568),
        textScaler: TextScaler.linear(2),
      );

      expect(find.byType(MortSpaceBackground), findsOneWidget);
      expect(find.byType(MortTeenDestinationHeader), findsOneWidget);
      expect(find.byType(MortBrandMark), findsNothing);
      expect(find.textContaining('123 Exact Street'), findsNothing);
      expect(find.textContaining('Carmel, IN'), findsOneWidget);
      expect(tester.takeException(), isNull);

      for (final label in [
        'ACTIVE JOB',
        'AVAILABLE NEARBY WORK',
        'Safety',
        'QUICK LINKS',
        'LEADERBOARD',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
        await tester.ensureVisible(find.text(label));
        await tester.pumpAndSettle();
        expect(find.text(label), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('teen home stays stable on the reference iPhone viewport', (
    tester,
  ) async {
    await _pumpTeenHome(
      tester,
      size: const Size(390, 844),
      textScaler: const TextScaler.linear(1.3),
    );

    expect(find.byType(MortTeenDestinationHeader), findsOneWidget);
    expect(find.textContaining('123 Exact Street'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('safety pulse never truncates critical status at large text', (
    tester,
  ) async {
    const status =
        'Emergency, report, and support tools are available whenever you need them.';
    await tester.pumpWidget(
      MaterialApp(
        theme: mortTestTheme(MortTheme.dark()),
        home: const MediaQuery(
          data: MediaQueryData(
            size: Size(320, 568),
            textScaler: TextScaler.linear(2),
          ),
          child: Scaffold(
            body: SingleChildScrollView(
              child: Center(
                child: MortSafetyPulse(title: 'Safety ready', status: status),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final paragraph = tester.renderObject<RenderParagraph>(find.text(status));
    expect(paragraph.didExceedMaxLines, isFalse);
    expect(tester.takeException(), isNull);
  });

  test(
    'teen home source keeps priority order and no legacy primary tokens',
    () {
      final source = File(
        '${Directory.current.path}/lib/features/mort_screens.dart',
      ).readAsStringSync();
      final teenHome = _slice(
        source,
        'class RoleHomeScreen',
        'class _DashboardActionDefinition',
      );

      expect(teenHome, contains('MortTeenDestinationHeader('));
      expect(teenHome, contains('if (role != UserRole.teen) ...['));
      expect(teenHome, isNot(contains('MortColors.roseGold')));
      expect(teenHome, isNot(contains('MortColors.godPink')));
      expect(teenHome, isNot(contains('MortColors.neon')));

      final active = teenHome.indexOf('const _TeenActiveJobSection()');
      final nearby = teenHome.indexOf('const _TeenNearbyWorkSection()');
      final safety = teenHome.indexOf('MortSafetyPulse(');
      final profile = teenHome.indexOf('MortProfileCompletionMeter(');
      final quickLinks = teenHome.indexOf(
        "MortSectionLabel(label: 'Quick links')",
      );
      final leaderboard = teenHome.indexOf('const _TeenLeaderboardSection()');
      for (final index in [
        active,
        nearby,
        safety,
        profile,
        quickLinks,
        leaderboard,
      ]) {
        expect(index, isNonNegative);
      }
      expect(active, lessThan(nearby));
      expect(nearby, lessThan(safety));
      expect(safety, lessThan(profile));
      expect(profile, lessThan(quickLinks));
      expect(quickLinks, lessThan(leaderboard));
    },
  );
}

const _activeJob = Job(
  id: 'job-active',
  posterId: 'poster-synthetic',
  title: 'Garden cleanup',
  description: 'Rake leaves in the front garden.',
  category: 'Yard work',
  locationText: 'Broad Ripple area',
  city: 'Indianapolis',
  state: 'IN',
  status: 'open',
  requiresGuardianApproval: false,
  payAmountCents: 3000,
);

const _nearbyJob = Job(
  id: 'job-nearby',
  posterId: 'poster-synthetic',
  title: 'Library shelf help',
  description: 'Organize books in a public area.',
  category: 'Community help',
  locationText: '123 Exact Street',
  city: 'Carmel',
  state: 'IN',
  status: 'open',
  requiresGuardianApproval: false,
  payAmountCents: 2200,
);

final _teenProfile = Profile(
  id: 'teen-synthetic',
  role: UserRole.teen,
  displayName: 'Alex',
  username: 'alex_synthetic',
  dob: DateTime(2009, 1, 1),
  city: 'Indianapolis',
  state: 'IN',
  onboardingCompleted: true,
  accountStatus: 'active',
  verificationStatus: 'approved',
  paymentPreference: 'none',
);

Future<void> _pumpTeenHome(
  WidgetTester tester, {
  required Size size,
  required TextScaler textScaler,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentProfileProvider.overrideWithValue(AsyncValue.data(_teenProfile)),
        myApplicationsProvider.overrideWithValue(
          const AsyncValue.data([
            MortApplication(
              id: 'application-active',
              jobId: 'job-active',
              teenId: 'teen-synthetic',
              status: 'accepted',
              job: _activeJob,
            ),
          ]),
        ),
        openJobsProvider.overrideWith2(_SyntheticOpenJobsController.new),
        myLeaderboardRankProvider.overrideWithValue(
          const AsyncValue.data(
            MyLeaderboardRank(
              score: 12,
              completedCount: 1,
              reviewCount: 1,
              averageRating: 5,
              tier: 'rising_star',
              rank: 4,
              leaderboardOptOut: false,
            ),
          ),
        ),
        leaderboardProvider.overrideWithValue(
          const AsyncValue.data(<LeaderboardEntry>[]),
        ),
      ],
      child: MaterialApp(
        theme: mortTestTheme(MortTheme.dark()),
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            disableAnimations: true,
            textScaler: textScaler,
          ),
          child: const RoleHomeScreen(role: UserRole.teen),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _SyntheticOpenJobsController extends OpenJobsController {
  _SyntheticOpenJobsController(super.filters);

  @override
  Future<JobFeedState> build() async =>
      const JobFeedState(items: [_nearbyJob], hasMore: false);
}

String _slice(String source, String start, String end) {
  final startIndex = source.indexOf(start);
  final endIndex = source.indexOf(end, startIndex);
  if (startIndex < 0 || endIndex < 0) {
    throw StateError('Unable to locate $start through $end');
  }
  return source.substring(startIndex, endIndex);
}
