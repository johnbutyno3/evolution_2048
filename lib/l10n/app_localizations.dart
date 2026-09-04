import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
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
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

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
    Locale('zh'),
  ];

  /// No description provided for @gameTitle.
  ///
  /// In en, this message translates to:
  /// **'Rebirth 2048'**
  String get gameTitle;

  /// No description provided for @chapterOcean.
  ///
  /// In en, this message translates to:
  /// **'Ocean'**
  String get chapterOcean;

  /// No description provided for @chapterLand.
  ///
  /// In en, this message translates to:
  /// **'Land'**
  String get chapterLand;

  /// No description provided for @chapterSky.
  ///
  /// In en, this message translates to:
  /// **'Sky'**
  String get chapterSky;

  /// No description provided for @chapterHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get chapterHistory;

  /// No description provided for @chapterTechnology.
  ///
  /// In en, this message translates to:
  /// **'Technology'**
  String get chapterTechnology;

  /// No description provided for @chapterSpace.
  ///
  /// In en, this message translates to:
  /// **'Space'**
  String get chapterSpace;

  /// No description provided for @creature01.
  ///
  /// In en, this message translates to:
  /// **'Diatom'**
  String get creature01;

  /// No description provided for @creature02.
  ///
  /// In en, this message translates to:
  /// **'Flagellate'**
  String get creature02;

  /// No description provided for @creature03.
  ///
  /// In en, this message translates to:
  /// **'Krill'**
  String get creature03;

  /// No description provided for @creature04.
  ///
  /// In en, this message translates to:
  /// **'Clownfish'**
  String get creature04;

  /// No description provided for @creature05.
  ///
  /// In en, this message translates to:
  /// **'Jellyfish'**
  String get creature05;

  /// No description provided for @creature06.
  ///
  /// In en, this message translates to:
  /// **'Squid'**
  String get creature06;

  /// No description provided for @creature07.
  ///
  /// In en, this message translates to:
  /// **'Ancient Deep-Sea Fish'**
  String get creature07;

  /// No description provided for @creature08.
  ///
  /// In en, this message translates to:
  /// **'Deep-Sea Predator'**
  String get creature08;

  /// No description provided for @creature09.
  ///
  /// In en, this message translates to:
  /// **'Large Marine Animal'**
  String get creature09;

  /// No description provided for @creature10.
  ///
  /// In en, this message translates to:
  /// **'Ocean Apex Predator'**
  String get creature10;

  /// No description provided for @creature11.
  ///
  /// In en, this message translates to:
  /// **'Yellowfin Tuna'**
  String get creature11;

  /// No description provided for @creature12.
  ///
  /// In en, this message translates to:
  /// **'Seabed Human'**
  String get creature12;

  /// No description provided for @chapterComplete.
  ///
  /// In en, this message translates to:
  /// **'Chapter Complete'**
  String get chapterComplete;

  /// No description provided for @nextChapterUnlocked.
  ///
  /// In en, this message translates to:
  /// **'Next Chapter Unlocked'**
  String get nextChapterUnlocked;

  /// No description provided for @finalChallenge.
  ///
  /// In en, this message translates to:
  /// **'Ultimate Challenge'**
  String get finalChallenge;

  /// No description provided for @tools.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get tools;

  /// No description provided for @toolsLocked.
  ///
  /// In en, this message translates to:
  /// **'Tools Locked'**
  String get toolsLocked;

  /// No description provided for @toolsDisabled.
  ///
  /// In en, this message translates to:
  /// **'Tools Disabled'**
  String get toolsDisabled;

  /// No description provided for @continueGame.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueGame;

  /// No description provided for @score.
  ///
  /// In en, this message translates to:
  /// **'Score'**
  String get score;

  /// No description provided for @best.
  ///
  /// In en, this message translates to:
  /// **'Best'**
  String get best;

  /// No description provided for @onboarding01Title.
  ///
  /// In en, this message translates to:
  /// **'A World Waiting to Live Again'**
  String get onboarding01Title;

  /// No description provided for @onboarding01Description.
  ///
  /// In en, this message translates to:
  /// **'A lifeless world is waiting for you. Restore its oceans, awaken life, and begin the journey of evolution.'**
  String get onboarding01Description;

  /// No description provided for @onboarding02Title.
  ///
  /// In en, this message translates to:
  /// **'Merge to Evolve'**
  String get onboarding02Title;

  /// No description provided for @onboarding02Description.
  ///
  /// In en, this message translates to:
  /// **'Merge identical life forms to create the next stage of evolution. Every move brings the ecosystem back to life.'**
  String get onboarding02Description;

  /// No description provided for @onboarding03Title.
  ///
  /// In en, this message translates to:
  /// **'From Life to the Universe'**
  String get onboarding03Title;

  /// No description provided for @onboarding03Description.
  ///
  /// In en, this message translates to:
  /// **'Journey through six chapters of evolution, from the first life in the ocean to civilizations, technology, and the universe.'**
  String get onboarding03Description;

  /// No description provided for @onboardingNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get onboardingNext;

  /// No description provided for @onboardingStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get onboardingStart;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Personal Profile'**
  String get profileTitle;

  /// No description provided for @profileWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Rebirth 2048'**
  String get profileWelcome;

  /// No description provided for @profileDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose a name for your player profile. You can change it later.'**
  String get profileDescription;

  /// No description provided for @profileNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Player Name'**
  String get profileNameLabel;

  /// No description provided for @profileNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your name'**
  String get profileNameHint;

  /// No description provided for @profileNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a player name.'**
  String get profileNameRequired;

  /// No description provided for @profileNameTooLong.
  ///
  /// In en, this message translates to:
  /// **'Player name must be 30 characters or fewer.'**
  String get profileNameTooLong;

  /// No description provided for @profileContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get profileContinue;

  /// No description provided for @authTitle.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get authTitle;

  /// No description provided for @authLoginTitle.
  ///
  /// In en, this message translates to:
  /// **'Log In'**
  String get authLoginTitle;

  /// No description provided for @authRegisterTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get authRegisterTitle;

  /// No description provided for @authEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get authEmail;

  /// No description provided for @authPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPassword;

  /// No description provided for @authEmailRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email.'**
  String get authEmailRequired;

  /// No description provided for @authPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your password.'**
  String get authPasswordRequired;

  /// No description provided for @authPasswordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters.'**
  String get authPasswordTooShort;

  /// No description provided for @authInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address.'**
  String get authInvalidEmail;

  /// No description provided for @authInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Email or password is incorrect.'**
  String get authInvalidCredentials;

  /// No description provided for @authEmailAlreadyInUse.
  ///
  /// In en, this message translates to:
  /// **'This email is already in use.'**
  String get authEmailAlreadyInUse;

  /// No description provided for @authWeakPassword.
  ///
  /// In en, this message translates to:
  /// **'Please choose a stronger password.'**
  String get authWeakPassword;

  /// No description provided for @authFailed.
  ///
  /// In en, this message translates to:
  /// **'Authentication failed. Please try again.'**
  String get authFailed;

  /// No description provided for @authLogin.
  ///
  /// In en, this message translates to:
  /// **'Log In'**
  String get authLogin;

  /// No description provided for @authRegister.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get authRegister;

  /// No description provided for @authSwitchToLogin.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Log in'**
  String get authSwitchToLogin;

  /// No description provided for @authSwitchToRegister.
  ///
  /// In en, this message translates to:
  /// **'New here? Create an account'**
  String get authSwitchToRegister;

  /// No description provided for @authChooseMethod.
  ///
  /// In en, this message translates to:
  /// **'Choose a sign-in method'**
  String get authChooseMethod;

  /// No description provided for @authGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get authGoogle;

  /// No description provided for @authApple.
  ///
  /// In en, this message translates to:
  /// **'Continue with Apple'**
  String get authApple;

  /// No description provided for @authPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone Number / SMS Code'**
  String get authPhone;

  /// No description provided for @authOr.
  ///
  /// In en, this message translates to:
  /// **'OR'**
  String get authOr;

  /// No description provided for @authSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip and enter the game'**
  String get authSkip;

  /// No description provided for @authPhoneRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your phone number.'**
  String get authPhoneRequired;

  /// No description provided for @authCodeSent.
  ///
  /// In en, this message translates to:
  /// **'Verification code sent.'**
  String get authCodeSent;

  /// No description provided for @authSendCodeFirst.
  ///
  /// In en, this message translates to:
  /// **'Please request an SMS verification code first.'**
  String get authSendCodeFirst;

  /// No description provided for @authPhoneMobileSetupRequired.
  ///
  /// In en, this message translates to:
  /// **'Phone verification is not fully configured for this platform yet.'**
  String get authPhoneMobileSetupRequired;

  /// No description provided for @authInvalidPhone.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid phone number.'**
  String get authInvalidPhone;

  /// No description provided for @authTooManyRequests.
  ///
  /// In en, this message translates to:
  /// **'Too many requests. Please try again later.'**
  String get authTooManyRequests;

  /// No description provided for @authPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get authPhoneNumber;

  /// No description provided for @authSmsCode.
  ///
  /// In en, this message translates to:
  /// **'SMS Verification Code'**
  String get authSmsCode;

  /// No description provided for @authCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get authCancel;

  /// No description provided for @authSendCode.
  ///
  /// In en, this message translates to:
  /// **'Send Code'**
  String get authSendCode;

  /// No description provided for @authVerify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get authVerify;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
