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
