import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('QA startup gate precedes every external startup provider', () {
    final main = File('lib/main.dart').readAsStringSync();
    final mainEntryPoint = main.indexOf('Future<void> main() async');
    final qaBranch = main.indexOf(
      'if (AppConfig.browserStackQaMode)',
      mainEntryPoint,
    );
    final bootstrap = main.indexOf(
      'Future<Object?> _initializeSafely() async',
    );
    final bootstrapQaBranch = main.indexOf(
      'if (AppConfig.browserStackQaMode)',
      bootstrap,
    );
    final releaseConfigValidation = main.indexOf(
      'AppConfig.assertValidReleaseConfiguration();',
      bootstrap,
    );
    final supabaseInitialization = main.indexOf(
      'SupabaseService.initializeIfConfigured',
    );

    expect(mainEntryPoint, greaterThanOrEqualTo(0));
    expect(qaBranch, greaterThanOrEqualTo(0));
    expect(supabaseInitialization, greaterThanOrEqualTo(0));
    expect(qaBranch, lessThan(supabaseInitialization));
    expect(
      main.indexOf('_runApp();', qaBranch),
      lessThan(supabaseInitialization),
    );
    expect(main.indexOf('return;', qaBranch), lessThan(supabaseInitialization));
    expect(bootstrap, greaterThanOrEqualTo(0));
    expect(bootstrapQaBranch, greaterThanOrEqualTo(0));
    expect(releaseConfigValidation, greaterThanOrEqualTo(0));
    expect(
      bootstrapQaBranch,
      lessThan(releaseConfigValidation),
      reason:
          'BrowserStack QA must bypass release configuration validation before startup can fail closed on production-only gates.',
    );
    expect(
      main.substring(bootstrapQaBranch, releaseConfigValidation),
      contains('return null;'),
    );
    expect(
      main.substring(mainEntryPoint, qaBranch),
      isNot(contains('configureRemotePushBackgroundHandler')),
    );
    expect(
      main.substring(mainEntryPoint, qaBranch),
      isNot(contains('MortSentryCrashProvider')),
    );
  });
}
