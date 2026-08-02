import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of MortLocalizations
/// returned by `MortLocalizations.of(context)`.
///
/// Applications need to include `MortLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: MortLocalizations.localizationsDelegates,
///   supportedLocales: MortLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the MortLocalizations.supportedLocales
/// property.
abstract class MortLocalizations {
  MortLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static MortLocalizations of(BuildContext context) {
    return Localizations.of<MortLocalizations>(context, MortLocalizations)!;
  }

  static const LocalizationsDelegate<MortLocalizations> delegate =
      _MortLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'MORT'**
  String get appTitle;

  /// No description provided for @sessionProtected.
  ///
  /// In en, this message translates to:
  /// **'Session protected'**
  String get sessionProtected;

  /// No description provided for @offlineTitle.
  ///
  /// In en, this message translates to:
  /// **'MORT is offline'**
  String get offlineTitle;

  /// No description provided for @offlineSessionPreserved.
  ///
  /// In en, this message translates to:
  /// **'MORT will not delete your saved session because the network is unavailable.'**
  String get offlineSessionPreserved;

  /// No description provided for @reconnectAndRetry.
  ///
  /// In en, this message translates to:
  /// **'Reconnect, then retry the secure account check.'**
  String get reconnectAndRetry;

  /// No description provided for @retryAccountCheck.
  ///
  /// In en, this message translates to:
  /// **'Retry account check'**
  String get retryAccountCheck;

  /// No description provided for @configurationRequired.
  ///
  /// In en, this message translates to:
  /// **'Configuration required'**
  String get configurationRequired;

  /// No description provided for @secureStartupFailed.
  ///
  /// In en, this message translates to:
  /// **'MORT cannot start securely'**
  String get secureStartupFailed;

  /// No description provided for @publicBackendConfigurationInvalid.
  ///
  /// In en, this message translates to:
  /// **'The public backend configuration is missing or invalid.'**
  String get publicBackendConfigurationInvalid;

  /// No description provided for @installConfiguredBuild.
  ///
  /// In en, this message translates to:
  /// **'Install a correctly configured MORT build and try again.'**
  String get installConfiguredBuild;

  /// No description provided for @refreshingSession.
  ///
  /// In en, this message translates to:
  /// **'Refreshing your session...'**
  String get refreshingSession;

  /// No description provided for @restoringSession.
  ///
  /// In en, this message translates to:
  /// **'Restoring your session...'**
  String get restoringSession;

  /// No description provided for @startingSecurely.
  ///
  /// In en, this message translates to:
  /// **'Starting MORT securely...'**
  String get startingSecurely;

  /// No description provided for @secureStartup.
  ///
  /// In en, this message translates to:
  /// **'Secure startup'**
  String get secureStartup;

  /// No description provided for @checkingDevice.
  ///
  /// In en, this message translates to:
  /// **'Checking this device before opening your account.'**
  String get checkingDevice;

  /// No description provided for @secureJobPinEntry.
  ///
  /// In en, this message translates to:
  /// **'Secure {digits}-digit job PIN entry'**
  String secureJobPinEntry(int digits);

  /// No description provided for @pinDigitsEntered.
  ///
  /// In en, this message translates to:
  /// **'{entered} of {total} digits entered'**
  String pinDigitsEntered(int entered, int total);

  /// No description provided for @deleteLastPinDigit.
  ///
  /// In en, this message translates to:
  /// **'Delete last PIN digit'**
  String get deleteLastPinDigit;

  /// No description provided for @pinDigit.
  ///
  /// In en, this message translates to:
  /// **'PIN digit {digit}'**
  String pinDigit(String digit);
}

class _MortLocalizationsDelegate
    extends LocalizationsDelegate<MortLocalizations> {
  const _MortLocalizationsDelegate();

  @override
  Future<MortLocalizations> load(Locale locale) {
    return SynchronousFuture<MortLocalizations>(
      lookupMortLocalizations(locale),
    );
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_MortLocalizationsDelegate old) => false;
}

MortLocalizations lookupMortLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return MortLocalizationsEn();
    case 'es':
      return MortLocalizationsEs();
  }

  throw FlutterError(
    'MortLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
