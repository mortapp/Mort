Uri? safeExternalHttpsUri(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      (uri.hasPort && uri.port != 443) ||
      _isLocalOrPrivateHost(uri.host)) {
    return null;
  }
  return uri;
}

Uri? safeStripeConnectUri(String value) {
  final uri = safeExternalHttpsUri(value);
  return uri != null && uri.host.toLowerCase() == 'connect.stripe.com'
      ? uri
      : null;
}

String? safeInternalHelpRoute(String? value) {
  if (value == null || value.length > 240) return null;
  final uri = Uri.tryParse(value.trim());
  if (uri == null ||
      uri.hasScheme ||
      uri.hasAuthority ||
      !uri.path.startsWith('/') ||
      uri.pathSegments.any((segment) => segment == '..')) {
    return null;
  }
  const exact = {'/support', '/guide', '/legal-center'};
  const prefixes = {'/legal/', '/legal-center/', '/support/', '/guide/'};
  final allowed =
      exact.contains(uri.path) ||
      prefixes.any((prefix) => uri.path.startsWith(prefix));
  return allowed ? uri.toString() : null;
}

bool _isLocalOrPrivateHost(String host) {
  final normalized = host.toLowerCase().replaceFirst(RegExp(r'\.$'), '');
  if (normalized == 'localhost' ||
      normalized == '::1' ||
      normalized.endsWith('.localhost') ||
      normalized.endsWith('.local') ||
      normalized.contains(':')) {
    return true;
  }
  final octets = normalized.split('.').map(int.tryParse).toList();
  if (octets.length != 4 || octets.any((value) => value == null)) return false;
  final a = octets[0]!;
  final b = octets[1]!;
  return a == 0 ||
      a == 10 ||
      a == 127 ||
      (a == 169 && b == 254) ||
      (a == 172 && b >= 16 && b <= 31) ||
      (a == 192 && b == 168) ||
      a >= 224;
}
