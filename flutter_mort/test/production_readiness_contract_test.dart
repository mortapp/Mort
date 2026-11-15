import 'dart:io';

import 'package:flutter_mort/core/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

String _read(String path) => File(path).readAsStringSync();

void main() {
  test('shared Safety route is guarded and obsolete jobs alias is absent', () {
    final router = _read('lib/core/routing/app_router.dart');
    final support = _read('lib/features/support/support_screens.dart');

    expect(router, contains("_guarded(\n        '/safety'"));
    expect(support, isNot(contains("context.go('/jobs')")));
    expect(support, contains("UserRole.teen => '/teen/applications'"));
    expect(support, contains("UserRole.adult => '/adult/jobs'"));
    expect(support, contains("UserRole.guardian => '/guardian/activity'"));
    expect(support, contains("UserRole.admin => '/admin/jobs'"));
  });

  test(
    'age evidence flows through private upload, staff provider, and review',
    () {
      final uploads = _read('lib/data/repositories/uploads_repository.dart');
      final teenScreen = _read(
        'lib/features/trust/teen_verification_screens.dart',
      );
      final admin = _read('lib/data/repositories/admin_repository.dart');
      final adminScreen = _read(
        'lib/features/admin/admin_moderation_detail_screen.dart',
      );
      final migration = _read(
        '../supabase/production-baseline-migrations/20261114223346_mort_complete_repair_bundle.sql',
      );

      expect(uploads, contains("from('verification-evidence')"));
      expect(uploads, contains("'submit_my_verification_evidence_v1'"));
      expect(uploads, contains("'p_verification_type': verificationType"));
      expect(uploads, contains("verificationType != 'school_id'"));
      expect(teenScreen, contains('submitMyAgeEvidence'));
      expect(teenScreen, contains("_chooseAndSubmit('age')"));
      expect(teenScreen, contains("_chooseAndSubmit('school_id')"));
      expect(admin, contains("'mort_record_staff_document_review'"));
      expect(admin, contains("'mort_review_verification_case'"));
      expect(adminScreen, contains("decision: 'verified'"));
      expect(migration, contains("('mort_staff_review','age',true)"));
      expect(migration, contains("('mort_staff_review','school_id',true)"));
    },
  );

  test(
    'onboarding RPC failures are thrown and rendered instead of advanced',
    () {
      final profile = _read('lib/data/repositories/profile_repository.dart');
      final onboarding = _read(
        'lib/features/onboarding/compact_onboarding.dart',
      );

      expect(profile, contains("if (result['ok'] != true)"));
      expect(
        profile,
        contains('throw MortCodedError(code, _profileErrorMessage(code))'),
      );
      expect(onboarding, contains('catch (error)'));
      expect(
        onboarding,
        contains('_showStepError(_saveFailureMessage(error))'),
      );
      expect(onboarding, contains('if (!progress.completed)'));
    },
  );

  test('onboarding records current legal versions before completing setup', () {
    final onboarding = _read('lib/features/onboarding/compact_onboarding.dart');
    final auth = _read('lib/features/auth/unified_auth_screen.dart');
    final legal = _read('lib/data/repositories/legal_contract_repository.dart');

    expect(onboarding, contains('legalRepo.acceptLegalVersion('));
    expect(onboarding, contains("item['acceptance_id'] == null"));
    expect(onboarding, contains("item['version_id']"));
    expect(onboarding, contains('await legalRepo.acceptLegalVersion'));
    expect(legal, contains("'submit_legal_acceptance'"));
    expect(auth, isNot(contains('recordOnboardingAcknowledgement')));
  });

  test(
    'staff activation is tied to role-request approval and verification gates',
    () {
      final migration = _read(
        '../supabase/production-baseline-migrations/20261114223346_mort_complete_repair_bundle.sql',
      );
      final legacyCaseMigration = _read(
        '../supabase/production-baseline-migrations/20261114223714_ignore_legacy_self_reported_age_cases.sql',
      );
      final admin = _read('lib/data/repositories/admin_repository.dart');

      expect(migration, contains("p_status is null or p_status <> 'active'"));
      expect(migration, contains("status = 'pending'"));
      expect(migration, contains('public.mort_review_role_request'));
      expect(migration, contains('activation_request_required'));
      expect(migration, contains('private.is_approved_school_email(u.email)'));
      expect(migration, contains('mort_queue_role_activation'));
      expect(legacyCaseMigration, contains('verification_provider_allowlist'));
      expect(
        legacyCaseMigration,
        contains(
          "not (p_verification_type = 'age' and vc.provider = 'self_reported')",
        ),
      );
      expect(
        legacyCaseMigration,
        contains(
          "not (vc.verification_type = 'age' and vc.provider = 'self_reported')",
        ),
      );
      expect(admin, contains("'admin_set_account_status_v2'"));
    },
  );

  test('release configuration is fail-closed and bound to MORT Supabase', () {
    final config = _read('lib/core/config/app_config.dart');
    final main = _read('lib/main.dart');

    expect(AppConfig.expectedSupabaseProjectRef, 'jxbnrkasktbhtiujkhay');
    expect(config, contains('assertValidReleaseConfiguration'));
    expect(
      config,
      contains('production pilot requires a configured remote push provider'),
    );
    expect(
      config,
      contains('reviewer mode must be excluded from production builds'),
    );
    expect(main, contains('AppConfig.assertValidReleaseConfiguration()'));
    expect(main, contains('return reporter.providerConfigured'));
    expect(main, contains('FlutterError.presentError'));
  });

  test(
    'reviewer routes are compile-gated and production scripts exclude them',
    () {
      final router = _read('lib/core/routing/app_router.dart');
      final pilot = _read('../scripts/build-production-pilot-aab.ps1');

      expect(router, contains('if (AppConfig.playReviewModeEnabled)'));
      expect(pilot, contains(r'-PlayReviewModeEnabled $false'));
      expect(pilot, contains('BLOCKED-EXTERNAL'));
    },
  );

  test(
    'job feed uses an immutable Riverpod family without fake distance math',
    () {
      final repository = _read('lib/data/repositories/jobs_repository.dart');
      final applications = _read(
        'lib/data/repositories/applications_repository.dart',
      );
      final providers = _read('lib/data/repositories/providers.dart');
      final screen = _read('lib/features/jobs/teen_job_screens.dart');

      expect(providers, contains('openJobsProvider'));
      expect(providers, contains('AsyncNotifierProvider.autoDispose'));
      expect(
        providers,
        contains('.family<OpenJobsController, JobFeedState, JobSearchFilters>'),
      );
      expect(screen, contains('ref.watch(openJobsProvider(filters))'));
      expect(screen, isNot(contains('FutureBuilder<List<Job>>')));
      expect(
        screen,
        contains('MORT does not calculate your distance to a job'),
      );
      expect(repository, isNot(contains('travel_radius_miles.lte')));
      expect(repository, contains("'list_open_jobs_page'"));
      expect(repository, isNot(contains(".from('jobs').select(_jobSelect)")));
      expect(repository, contains("'manage_job_v2'"));
      expect(repository, isNot(contains("'manage_job',")));
      expect(applications, contains("'update_my_job_application_status_v3'"));
      expect(applications, isNot(contains("'update_application_status_v3'")));
      expect(applications, isNot(contains("'update_application_status_v2'")));
    },
  );

  test('job model maps production region and category values', () {
    final model = _read('lib/data/models/job.dart');
    final composer = _read('lib/features/jobs/job_screens.dart');

    expect(model, contains("json['region'] ?? json['state']"));
    expect(model, contains("_productionCategory(json['category'])"));
    for (final category in const [
      'pet_care',
      'yard_work',
      'tutoring',
      'household_help',
      'moving_help',
      'tech_help',
      'other',
    ]) {
      expect(composer, contains("'$category'"));
    }
  });

  test(
    'application transition replay rejects a reused key with a changed payload',
    () {
      final migration = _read(
        '../supabase/migrations/20261115000000_fix_application_transition_idempotency_replay.sql',
      );

      expect(migration, contains('v_existing_hash text;'));
      expect(migration, contains('p_action is null'));
      expect(
        migration,
        contains(
          'select response, request_hash into v_response, v_existing_hash',
        ),
      );
      expect(migration, contains("v_existing_hash is distinct from v_hash"));
      expect(migration, contains("'idempotency_key_reused'"));
    },
  );

  test('message RPC errors cannot become a sent message or empty inbox', () {
    final messaging = _read('lib/data/repositories/messaging_repository.dart');

    expect(messaging, contains("if (response['ok'] == false)"));
    expect(messaging, contains("if (response['id'] == null"));
    expect(messaging, contains("if (response['items'] is! List)"));
    expect(messaging, contains('The message was not sent.'));
  });

  test(
    'proof upload retries preserve objects that predate the current attempt',
    () {
      final uploads = _read('lib/data/repositories/uploads_repository.dart');

      expect(uploads, contains('var uploadedByThisAttempt = false;'));
      expect(uploads, contains('uploadedByThisAttempt = true;'));
      expect(uploads, contains("if (error.statusCode != '409') rethrow;"));
      expect(uploads, contains('if (uploadedByThisAttempt) {'));
    },
  );

  test(
    'free pilot collects no personal payment handles or Billing permission',
    () {
      final onboarding = _read('lib/features/mort_screens.dart');
      final profileRepository = _read(
        'lib/data/repositories/profile_repository.dart',
      );
      final manifest = _read('android/app/src/main/AndroidManifest.xml');
      final pubspec = _read('pubspec.yaml');

      expect(onboarding, isNot(contains('savePaymentPreference')));
      expect(onboarding, isNot(contains("'cash_app':")));
      expect(onboarding, isNot(contains("'square_link':")));
      expect(profileRepository, isNot(contains('savePaymentPreference')));
      expect(manifest, isNot(contains('com.android.vending.BILLING')));
      expect(pubspec, isNot(contains('in_app_purchase:')));
      expect(pubspec, contains('flutter_stripe'));
      expect(AppConfig.nativeStripePaymentSheetCompiledIn, isTrue);
    },
  );

  test('adaptive and monochrome launcher assets have transparent corners', () {
    final foreground = image.decodePng(
      File(
        'android/app/src/main/res/drawable-xxxhdpi/ic_launcher_foreground.png',
      ).readAsBytesSync(),
    );
    final monochrome = image.decodePng(
      File(
        'android/app/src/main/res/drawable-xxxhdpi/ic_launcher_monochrome.png',
      ).readAsBytesSync(),
    );
    final adaptiveXml = _read(
      'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml',
    );

    expect(foreground, isNotNull);
    expect(monochrome, isNotNull);
    expect(foreground!.getPixel(0, 0).a, 0);
    expect(monochrome!.getPixel(0, 0).a, 0);
    expect(adaptiveXml, contains('<monochrome>'));
  });

  test('release pipeline uses upload identity and a real R8 rules file', () {
    final buildScript = _read('../scripts/android-release-profile-common.ps1');
    final apkQa = _read('../scripts/qa-android-apk.ps1');
    final signing = _read('../scripts/android-signing-common.ps1');
    final gradle = _read('android/app/build.gradle.kts');
    final proguard = File('android/app/proguard-rules.pro');

    expect(buildScript, contains('upload certificate'));
    expect(buildScript, contains('Get-MortUploadCertificateSha256'));
    expect(apkQa, contains('--print-certs'));
    expect(apkQa, contains('APK signer does not match'));
    expect(signing, contains('ConvertTo-MortCertificateDigest'));
    expect(buildScript, contains('MORT_SUPABASE_PROJECT_REF'));
    expect(buildScript, contains('--dart-define-from-file'));
    expect(
      buildScript,
      contains(r'$($version.versionName)-$($version.versionCode)'),
    );
    expect(
      buildScript,
      contains(r'$artifactBaseName-$extension-build-manifest.json'),
    );
    expect(gradle, contains('MORT_UPLOAD_KEYSTORE_PATH'));
    expect(proguard.existsSync(), isTrue);
    expect(proguard.readAsStringSync(), isNot(contains('-keep class **')));

    final verifier = _read('../scripts/verify-play-aab.ps1');
    expect(verifier, contains('androidx\\.profileinstaller'));
    expect(verifier, contains('android\\.permission\\.DUMP'));
  });
}
