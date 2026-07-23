class PasskeyCapability {
  const PasskeyCapability({
    required this.browserApiAvailable,
    required this.secureContext,
    required this.platformAuthenticatorAvailable,
    required this.detail,
  });

  final bool browserApiAvailable;
  final bool secureContext;
  final bool platformAuthenticatorAvailable;
  final String detail;

  bool get canUseBrowserPasskeys =>
      browserApiAvailable && secureContext && platformAuthenticatorAvailable;
}
