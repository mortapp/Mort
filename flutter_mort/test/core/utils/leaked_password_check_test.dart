import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mort/core/utils/leaked_password_check.dart';

void main() {
  group('LeakedPasswordCheck response policy', () {
    test('rejects a password the backend confirms is breached', () {
      final response = {'leaked': true};
      expect(LeakedPasswordCheck.responseIsLeaked(response), isTrue);
    });

    test('accepts a clean response', () {
      final response = {'leaked': false};
      expect(LeakedPasswordCheck.responseIsLeaked(response), isFalse);
    });

    test('fails open when the HIBP lookup is unavailable', () {
      final response = {'leaked': false, 'check_unavailable': true};
      expect(LeakedPasswordCheck.responseIsLeaked(response), isFalse);
    });

    test('fails open for malformed or unexpected responses', () {
      expect(LeakedPasswordCheck.responseIsLeaked({}), isFalse);
      final response = {'suffixes': <String>[]};
      expect(LeakedPasswordCheck.responseIsLeaked(response), isFalse);
    });
  });
}
