enum OAuthFlowStage {
  idle,
  launchingProvider,
  waitingForRedirect,
  processingCallback,
  completingProfile,
  success,
  sessionExchangeFailed,
  profileBootstrapFailed,
  identityAuditFailed,
  providerCanceled,
  browserClosed,
  networkUnavailable,
  providerDisabled,
  invalidRedirect,
  stateMismatch,
  loginBlocked,
  accountSuspended,
  accountDeletionPending,
  internalFailure,
  retryAvailable,
}

class OAuthFlowSnapshot {
  const OAuthFlowSnapshot(this.stage, this.message);

  const OAuthFlowSnapshot.idle() : stage = OAuthFlowStage.idle, message = '';

  final OAuthFlowStage stage;
  final String message;

  bool get isBusy => switch (stage) {
    OAuthFlowStage.launchingProvider ||
    OAuthFlowStage.waitingForRedirect ||
    OAuthFlowStage.processingCallback ||
    OAuthFlowStage.completingProfile => true,
    _ => false,
  };

  bool get canCancel => stage == OAuthFlowStage.waitingForRedirect;

  bool get isError => switch (stage) {
    OAuthFlowStage.sessionExchangeFailed ||
    OAuthFlowStage.profileBootstrapFailed ||
    OAuthFlowStage.identityAuditFailed ||
    OAuthFlowStage.providerCanceled ||
    OAuthFlowStage.browserClosed ||
    OAuthFlowStage.networkUnavailable ||
    OAuthFlowStage.providerDisabled ||
    OAuthFlowStage.invalidRedirect ||
    OAuthFlowStage.stateMismatch ||
    OAuthFlowStage.loginBlocked ||
    OAuthFlowStage.accountSuspended ||
    OAuthFlowStage.accountDeletionPending ||
    OAuthFlowStage.internalFailure ||
    OAuthFlowStage.retryAvailable => true,
    _ => false,
  };
}

class OAuthSessionReadinessPolicy {
  const OAuthSessionReadinessPolicy._();

  static bool isReady({
    required bool hasSession,
    required bool hasUser,
    required bool userIdsMatch,
  }) => hasSession && hasUser && userIdsMatch;
}

class OAuthCompletionGate {
  Future<void>? _activeCompletion;

  Future<void> run(Future<void> Function() completion) {
    final active = _activeCompletion;
    if (active != null) return active;

    final next = completion();
    _activeCompletion = next;
    return next.whenComplete(() {
      if (identical(_activeCompletion, next)) _activeCompletion = null;
    });
  }
}

class OAuthLaunchGate {
  OAuthLaunchGate({this.cooldown = const Duration(seconds: 2)});

  final Duration cooldown;
  bool _active = false;
  DateTime? _releasedAt;

  bool get isActive => _active;

  bool tryAcquire([DateTime? now]) {
    final current = now ?? DateTime.now().toUtc();
    if (_active) return false;
    if (_releasedAt != null && current.difference(_releasedAt!) < cooldown) {
      return false;
    }
    _active = true;
    return true;
  }

  void release([DateTime? now]) {
    _active = false;
    _releasedAt = now ?? DateTime.now().toUtc();
  }
}

class MortOAuthCallbackPolicy {
  const MortOAuthCallbackPolicy._();

  static const nativeScheme = 'com.mortapp.mobile';
  static const nativeHost = 'app';
  static const nativePath = '/auth-callback';
  static const webHost = 'mort-web.vercel.app';
  static const webPath = '/auth-callback';

  static const _sensitiveParameters = <String>{
    'access_token',
    'refresh_token',
    'id_token',
  };

  static Uri normalize(Uri uri, {required bool isWeb}) {
    if (uri.hasScheme || isWeb || uri.path != nativePath) return uri;
    return Uri(
      scheme: nativeScheme,
      host: nativeHost,
      path: nativePath,
      query: uri.query.isEmpty ? null : uri.query,
      fragment: uri.fragment.isEmpty ? null : uri.fragment,
    );
  }

  static bool isApproved(Uri uri, {required bool isWeb}) {
    final normalized = normalize(uri, isWeb: isWeb);
    if (normalized.queryParameters.keys.any(_sensitiveParameters.contains) ||
        _fragmentContainsSensitiveParameter(normalized.fragment)) {
      return false;
    }

    if (isWeb) {
      if (!normalized.hasScheme) return normalized.path == webPath;
      return normalized.scheme == 'https' &&
          normalized.host == webHost &&
          normalized.path == webPath;
    }

    return normalized.scheme == nativeScheme &&
        normalized.host == nativeHost &&
        normalized.path == nativePath;
  }

  static bool _fragmentContainsSensitiveParameter(String fragment) {
    if (fragment.isEmpty) return false;
    try {
      return Uri.splitQueryString(
        fragment,
      ).keys.any(_sensitiveParameters.contains);
    } on FormatException {
      return true;
    }
  }

  static OAuthFlowSnapshot providerFailure(Uri uri) {
    final code =
        (uri.queryParameters['error_code'] ??
                uri.queryParameters['error'] ??
                '')
            .trim()
            .toLowerCase();
    return switch (code) {
      'access_denied' ||
      'user_cancelled' ||
      'user_canceled' => const OAuthFlowSnapshot(
        OAuthFlowStage.providerCanceled,
        'Google sign-in was canceled. You can try again.',
      ),
      'bad_oauth_state' || 'state_mismatch' => const OAuthFlowSnapshot(
        OAuthFlowStage.stateMismatch,
        'The sign-in response could not be verified. Start again from MORT.',
      ),
      'provider_disabled' => const OAuthFlowSnapshot(
        OAuthFlowStage.providerDisabled,
        'Google sign-in is not available right now. Use email and password.',
      ),
      _ => const OAuthFlowSnapshot(
        OAuthFlowStage.internalFailure,
        'Google could not complete sign-in. No account changes were made.',
      ),
    };
  }
}
