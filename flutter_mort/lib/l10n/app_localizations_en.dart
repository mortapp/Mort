// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class MortLocalizationsEn extends MortLocalizations {
  MortLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'MORT';

  @override
  String get sessionProtected => 'Session protected';

  @override
  String get offlineTitle => 'MORT is offline';

  @override
  String get offlineSessionPreserved =>
      'MORT will not delete your saved session because the network is unavailable.';

  @override
  String get reconnectAndRetry =>
      'Reconnect, then retry the secure account check.';

  @override
  String get retryAccountCheck => 'Retry account check';

  @override
  String get configurationRequired => 'Configuration required';

  @override
  String get secureStartupFailed => 'MORT cannot start securely';

  @override
  String get publicBackendConfigurationInvalid =>
      'The public backend configuration is missing or invalid.';

  @override
  String get installConfiguredBuild =>
      'Install a correctly configured MORT build and try again.';

  @override
  String get refreshingSession => 'Refreshing your session...';

  @override
  String get restoringSession => 'Restoring your session...';

  @override
  String get startingSecurely => 'Starting MORT securely...';

  @override
  String get secureStartup => 'Secure startup';

  @override
  String get checkingDevice =>
      'Checking this device before opening your account.';

  @override
  String secureJobPinEntry(int digits) {
    return 'Secure $digits-digit job PIN entry';
  }

  @override
  String pinDigitsEntered(int entered, int total) {
    return '$entered of $total digits entered';
  }

  @override
  String get deleteLastPinDigit => 'Delete last PIN digit';

  @override
  String pinDigit(String digit) {
    return 'PIN digit $digit';
  }
}
