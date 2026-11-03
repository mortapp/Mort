import 'package:flutter_mort/features/ads/data/ad_session_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final futureExpiry = DateTime.now().toUtc().add(const Duration(minutes: 5));

  AdSessionIdentity identity({
    String userId = 'user-a',
    String accessToken = 'token-a',
    DateTime? expiresAt,
  }) {
    return AdSessionIdentity(
      userId: userId,
      accessToken: accessToken,
      expiresAt: expiresAt ?? futureExpiry,
    );
  }

  test('only the exact active user session matches', () {
    final captured = identity();

    expect(captured.matchesActive(identity()), isTrue);
    expect(captured.matchesActive(identity(userId: 'user-b')), isFalse);
    expect(captured.matchesActive(identity(accessToken: 'token-b')), isFalse);
    expect(
      captured.matchesActive(
        identity(expiresAt: futureExpiry.add(const Duration(seconds: 1))),
      ),
      isFalse,
    );
    expect(captured.matchesActive(null), isFalse);
  });

  test('expired or incomplete sessions cannot authorize ad work', () {
    expect(
      identity(
        expiresAt: DateTime.now().toUtc().subtract(const Duration(seconds: 1)),
      ).isActive,
      isFalse,
    );
    expect(
      const AdSessionIdentity(
        userId: 'user-a',
        accessToken: 'token-a',
        expiresAt: null,
      ).isActive,
      isFalse,
    );
    expect(
      const AdSessionIdentity(
        userId: 'user-a',
        accessToken: '',
        expiresAt: null,
      ).isActive,
      isFalse,
    );
  });

  test('request generations reject callbacks from invalidated sessions', () {
    final guard = AdRequestSessionGuard();
    final captured = identity();
    final request = guard.begin();

    expect(guard.isCurrent(request, captured, captured), isTrue);
    expect(
      guard.isCurrent(request, captured, identity(userId: 'user-b')),
      isFalse,
    );
    expect(
      guard.isCurrent(request, captured, identity(accessToken: 'token-b')),
      isFalse,
    );

    guard.invalidate();
    expect(guard.isCurrent(request, captured, captured), isFalse);
    expect(guard.isCurrent(guard.begin(), captured, captured), isTrue);
  });
}
