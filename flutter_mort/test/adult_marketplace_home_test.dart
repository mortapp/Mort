import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_mort/core/theme/mort_theme.dart';
import 'package:flutter_mort/data/models/job.dart';
import 'package:flutter_mort/data/repositories/providers.dart';
import 'package:flutter_mort/features/jobs/job_screens.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/mort_widget_harness.dart';

void main() {
  testMortWidgets('adult Home presents posted work instead of a dashboard', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          myJobsProvider.overrideWith((ref) async => const [_adultJob]),
        ],
        child: MaterialApp(
          theme: MortTheme.light(),
          home: const AdultJobsScreen(homeMode: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Good help starts here.'), findsNothing);
    expect(find.textContaining('LOCAL HELP'), findsNothing);
    expect(find.text('MORT'), findsNothing);
    expect(find.text('Your posted jobs'), findsOneWidget);
    expect(find.text('Yard cleanup'), findsOneWidget);
    expect(find.text('Adult dashboard'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testMortWidgets('adult Home remains usable with large text', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          myJobsProvider.overrideWith((ref) async => const [_adultJob]),
        ],
        child: MaterialApp(
          theme: MortTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const AdultJobsScreen(homeMode: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Yard cleanup'), findsOneWidget);
  });
}

const _adultJob = Job(
  id: 'adult-preview-job',
  posterId: 'adult-preview-poster',
  title: 'Yard cleanup',
  description: 'Rake leaves and tidy the lawn.',
  category: 'Yard work',
  locationText: 'General area',
  city: 'Indianapolis',
  state: 'IN',
  status: 'open',
  requiresGuardianApproval: false,
  payAmountCents: 3000,
  scheduleType: 'flexible',
);
