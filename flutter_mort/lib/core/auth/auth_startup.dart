import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/services/supabase_service.dart';

enum MortAuthStartupStage {
  initializing,
  restoring,
  refreshing,
  authenticated,
  unauthenticated,
  onboarding,
  suspended,
  deletionPending,
  offline,
  fatalConfiguration,
}

class MortAuthStartupSnapshot {
  const MortAuthStartupSnapshot({
    required this.stage,
    this.destination,
    this.userId,
    this.message,
  });

  const MortAuthStartupSnapshot.initializing()
    : this(stage: MortAuthStartupStage.initializing);

  final MortAuthStartupStage stage;
  final String? destination;
  final String? userId;
  final String? message;

  bool get blocksNavigation => switch (stage) {
    MortAuthStartupStage.initializing ||
    MortAuthStartupStage.restoring ||
    MortAuthStartupStage.refreshing ||
    MortAuthStartupStage.offline ||
    MortAuthStartupStage.fatalConfiguration => true,
    _ => false,
  };

  String get navigationKey => '$stage|$destination|$userId';
}

class MortSessionSnapshot {
  const MortSessionSnapshot({required this.userId, required this.isExpired});

  final String userId;
  final bool isExpired;
}

enum MortAuthEventType {
  initialSession,
  signedIn,
  tokenRefreshed,
  signedOut,
  userUpdated,
  userDeleted,
  passwordRecovery,
  other,
}

class MortAuthEvent {
  const MortAuthEvent(this.type, this.session);

  final MortAuthEventType type;
  final MortSessionSnapshot? session;
}

abstract interface class MortAuthStartupGateway {
  bool get isConfigured;
  bool get isInitialized;
  MortSessionSnapshot? get currentSession;
  Stream<MortAuthEvent> get events;
  Future<MortSessionSnapshot?> refreshSession();
  Future<Map<String, dynamic>> ensureCurrentProfile();
  Future<void> clearLocalSession();
}

class SupabaseAuthStartupGateway implements MortAuthStartupGateway {
  const SupabaseAuthStartupGateway();

  @override
  bool get isConfigured => SupabaseService.isConfigured;

  @override
  bool get isInitialized => SupabaseService.isInitialized;

  @override
  MortSessionSnapshot? get currentSession {
    if (!isInitialized) return null;
    return _snapshot(SupabaseService.client.auth.currentSession);
  }

  @override
  Stream<MortAuthEvent> get events =>
      SupabaseService.client.auth.onAuthStateChange.map(
        (event) =>
            MortAuthEvent(_eventType(event.event), _snapshot(event.session)),
      );

  @override
  Future<MortSessionSnapshot?> refreshSession() async {
    final response = await SupabaseService.client.auth.refreshSession();
    return _snapshot(response.session);
  }

  @override
  Future<Map<String, dynamic>> ensureCurrentProfile() async {
    final result = await SupabaseService.client.rpc('ensure_my_profile');
    Map<String, dynamic> profile;
    if (result is Map) {
      profile = Map<String, dynamic>.from(result);
    } else if (result is List && result.isNotEmpty && result.first is Map) {
      profile = Map<String, dynamic>.from(result.first as Map);
    } else {
      return const <String, dynamic>{};
    }
    if (profile['onboarding_completed'] != true) {
      final progress = await SupabaseService.client.rpc(
        'get_my_onboarding_progress',
      );
      if (progress is Map && progress['ok'] == true) {
        profile['onboarding_resume_path'] = progress['resume_path'];
      }
    }
    return profile;
  }

  @override
  Future<void> clearLocalSession() async {
    try {
      await SupabaseService.client.auth.signOut(scope: SignOutScope.local);
    } finally {
      await SupabaseService.clearPersistedSession();
    }
  }

  static MortSessionSnapshot? _snapshot(Session? session) {
    if (session == null) return null;
    return MortSessionSnapshot(
      userId: session.user.id,
      isExpired: session.isExpired,
    );
  }

  static MortAuthEventType _eventType(AuthChangeEvent event) {
    if (event == AuthChangeEvent.initialSession) {
      return MortAuthEventType.initialSession;
    }
    if (event == AuthChangeEvent.signedIn) {
      return MortAuthEventType.signedIn;
    }
    if (event == AuthChangeEvent.tokenRefreshed) {
      return MortAuthEventType.tokenRefreshed;
    }
    if (event == AuthChangeEvent.signedOut) {
      return MortAuthEventType.signedOut;
    }
    if (event == AuthChangeEvent.userUpdated) {
      return MortAuthEventType.userUpdated;
    }
    if (event == AuthChangeEvent.userDeleted) {
      return MortAuthEventType.userDeleted;
    }
    if (event == AuthChangeEvent.passwordRecovery) {
      return MortAuthEventType.passwordRecovery;
    }
    return MortAuthEventType.other;
  }
}

MortAuthStartupSnapshot routeAuthenticatedProfile({
  required String userId,
  required Map<String, dynamic> profile,
}) {
  if (profile['id']?.toString() != userId) {
    return const MortAuthStartupSnapshot(
      stage: MortAuthStartupStage.offline,
      message: 'MORT could not verify this account profile.',
    );
  }

  final accountStatus = profile['account_status']?.toString() ?? 'active';
  if (accountStatus.contains('deletion')) {
    return MortAuthStartupSnapshot(
      stage: MortAuthStartupStage.deletionPending,
      destination: '/account-status',
      userId: userId,
    );
  }
  if (accountStatus != 'active') {
    return MortAuthStartupSnapshot(
      stage: MortAuthStartupStage.suspended,
      destination: '/account-status',
      userId: userId,
    );
  }

  final role = profile['role']?.toString();
  final onboardingComplete = profile['onboarding_completed'] == true;
  if (!onboardingComplete ||
      !const {'teen', 'adult', 'guardian', 'admin'}.contains(role)) {
    final persistedResumePath = profile['onboarding_resume_path']?.toString();
    final destination = persistedResumePath?.startsWith('/onboarding/') == true
        ? persistedResumePath!
        : profile['dob'] == null
        ? '/onboarding/age'
        : role == null || role.isEmpty
        ? '/onboarding/role'
        : '/onboarding';
    return MortAuthStartupSnapshot(
      stage: MortAuthStartupStage.onboarding,
      destination: destination,
      userId: userId,
    );
  }

  final destination = switch (role) {
    'teen' => '/teen/home',
    'adult' => '/adult/home',
    'guardian' => '/guardian/home',
    'admin' => '/admin/home',
    _ => '/account-status',
  };
  return MortAuthStartupSnapshot(
    stage: MortAuthStartupStage.authenticated,
    destination: destination,
    userId: userId,
  );
}

class AuthStartupController extends ChangeNotifier {
  AuthStartupController(
    this._gateway, {
    this.refreshAttempts = 2,
    this.refreshTimeout = const Duration(seconds: 12),
    this.profileTimeout = const Duration(seconds: 12),
    this.initialRecoveryGrace = const Duration(seconds: 3),
    this.retryDelay = const Duration(milliseconds: 350),
  });

  final MortAuthStartupGateway _gateway;
  final int refreshAttempts;
  final Duration refreshTimeout;
  final Duration profileTimeout;
  final Duration initialRecoveryGrace;
  final Duration retryDelay;

  MortAuthStartupSnapshot snapshot =
      const MortAuthStartupSnapshot.initializing();
  StreamSubscription<MortAuthEvent>? _subscription;
  int _operation = 0;
  bool _disposed = false;

  Future<void> start() async {
    if (_disposed) return;
    if (!_gateway.isConfigured || !_gateway.isInitialized) {
      _set(
        const MortAuthStartupSnapshot(
          stage: MortAuthStartupStage.fatalConfiguration,
          message: 'MORT is missing its public backend configuration.',
        ),
      );
      return;
    }
    _subscription ??= _gateway.events.listen(
      _handleAuthEvent,
      onError: _handleAuthError,
    );
    await _resolve(session: _gateway.currentSession, restoring: true);
  }

  Future<void> retry() =>
      _resolve(session: _gateway.currentSession, restoring: true);

  void markSignedOut({String destination = '/auth/sign-in'}) {
    _operation++;
    _set(
      MortAuthStartupSnapshot(
        stage: MortAuthStartupStage.unauthenticated,
        destination: destination,
      ),
    );
  }

  Future<void> _resolve({
    required MortSessionSnapshot? session,
    required bool restoring,
  }) async {
    final operation = ++_operation;
    _set(
      MortAuthStartupSnapshot(
        stage: restoring
            ? MortAuthStartupStage.restoring
            : MortAuthStartupStage.initializing,
      ),
    );

    if (session == null) {
      if (restoring && initialRecoveryGrace > Duration.zero) {
        final recovered = await _waitForRestoredSession(operation);
        if (operation != _operation || _disposed) return;
        if (recovered != null) {
          await _resolve(session: recovered, restoring: true);
          return;
        }
      }
      _completeIfCurrent(
        operation,
        const MortAuthStartupSnapshot(
          stage: MortAuthStartupStage.unauthenticated,
          destination: '/splash',
        ),
      );
      return;
    }

    var activeSession = session;
    if (activeSession.isExpired) {
      _set(
        MortAuthStartupSnapshot(
          stage: MortAuthStartupStage.refreshing,
          userId: activeSession.userId,
        ),
      );
      if (initialRecoveryGrace > Duration.zero) {
        await Future<void>.delayed(initialRecoveryGrace);
        if (operation != _operation || _disposed) return;
        final recovered = _gateway.currentSession;
        if (recovered != null && !recovered.isExpired) {
          activeSession = recovered;
        }
      }

      Object? lastRefreshError;
      for (
        var attempt = 0;
        activeSession.isExpired && attempt < refreshAttempts;
        attempt++
      ) {
        try {
          final refreshed = await _gateway.refreshSession().timeout(
            refreshTimeout,
          );
          if (operation != _operation || _disposed) return;
          if (refreshed == null) {
            await _clearRevokedSession(operation);
            return;
          }
          activeSession = refreshed;
          lastRefreshError = null;
        } catch (error) {
          lastRefreshError = error;
          if (_isRevokedSessionError(error)) {
            await _clearRevokedSession(operation);
            return;
          }
          if (attempt + 1 < refreshAttempts && retryDelay > Duration.zero) {
            await Future<void>.delayed(retryDelay);
          }
        }
      }
      if (activeSession.isExpired) {
        _completeIfCurrent(
          operation,
          MortAuthStartupSnapshot(
            stage: MortAuthStartupStage.offline,
            userId: activeSession.userId,
            message: _isNetworkError(lastRefreshError)
                ? 'You appear to be offline. Your session remains on this device.'
                : 'MORT could not refresh this session. Retry when connected.',
          ),
        );
        return;
      }
    }

    try {
      final profile = await _gateway.ensureCurrentProfile().timeout(
        profileTimeout,
      );
      _completeIfCurrent(
        operation,
        routeAuthenticatedProfile(
          userId: activeSession.userId,
          profile: profile,
        ),
      );
    } catch (error) {
      _completeIfCurrent(
        operation,
        MortAuthStartupSnapshot(
          stage: MortAuthStartupStage.offline,
          userId: activeSession.userId,
          message: _isNetworkError(error)
              ? 'You appear to be offline. Your session remains on this device.'
              : 'MORT could not verify account access. Retry before continuing.',
        ),
      );
    }
  }

  Future<MortSessionSnapshot?> _waitForRestoredSession(int operation) async {
    final current = _gateway.currentSession;
    if (current != null) return current;

    final completer = Completer<MortSessionSnapshot?>.sync();
    late final StreamSubscription<MortAuthEvent> subscription;
    subscription = _gateway.events.listen(
      (event) {
        if (completer.isCompleted) return;
        if (event.type == MortAuthEventType.signedOut ||
            event.type == MortAuthEventType.userDeleted) {
          completer.complete(null);
          return;
        }
        if (event.session != null) {
          completer.complete(event.session);
        }
      },
      onError: (_) {
        if (!completer.isCompleted) completer.complete(null);
      },
    );

    try {
      return await completer.future.timeout(
        initialRecoveryGrace,
        onTimeout: () async {
          await Future<void>.delayed(const Duration(milliseconds: 250));
          return _gateway.currentSession;
        },
      );
    } finally {
      await subscription.cancel();
    }
  }

  Future<void> _clearRevokedSession(int operation) async {
    try {
      await _gateway.clearLocalSession();
    } finally {
      _completeIfCurrent(
        operation,
        const MortAuthStartupSnapshot(
          stage: MortAuthStartupStage.unauthenticated,
          destination: '/auth/sign-in',
          message: 'Your session ended. Sign in again.',
        ),
      );
    }
  }

  void _handleAuthEvent(MortAuthEvent event) {
    if (event.type == MortAuthEventType.signedOut ||
        event.type == MortAuthEventType.userDeleted) {
      markSignedOut();
      return;
    }
    if (event.type == MortAuthEventType.passwordRecovery ||
        event.type == MortAuthEventType.other) {
      return;
    }
    unawaited(_resolve(session: event.session, restoring: true));
  }

  void _handleAuthError(Object error, StackTrace stackTrace) {
    final session = _gateway.currentSession;
    if (session == null) {
      _operation++;
      _set(
        const MortAuthStartupSnapshot(
          stage: MortAuthStartupStage.offline,
          message: 'Session updates are unavailable. Retry when connected.',
        ),
      );
      return;
    }
    _operation++;
    _set(
      MortAuthStartupSnapshot(
        stage: MortAuthStartupStage.offline,
        userId: session.userId,
        message: 'Session updates are unavailable. Retry when connected.',
      ),
    );
  }

  void _completeIfCurrent(int operation, MortAuthStartupSnapshot next) {
    if (operation == _operation && !_disposed) _set(next);
  }

  void _set(MortAuthStartupSnapshot next) {
    if (_disposed) return;
    snapshot = next;
    notifyListeners();
  }

  static bool _isNetworkError(Object? error) {
    final value = error?.toString().toLowerCase() ?? '';
    return value.contains('socket') ||
        value.contains('network') ||
        value.contains('connection') ||
        value.contains('timed out') ||
        value.contains('timeout') ||
        value.contains('host lookup');
  }

  static bool _isRevokedSessionError(Object error) {
    if (error is AuthException &&
        const {'400', '401', '403', '404'}.contains(error.statusCode)) {
      return true;
    }
    final value = error.toString().toLowerCase();
    return value.contains('refresh_token_not_found') ||
        value.contains('invalid refresh token') ||
        value.contains('refresh token has been revoked') ||
        value.contains('user not found');
  }

  @override
  void dispose() {
    _disposed = true;
    _operation++;
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}

final authStartupGatewayProvider = Provider<MortAuthStartupGateway>(
  (ref) => const SupabaseAuthStartupGateway(),
);

final authStartupProvider = ChangeNotifierProvider<AuthStartupController>((
  ref,
) {
  final controller = AuthStartupController(
    ref.watch(authStartupGatewayProvider),
  );
  unawaited(controller.start());
  return controller;
});
