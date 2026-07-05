import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mort_mobile_app/main.dart';

void main() {
  testWidgets('MORT opens the teen workspace', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const MortApp());

    expect(find.text('MORT'), findsOneWidget);
    expect(find.text('Ready for safe pickup'), findsOneWidget);
    expect(find.text('Hustles'), findsOneWidget);
  });

  test('MORT state accepts and completes a hustle', () {
    final state = MortState.demo();
    final job = state.jobs.first;

    state.acceptJob(job);

    expect(state.activeJob, job);
    expect(job.status, JobStatus.active);

    state.completeActiveJob();

    expect(state.activeJob, isNull);
    expect(job.status, JobStatus.completed);
    expect(state.totalEarned, greaterThan(428));
    expect(state.feed.first.type, 'Completed');
  });
}
