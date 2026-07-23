import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mort/core/widgets/mort_widgets.dart';
import 'package:flutter_mort/features/legal/legal_screens.dart';
import 'package:flutter_mort/features/legal/trust_foundation_screens.dart';

void main() {
  testWidgets('teen summary states payment and identity limits', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: TeenTermsSummaryScreen()));

    expect(find.text('Teen terms summary'), findsOneWidget);
    expect(find.textContaining('does not process money'), findsOneWidget);
    expect(
      find.textContaining('do not by themselves prove legal identity'),
      findsOneWidget,
    );
    expect(find.textContaining('Guardian Mode is optional'), findsOneWidget);
  });

  testWidgets('browser capture preparation exposes no upload command', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: BrowserSafeCapturePreparationScreen()),
    );

    expect(find.text('Real identity capture is off'), findsOneWidget);
    final finder = find.widgetWithText(
      MortButton,
      'Native app required for future approved capture',
    );
    expect(finder, findsOneWidget);
    expect(tester.widget<MortButton>(finder).onPressed, isNull);
  });

  test(
    'repository uses server RPCs and never client-writes protected tables',
    () {
      final source = File(
        'lib/data/repositories/legal_contract_repository.dart',
      ).readAsStringSync();

      for (final rpc in [
        'get_my_legal_requirements',
        'submit_legal_acceptance',
        'confirm_job_contract_version',
        'request_job_contract_change',
        'report_nonpayment',
        'request_payment_evidence_export',
        'get_first_party_trust_status',
      ]) {
        expect(source, contains(rpc));
      }
      expect(source, isNot(contains("from('legal_acceptances').insert")));
      expect(source, isNot(contains("from('payment_disputes').insert")));
      expect(source, isNot(contains('SUPABASE_SERVICE_ROLE_KEY')));
    },
  );

  test('web trust screens do not import camera or image picker APIs', () {
    final source = File(
      'lib/features/legal/trust_foundation_screens.dart',
    ).readAsStringSync();

    expect(source, contains('Real identity capture is off'));
    expect(source, contains('Real liveness disabled'));
    expect(source, isNot(contains('ImagePicker')));
    expect(source, isNot(contains('availableCameras')));
    expect(source, isNot(contains('Face ID success')));
  });
}
