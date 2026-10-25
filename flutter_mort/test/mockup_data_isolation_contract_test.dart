import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The electric-blue visual mockups (onboarding, Discover, Jobs, Safety,
/// Messages, Profile, membership) used named people, jobs, and stats as
/// visual references only. This test is the durable guardrail proving
/// none of those placeholder identities, or a demo-data-fallback pattern,
/// ever made it into production `lib/` source.
void main() {
  final libDir = Directory('lib');

  List<File> dartFiles() => libDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  test(
    'mockup-only placeholder names never appear in production lib/ source',
    () {
      const forbiddenNames = <String>[
        'Jamie R.',
        'Taylor M.',
        'Alex R.',
        'Jordan M.',
        'Casey D.',
        'Riley K.',
        'Greenway Homeowners',
      ];

      final offenders = <String>[];
      for (final file in dartFiles()) {
        final content = file.readAsStringSync();
        for (final name in forbiddenNames) {
          if (content.contains(name)) {
            offenders.add('${file.path}: "$name"');
          }
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'Mockup-only placeholder identities must never be hardcoded into '
            'production source. Found: ${offenders.join(', ')}',
      );
    },
  );

  test(
    'no screen falls back to fabricated demo data when real data is empty',
    () {
      final forbiddenPatterns = <RegExp>[
        RegExp(r'\bdemoJobs\b'),
        RegExp(r'\bdemoUsers\b'),
        RegExp(r'\bdemoConversations\b'),
        RegExp(r'\bmockJobs\b'),
        RegExp(r'\bfakeJobs\b'),
        RegExp(r'\bsampleJobs\b'),
        RegExp(r'isEmpty\s*\?\s*demo'),
        RegExp(r'isEmpty\s*\?\s*mock'),
        RegExp(r'isEmpty\s*\?\s*fake'),
        RegExp(r'isEmpty\s*\?\s*sample'),
      ];

      final offenders = <String>[];
      for (final file in dartFiles()) {
        final content = file.readAsStringSync();
        for (final pattern in forbiddenPatterns) {
          if (pattern.hasMatch(content)) {
            offenders.add('${file.path}: ${pattern.pattern}');
          }
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'Empty states must be genuinely empty states, never a silent '
            'fallback to fabricated data. Found: ${offenders.join(', ')}',
      );
    },
  );

  test('membership/paywall copy makes no unconfigured benefit claims', () {
    final forbiddenClaims = <String>[
      r'$1M travel protection',
      '\$1,000,000 travel protection',
      'Priority Safety',
      'travel insurance',
    ];

    final monetizationFiles = dartFiles().where(
      (f) =>
          f.path.contains('monetization') ||
          f.path.toLowerCase().contains('paywall'),
    );

    final offenders = <String>[];
    for (final file in monetizationFiles) {
      final content = file.readAsStringSync();
      for (final claim in forbiddenClaims) {
        if (content.contains(claim)) {
          offenders.add('${file.path}: "$claim"');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Membership copy must only describe real, store-configured '
          'entitlements. Found: ${offenders.join(', ')}',
    );
  });
}
