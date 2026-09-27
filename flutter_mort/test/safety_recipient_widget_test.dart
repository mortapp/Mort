import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mort/core/theme/mort_theme.dart';
import 'package:flutter_mort/data/repositories/providers.dart';
import 'package:flutter_mort/data/repositories/safety_repository.dart';
import 'package:flutter_mort/features/safety/manual_travel_card.dart';
import 'package:flutter_mort/features/safety/safety_calm_surface.dart';
import 'package:flutter_mort/features/safety/safety_event_screen.dart';
import 'package:flutter_mort/features/mort_screens.dart';
import 'helpers/mort_widget_harness.dart';

class _Safety extends SafetyRepository {
  bool revoked = false;
  String runtimeState = 'normal';
  @override
  Future<Map<String, dynamic>> getRuntime() async => {
    'ok': true,
    'safety_state': runtimeState,
  };
  @override
  Future<Map<String, dynamic>> getSafetyCenterConfig() async => {};
  @override
  Future<List<Map<String, dynamic>>> listActiveJobCheckins() async => [];
  @override
  Future<Map<String, dynamic>> getSafetyEvent(String id) async {
    if (revoked) throw StateError('safety_event_not_authorized');
    return {
      'teen_name': 'QA linked teen',
      'safety_state': 'connection_lost',
      'battery_percent': 5,
      'live_sharing': true,
      'sharing_expires_at': DateTime.now()
          .subtract(const Duration(seconds: 1))
          .toIso8601String(),
    };
  }

  @override
  Future<Map<String, dynamic>> getJobRuntime(String id) async => {
    'application_id': id,
    'job_id': 'qa-job',
    'job_status': 'accepted',
    'connection_lost': true,
    'travel_state': 'reconfirm',
  };
}

Widget _app(_Safety repo, Widget child) => ProviderScope(
  overrides: [
    safetyRepositoryProvider.overrideWithValue(repo),
    currentProfileProvider.overrideWithValue(const AsyncValue.data(null)),
  ],
  child: MaterialApp(
    theme: mortTestTheme(MortTheme.dark()),
    home: SafetyCalmSurface(child: child),
  ),
);

void main() {
  testMortWidgets(
    'Safety Center refreshes foreground escalation without claiming physical safety',
    (tester) async {
      final repo = _Safety();
      await tester.pumpWidget(
        _app(repo, const SafetyCenterScreen(emergencyDialerEnabled: false)),
      );
      await tester.pumpAndSettle();
      expect(find.text("You're Safe"), findsNothing);
      expect(find.text('No active Safety alert'), findsOneWidget);
      repo.runtimeState = 'attention';
      await tester.pump(const Duration(seconds: 30));
      await tester.pumpAndSettle();
      expect(find.text('Attention'), findsWidgets);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
  );
  testMortWidgets(
    'Expired sharing never shows live and revocation clears recipient data',
    (tester) async {
      final repo = _Safety();
      await tester.pumpWidget(
        _app(repo, const SafetyEventScreen(eventId: 'qa-event')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Live sharing: Off'), findsOneWidget);
      expect(find.text('QA linked teen'), findsOneWidget);
      repo.revoked = true;
      await tester.pump(const Duration(seconds: 30));
      await tester.pumpAndSettle();
      expect(find.text('QA linked teen'), findsNothing);
      expect(find.text('Safety event unavailable'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testMortWidgets(
    'Poster connection controls cannot offer a teen Start action',
    (tester) async {
      await tester.pumpWidget(
        _app(
          _Safety(),
          Scaffold(
            body: SingleChildScrollView(
              child: ManualTravelCard(
                applicationId: 'qa-app',
                isTeen: false,
                onReschedule: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final label in [
        'Wait for Worker',
        'Worker Arrived but Device Unavailable',
        'Wait for Device',
        'Cancel for Connection / Safety Issue',
        'Report Arrival Issue',
        'Reschedule Job',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text("I'm Here"), findsNothing);
      expect(find.text('Start Job for Teen'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testMortWidgets('Safety surface disables decorative motion', (tester) async {
    bool? calm;
    await tester.pumpWidget(
      _app(
        _Safety(),
        Builder(
          builder: (context) {
            calm = MediaQuery.disableAnimationsOf(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(calm, true);
  });
}
