import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/auth/oauth_flow.dart';
import '../../core/config/app_config.dart';
import '../../core/errors/mort_error.dart';
import '../services/secure_device_storage.dart';
import '../services/supabase_service.dart';

enum OAuthPurpose { signIn, link }

class ConnectedAuthIdentity {
  const ConnectedAuthIdentity({
    required this.provider,
    required this.email,
    required this.createdAt,
    required this.isGoogle,
    required this.isPassword,
  });

  final String provider;
  final String? email;
  final DateTime? createdAt;
  final bool isGoogle;
  final bool isPassword;
}

class AuthRepository {
  static const _uuid = Uuid();
  static const _recentAuthenticationWindow = Duration(minutes: 15);
  static const _oauthIntentLifetime = Duration(minutes: 10);
  static const _oauthPurposeKey = 'mort.oauth.purpose';
  static const _oauthStartedAtKey = 'mort.oauth.started_at';

  AuthRepository() {
    _ensureAuthListener();
  }

  final _oauthStates = StreamController<OAuthFlowSnapshot>.broadcast(
    sync: true,
  );
  final _launchGate = OAuthLaunchGate();
  OAuthFlowSnapshot _oauthState = const OAuthFlowSnapshot.idle();
  OAuthPurpose? _oauthPurpose;
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
    return _launchGoogle(OAuthPurpose.signIn);
  }

  Future<OAuthFlowSnapshot> linkGoogleIdentity() async {
    if (currentUser == null) {
      throw const MortCodedError(
        'authentication_required',
        'Sign in before connecting Google.',
      );
    }
    if (!isRecentlyAuthenticated(currentUser)) {
      throw const MortCodedError(
        'recent_authentication_required',
        'Sign out and sign back in, then connect Google within 15 minutes.',
      );
    }
    return _launchGoogle(OAuthPurpose.link);
  }

  Future<OAuthFlowSnapshot> _launchGoogle(OAuthPurpose purpose) async {
    _ensureAuthListener();
    if (!AppConfig.googleAuthEnabled) {
      return _setOAuth(
        const OAuthFlowSnapshot(
          OAuthFlowStage.providerDisabled,
          'Google sign-in needs owner configuration. Use email and password.',
        ),
      );
    }
    if (!_launchGate.tryAcquire()) return _oauthState;

    _oauthPurpose = purpose;
    _callbackProcessing = false;
    _setOAuth(
      const OAuthFlowSnapshot(
        OAuthFlowStage.launchingProvider,
        'Opening Google securely...',
      ),
    );
    try {
      await _persistOAuthPurpose(purpose);
      final launched = purpose == OAuthPurpose.link
          ? await SupabaseService.client.auth.linkIdentity(
              OAuthProvider.google,
              redirectTo: AppConfig.resolvedAuthRedirectUrl,
              scopes: 'openid email profile',
              authScreenLaunchMode: LaunchMode.externalApplication,
            )
          : await SupabaseService.client.auth.signInWithOAuth(
              OAuthProvider.google,
              redirectTo: AppConfig.resolvedAuthRedirectUrl,
              scopes: 'openid email profile',
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
        const OAuthFlowSnapshot(
          OAuthFlowStage.waitingForRedirect,
          'Finish with Google in your browser, then return to MORT.',
        ),
      );
    } catch (error) {
      _finishOAuth();
      return _setOAuth(_safeLaunchFailure(error));
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
    _oauthPurpose ??= await _restoreOAuthPurpose() ?? OAuthPurpose.signIn;
    _callbackProcessing = true;
    _setOAuth(
      const OAuthFlowSnapshot(
        OAuthFlowStage.processingCallback,
        'Verifying the sign-in response...',
      ),
    );
    if (SupabaseService.client.auth.currentSession != null) {
      await _completeOAuth();
    } else {
      _oauthTimeout?.cancel();
      _oauthTimeout = Timer(const Duration(seconds: 30), () {
        if (_oauthState.stage != OAuthFlowStage.processingCallback) return;
        _finishOAuth();
        _setOAuth(
          const OAuthFlowSnapshot(
            OAuthFlowStage.retryAvailable,
            'The secure sign-in session did not arrive. Start again from MORT.',
          ),
        );
      });
    }
    return _oauthState;
  }

  void cancelOAuthFlow() {
    if (!_oauthState.isBusy) return;
    _finishOAuth();
    _setOAuth(
      const OAuthFlowSnapshot(
        OAuthFlowStage.providerCanceled,
        'Google sign-in was canceled. You can try again.',
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
            isPassword: identity.provider == 'email',
          ),
        )
        .toList(growable: false);
  }

  Future<void> unlinkGoogleIdentity() async {
    final user = currentUser;
    if (user == null) {
      throw const MortCodedError(
        'authentication_required',
        'Sign in before changing connected accounts.',
      );
    }
    if (!isRecentlyAuthenticated(user)) {
      throw const MortCodedError(
        'recent_authentication_required',
        'Sign out and sign back in, then disconnect Google within 15 minutes.',
      );
    }
    final identities = await SupabaseService.client.auth.getUserIdentities();
    final google = identities
        .where((item) => item.provider == 'google')
        .toList();
    if (google.isEmpty) return;
    if (identities.length < 2) {
      throw const MortCodedError(
        'last_identity_required',
        'Add another sign-in method before disconnecting Google.',
      );
    }

    await SupabaseService.client.auth.unlinkIdentity(google.single);
    await _recordAuthIdentityEvent('google_unlinked');
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
    await SupabaseService.client.auth.signOut(scope: SignOutScope.global);
  }

  bool get canCompletePasswordRecovery {
    final expiresAt = _passwordRecoveryAuthorizedUntil;
    return expiresAt != null && DateTime.now().toUtc().isBefore(expiresAt);
  }

  Future<void> signOut() async {
    _finishOAuth();
    await SupabaseService.client.auth.signOut();
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
    _authSubscription = SupabaseService.client.auth.onAuthStateChange.listen((
      state,
    ) {
      if (state.event == AuthChangeEvent.passwordRecovery) {
        _passwordRecoveryAuthorizedUntil = DateTime.now().toUtc().add(
          const Duration(minutes: 10),
        );
      }
      if (!_launchGate.isActive) return;
      if (state.event == AuthChangeEvent.signedIn ||
          state.event == AuthChangeEvent.userUpdated) {
        unawaited(_completeOAuth());
      } else if (state.event == AuthChangeEvent.signedOut) {
        _finishOAuth();
      }
    });
  }

  Future<void> _completeOAuth() async {
    if (!_launchGate.isActive || _oauthState.stage == OAuthFlowStage.success) {
      return;
    }
    _setOAuth(
      const OAuthFlowSnapshot(
        OAuthFlowStage.completingProfile,
        'Checking your MORT account...',
      ),
    );
    try {
      final rows = await SupabaseService.client.rpc('get_my_profile');
      final profile = rows is List && rows.isNotEmpty && rows.first is Map
          ? Map<String, dynamic>.from(rows.first as Map)
          : const <String, dynamic>{};
      final accountStatus = profile['account_status']?.toString() ?? 'active';
      if (accountStatus.contains('deletion')) {
        _finishOAuth();
        _setOAuth(
          const OAuthFlowSnapshot(
            OAuthFlowStage.accountDeletionPending,
            'This account has a deletion request in progress. Contact support.',
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

      await _recordAuthIdentityEvent(
        _oauthPurpose == OAuthPurpose.link ? 'google_linked' : 'google_sign_in',
      );
      _finishOAuth();
      _setOAuth(
        const OAuthFlowSnapshot(
          OAuthFlowStage.success,
          'Google authentication completed securely.',
        ),
      );
    } catch (error) {
      _finishOAuth();
      _setOAuth(_safeLaunchFailure(error));
    }
  }

  Future<void> _recordAuthIdentityEvent(String eventType) async {
    final result = await SupabaseService.client.rpc(
      'record_my_auth_identity_event',
      params: {
        'p_event_type': eventType,
        'p_provider': 'google',
        'p_client_request_id': _uuid.v4(),
      },
    );
    if (result is! Map || result['ok'] != true) {
      throw const MortCodedError(
        'identity_audit_failed',
        'The account changed, but MORT could not verify its security history. Contact Support before trying again.',
      );
    }
  }

  Future<void> _persistOAuthPurpose(OAuthPurpose purpose) async {
    await mortSecureDeviceStorage.write(
      key: _oauthPurposeKey,
      value: purpose.name,
    );
    await mortSecureDeviceStorage.write(
      key: _oauthStartedAtKey,
      value: DateTime.now().toUtc().toIso8601String(),
    );
  }

  Future<OAuthPurpose?> _restoreOAuthPurpose() async {
    final purpose = await mortSecureDeviceStorage.read(key: _oauthPurposeKey);
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
    for (final value in OAuthPurpose.values) {
      if (value.name == purpose) return value;
    }
    return null;
  }

  Future<void> _clearOAuthPurpose() async {
    await mortSecureDeviceStorage.delete(key: _oauthPurposeKey);
    await mortSecureDeviceStorage.delete(key: _oauthStartedAtKey);
  }

  OAuthFlowSnapshot _safeLaunchFailure(Object error) {
    final message = error.toString().toLowerCase();
    if (message.contains('provider') && message.contains('disabled')) {
      return const OAuthFlowSnapshot(
        OAuthFlowStage.providerDisabled,
        'Google sign-in is not available right now. Use email and password.',
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
    return const OAuthFlowSnapshot(
      OAuthFlowStage.internalFailure,
      'Google authentication could not finish. No private token was stored.',
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
