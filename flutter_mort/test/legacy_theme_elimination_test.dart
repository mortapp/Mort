import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'production feature surfaces contain no retired primary theme tokens',
    () {
      final featureRoot = Directory('${Directory.current.path}/lib/features');
      final sources = featureRoot
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .map((file) => file.readAsStringSync())
          .join('\n');

      for (final token in [
        'MortColors.roseGold',
        'MortColors.neon',
        'MortColors.godPink',
      ]) {
        expect(sources, isNot(contains(token)), reason: token);
      }
    },
  );
}
