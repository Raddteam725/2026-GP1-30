import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
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
    Locale('ar'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Radd'**
  String get appTitle;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get loading;

  /// No description provided for @showPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// No description provided for @pageNotFound.
  ///
  /// In en, this message translates to:
  /// **'Page not found'**
  String get pageNotFound;

  /// No description provided for @chooseLanguage.
  ///
  /// In en, this message translates to:
  /// **'Choose Your Language'**
  String get chooseLanguage;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @chooseRole.
  ///
  /// In en, this message translates to:
  /// **'Choose Your Role'**
  String get chooseRole;

  /// No description provided for @guardianRole.
  ///
  /// In en, this message translates to:
  /// **'Guardian'**
  String get guardianRole;

  /// No description provided for @volunteerRole.
  ///
  /// In en, this message translates to:
  /// **'Volunteer'**
  String get volunteerRole;

  /// No description provided for @selectedRole.
  ///
  /// In en, this message translates to:
  /// **'Selected role: {role}'**
  String selectedRole(String role);

  /// No description provided for @languageHint.
  ///
  /// In en, this message translates to:
  /// **'Choose the language you prefer.'**
  String get languageHint;

  /// No description provided for @currentSelection.
  ///
  /// In en, this message translates to:
  /// **'Current selection'**
  String get currentSelection;

  /// No description provided for @englishLanguage.
  ///
  /// In en, this message translates to:
  /// **'English language'**
  String get englishLanguage;

  /// No description provided for @arabicLanguage.
  ///
  /// In en, this message translates to:
  /// **'Arabic language'**
  String get arabicLanguage;

  /// No description provided for @brandFooter.
  ///
  /// In en, this message translates to:
  /// **'Radd • Bringing People Back Together'**
  String get brandFooter;

  /// No description provided for @joinRadd.
  ///
  /// In en, this message translates to:
  /// **'Join Radd'**
  String get joinRadd;

  /// No description provided for @roleHint.
  ///
  /// In en, this message translates to:
  /// **'Choose how you would like to continue'**
  String get roleHint;

  /// No description provided for @guardianDescription.
  ///
  /// In en, this message translates to:
  /// **'Register individuals under your care and manage their safety during the event.'**
  String get guardianDescription;

  /// No description provided for @volunteerDescription.
  ///
  /// In en, this message translates to:
  /// **'Access your volunteer account and assist with active cases during the event.'**
  String get volunteerDescription;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome Back'**
  String get welcomeBack;

  /// No description provided for @loginHint.
  ///
  /// In en, this message translates to:
  /// **'Log in to continue'**
  String get loginHint;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email Address'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullName;

  /// No description provided for @phone.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phone;

  /// No description provided for @phoneHelp.
  ///
  /// In en, this message translates to:
  /// **'Include country code, e.g. +966501234567'**
  String get phoneHelp;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Log In'**
  String get login;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// No description provided for @createTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Your Account'**
  String get createTitle;

  /// No description provided for @createHint.
  ///
  /// In en, this message translates to:
  /// **'Create your Guardian account to continue'**
  String get createHint;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPassword;

  /// No description provided for @resetTitle.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get resetTitle;

  /// No description provided for @resetHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your email to request password reset instructions.'**
  String get resetHint;

  /// No description provided for @sendReset.
  ///
  /// In en, this message translates to:
  /// **'Send Reset Instructions'**
  String get sendReset;

  /// No description provided for @resetSent.
  ///
  /// In en, this message translates to:
  /// **'If an account exists for this email, password reset instructions will be sent.'**
  String get resetSent;

  /// No description provided for @noAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get noAccount;

  /// No description provided for @rememberPassword.
  ///
  /// In en, this message translates to:
  /// **'Remember your password?'**
  String get rememberPassword;

  /// No description provided for @ageConfirm.
  ///
  /// In en, this message translates to:
  /// **'I confirm that I am 18 years of age or older.'**
  String get ageConfirm;

  /// No description provided for @privacyConfirm.
  ///
  /// In en, this message translates to:
  /// **'I have read and agree to the Privacy Notice.'**
  String get privacyConfirm;

  /// No description provided for @privacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy Notice'**
  String get privacyTitle;

  /// No description provided for @privacyBody.
  ///
  /// In en, this message translates to:
  /// **'Project information — final notice pending approval.\n\nRadd processes information and photographs for event-specific reunification. Access is intended to follow system roles. Identifiable records and photographs are subject to the project\'s retention and deletion rules; anonymized aggregate information may be retained under the project design.\n\nThis interim notice will be replaced with the team\'s approved wording.'**
  String get privacyBody;

  /// No description provided for @requiredField.
  ///
  /// In en, this message translates to:
  /// **'This field is required.'**
  String get requiredField;

  /// No description provided for @invalidName.
  ///
  /// In en, this message translates to:
  /// **'Use a name of no more than 120 characters.'**
  String get invalidName;

  /// No description provided for @invalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get invalidEmail;

  /// No description provided for @invalidPhone.
  ///
  /// In en, this message translates to:
  /// **'Enter + followed by your country code and phone number (8–15 digits).'**
  String get invalidPhone;

  /// No description provided for @passwordHelp.
  ///
  /// In en, this message translates to:
  /// **'Use 8+ characters with uppercase, lowercase, a number and a special character.'**
  String get passwordHelp;

  /// No description provided for @confirmRequired.
  ///
  /// In en, this message translates to:
  /// **'Both confirmations are required.'**
  String get confirmRequired;

  /// No description provided for @invalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Invalid email or password.'**
  String get invalidCredentials;

  /// No description provided for @emailExists.
  ///
  /// In en, this message translates to:
  /// **'This email is already registered.'**
  String get emailExists;

  /// No description provided for @networkError.
  ///
  /// In en, this message translates to:
  /// **'Unable to connect. Check your connection and try again.'**
  String get networkError;

  /// No description provided for @serviceError.
  ///
  /// In en, this message translates to:
  /// **'The service is currently unavailable. Please try again.'**
  String get serviceError;

  /// No description provided for @rateLimit.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please try again later.'**
  String get rateLimit;

  /// No description provided for @roleError.
  ///
  /// In en, this message translates to:
  /// **'This account cannot access Guardian services.'**
  String get roleError;

  /// No description provided for @notFoundError.
  ///
  /// In en, this message translates to:
  /// **'This record is no longer available.'**
  String get notFoundError;

  /// No description provided for @activeCaseError.
  ///
  /// In en, this message translates to:
  /// **'This individual cannot be deleted while an active case exists. Resolve or cancel the case first.'**
  String get activeCaseError;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get retry;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @myIndividuals.
  ///
  /// In en, this message translates to:
  /// **'My Individuals'**
  String get myIndividuals;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @registerIndividual.
  ///
  /// In en, this message translates to:
  /// **'Register an Individual'**
  String get registerIndividual;

  /// No description provided for @registerHint.
  ///
  /// In en, this message translates to:
  /// **'Add a person under your care'**
  String get registerHint;

  /// No description provided for @individualsHint.
  ///
  /// In en, this message translates to:
  /// **'People registered under your care'**
  String get individualsHint;

  /// No description provided for @emptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No individuals registered yet'**
  String get emptyTitle;

  /// No description provided for @emptyHint.
  ///
  /// In en, this message translates to:
  /// **'Register someone under your care to get started.'**
  String get emptyHint;

  /// No description provided for @addIndividual.
  ///
  /// In en, this message translates to:
  /// **'Add Individual'**
  String get addIndividual;

  /// No description provided for @editIndividual.
  ///
  /// In en, this message translates to:
  /// **'Edit Individual'**
  String get editIndividual;

  /// No description provided for @individualProfile.
  ///
  /// In en, this message translates to:
  /// **'Individual Profile'**
  String get individualProfile;

  /// No description provided for @photoLabel.
  ///
  /// In en, this message translates to:
  /// **'Photograph'**
  String get photoLabel;

  /// No description provided for @takePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take Photo'**
  String get takePhoto;

  /// No description provided for @retakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Retake Photo'**
  String get retakePhoto;

  /// No description provided for @cameraOnly.
  ///
  /// In en, this message translates to:
  /// **'Live in-app camera capture only'**
  String get cameraOnly;

  /// No description provided for @cameraGuide.
  ///
  /// In en, this message translates to:
  /// **'Keep the face visible, use good lighting and avoid obstructions.'**
  String get cameraGuide;

  /// No description provided for @cameraDenied.
  ///
  /// In en, this message translates to:
  /// **'Camera access was denied. Allow camera permission to take a photo. If requests are blocked, enable it in Android app permissions.'**
  String get cameraDenied;

  /// No description provided for @cameraUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The camera is unavailable. Please try again.'**
  String get cameraUnavailable;

  /// No description provided for @capture.
  ///
  /// In en, this message translates to:
  /// **'Capture Photo'**
  String get capture;

  /// No description provided for @photoRequired.
  ///
  /// In en, this message translates to:
  /// **'Take a photo before saving.'**
  String get photoRequired;

  /// No description provided for @photoTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The photo is too large. Please retake it.'**
  String get photoTooLarge;

  /// No description provided for @age.
  ///
  /// In en, this message translates to:
  /// **'Age'**
  String get age;

  /// No description provided for @invalidAge.
  ///
  /// In en, this message translates to:
  /// **'Enter a whole-number age between 0 and 130.'**
  String get invalidAge;

  /// No description provided for @gender.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get gender;

  /// No description provided for @female.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get female;

  /// No description provided for @male.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get male;

  /// No description provided for @relationship.
  ///
  /// In en, this message translates to:
  /// **'Relationship to Guardian'**
  String get relationship;

  /// No description provided for @daughter.
  ///
  /// In en, this message translates to:
  /// **'Daughter'**
  String get daughter;

  /// No description provided for @son.
  ///
  /// In en, this message translates to:
  /// **'Son'**
  String get son;

  /// No description provided for @parent.
  ///
  /// In en, this message translates to:
  /// **'Parent'**
  String get parent;

  /// No description provided for @sibling.
  ///
  /// In en, this message translates to:
  /// **'Sibling'**
  String get sibling;

  /// No description provided for @other.
  ///
  /// In en, this message translates to:
  /// **'Other person under my care'**
  String get other;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @deleteIndividual.
  ///
  /// In en, this message translates to:
  /// **'Delete Individual'**
  String get deleteIndividual;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get logout;

  /// No description provided for @logoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Log Out?'**
  String get logoutTitle;

  /// No description provided for @logoutMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to log out of your account?'**
  String get logoutMessage;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfile;

  /// No description provided for @emailReadOnly.
  ///
  /// In en, this message translates to:
  /// **'Email is managed by Firebase Authentication and cannot be edited here.'**
  String get emailReadOnly;

  /// No description provided for @volunteerUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Volunteer access is not available in this build yet.'**
  String get volunteerUnavailable;

  /// No description provided for @sessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Please log in to continue.'**
  String get sessionExpired;

  /// No description provided for @completeProfile.
  ///
  /// In en, this message translates to:
  /// **'Complete your Guardian profile'**
  String get completeProfile;

  /// No description provided for @completeProfileHint.
  ///
  /// In en, this message translates to:
  /// **'Your account is signed in. Complete or retry saving your profile to continue.'**
  String get completeProfileHint;

  /// No description provided for @brandTagline.
  ///
  /// In en, this message translates to:
  /// **'Bringing People Back Together'**
  String get brandTagline;

  /// No description provided for @splashSupport.
  ///
  /// In en, this message translates to:
  /// **'A safer tomorrow for every journey'**
  String get splashSupport;

  /// No description provided for @validationError.
  ///
  /// In en, this message translates to:
  /// **'Please review the information and try again.'**
  String get validationError;

  /// No description provided for @greeting.
  ///
  /// In en, this message translates to:
  /// **'Hello, {name}'**
  String greeting(String name);

  /// No description provided for @deleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Delete {name} and their photograph? This cannot be undone.'**
  String deleteMessage(String name);

  /// No description provided for @emailPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'name@example.com'**
  String get emailPlaceholder;

  /// No description provided for @alreadyAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get alreadyAccount;

  /// No description provided for @qrCode.
  ///
  /// In en, this message translates to:
  /// **'QR Code'**
  String get qrCode;

  /// No description provided for @cases.
  ///
  /// In en, this message translates to:
  /// **'Cases'**
  String get cases;

  /// No description provided for @comingLater.
  ///
  /// In en, this message translates to:
  /// **'This feature will be available in a later sprint.'**
  String get comingLater;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @greetingIntro.
  ///
  /// In en, this message translates to:
  /// **'Welcome,'**
  String get greetingIntro;

  /// No description provided for @individualsTitle.
  ///
  /// In en, this message translates to:
  /// **'Individuals'**
  String get individualsTitle;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get viewAll;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @addIndividualHint.
  ///
  /// In en, this message translates to:
  /// **'Add the individual’s information for this event.'**
  String get addIndividualHint;

  /// No description provided for @photoHeading.
  ///
  /// In en, this message translates to:
  /// **'PHOTO'**
  String get photoHeading;

  /// No description provided for @cameraRequired.
  ///
  /// In en, this message translates to:
  /// **'Camera required'**
  String get cameraRequired;

  /// No description provided for @enterFullName.
  ///
  /// In en, this message translates to:
  /// **'Enter full name'**
  String get enterFullName;

  /// No description provided for @enterAge.
  ///
  /// In en, this message translates to:
  /// **'Enter age'**
  String get enterAge;

  /// No description provided for @selectRelationship.
  ///
  /// In en, this message translates to:
  /// **'Select relationship'**
  String get selectRelationship;

  /// No description provided for @personalInformation.
  ///
  /// In en, this message translates to:
  /// **'Personal Information'**
  String get personalInformation;

  /// No description provided for @accountInformation.
  ///
  /// In en, this message translates to:
  /// **'Account Information'**
  String get accountInformation;

  /// No description provided for @changePhotoCamera.
  ///
  /// In en, this message translates to:
  /// **'Change Photo (Camera)'**
  String get changePhotoCamera;

  /// No description provided for @usePhoto.
  ///
  /// In en, this message translates to:
  /// **'Use Photo'**
  String get usePhoto;

  /// No description provided for @deleteIndividualTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Individual?'**
  String get deleteIndividualTitle;

  /// No description provided for @volunteerLogin.
  ///
  /// In en, this message translates to:
  /// **'Volunteer Login'**
  String get volunteerLogin;

  /// No description provided for @restoringSession.
  ///
  /// In en, this message translates to:
  /// **'Restoring your session'**
  String get restoringSession;

  /// No description provided for @restoringSessionHint.
  ///
  /// In en, this message translates to:
  /// **'Checking your account and role securely.'**
  String get restoringSessionHint;

  /// No description provided for @sessionRecovery.
  ///
  /// In en, this message translates to:
  /// **'Account recovery'**
  String get sessionRecovery;

  /// No description provided for @missingProfileRecovery.
  ///
  /// In en, this message translates to:
  /// **'Your account is signed in, but its profile is incomplete. Complete your Guardian profile or choose your role to continue.'**
  String get missingProfileRecovery;

  /// No description provided for @expiredSessionRecovery.
  ///
  /// In en, this message translates to:
  /// **'Your session could not be verified. Choose your role to sign in again.'**
  String get expiredSessionRecovery;

  /// No description provided for @roleRecovery.
  ///
  /// In en, this message translates to:
  /// **'This account could not be verified for the selected role. Return to role selection or sign in with the correct account.'**
  String get roleRecovery;

  /// No description provided for @sessionUnavailable.
  ///
  /// In en, this message translates to:
  /// **'We could not verify your account profile because the account service is unavailable. Retry, or return to role selection to access sign-in. Your account has not been deleted.'**
  String get sessionUnavailable;

  /// No description provided for @completeGuardianProfile.
  ///
  /// In en, this message translates to:
  /// **'Complete Guardian profile'**
  String get completeGuardianProfile;

  /// No description provided for @returnToRoles.
  ///
  /// In en, this message translates to:
  /// **'Return to Role Selection'**
  String get returnToRoles;

  /// No description provided for @startupFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to start Radd'**
  String get startupFailed;

  /// No description provided for @startupFailedHint.
  ///
  /// In en, this message translates to:
  /// **'Initialization did not finish. Please try again.'**
  String get startupFailedHint;
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
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
