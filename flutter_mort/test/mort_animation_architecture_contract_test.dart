import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('continuous atmosphere and wordmark callbacks never call setState', () {
    final files = [
      File('lib/core/atmosphere/mort_atmospheric_background.dart'),
      File('lib/core/atmosphere/mort_wordmark_reveal.dart'),
    ];
    final offenders = <String>[];

    for (final file in files) {
      final source = file.readAsStringSync();
      final callbackPattern = RegExp(
        r'void\s+_(?:onTick|handleTick)\s*\([^)]*\)\s*\{([\s\S]*?)\n\s*\}',
      );
      for (final match in callbackPattern.allMatches(source)) {
        if ((match.group(1) ?? '').contains('setState(')) {
          offenders.add(file.path);
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Ticker/controller callbacks must notify painters directly; '
          'continuous setState rebuilds are forbidden: $offenders',
    );
  });
}
