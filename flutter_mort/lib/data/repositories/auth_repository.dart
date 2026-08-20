import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/auth/oauth_flow.dart';
import '../../core/config/app_config.dart';
import '../../core/errors/mort_error.dart';
import '../../core/observability/operational_telemetry.dart';
import '../../services/push/push_notification_coordinator.dart';
import '../services/secure_device_storage.dart';
import '../services/supabase_service.dart';

enum OAuthPurpose { signIn, link }

class _OAuthProviderInfo {
  const _OAuthProviderInfo({
    required this.provider,
    required this.key,
    required this.displayName,
    required this.scopes,
  });

  final OAuthProvider provider;

  /// Matches `identity.provider` from Supabase and the audit event type
  /// prefix (e.g. `'google_linked'`, `'apple_linked'`).
  final String key;
  final String displayName;
  final String scopes;
}

const _googleOAuthProvider = _OAuthProviderInfo(
  provider: OAuthProvider.google,
  key: 'google',
  displayName: 'Google',
  scopes: 'openid email profile',
);

// Apple's own documented scope set for Sign in with Apple -- not the same
// string as Google's OIDC scopes.
const _appleOAuthProvider = _OAuthProviderInfo(
  provider: OAuthProvider.apple,
  key: 'apple',
  displayName: 'Apple',
  scopes: 'name email',
);

class _OAuthIntent {
  const _OAuthIntent({required this.purpose, required this.provider});

  final OAuthPurpose purpose;
  final _OAuthProviderInfo provider;
}

class ConnectedAuthIdentity {
  const ConnectedAuthIdentity({
    required this.provider,
    required this.email,
    required this.createdAt,
    required this.isGoogle,
    required this.isApple,
    required this.isPassword,
  });

  final String provider;
  final String? email;
  final DateTime? createdAt;
  final bool isGoogle;
  final bool isApple;
  final bool isPassword;
}

class AuthRepository {
  static const _uuid = Uuid();
  static const _recentAuthenticationWindow = Duration(minutes: 15);
  static const _oauthIntentLifetime = Duration(minutes: 10);
  static const _oauthPurposeKey = 'mort.oauth.purpose';
  static const _oauthProviderKey = 'mort.oauth.provider';
  static const _oauthStartedAtKey = 'mort.oauth.started_at';

  AuthRepository() {
    _ensureAuthListener();
  }

  final _oauthStates = StreamController<OAuthFlowSnapshot>.broadcast(
    sync: true,
  );
  final _launchGate = OAuthLaunchGate();
  final _completionGate = OAuthCompletionGate();
  OAuthFlowSnapshot _oauthState = const OAuthFlowSnapshot.idle();
  OAuthPurpose? _oauthPurpose;
  _OAuthProviderInfo _activeOAuthProvider = _googleOAuthProvider;
  StreamSubscription<AuthState>? _authSubscription;
  Timer? _oauthTimeout;
  bool _callbackProcessing = false;
  DateTime? _passwordRecoveryAuthorizedUntil;

  bool get isConfigured => SupabaseService.isConfigured;
  OAuthFlowSnapshot get oauthState => _oauthState;
  Stream<OAuthFlowSnapshot> get oauthStates => _oauthStates.stream;

  User? get currentUser => SupabaseService.isInitialized
      ? SupabaseService.client.auth.currentUser
      : null;

  Stream<AuthState> get authStateChanges {
    _ensureAuthListener();
    if (!SupabaseService.isInitialized) return const Stream<AuthState>.empty();
    return SupabaseService.client.auth.onAuthStateChange;
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) async {
    final response = await SupabaseService.client.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: AppConfig.resolvedAuthConfirmationRedirectUrl,
    );
    return response;
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    final response = await SupabaseService.client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    return response;
  }

  Future<OAuthFlowSnapshot> signInWithGoogle() {
    return _launchOAuth(_googleOAuthProvider, OAuthPurpose.signIn);
  }

  Future<OAuthFlowSnapshot> linkGoogleIdentity() {
    return _linkOAuthIdentity(_googleOAuthProvider);
  }

  Future<OAuthFlowSnapshot> signInWithApple() {
    return _launchOAuth(_appleOAuthProvider, OAuthPurpose.signIn);
  }

  Future<OAuthFlowSnapshot> linkAppleIdentity() {
    return _linkOAuthIdentity(_appleOAuthProvider);
  }

  Future<OAuthFlowSnapshot> _linkOAuthIdentity(
    _OAuthProviderInfo providerInfo,
  ) async {
    if (currentUser == null) {
      throw MortCodedError(
        'authentication_required',
        'Sign in before connecting ${providerInfo.displayName}.',
      );
    }
    if (!isRecentlyAuthenticated(currentUser)) {
      throw MortCodedError(
        'recent_authentication_required',
        'Sign out and sign back in, then connect ${providerInfo.displayName} within 15 minutes.',
      );
    }
    return _launchOAuth(providerInfo, OAuthPurpose.link);
  }

  Future<OAuthFlowSnapshot> _launchOAuth(
    _OAuthProviderInfo providerInfo,
    OAuthPurpose purpose,
  ) async {
    _ensureAuthListener();
    final providerEnabled = providerInfo.key == 'google'
        ? AppConfig.googleAuthEnabled
        : AppConfig.appleAuthEnabled;
    if (!providerEnabled) {
      return _setOAuth(
        OAuthFlowSnapshot(
          OAuthFlowStage.providerDisabled,
          '${providerInfo.displayName} sign-in needs owner configuration. Use email and password.',
        ),
      );
    }
    if (!_launchGate.tryAcquire()) return _oauthState;

    _oauthPurpose = purpose;
    _activeOAuthProvider = providerInfo;
    _callbackProcessing = false;
    _setOAuth(
      OAuthFlowSnapshot(
        OAuthFlowStage.launchingProvider,
        'Opening ${providerInfo.displayName} securely...',
      ),
    );
    try {
      await _persistOAuthIntent(purpose, providerInfo);
      final launched = purpose == OAuthPurpose.link
          ? await SupabaseService.client.auth.linkIdentity(
              providerInfo.provider,
              redirectTo: AppConfig.resolvedAuthRedirectUrl,
              scopes: providerInfo.scopes,
              authScreenLaunchMode: LaunchMode.externalApplication,
            )
          : await SupabaseService.client.auth.signInWithOAuth(
              providerInfo.provider,
              redirectTo: AppConfig.resolvedAuthRedirectUrl,
              scopes: providerInfo.scopes,
              authScreenLaunchMode: LaunchMode.externalApplication,
            );
      if (!launched) {
        _finishOAuth();
        return _setOAuth(
          const OAuthFlowSnapshot(
            OAuthFlowStage.browserClosed,
            'MORT could not open the browser. Check browser access and retry.',
          ),
        );
      }
      _oauthTimeout?.cancel();
      _oauthTimeout = Timer(const Duration(minutes: 3), () {
        if (_oauthState.stage == OAuthFlowStage.waitingForRedirect) {
          _finishOAuth();
          _setOAuth(
            const OAuthFlowSnapshot(
              OAuthFlowStage.retryAvailable,
              'No sign-in response arrived. You can safely try again.',
            ),
          );
        }
      });
      return _setOAuth(
        OAuthFlowSnapshot(
          OAuthFlowStage.waitingForRedirect,
          'Finish with ${providerInfo.displayName} in your browser, then return to MORT.',
        ),
      );
    } catch (error) {
      unawaited(
        MortOperationalTelemetry.recordFailure(
          eventType: 'auth_failure',
          safeCode: 'auth.oauth_launch_failed',
        ),
      );
      _finishOAuth();
      return _setOAuth(_safeLaunchFailure(providerInfo, error));
    }
  }

  Future<OAuthFlowSnapshot> handleOAuthCallback(Uri callback) async {
    final normalized = MortOAuthCallbackPolicy.normalize(
      callback,
      isWeb: kIsWeb,
    );
    if (!MortOAuthCallbackPolicy.isApproved(normalized, isWeb: kIsWeb)) {
      _finishOAuth();
      return _setOAuth(
        const OAuthFlowSnapshot(
          OAuthFlowStage.invalidRedirect,
          'MORT rejected an unrecognized sign-in response.',
        ),
      );
    }
    if (normalized.queryParameters.containsKey('error')) {
      _finishOAuth();
      return _setOAuth(MortOAuthCallbackPolicy.providerFailure(normalized));
    }
    if (_callbackProcessing) return _oauthState;
    _ensureAuthListener();
    if (!_launchGate.isActive && !_launchGate.tryAcquire()) {
      return _oauthState;
    }
    if (_oauthPurpose == null) {
      final restored = await _restoreOAuthIntent();
      _oauthPurpose = restored?.purpose ?? OAuthPurpose.signIn;
      _activeOAuthProvider = restored?.provider ?? _googleOAuthProvider;
    }
    _callbackProcessing = true;
    _setOAuth(
      const OAuthFlowSnapshot(
        OAuthFlowStage.processingCallback,
        'Verifying the sign-in response...',
      ),
    );
    if (_hasAuthenticatedSession) {
      await _completeOAuthOnce();
    } else {
      final providerInfo = _activeOAuthProvider;
      _oauthTimeout?.cancel();
      _oauthTimeout = Timer(const Duration(seconds: 30), () {
        if (_oauthState.stage != OAuthFlowStage.processingCallback) return;
        _finishOAuth();
        _setOAuth(
          OAuthFlowSnapshot(
            OAuthFlowStage.sessionExchangeFailed,
            '${providerInfo.displayName} finished, but MORT could not establish a secure session. Start again from MORT.',
          ),
        );
      });
    }
    return _oauthState;
  }

  void cancelOAuthFlow() {
    if (!_oauthState.isBusy) return;
    final providerInfo = _activeOAuthProvider;
    _finishOAuth();
    _setOAuth(
      OAuthFlowSnapshot(
        OAuthFlowStage.providerCanceled,
        '${providerInfo.displayName} sign-in was canceled. You can try again.',
      ),
    );
  }

  void resetOAuthState() {
    if (_oauthState.isBusy) return;
    _setOAuth(const OAuthFlowSnapshot.idle());
  }

  Future<List<ConnectedAuthIdentity>> getConnectedIdentities() async {
    final identities = await SupabaseService.client.auth.getUserIdentities();
    return identities
        .map(
          (identity) => ConnectedAuthIdentity(
            provider: identity.provider,
            email: identity.identityData?['email']?.toString(),
            createdAt: DateTime.tryParse(identity.createdAt ?? '')?.toUtc(),
            isGoogle: identity.provider == 'google',
            isApple: identity.provider == 'apple',
            isPassword: identity.provider == 'email',
          ),
        )
        .toList(growable: false);
  }

  Future<void> unlinkGoogleIdentity() => _unlinkIdentity(_googleOAuthProvider);

  Future<void> unlinkAppleIdentity() => _unlinkIdentity(_appleOAuthProvider);

  Future<void> _unlinkIdentity(_OAuthProviderInfo providerInfo) async {
    final user = currentUser;
    if (user == null) {
      throw const MortCodedError(
        'authentication_required',
        'Sign in before changing connected accounts.',
      );
    }
    if (!isRecentlyAuthenticated(user)) {
      throw MortCodedError(
        'recent_authentication_required',
        'Sign out and sign back in, then disconnect ${providerInfo.displayName} within 15 minutes.',
      );
    }
    final identities = await SupabaseService.client.auth.getUserIdentities();
    final matching = identities
        .where((item) => item.provider == providerInfo.key)
        .toList();
    if (matching.isEmpty) return;
    if (identities.length < 2) {
      throw MortCodedError(
        'last_identity_required',
        'Add another sign-in method before disconnecting ${providerInfo.displayName}.',
      );
    }

    await SupabaseService.client.auth.unlinkIdentity(matching.single);
    if (!await _recordAuthIdentityEvent(
      '${providerInfo.key}_unlinked',
      providerInfo,
    )) {
      throw MortCodedError(
        'identity_audit_failed',
        '${providerInfo.displayName} was disconnected, but MORT could not record the account security change. Contact Support.',
      );
    }
  }

  Future<void> reauthenticateWithPassword(String password) async {
    final email = currentUser?.email;
    if (email == null || email.isEmpty) {
      throw const AuthException(
        'This account cannot use password reauthentication. Sign out and sign in again before changing the account.',
      );
    }
    await SupabaseService.client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> resetPassword(String email) {
    return SupabaseService.client.auth.resetPasswordForEmail(
      email,
      redirectTo: AppConfig.resolvedPasswordRecoveryRedirectUrl,
    );
  }

  Future<void> completePasswordRecovery(String password) async {
    if (currentUser == null || !canCompletePasswordRecovery) {
      throw const MortCodedError(
        'password_recovery_session_required',
        'Request a new password reset link and open it on this device.',
      );
    }
    await SupabaseService.client.auth.updateUser(
      UserAttributes(password: password),
    );
    _passwordRecoveryAuthorizedUntil = null;
    await signOutGlobal();
  }

  bool get canCompletePasswordRecovery {
    final expiresAt = _passwordRecoveryAuthorizedUntil;
    return expiresAt != null && DateTime.now().toUtc().isBefore(expiresAt);
  }

  Future<void> signOutLocal() => _signOut(SignOutScope.local);

  Future<void> signOutGlobal() => _signOut(SignOutScope.global);

  Future<void> signOut() => signOutLocal();

  Future<void> _signOut(SignOutScope scope) async {
    _finishOAuth();
    _passwordRecoveryAuthorizedUntil = null;
    Object? pushFailure;
    try {
      try {
        await PushNotificationCoordinator.instance.prepareForSignOut(
          allDevices: scope == SignOutScope.global,
        );
      } catch (error) {
        pushFailure = error;
      }
      await SupabaseService.client.auth.signOut(scope: scope);
    } finally {
      await SupabaseService.clearPersistedSession();
    }
    if (pushFailure != null) {
      throw const MortCodedError(
        'push_revocation_unconfirmed',
        'This device signed out, but notification revocation could not be confirmed.',
      );
    }
  }

  static bool isRecentlyAuthenticated(
    User? user, {
    DateTime? now,
    Duration window = _recentAuthenticationWindow,
  }) {
    final signedInAt = DateTime.tryParse(user?.lastSignInAt ?? '')?.toUtc();
    if (signedInAt == null) return false;
    final current = (now ?? DateTime.now()).toUtc();
    final age = current.difference(signedInAt);
    return !age.isNegative && age <= window;
  }

  void _ensureAuthListener() {
    if (_authSubscription != null || !SupabaseService.isInitialized) return;
    _authSubscription = SupabaseService.client.auth.onAuthStateChange.listen(
      (state) {
        if (state.event == AuthChangeEvent.passwordRecovery) {
          _passwordRecoveryAuthorizedUntil = DateTime.now().toUtc().add(
            const Duration(minutes: 10),
          );
        }
        if (!_launchGate.isActive) return;
        if (state.event == AuthChangeEvent.initialSession ||
            state.event == AuthChangeEvent.signedIn ||
            state.event == AuthChangeEvent.userUpdated) {
          if (state.session != null && _hasAuthenticatedSession) {
            unawaited(_completeOAuthOnce());
          }
        } else if (state.event == AuthChangeEvent.signedOut) {
          _finishOAuth();
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!_launchGate.isActive || !_oauthState.isBusy) return;
        final providerInfo = _activeOAuthProvider;
        _finishOAuth();
        _setOAuth(_safeLaunchFailure(providerInfo, error));
      },
    );
  }

  bool get _hasAuthenticatedSession {
    final auth = SupabaseService.client.auth;
    final session = auth.currentSession;
    final user = auth.currentUser;
    return OAuthSessionReadinessPolicy.isReady(
      hasSession: session != null,
      hasUser: user != null,
      userIdsMatch:
          session != null && user != null && session.user.id == user.id,
    );
  }

  Future<void> _completeOAuthOnce() => _completionGate.run(_completeOAuth);

  Future<void> _completeOAuth() async {
    if (!_launchGate.isActive || _oauthState.stage == OAuthFlowStage.success) {
      return;
    }
    final providerInfo = _activeOAuthProvider;
    final auth = SupabaseService.client.auth;
    final session = auth.currentSession;
    final user = auth.currentUser;
    if (!OAuthSessionReadinessPolicy.isReady(
      hasSession: session != null,
      hasUser: user != null,
      userIdsMatch:
          session != null && user != null && session.user.id == user.id,
    )) {
      _finishOAuth();
      _setOAuth(
        OAuthFlowSnapshot(
          OAuthFlowStage.sessionExchangeFailed,
          '${providerInfo.displayName} finished, but MORT could not establish a secure session. Start again from MORT.',
        ),
      );
      return;
    }

    _oauthTimeout?.cancel();
    _oauthTimeout = null;
    _setOAuth(
      const OAuthFlowSnapshot(
        OAuthFlowStage.completingProfile,
        'Checking your MORT account...',
      ),
    );

    late final Map<String, dynamic> profile;
    try {
      final result = await SupabaseService.client.rpc('ensure_my_profile');
      profile = _profileFromRpc(result);
      if (profile.isEmpty || profile['id']?.toString() != user!.id) {
        throw const MortCodedError(
          'profile_bootstrap_failed',
          'The signed-in account profile was not available.',
        );
      }
    } catch (error) {
      unawaited(
        MortOperationalTelemetry.recordFailure(
          eventType: 'auth_failure',
          safeCode: 'auth.profile_bootstrap_failed',
        ),
      );
      _finishOAuth();
      final safeFailure = _safeLaunchFailure(providerInfo, error);
      _setOAuth(
        safeFailure.stage == OAuthFlowStage.networkUnavailable
            ? safeFailure
            : const OAuthFlowSnapshot(
                OAuthFlowStage.profileBootstrapFailed,
                'You are signed in, but MORT could not prepare your account. Retry, then contact Support if this continues.',
              ),
      );
      return;
    }

    final accountStatus = profile['account_status']?.toString() ?? 'active';
    if (accountStatus.contains('deletion')) {
      _finishOAuth();
      _setOAuth(
        const OAuthFlowSnapshot(
          OAuthFlowStage.accountDeletionPending,
          'This account has a deletion request in progress. Contact Support.',
        ),
      );
      return;
    }
    if (accountStatus != 'active') {
      _finishOAuth();
      _setOAuth(
        const OAuthFlowSnapshot(
          OAuthFlowStage.accountSuspended,
          'This MORT account is restricted. Use Support for next steps.',
        ),
      );
      return;
    }

    final purpose = _oauthPurpose ?? OAuthPurpose.signIn;
    final auditRecorded = await _recordAuthIdentityEvent(
      purpose == OAuthPurpose.link
          ? '${providerInfo.key}_linked'
          : '${providerInfo.key}_sign_in',
      providerInfo,
    );
    if (!auditRecorded && purpose == OAuthPurpose.link) {
      _finishOAuth();
      _setOAuth(
        OAuthFlowSnapshot(
          OAuthFlowStage.identityAuditFailed,
          '${providerInfo.displayName} is connected, but MORT could not verify the account security record. Contact Support before retrying.',
        ),
      );
      return;
    }

    _finishOAuth();
    _setOAuth(
      OAuthFlowSnapshot(
        OAuthFlowStage.success,
        purpose == OAuthPurpose.link
            ? '${providerInfo.displayName} is connected to your MORT account.'
            : 'You are signed in to MORT.',
      ),
    );
  }

  Map<String, dynamic> _profileFromRpc(Object? result) {
    if (result is Map) return Map<String, dynamic>.from(result);
    if (result is List && result.isNotEmpty && result.first is Map) {
      return Map<String, dynamic>.from(result.first as Map);
    }
    return const <String, dynamic>{};
  }

  Future<bool> _recordAuthIdentityEvent(
    String eventType,
    _OAuthProviderInfo providerInfo,
  ) async {
    try {
      final result = await SupabaseService.client.rpc(
        'record_my_auth_identity_event',
        params: {
          'p_event_type': eventType,
          'p_provider': providerInfo.key,
          'p_client_request_id': _uuid.v4(),
        },
      );
      return result is Map && result['ok'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _persistOAuthIntent(
    OAuthPurpose purpose,
    _OAuthProviderInfo providerInfo,
  ) async {
    await mortSecureDeviceStorage.write(
      key: _oauthPurposeKey,
      value: purpose.name,
    );
    await mortSecureDeviceStorage.write(
      key: _oauthProviderKey,
      value: providerInfo.key,
    );
    await mortSecureDeviceStorage.write(
      key: _oauthStartedAtKey,
      value: DateTime.now().toUtc().toIso8601String(),
    );
  }

  Future<_OAuthIntent?> _restoreOAuthIntent() async {
    final purpose = await mortSecureDeviceStorage.read(key: _oauthPurposeKey);
    final providerKey = await mortSecureDeviceStorage.read(
      key: _oauthProviderKey,
    );
    final startedAt = DateTime.tryParse(
      await mortSecureDeviceStorage.read(key: _oauthStartedAtKey) ?? '',
    )?.toUtc();
    final age = startedAt == null
        ? null
        : DateTime.now().toUtc().difference(startedAt);
    if (age == null || age.isNegative || age > _oauthIntentLifetime) {
      await _clearOAuthPurpose();
      return null;
    }
    OAuthPurpose? resolvedPurpose;
    for (final value in OAuthPurpose.values) {
      if (value.name == purpose) resolvedPurpose = value;
    }
    if (resolvedPurpose == null) return null;
    final resolvedProvider = providerKey == _appleOAuthProvider.key
        ? _appleOAuthProvider
        : _googleOAuthProvider;
    return _OAuthIntent(purpose: resolvedPurpose, provider: resolvedProvider);
  }

  Future<void> _clearOAuthPurpose() async {
    await mortSecureDeviceStorage.delete(key: _oauthPurposeKey);
    await mortSecureDeviceStorage.delete(key: _oauthProviderKey);
    await mortSecureDeviceStorage.delete(key: _oauthStartedAtKey);
  }

  OAuthFlowSnapshot _safeLaunchFailure(
    _OAuthProviderInfo providerInfo,
    Object error,
  ) {
    final message = error.toString().toLowerCase();
    if (message.contains('provider') && message.contains('disabled')) {
      return OAuthFlowSnapshot(
        OAuthFlowStage.providerDisabled,
        '${providerInfo.displayName} sign-in is not available right now. Use email and password.',
      );
    }
    if (message.contains('network') ||
        message.contains('socket') ||
        message.contains('connection')) {
      return const OAuthFlowSnapshot(
        OAuthFlowStage.networkUnavailable,
        'No network connection is available. Reconnect and try again.',
      );
    }
    return OAuthFlowSnapshot(
      OAuthFlowStage.internalFailure,
      'MORT could not start ${providerInfo.displayName} sign-in. Try again.',
    );
  }

  OAuthFlowSnapshot _setOAuth(OAuthFlowSnapshot next) {
    _oauthState = next;
    if (!_oauthStates.isClosed) _oauthStates.add(next);
    return next;
  }

  void _finishOAuth() {
    _oauthTimeout?.cancel();
    _oauthTimeout = null;
    _callbackProcessing = false;
    _oauthPurpose = null;
    if (_launchGate.isActive) _launchGate.release();
    unawaited(_clearOAuthPurpose());
  }

  void dispose() {
    _oauthTimeout?.cancel();
    _authSubscription?.cancel();
    _oauthStates.close();
  }
}
