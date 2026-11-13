import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mort/core/utils/leaked_password_check.dart';

void main() {
  group('LeakedPasswordCheck', () {
    test('builds the HIBP SHA-1 range prefix locally', () {
      // SHA-1("password") =
      // 5baa61e4c9b93f3f0682250b6cf8331b7ee68fd8
      expect(LeakedPasswordCheck.sha1PrefixForPassword('password'), '5BAA6');
    });

    test('detects a matching breach suffix from the backend response', () {
      expect(
        LeakedPasswordCheck.responseContainsPassword('password', {
          'ok': true,
          'degraded': false,
          'suffixes': ['1E4C9B93F3F0682250B6CF8331B7EE68FD8'],
        }),
        isTrue,
      );
    });

    test('compares suffixes case-insensitively', () {
      expect(
        LeakedPasswordCheck.responseContainsPassword('password', {
          'ok': true,
          'degraded': false,
          'suffixes': ['1e4c9b93f3f0682250b6cf8331b7ee68fd8'],
        }),
        isTrue,
      );
    });

    test('does not flag a password when its suffix is absent', () {
      expect(
        LeakedPasswordCheck.responseContainsPassword('password', {
          'ok': true,
          'degraded': false,
          'suffixes': ['00000000000000000000000000000000000'],
        }),
        isFalse,
      );
    });

    test('fails open when the backend reports a degraded lookup', () {
      expect(
        LeakedPasswordCheck.responseContainsPassword('password', {
          'ok': true,
          'degraded': true,
          'suffixes': ['1E4C9B93F3F0682250B6CF8331B7EE68FD8'],
        }),
        isFalse,
      );
    });

    test('fails open for a malformed backend response', () {
      expect(
        LeakedPasswordCheck.responseContainsPassword('password', {
          'ok': false,
          'suffixes': ['1E4C9B93F3F0682250B6CF8331B7EE68FD8'],
        }),
        isFalse,
      );
    });
  });
}
