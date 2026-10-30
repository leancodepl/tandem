import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'design_system_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of DesignSystemLocalizations
/// returned by `DesignSystemLocalizations.of(context)`.
///
/// Applications need to include `DesignSystemLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/design_system_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: DesignSystemLocalizations.localizationsDelegates,
///   supportedLocales: DesignSystemLocalizations.supportedLocales,
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
/// be consistent with the languages listed in the DesignSystemLocalizations.supportedLocales
/// property.
abstract class DesignSystemLocalizations {
  DesignSystemLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static DesignSystemLocalizations of(BuildContext context) {
    return Localizations.of<DesignSystemLocalizations>(
      context,
      DesignSystemLocalizations,
    )!;
  }

  static const LocalizationsDelegate<DesignSystemLocalizations> delegate =
      _DesignSystemLocalizationsDelegate();

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
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// Tooltip of the button that goes back to the page before.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// Tooltip of the button that closes a sheet.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// Tooltip of the composer's button that sends the message to the assistant.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// Tooltip of the composer's button that stops the assistant at work.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @reject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get reject;

  /// No description provided for @approve.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get approve;
}

class _DesignSystemLocalizationsDelegate
    extends LocalizationsDelegate<DesignSystemLocalizations> {
  const _DesignSystemLocalizationsDelegate();

  @override
  Future<DesignSystemLocalizations> load(Locale locale) {
    return SynchronousFuture<DesignSystemLocalizations>(
      lookupDesignSystemLocalizations(locale),
    );
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_DesignSystemLocalizationsDelegate old) => false;
}

DesignSystemLocalizations lookupDesignSystemLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return DesignSystemLocalizationsEn();
  }

  throw FlutterError(
    'DesignSystemLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
