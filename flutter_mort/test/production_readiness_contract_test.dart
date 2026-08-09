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

  test('release configuration is fail-closed and bound to MORT Supabase', () {
    final config = _read('lib/core/config/app_config.dart');
    final main = _read('lib/main.dart');

    expect(AppConfig.expectedSupabaseProjectRef, 'rakjydmgwwgtdislanbt');
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
      expect(applications, contains("'update_application_status_v3'"));
      expect(applications, isNot(contains("'update_application_status_v2'")));
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
      expect(pubspec, isNot(contains('flutter_stripe')));
      expect(AppConfig.nativeStripePaymentSheetCompiledIn, isFalse);
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
    final gradle = _read('android/app/build.gradle.kts');
    final proguard = File('android/app/proguard-rules.pro');

    expect(buildScript, contains('upload certificate'));
    expect(buildScript, contains('MORT_SUPABASE_PROJECT_REF'));
    expect(buildScript, contains('--dart-define-from-file'));
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
