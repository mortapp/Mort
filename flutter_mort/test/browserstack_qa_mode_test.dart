import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('QA bootstrap branch runs before Supabase initialization', () {
    final main = File('lib/main.dart').readAsStringSync();
    final qaBranch = main.indexOf('AppConfig.browserStackQaMode');
    final supabaseInitialization = main.indexOf(
      'SupabaseService.initializeIfConfigured',
    );

    expect(qaBranch, greaterThanOrEqualTo(0));
    expect(supabaseInitialization, greaterThanOrEqualTo(0));
    expect(qaBranch, lessThan(supabaseInitialization));
  });
}
