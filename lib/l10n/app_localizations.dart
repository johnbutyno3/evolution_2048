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
