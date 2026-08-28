import 'dart:js_interop';

import 'passkey_capability_model.dart';

@JS('window.PublicKeyCredential')
external JSObject? get _publicKeyCredential;

@JS('window.isSecureContext')
external JSBoolean? get _isSecureContext;

@JS('PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable')
external JSPromise<JSBoolean> _platformAuthenticatorAvailable();

Future<PasskeyCapability> detectPasskeyCapability() async {
  final browserApiAvailable = _publicKeyCredential != null;
  final secureContext = _isSecureContext?.toDart ?? false;
  var platformAuthenticatorAvailable = false;

  if (browserApiAvailable && secureContext) {
    try {
      platformAuthenticatorAvailable =
          (await _platformAuthenticatorAvailable().toDart).toDart;
    } catch (_) {
      platformAuthenticatorAvailable = false;
    }
  }

  final detail = !secureContext
      ? 'Passkeys require HTTPS or a secure local development context.'
      : !browserApiAvailable
      ? 'This browser does not expose the WebAuthn PublicKeyCredential API.'
      : !platformAuthenticatorAvailable
      ? 'The browser did not report an available platform authenticator.'
      : 'This browser reports a platform authenticator. MORT server enrollment remains disabled.';

  return PasskeyCapability(
    browserApiAvailable: browserApiAvailable,
    secureContext: secureContext,
    platformAuthenticatorAvailable: platformAuthenticatorAvailable,
    detail: detail,
  );
}
