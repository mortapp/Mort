import 'passkey_capability_model.dart';

Future<PasskeyCapability> detectPasskeyCapability() async {
  return const PasskeyCapability(
    browserApiAvailable: false,
    secureContext: false,
    platformAuthenticatorAvailable: false,
    detail:
        'Browser passkey detection applies only to the Flutter Web preview.',
  );
}
