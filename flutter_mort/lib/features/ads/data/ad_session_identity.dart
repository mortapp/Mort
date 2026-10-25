import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/services/supabase_service.dart';

final adSessionIdentityReaderProvider = Provider<AdSessionIdentity? Function()>(
  (ref) => AdSessionIdentity.current,
);

class AdSessionIdentity {
  const AdSessionIdentity({
    required this.userId,
    required this.accessToken,
    required this.expiresAt,
  });

  final String userId;
  final String accessToken;
  final DateTime? expiresAt;

  bool get isActive {
    final expiry = expiresAt;
    return userId.isNotEmpty &&
        accessToken.isNotEmpty &&
        expiry != null &&
        expiry.isAfter(DateTime.now().toUtc());
  }

  bool matchesActive(AdSessionIdentity? other) {
    return other != null &&
        isActive &&
        other.isActive &&
        userId == other.userId &&
        accessToken == other.accessToken &&
        expiresAt == other.expiresAt;
  }

  static AdSessionIdentity? current() {
    if (!SupabaseService.isInitialized) return null;
    final session = SupabaseService.client.auth.currentSession;
    if (session == null) return null;
    final expiresAt = session.expiresAt;
    return AdSessionIdentity(
      userId: session.user.id,
      accessToken: session.accessToken,
      expiresAt: expiresAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000, isUtc: true),
    );
  }
}

class AdRequestSessionGuard {
  int _generation = 0;

  int get generation => _generation;

  int begin() => ++_generation;

  void invalidate() {
    _generation++;
  }

  bool isCurrent(
    int generation,
    AdSessionIdentity captured,
    AdSessionIdentity? current,
  ) {
    return generation == _generation && captured.matchesActive(current);
  }
}
