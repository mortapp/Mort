import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_mort/core/errors/mort_error.dart';
import 'package:flutter_mort/core/errors/user_facing_error.dart';
import 'package:flutter_mort/core/widgets/mort_widgets.dart';
import 'package:flutter_mort/data/models/job.dart';
import 'package:flutter_mort/data/models/profile.dart';
import 'package:flutter_mort/data/repositories/avatar_repository.dart';
import 'package:flutter_mort/data/repositories/uploads_repository.dart';
import 'package:flutter_mort/features/guardian/guardian_mode_screens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  group('guardian optional product behavior', () {
    testWidgets('onboarding clearly permits skipping Guardian Mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: GuardianOptionalOnboardingScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add a guardian? Optional.'), findsOneWidget);
      expect(
        find.textContaining('Skipping this will not prevent'),
        findsOneWidget,
      );
      expect(find.text('Skip for now'), findsOneWidget);
    });

    test('profile completion does not include guardian linking', () {
      final complete = Profile(
        id: 'teen-id',
        role: UserRole.teen,
        displayName: 'Teen Tester',
        username: 'teen_tester',
        dob: DateTime(2011, 1, 1),
        city: 'Indianapolis',
        state: 'IN',
        onboardingCompleted: true,
        accountStatus: 'active',
        verificationStatus: 'not_started',
        paymentPreference: 'cash',
        guardianSetupStatus: 'skipped',
        avatarPath: 'teen-id/avatar.jpg',
        bio: 'Reliable local helper.',
        availability: 'Weekends',
        preferredJobCategories: const ['tutoring'],
      );

      expect(complete.completionRatio, 1);
    });
  });

  group('job presentation and eligibility errors', () {
    test('missing guardian flag defaults to false', () {
      final job = Job.fromMap({
        'id': 'job-id',
        'poster_id': 'poster-id',
        'title': 'Walk a dog',
        'description': 'Walk one friendly dog around a public neighborhood.',
        'category': 'dog walking',
        'location_text': 'North side',
        'city': 'Indianapolis',
        'state': 'IN',
        'status': 'open',
      });

      expect(job.requiresGuardianApproval, isFalse);
    });

    test('flexible and exact schedules never render Not set', () {
      final flexible = _job(scheduleType: 'flexible');
      final exact = _job(
        scheduleType: 'exact',
        startsAt: DateTime(2030, 1, 2, 15),
      );

      expect(flexible.scheduleDisplay, 'Flexible schedule');
      expect(flexible.scheduleDisplay, isNot(contains('Not set')));
      expect(exact.scheduleDisplay, isNot('Flexible schedule'));
      expect(exact.scheduleDisplay, isNot(contains('Not set')));
    });

    test('structured application errors replace generic permission copy', () {
      expect(
        userFacingError(
          const MortCodedError(
            'application_already_exists',
            'backend fallback',
          ),
        ),
        'You already applied to this job.',
      );
      expect(
        userFacingError(
          const MortCodedError('guardian_link_required', 'backend fallback'),
        ),
        contains('This job requires guardian approval'),
      );
    });
  });

  group('avatar processing', () {
    test('re-encodes, center-crops, and resizes an image', () {
      final source = img.Image(width: 900, height: 600)
        ..clear(img.ColorRgb8(40, 180, 120));
      final output = AvatarRepository.processAvatarBytes(
        Uint8List.fromList(img.encodePng(source)),
      );
      final decoded = img.decodeJpg(output);

      expect(output.take(2), [0xff, 0xd8]);
      expect(decoded, isNotNull);
      expect(decoded!.width, 512);
      expect(decoded.height, 512);
    });

    test('rejects unsupported and oversized files', () {
      expect(
        () => AvatarRepository.processAvatarBytes(
          Uint8List.fromList([1, 2, 3, 4]),
        ),
        throwsA(isA<MortCodedError>()),
      );
      expect(
        () => AvatarRepository.processAvatarBytes(
          Uint8List(AvatarRepository.maximumSourceBytes + 1),
        ),
        throwsA(isA<MortCodedError>()),
      );
    });
  });

  group('proof processing', () {
    test('preserves aspect ratio and caps the longest side', () {
      final source = img.Image(width: 2400, height: 1200)
        ..clear(img.ColorRgb8(30, 90, 210));
      final proof = UploadsRepository.prepareProof(
        Uint8List.fromList(img.encodePng(source)),
      );
      final decoded = img.decodeJpg(proof.bytes);

      expect(proof.bytes.take(2), [0xff, 0xd8]);
      expect(decoded, isNotNull);
      expect(decoded!.width, 1600);
      expect(decoded.height, 800);
    });

    test('rejects malformed proof bytes before private upload', () {
      expect(
        () => UploadsRepository.prepareProof(
          Uint8List.fromList([0xff, 0xd8, 0xff, 0x00]),
        ),
        throwsA(isA<MortCodedError>()),
      );
    });
  });

  test('verification images are re-encoded without changing orientation', () {
    final source = img.Image(width: 700, height: 1100)
      ..clear(img.ColorRgb8(80, 80, 80));
    final document = UploadsRepository.prepareVerification(
      Uint8List.fromList(img.encodePng(source)),
    );
    final decoded = img.decodeJpg(document.bytes);

    expect(document.bytes.take(2), [0xff, 0xd8]);
    expect(decoded, isNotNull);
    expect(decoded!.width, 700);
    expect(decoded.height, 1100);
  });

  testWidgets('sticky action area remains in a mobile safe area', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: MortScreen(
          children: [Text('Scrollable job details')],
          bottom: SafeArea(child: MortButton(label: 'Apply now')),
        ),
      ),
    );

    expect(find.text('Apply now'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Job _job({required String scheduleType, DateTime? startsAt}) {
  return Job(
    id: 'job-id',
    posterId: 'poster-id',
    title: 'Technology help',
    description: 'Help organize files on a laptop in a public library.',
    category: 'technology help',
    locationText: 'Downtown',
    city: 'Indianapolis',
    state: 'IN',
    status: 'open',
    requiresGuardianApproval: false,
    scheduleType: scheduleType,
    startsAt: startsAt,
  );
}
