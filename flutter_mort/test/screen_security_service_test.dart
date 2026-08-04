import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mort/services/screen_security_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    ScreenSecurityService.setPlatformSetter(null);
    await ScreenSecurityService.debugReset();
  });

  tearDown(() async {
    ScreenSecurityService.setPlatformSetter(null);
    await ScreenSecurityService.debugReset();
  });

  test('acquire calls native setSecure(true) once', () async {
    final calls = <bool>[];
    ScreenSecurityService.setPlatformSetter((enabled) async {
      calls.add(enabled);
    });

    await ScreenSecurityService.acquire();
    expect(calls, [true]);
  });

  test('injectable platform setter is used when provided', () async {
    final calls = <bool>[];
    ScreenSecurityService.setPlatformSetter((enabled) async {
      calls.add(enabled);
    });

    await ScreenSecurityService.acquire();
    expect(calls, [true]);
    await ScreenSecurityService.release();
    expect(calls, [true, false]);

    ScreenSecurityService.setPlatformSetter(null);
  });

  test(
    'release calls native setSecure(false) when counter reaches zero',
    () async {
      final calls = <bool>[];
      ScreenSecurityService.setPlatformSetter((enabled) async {
        calls.add(enabled);
      });

      await ScreenSecurityService.acquire();
      await ScreenSecurityService.release();

      expect(calls, [true, false]);
    },
  );

  test(
    'nested acquires increment counter and single setSecure(true)',
    () async {
      final calls = <bool>[];
      ScreenSecurityService.setPlatformSetter((enabled) async {
        calls.add(enabled);
      });

      await ScreenSecurityService.acquire();
      await ScreenSecurityService.acquire();
      expect(calls, [true]);

      await ScreenSecurityService.release();
      expect(calls, [true]);

      await ScreenSecurityService.release();
      expect(calls, [true, false]);
    },
  );

  test(
    'release clamps at zero and still calls setSecure(false) once',
    () async {
      final calls = <bool>[];
      ScreenSecurityService.setPlatformSetter((enabled) async {
        calls.add(enabled);
      });

      await ScreenSecurityService.release();
      expect(calls, isEmpty);

      await ScreenSecurityService.acquire();
      await ScreenSecurityService.release();
      await ScreenSecurityService.release();

      expect(calls, [true, false]);
    },
  );
}
