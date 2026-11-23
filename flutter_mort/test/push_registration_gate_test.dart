import 'dart:async';

import 'package:flutter_mort/services/push/push_registration_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'explicit opt-in is not absorbed by an automatic eligibility check',
    () async {
      final gate = PushRegistrationGate();
      final automatedCheck = Completer<void>();
      final events = <String>[];
      final automatic = gate.sync('owner', () async {
        await automatedCheck.future;
        events.add('automatic');
      });
      final explicit = gate.sync(
        'owner',
        () async => events.add('explicit'),
        runAfterActive: true,
      );
      expect(events, isEmpty);
      automatedCheck.complete();
      await automatic;
      await explicit;
      expect(events, ['automatic', 'explicit']);
    },
  );

  test(
    'revocation waits for an existing registration and blocks callbacks',
    () async {
      final gate = PushRegistrationGate();
      final started = Completer<void>();
      final register = Completer<void>();
      final events = <String>[];
      final first = gate.sync('owner', () async {
        started.complete();
        await register.future;
        events.add('register');
      });
      await started.future;
      final revocation = gate.revoke('owner', () async => events.add('revoke'));
      expect(gate.allows('owner'), isFalse);
      expect(gate.allows('different-owner'), isFalse);
      gate.explicitOptIn('owner');
      await gate.sync('owner', () async => events.add('unexpected'));
      expect(events, isEmpty);
      register.complete();
      await first;
      await revocation;
      await gate.sync('owner', () async => events.add('unexpected'));
      expect(events, ['register', 'revoke']);
      gate.explicitOptIn('owner');
      await gate.sync('owner', () async => events.add('opted back in'));
      expect(events, ['register', 'revoke', 'opted back in']);
    },
  );

  test(
    'queued registration skips the provider after revocation starts',
    () async {
      final gate = PushRegistrationGate();
      var writes = 0;
      final queued = gate.sync('owner', () async => writes++);
      final revocation = gate.revoke('owner', () async {});
      await queued;
      await revocation;
      expect(writes, 0);
      expect(gate.allows('owner'), isFalse);
      expect(gate.allows('different-owner'), isTrue);
    },
  );
}
