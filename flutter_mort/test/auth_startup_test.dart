import 'dart:async';

import 'package:flutter_mort/core/auth/auth_startup.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeGateway implements MortAuthStartupGateway {
  _FakeGateway({
    this.isConfigured = true,
    this.isInitialized = true,
    this.session,
    Map<String, dynamic>? profile,
  }) : profile =
           profile ??
           {
             'id': session?.userId,
             'role': 'teen',
             'dob': '2010-01-01',
             'onboarding_completed': true,
             'account_status': 'active',
           };

  @override
  final bool isConfigured;
  @override
  final bool isInitialized;
  MortSessionSnapshot? session;
  Map<String, dynamic> profile;
  Object? profileError;
  final refreshResults = <Object?>[];
  final controller = StreamController<MortAuthEvent>.broadcast();
  int refreshCalls = 0;
  int clearCalls = 0;
  int recoverCalls = 0;
  @override
  MortSessionSnapshot? get currentSession => session;

  @override
  Stream<MortAuthEvent> get events => controller.stream;

  @override
  Future<Map<String, dynamic>> ensureCurrentProfile() async {
    if (profileError != null) throw profileError!;
    return profile;
  }

  @override
  Future<MortSessionSnapshot?> refreshSession() async {
    refreshCalls++;
    final result = refreshResults.removeAt(0);
    if (result is Object && result is! MortSessionSnapshot) throw result;
    session = result as MortSessionSnapshot?;
    return session;
  }

  @override
  Future<void> clearLocalSession() async {
    clearCalls++;
    session = null;
  }

  Future<void> close() => controller.close();
}

class _DelayedProfileGateway extends _FakeGateway {
  _DelayedProfileGateway({
    super.session,
    Object? profileError,
    required this.delay,
  }) {
    this.profileError = profileError;
  }

  final Duration delay;

  @override
  Future<Map<String, dynamic>> ensureCurrentProfile() async {
    await Future<void>.delayed(delay);
    return super.ensureCurrentProfile();
  }
}

AuthStartupController _startup(_FakeGateway gateway) => AuthStartupController(
  gateway,
  refreshAttempts: 2,
  refreshTimeout: const Duration(milliseconds: 100),
  profileTimeout: const Duration(milliseconds: 100),
  initialRecoveryGrace: Duration.zero,
  retryDelay: Duration.zero,
);

MortSessionSnapshot _session({bool expired = false}) =>
    MortSessionSnapshot(userId: 'user-1', isExpired: expired);

void main() {
  test('missing configuration fails closed', () async {
    final gateway = _FakeGateway(isConfigured: false);
    final startup = _startup(gateway);

    await startup.start();

    expect(startup.snapshot.stage, MortAuthStartupStage.fatalConfiguration);
    startup.dispose();
    await gateway.close();
  });

  test('configured but uninitialized backend fails closed', () async {
    final gateway = _FakeGateway(isInitialized: false);
    final startup = _startup(gateway);

    await startup.start();

    expect(startup.snapshot.stage, MortAuthStartupStage.fatalConfiguration);
    startup.dispose();
    await gateway.close();
  });

  test('cold start without a session routes to the public splash', () async {
    final gateway = _FakeGateway();
    final startup = _startup(gateway);

    await startup.start();

    expect(startup.snapshot.stage, MortAuthStartupStage.unauthenticated);
    expect(startup.snapshot.destination, '/splash');
    startup.dispose();
    await gateway.close();
  });

  test(
    'startup succeeds when a persisted session already exists before startup',
    () async {
      final gateway = _FakeGateway(session: _session());
      gateway.profile = {
        'id': 'user-1',
        'role': 'teen',
        'dob': '2010-01-01',
        'onboarding_completed': true,
        'account_status': 'active',
      };
      final startup = AuthStartupController(
        gateway,
        refreshAttempts: 2,
        refreshTimeout: const Duration(milliseconds: 100),
        profileTimeout: const Duration(milliseconds: 100),
        initialRecoveryGrace: const Duration(milliseconds: 25),
        retryDelay: Duration.zero,
      );

      await startup.start();

      expect(startup.snapshot.stage, MortAuthStartupStage.authenticated);
      expect(startup.snapshot.destination, '/teen/home');
      startup.dispose();
      await gateway.close();
    },
  );

  test(
    'startup waits briefly for a restored session before falling back to splash',
    () async {
      final gateway = _FakeGateway();
      final startup = AuthStartupController(
        gateway,
        refreshAttempts: 2,
        refreshTimeout: const Duration(milliseconds: 100),
        profileTimeout: const Duration(milliseconds: 100),
        initialRecoveryGrace: const Duration(milliseconds: 25),
        retryDelay: Duration.zero,
      );

      final startupFuture = startup.start();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      gateway.controller.add(
        MortAuthEvent(MortAuthEventType.initialSession, _session()),
      );
      gateway.profile = {
        'id': 'user-1',
        'role': 'teen',
        'dob': '2010-01-01',
        'onboarding_completed': true,
        'account_status': 'active',
      };
      await startupFuture;

      expect(startup.snapshot.stage, MortAuthStartupStage.authenticated);
      expect(startup.snapshot.destination, '/teen/home');
      startup.dispose();
      await gateway.close();
    },
  );

  test(
    'startup recovers a session emitted just before the grace period ends',
    () async {
      final gateway = _FakeGateway();
      final startup = AuthStartupController(
        gateway,
        refreshAttempts: 2,
        refreshTimeout: const Duration(milliseconds: 100),
        profileTimeout: const Duration(milliseconds: 100),
        initialRecoveryGrace: const Duration(milliseconds: 25),
        retryDelay: Duration.zero,
      );

      final startupFuture = startup.start();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      gateway.controller.add(
        MortAuthEvent(MortAuthEventType.initialSession, _session()),
      );
      gateway.profile = {
        'id': 'user-1',
        'role': 'adult',
        'dob': '1985-01-01',
        'onboarding_completed': true,
        'account_status': 'active',
      };
      await startupFuture;

      expect(startup.snapshot.stage, MortAuthStartupStage.authenticated);
      expect(startup.snapshot.destination, '/adult/home');
      startup.dispose();
      await gateway.close();
    },
  );

  test(
    'startup still recovers when a restored session arrives shortly after the grace window',
    () async {
      final gateway = _FakeGateway();
      final startup = AuthStartupController(
        gateway,
        refreshAttempts: 2,
        refreshTimeout: const Duration(milliseconds: 100),
        profileTimeout: const Duration(milliseconds: 100),
        initialRecoveryGrace: const Duration(milliseconds: 500),
        retryDelay: Duration.zero,
      );

      final startupFuture = startup.start();
      await Future<void>.delayed(const Duration(milliseconds: 700));
      gateway.controller.add(
        MortAuthEvent(MortAuthEventType.initialSession, _session()),
      );
      gateway.profile = {
        'id': 'user-1',
        'role': 'adult',
        'dob': '1985-01-01',
        'onboarding_completed': true,
        'account_status': 'active',
      };
      await startupFuture;

      expect(startup.snapshot.stage, MortAuthStartupStage.authenticated);
      expect(startup.snapshot.destination, '/adult/home');
      startup.dispose();
      await gateway.close();
    },
  );

  test('startup resolves unauthenticated when no session appears', () async {
    final gateway = _FakeGateway();
    final startup = AuthStartupController(
      gateway,
      refreshAttempts: 2,
      refreshTimeout: const Duration(milliseconds: 100),
      profileTimeout: const Duration(milliseconds: 100),
      initialRecoveryGrace: const Duration(milliseconds: 25),
      retryDelay: Duration.zero,
    );

    await startup.start();

    expect(startup.snapshot.stage, MortAuthStartupStage.unauthenticated);
    expect(startup.snapshot.destination, '/splash');
    startup.dispose();
    await gateway.close();
  });

  test(
    'startup uses offline state when auth stream errors before session restoration',
    () async {
      final gateway = _FakeGateway();
      final startup = AuthStartupController(
        gateway,
        refreshAttempts: 2,
        refreshTimeout: const Duration(milliseconds: 100),
        profileTimeout: const Duration(milliseconds: 100),
        initialRecoveryGrace: const Duration(milliseconds: 25),
        retryDelay: Duration.zero,
      );

      final startupFuture = startup.start();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      gateway.controller.addError(StateError('socket disconnected'));
      await startupFuture;

      expect(startup.snapshot.stage, MortAuthStartupStage.offline);
      expect(startup.snapshot.destination, isNull);
      startup.dispose();
      await gateway.close();
    },
  );

  test(
    'startup waits for profile resolution before final destination',
    () async {
      final gateway = _DelayedProfileGateway(
        session: _session(),
        delay: const Duration(milliseconds: 40),
      );
      final startup = AuthStartupController(
        gateway,
        refreshAttempts: 2,
        refreshTimeout: const Duration(milliseconds: 100),
        profileTimeout: const Duration(milliseconds: 200),
        initialRecoveryGrace: Duration.zero,
        retryDelay: Duration.zero,
      );

      final stages = <MortAuthStartupStage>[];
      startup.addListener(() => stages.add(startup.snapshot.stage));

      await startup.start();

      expect(stages, contains(MortAuthStartupStage.restoring));
      expect(stages, contains(MortAuthStartupStage.authenticated));
      expect(startup.snapshot.destination, '/teen/home');
      startup.dispose();
      await gateway.close();
    },
  );

  for (final entry in {
    'adult': '/adult/home',
    'guardian': '/guardian/home',
    'admin': '/admin/home',
    'teen': '/teen/home',
  }.entries) {
    test('restored ${entry.key} session resolves to ${entry.value}', () async {
      final gateway = _FakeGateway(
        session: _session(),
        profile: {
          'id': 'user-1',
          'role': entry.key,
          'dob': '2010-01-01',
          'onboarding_completed': true,
          'account_status': 'active',
        },
      );
      final startup = _startup(gateway);

      await startup.start();

      expect(startup.snapshot.stage, MortAuthStartupStage.authenticated);
      expect(startup.snapshot.destination, entry.value);
      startup.dispose();
      await gateway.close();
    });
  }

  test(
    'valid restored session reaches the server-authoritative teen route',
    () async {
      final gateway = _FakeGateway(session: _session());
      final startup = _startup(gateway);
      final stages = <MortAuthStartupStage>[];
      startup.addListener(() => stages.add(startup.snapshot.stage));

      await startup.start();

      expect(stages, contains(MortAuthStartupStage.restoring));
      expect(startup.snapshot.stage, MortAuthStartupStage.authenticated);
      expect(startup.snapshot.destination, '/teen/home');
      startup.dispose();
      await gateway.close();
    },
  );

  test('a second controller restores the same persisted session', () async {
    final gateway = _FakeGateway(session: _session());
    final first = _startup(gateway);
    await first.start();
    first.dispose();

    final restarted = _startup(gateway);
    await restarted.start();

    expect(restarted.snapshot.stage, MortAuthStartupStage.authenticated);
    expect(restarted.snapshot.userId, 'user-1');
    restarted.dispose();
    await gateway.close();
  });

  test('expired session waits for refresh before private navigation', () async {
    final gateway = _FakeGateway(session: _session(expired: true));
    gateway.refreshResults.add(_session());
    final startup = _startup(gateway);
    final stages = <MortAuthStartupStage>[];
    startup.addListener(() => stages.add(startup.snapshot.stage));

    await startup.start();

    expect(stages, contains(MortAuthStartupStage.refreshing));
    expect(gateway.refreshCalls, 1);
    expect(startup.snapshot.stage, MortAuthStartupStage.authenticated);
    startup.dispose();
    await gateway.close();
  });

  test('offline refresh is bounded and preserves the local session', () async {
    final gateway = _FakeGateway(session: _session(expired: true));
    gateway.refreshResults.addAll([
      StateError('network connection unavailable'),
      StateError('network connection unavailable'),
    ]);
    final startup = _startup(gateway);

    await startup.start();

    expect(gateway.refreshCalls, 2);
    expect(gateway.clearCalls, 0);
    expect(gateway.currentSession, isNotNull);
    expect(startup.snapshot.stage, MortAuthStartupStage.offline);
    startup.dispose();
    await gateway.close();
  });

  test('revoked refresh clears only the local session', () async {
    final gateway = _FakeGateway(session: _session(expired: true));
    gateway.refreshResults.add(StateError('invalid refresh token'));
    final startup = _startup(gateway);

    await startup.start();

    expect(gateway.clearCalls, 1);
    expect(startup.snapshot.stage, MortAuthStartupStage.unauthenticated);
    expect(startup.snapshot.destination, '/auth/sign-in');
    startup.dispose();
    await gateway.close();
  });

  test(
    'missing DOB routes restored accounts to the one true onboarding screen',
    () async {
      final gateway = _FakeGateway(
        session: _session(),
        profile: {
          'id': 'user-1',
          'role': null,
          'dob': null,
          'onboarding_completed': false,
          'account_status': 'active',
        },
      );
      final startup = _startup(gateway);

      await startup.start();

      expect(startup.snapshot.stage, MortAuthStartupStage.onboarding);
      expect(startup.snapshot.destination, '/onboarding');
      startup.dispose();
      await gateway.close();
    },
  );

  test('incomplete onboarding always resumes through CompactOnboardingScreen, '
      'which reads the persisted server step itself', () async {
    final gateway = _FakeGateway(
      session: _session(),
      profile: {
        'id': 'user-1',
        'role': 'teen',
        'dob': '2010-01-01',
        'onboarding_completed': false,
        'account_status': 'active',
        'onboarding_resume_path': '/onboarding/transportation',
      },
    );
    final startup = _startup(gateway);

    await startup.start();

    expect(startup.snapshot.stage, MortAuthStartupStage.onboarding);
    expect(startup.snapshot.destination, '/onboarding');
    startup.dispose();
    await gateway.close();
  });

  for (final entry in {
    'suspended': MortAuthStartupStage.suspended,
    'deletion_pending': MortAuthStartupStage.deletionPending,
  }.entries) {
    test('${entry.key} status blocks restored private navigation', () async {
      final gateway = _FakeGateway(
        session: _session(),
        profile: {
          'id': 'user-1',
          'role': 'teen',
          'dob': '2010-01-01',
          'onboarding_completed': true,
          'account_status': entry.key,
        },
      );
      final startup = _startup(gateway);

      await startup.start();

      expect(startup.snapshot.stage, entry.value);
      expect(startup.snapshot.destination, '/account-status');
      startup.dispose();
      await gateway.close();
    });
  }

  test(
    'profile lookup failure keeps the session and shows offline state',
    () async {
      final gateway = _FakeGateway(session: _session())
        ..profileError = StateError('network offline');
      final startup = _startup(gateway);

      await startup.start();

      expect(gateway.clearCalls, 0);
      expect(startup.snapshot.stage, MortAuthStartupStage.offline);
      startup.dispose();
      await gateway.close();
    },
  );

  test('signed-out auth event immediately blocks the prior account', () async {
    final gateway = _FakeGateway(session: _session());
    final startup = _startup(gateway);
    await startup.start();

    gateway.session = null;
    gateway.controller.add(
      const MortAuthEvent(MortAuthEventType.signedOut, null),
    );
    await Future<void>.delayed(Duration.zero);

    expect(startup.snapshot.stage, MortAuthStartupStage.unauthenticated);
    expect(startup.snapshot.destination, '/auth/sign-in');
    startup.dispose();
    await gateway.close();
  });

  test('auth stream errors never delete an otherwise saved session', () async {
    final gateway = _FakeGateway(session: _session());
    final startup = _startup(gateway);
    await startup.start();

    gateway.controller.addError(StateError('socket disconnected'));
    await Future<void>.delayed(Duration.zero);

    expect(gateway.clearCalls, 0);
    expect(startup.snapshot.stage, MortAuthStartupStage.offline);
    startup.dispose();
    await gateway.close();
  });
}
