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
    final providerInitialization = main.indexOf(
      'configureRemotePushBackgroundHandler',
      mainEntryPoint,
    );

    expect(mainEntryPoint, greaterThanOrEqualTo(0));
    expect(qaBranch, greaterThanOrEqualTo(0));
    expect(providerInitialization, greaterThanOrEqualTo(0));
    expect(qaBranch, lessThan(providerInitialization));
    expect(
      main.indexOf('runApp(const BrowserStackQaApp())', qaBranch),
      lessThan(providerInitialization),
    );
    expect(main.indexOf('return;', qaBranch), lessThan(providerInitialization));
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
