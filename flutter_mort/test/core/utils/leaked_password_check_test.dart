import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mort/core/utils/leaked_password_check.dart';

void main() {
  group('LeakedPasswordCheck response policy', () {
    test('rejects a password the backend confirms is breached', () {
      expect(
        LeakedPasswordCheck.responseIsLeaked({'leaked': true}),
        isTrue,
      );
    });

    test('accepts a clean response', () {
      expect(
        LeakedPasswordCheck.responseIsLeaked({'leaked': false}),
        isFalse,
      );
    });

    test('fails open when the HIBP lookup is unavailable', () {
      expect(
        LeakedPasswordCheck.responseIsLeaked({
          'leaked': false,
          'check_unavailable': true,
        }),
        isFalse,
      );
    });

    test('fails open for malformed or unexpected responses', () {
      expect(LeakedPasswordCheck.responseIsLeaked({}), isFalse);
      expect(
        LeakedPasswordCheck.responseIsLeaked({'suffixes': <String>[]}),
        isFalse,
      );
    });
  });
}
