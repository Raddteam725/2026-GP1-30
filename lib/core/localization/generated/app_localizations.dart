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
  /// **'Radd · Bringing People Back Together'**
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
  /// **'Use at least 8 characters, including an uppercase English letter, a lowercase English letter, a number, and a special character such as !, @, #, or \$.'**
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
  /// **'This individual cannot be edited or deleted while an active case exists. Resolve or cancel the case first.'**
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
  /// **'Other'**
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

  /// No description provided for @vApp.
  ///
  /// In en, this message translates to:
  /// **'Radd Volunteer'**
  String get vApp;

  /// No description provided for @vHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get vHome;

  /// No description provided for @vCases.
  ///
  /// In en, this message translates to:
  /// **'Cases'**
  String get vCases;

  /// No description provided for @vReport.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get vReport;

  /// No description provided for @vBadge.
  ///
  /// In en, this message translates to:
  /// **'Badge'**
  String get vBadge;

  /// No description provided for @vProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get vProfile;

  /// No description provided for @vAccount.
  ///
  /// In en, this message translates to:
  /// **'Volunteer Account'**
  String get vAccount;

  /// No description provided for @vActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get vActive;

  /// No description provided for @vInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get vInactive;

  /// No description provided for @vAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available Cases'**
  String get vAvailable;

  /// No description provided for @vMyCases.
  ///
  /// In en, this message translates to:
  /// **'My Cases'**
  String get vMyCases;

  /// No description provided for @vPriorityCases.
  ///
  /// In en, this message translates to:
  /// **'Priority Nearby Cases'**
  String get vPriorityCases;

  /// No description provided for @vNearby.
  ///
  /// In en, this message translates to:
  /// **'Within 500 m'**
  String get vNearby;

  /// No description provided for @vViewCase.
  ///
  /// In en, this message translates to:
  /// **'View Case'**
  String get vViewCase;

  /// No description provided for @vViewAll.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get vViewAll;

  /// No description provided for @vQuickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get vQuickActions;

  /// No description provided for @vReportFound.
  ///
  /// In en, this message translates to:
  /// **'Report Found Individual'**
  String get vReportFound;

  /// No description provided for @vDigitalId.
  ///
  /// In en, this message translates to:
  /// **'Digital Volunteer ID'**
  String get vDigitalId;

  /// No description provided for @vVolunteerId.
  ///
  /// In en, this message translates to:
  /// **'Volunteer ID'**
  String get vVolunteerId;

  /// No description provided for @vStartSearch.
  ///
  /// In en, this message translates to:
  /// **'Start Search'**
  String get vStartSearch;

  /// No description provided for @vReportReceived.
  ///
  /// In en, this message translates to:
  /// **'Report Received'**
  String get vReportReceived;

  /// No description provided for @vSearchProgress.
  ///
  /// In en, this message translates to:
  /// **'Search in Progress'**
  String get vSearchProgress;

  /// No description provided for @vMatchConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Match Confirmed'**
  String get vMatchConfirmed;

  /// No description provided for @vAwaitingGuardian.
  ///
  /// In en, this message translates to:
  /// **'Awaiting Guardian Verification'**
  String get vAwaitingGuardian;

  /// No description provided for @vReunited.
  ///
  /// In en, this message translates to:
  /// **'Reunited'**
  String get vReunited;

  /// No description provided for @vCaseDetails.
  ///
  /// In en, this message translates to:
  /// **'Case Details'**
  String get vCaseDetails;

  /// No description provided for @vMissingReport.
  ///
  /// In en, this message translates to:
  /// **'Missing-person Report'**
  String get vMissingReport;

  /// No description provided for @vAge.
  ///
  /// In en, this message translates to:
  /// **'Age'**
  String get vAge;

  /// No description provided for @vGender.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get vGender;

  /// No description provided for @vMale.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get vMale;

  /// No description provided for @vFemale.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get vFemale;

  /// No description provided for @vCaseId.
  ///
  /// In en, this message translates to:
  /// **'Case ID'**
  String get vCaseId;

  /// No description provided for @vStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get vStatus;

  /// No description provided for @vReported.
  ///
  /// In en, this message translates to:
  /// **'Reported'**
  String get vReported;

  /// No description provided for @vUpdated.
  ///
  /// In en, this message translates to:
  /// **'Updated'**
  String get vUpdated;

  /// No description provided for @vPendingDetails.
  ///
  /// In en, this message translates to:
  /// **'Additional details are being collected'**
  String get vPendingDetails;

  /// No description provided for @vPendingHint.
  ///
  /// In en, this message translates to:
  /// **'Additional information will appear when provided by the Guardian. You can start searching now.'**
  String get vPendingHint;

  /// No description provided for @vLastSeen.
  ///
  /// In en, this message translates to:
  /// **'Last Seen'**
  String get vLastSeen;

  /// No description provided for @vCaseInformation.
  ///
  /// In en, this message translates to:
  /// **'Case Information'**
  String get vCaseInformation;

  /// No description provided for @vClothing.
  ///
  /// In en, this message translates to:
  /// **'Clothing'**
  String get vClothing;

  /// No description provided for @vDistinctive.
  ///
  /// In en, this message translates to:
  /// **'Distinctive Items / Features'**
  String get vDistinctive;

  /// No description provided for @vAdditional.
  ///
  /// In en, this message translates to:
  /// **'Additional Information'**
  String get vAdditional;

  /// No description provided for @vJoined.
  ///
  /// In en, this message translates to:
  /// **'Added to My Cases'**
  String get vJoined;

  /// No description provided for @vNoCases.
  ///
  /// In en, this message translates to:
  /// **'No cases here yet'**
  String get vNoCases;

  /// No description provided for @vNoCasesHint.
  ///
  /// In en, this message translates to:
  /// **'Cases will appear here when they are available.'**
  String get vNoCasesHint;

  /// No description provided for @vNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get vNotifications;

  /// No description provided for @vAllAlerts.
  ///
  /// In en, this message translates to:
  /// **'All Alerts'**
  String get vAllAlerts;

  /// No description provided for @vPriorityOnly.
  ///
  /// In en, this message translates to:
  /// **'Priority Cases'**
  String get vPriorityOnly;

  /// No description provided for @vRecentAlerts.
  ///
  /// In en, this message translates to:
  /// **'Recent Alerts'**
  String get vRecentAlerts;

  /// No description provided for @vNewAlert.
  ///
  /// In en, this message translates to:
  /// **'New Case Alert'**
  String get vNewAlert;

  /// No description provided for @vPriorityAlert.
  ///
  /// In en, this message translates to:
  /// **'Priority Nearby Case'**
  String get vPriorityAlert;

  /// No description provided for @vStatusAlert.
  ///
  /// In en, this message translates to:
  /// **'Case Status Update'**
  String get vStatusAlert;

  /// No description provided for @vPriorityHint.
  ///
  /// In en, this message translates to:
  /// **'Priority alerts depend on being within 500 meters of a reported last-seen location with available coordinates.'**
  String get vPriorityHint;

  /// No description provided for @vNoAlerts.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet'**
  String get vNoAlerts;

  /// No description provided for @vClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get vClose;

  /// No description provided for @vCaptureNotice.
  ///
  /// In en, this message translates to:
  /// **'Only capture a photo when assisting a found or separated individual.'**
  String get vCaptureNotice;

  /// No description provided for @vPositionFace.
  ///
  /// In en, this message translates to:
  /// **'Position the face clearly'**
  String get vPositionFace;

  /// No description provided for @vPhotoHint.
  ///
  /// In en, this message translates to:
  /// **'Make sure the face is visible and well lit.'**
  String get vPhotoHint;

  /// No description provided for @vOpenCamera.
  ///
  /// In en, this message translates to:
  /// **'Open Camera'**
  String get vOpenCamera;

  /// No description provided for @vPhotoPurpose.
  ///
  /// In en, this message translates to:
  /// **'The captured photo is used only to find possible matches.'**
  String get vPhotoPurpose;

  /// No description provided for @vFinding.
  ///
  /// In en, this message translates to:
  /// **'Finding a Match'**
  String get vFinding;

  /// No description provided for @vSearchingProfiles.
  ///
  /// In en, this message translates to:
  /// **'Searching registered profiles…'**
  String get vSearchingProfiles;

  /// No description provided for @vMatchingHint.
  ///
  /// In en, this message translates to:
  /// **'Checking eligible registered profiles for possible matches.'**
  String get vMatchingHint;

  /// No description provided for @vCancelSearch.
  ///
  /// In en, this message translates to:
  /// **'Cancel Search'**
  String get vCancelSearch;

  /// No description provided for @vPotentialMatches.
  ///
  /// In en, this message translates to:
  /// **'Potential Matches'**
  String get vPotentialMatches;

  /// No description provided for @vPotentialMatch.
  ///
  /// In en, this message translates to:
  /// **'Potential Match'**
  String get vPotentialMatch;

  /// No description provided for @vCandidateHint.
  ///
  /// In en, this message translates to:
  /// **'These are possible matches, not confirmed identities. Review the individual’s information before selecting a match.'**
  String get vCandidateHint;

  /// No description provided for @vSimilarity.
  ///
  /// In en, this message translates to:
  /// **'Similarity'**
  String get vSimilarity;

  /// No description provided for @vViewDetails.
  ///
  /// In en, this message translates to:
  /// **'View Details'**
  String get vViewDetails;

  /// No description provided for @vManualFallback.
  ///
  /// In en, this message translates to:
  /// **'No useful match? Continue with manual review.'**
  String get vManualFallback;

  /// No description provided for @vManualReview.
  ///
  /// In en, this message translates to:
  /// **'Manual Review'**
  String get vManualReview;

  /// No description provided for @vSearchName.
  ///
  /// In en, this message translates to:
  /// **'Search by name'**
  String get vSearchName;

  /// No description provided for @vAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get vAll;

  /// No description provided for @vClearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear Filters'**
  String get vClearFilters;

  /// No description provided for @vRegisteredIndividuals.
  ///
  /// In en, this message translates to:
  /// **'Registered Individuals'**
  String get vRegisteredIndividuals;

  /// No description provided for @vNoResults.
  ///
  /// In en, this message translates to:
  /// **'No matching profiles'**
  String get vNoResults;

  /// No description provided for @vMatchDetails.
  ///
  /// In en, this message translates to:
  /// **'Match Details'**
  String get vMatchDetails;

  /// No description provided for @vFoundIndividual.
  ///
  /// In en, this message translates to:
  /// **'Found Individual'**
  String get vFoundIndividual;

  /// No description provided for @vRegisteredProfile.
  ///
  /// In en, this message translates to:
  /// **'Registered Profile'**
  String get vRegisteredProfile;

  /// No description provided for @vCompare.
  ///
  /// In en, this message translates to:
  /// **'Compare Photographs'**
  String get vCompare;

  /// No description provided for @vMatchNotice.
  ///
  /// In en, this message translates to:
  /// **'A potential match requires Volunteer review and Guardian verification. Identity is not confirmed automatically.'**
  String get vMatchNotice;

  /// No description provided for @vConfirmMatch.
  ///
  /// In en, this message translates to:
  /// **'Confirm Match'**
  String get vConfirmMatch;

  /// No description provided for @vConfirmMatchQuestion.
  ///
  /// In en, this message translates to:
  /// **'Confirm Match?'**
  String get vConfirmMatchQuestion;

  /// No description provided for @vConfirmMatchHint.
  ///
  /// In en, this message translates to:
  /// **'Select this individual as the match and proceed to Guardian Contact?'**
  String get vConfirmMatchHint;

  /// No description provided for @vCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get vCancel;

  /// No description provided for @vBackResults.
  ///
  /// In en, this message translates to:
  /// **'Back to Results'**
  String get vBackResults;

  /// No description provided for @vGuardianContact.
  ///
  /// In en, this message translates to:
  /// **'Guardian Contact'**
  String get vGuardianContact;

  /// No description provided for @vMatchedIndividual.
  ///
  /// In en, this message translates to:
  /// **'Matched Individual'**
  String get vMatchedIndividual;

  /// No description provided for @vGuardianDetails.
  ///
  /// In en, this message translates to:
  /// **'Guardian Details'**
  String get vGuardianDetails;

  /// No description provided for @vGuardianName.
  ///
  /// In en, this message translates to:
  /// **'Guardian Name'**
  String get vGuardianName;

  /// No description provided for @vRelationship.
  ///
  /// In en, this message translates to:
  /// **'Relationship'**
  String get vRelationship;

  /// No description provided for @vMother.
  ///
  /// In en, this message translates to:
  /// **'Mother'**
  String get vMother;

  /// No description provided for @vFather.
  ///
  /// In en, this message translates to:
  /// **'Father'**
  String get vFather;

  /// No description provided for @vRegisteredContact.
  ///
  /// In en, this message translates to:
  /// **'Registered Contact'**
  String get vRegisteredContact;

  /// No description provided for @vContactGuardian.
  ///
  /// In en, this message translates to:
  /// **'Contact Guardian'**
  String get vContactGuardian;

  /// No description provided for @vProceedVerification.
  ///
  /// In en, this message translates to:
  /// **'Proceed to Verification'**
  String get vProceedVerification;

  /// No description provided for @vVerifyGuardian.
  ///
  /// In en, this message translates to:
  /// **'Verify Guardian'**
  String get vVerifyGuardian;

  /// No description provided for @vScanInstruction.
  ///
  /// In en, this message translates to:
  /// **'Scan the QR code displayed in the Guardian’s Radd case.'**
  String get vScanInstruction;

  /// No description provided for @vScanHint.
  ///
  /// In en, this message translates to:
  /// **'Keep the case-specific code steady within the frame.'**
  String get vScanHint;

  /// No description provided for @vScanCode.
  ///
  /// In en, this message translates to:
  /// **'Scan QR Code'**
  String get vScanCode;

  /// No description provided for @vUnableScan.
  ///
  /// In en, this message translates to:
  /// **'Unable to display the QR code?'**
  String get vUnableScan;

  /// No description provided for @vUseIdentifier.
  ///
  /// In en, this message translates to:
  /// **'Use Case Identifier'**
  String get vUseIdentifier;

  /// No description provided for @vVerifyIdentifier.
  ///
  /// In en, this message translates to:
  /// **'Verify Case Identifier'**
  String get vVerifyIdentifier;

  /// No description provided for @vIdentifierHelp.
  ///
  /// In en, this message translates to:
  /// **'Ask the Guardian to display the case identifier from their authenticated Radd account when they cannot display the QR code.'**
  String get vIdentifierHelp;

  /// No description provided for @vGuardianIdentifier.
  ///
  /// In en, this message translates to:
  /// **'Guardian Case Identifier'**
  String get vGuardianIdentifier;

  /// No description provided for @vExactIdentifier.
  ///
  /// In en, this message translates to:
  /// **'The identifiers must match. Compare it with the case shown on the Guardian’s own device.'**
  String get vExactIdentifier;

  /// No description provided for @vAuthenticatedAccount.
  ///
  /// In en, this message translates to:
  /// **'The Guardian is showing this case in their authenticated Radd account.'**
  String get vAuthenticatedAccount;

  /// No description provided for @vVerify.
  ///
  /// In en, this message translates to:
  /// **'Verify Identifier'**
  String get vVerify;

  /// No description provided for @vVerificationFailed.
  ///
  /// In en, this message translates to:
  /// **'Verification Failed'**
  String get vVerificationFailed;

  /// No description provided for @vVerificationMismatch.
  ///
  /// In en, this message translates to:
  /// **'The code or identifier does not match the Guardian and case.'**
  String get vVerificationMismatch;

  /// No description provided for @vNoHandover.
  ///
  /// In en, this message translates to:
  /// **'Do not hand over the individual. Retry verification or use the case identifier.'**
  String get vNoHandover;

  /// No description provided for @vTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get vTryAgain;

  /// No description provided for @vGuardianVerified.
  ///
  /// In en, this message translates to:
  /// **'Guardian Verified'**
  String get vGuardianVerified;

  /// No description provided for @vVerificationSuccess.
  ///
  /// In en, this message translates to:
  /// **'Verification Successful'**
  String get vVerificationSuccess;

  /// No description provided for @vAccountCaseVerified.
  ///
  /// In en, this message translates to:
  /// **'The Guardian’s account has been verified for this case.'**
  String get vAccountCaseVerified;

  /// No description provided for @vVerifiedTime.
  ///
  /// In en, this message translates to:
  /// **'Verified Time'**
  String get vVerifiedTime;

  /// No description provided for @vVerificationMethod.
  ///
  /// In en, this message translates to:
  /// **'Verification Method'**
  String get vVerificationMethod;

  /// No description provided for @vQrMethod.
  ///
  /// In en, this message translates to:
  /// **'Case-specific QR code'**
  String get vQrMethod;

  /// No description provided for @vIdentifierMethod.
  ///
  /// In en, this message translates to:
  /// **'Case identifier'**
  String get vIdentifierMethod;

  /// No description provided for @vContinueHandover.
  ///
  /// In en, this message translates to:
  /// **'Continue to Handover'**
  String get vContinueHandover;

  /// No description provided for @vConfirmHandover.
  ///
  /// In en, this message translates to:
  /// **'Confirm Handover'**
  String get vConfirmHandover;

  /// No description provided for @vHandoverHint.
  ///
  /// In en, this message translates to:
  /// **'Confirm only after the individual has been handed over to the verified Guardian.'**
  String get vHandoverHint;

  /// No description provided for @vHandoverQuestion.
  ///
  /// In en, this message translates to:
  /// **'Confirm Reunification?'**
  String get vHandoverQuestion;

  /// No description provided for @vHandoverConfirmHint.
  ///
  /// In en, this message translates to:
  /// **'Confirm that the individual has been safely handed over to the verified Guardian.'**
  String get vHandoverConfirmHint;

  /// No description provided for @vCompleted.
  ///
  /// In en, this message translates to:
  /// **'Case Completed'**
  String get vCompleted;

  /// No description provided for @vCompletedHint.
  ///
  /// In en, this message translates to:
  /// **'The handover has been successfully confirmed.'**
  String get vCompletedHint;

  /// No description provided for @vHandoverTime.
  ///
  /// In en, this message translates to:
  /// **'Handover Time'**
  String get vHandoverTime;

  /// No description provided for @vConfirmedBy.
  ///
  /// In en, this message translates to:
  /// **'Confirmed By'**
  String get vConfirmedBy;

  /// No description provided for @vDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get vDone;

  /// No description provided for @vAuthorized.
  ///
  /// In en, this message translates to:
  /// **'Authorized Radd Volunteer'**
  String get vAuthorized;

  /// No description provided for @vVolunteerName.
  ///
  /// In en, this message translates to:
  /// **'Volunteer Name'**
  String get vVolunteerName;

  /// No description provided for @vAccountInformation.
  ///
  /// In en, this message translates to:
  /// **'Account Information'**
  String get vAccountInformation;

  /// No description provided for @vFullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get vFullName;

  /// No description provided for @vEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get vEmail;

  /// No description provided for @vPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get vPhone;

  /// No description provided for @vLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get vLanguage;

  /// No description provided for @vLogout.
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get vLogout;

  /// No description provided for @vLogoutQuestion.
  ///
  /// In en, this message translates to:
  /// **'End your volunteer session?'**
  String get vLogoutQuestion;

  /// No description provided for @vPreview.
  ///
  /// In en, this message translates to:
  /// **'Design preview · Sample data'**
  String get vPreview;

  /// No description provided for @vPreviewOpen.
  ///
  /// In en, this message translates to:
  /// **'Preview Volunteer Designs'**
  String get vPreviewOpen;

  /// No description provided for @vPreviewCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera preview'**
  String get vPreviewCamera;

  /// No description provided for @vPreviewCameraHint.
  ///
  /// In en, this message translates to:
  /// **'This preview uses the supplied sample photograph. No camera capture or AI request takes place.'**
  String get vPreviewCameraHint;

  /// No description provided for @vPreviewCapture.
  ///
  /// In en, this message translates to:
  /// **'Simulate Capture'**
  String get vPreviewCapture;

  /// No description provided for @vPreviewQr.
  ///
  /// In en, this message translates to:
  /// **'Preview QR verification'**
  String get vPreviewQr;

  /// No description provided for @vPreviewQrHint.
  ///
  /// In en, this message translates to:
  /// **'Choose a sample outcome. No QR code is scanned and no real Guardian is verified.'**
  String get vPreviewQrHint;

  /// No description provided for @vPreviewValid.
  ///
  /// In en, this message translates to:
  /// **'Matching Code'**
  String get vPreviewValid;

  /// No description provided for @vPreviewInvalid.
  ///
  /// In en, this message translates to:
  /// **'Non-matching Code'**
  String get vPreviewInvalid;

  /// No description provided for @vPreviewCall.
  ///
  /// In en, this message translates to:
  /// **'Sample contact only. No call is placed in design preview.'**
  String get vPreviewCall;

  /// No description provided for @vUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This service is not connected yet.'**
  String get vUnavailable;

  /// No description provided for @vBackendHint.
  ///
  /// In en, this message translates to:
  /// **'Case services will be available after the event server is connected.'**
  String get vBackendHint;

  /// No description provided for @vInactiveHint.
  ///
  /// In en, this message translates to:
  /// **'This Volunteer account is inactive. Contact the event organizer.'**
  String get vInactiveHint;

  /// No description provided for @vLocation.
  ///
  /// In en, this message translates to:
  /// **'Nearby Case Alerts'**
  String get vLocation;

  /// No description provided for @vLocationHelp.
  ///
  /// In en, this message translates to:
  /// **'Allow location while using Radd to check whether you are within 500 meters of a reported location. General alerts remain available without location.'**
  String get vLocationHelp;

  /// No description provided for @vAllowLocation.
  ///
  /// In en, this message translates to:
  /// **'Allow Location'**
  String get vAllowLocation;

  /// No description provided for @vLocationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Location is unavailable. You can still use Radd and receive general alerts.'**
  String get vLocationUnavailable;

  /// No description provided for @vLocationReady.
  ///
  /// In en, this message translates to:
  /// **'Location is available while using Radd.'**
  String get vLocationReady;

  /// No description provided for @vLogin.
  ///
  /// In en, this message translates to:
  /// **'Log In'**
  String get vLogin;

  /// No description provided for @vWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome Back'**
  String get vWelcome;

  /// No description provided for @vLoginHint.
  ///
  /// In en, this message translates to:
  /// **'Log in to your Volunteer account'**
  String get vLoginHint;

  /// No description provided for @vPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get vPassword;

  /// No description provided for @vForgot.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get vForgot;

  /// No description provided for @vReset.
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get vReset;

  /// No description provided for @vResetHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your email to receive password reset instructions.'**
  String get vResetHint;

  /// No description provided for @vSendReset.
  ///
  /// In en, this message translates to:
  /// **'Send Instructions'**
  String get vSendReset;

  /// No description provided for @vResetSent.
  ///
  /// In en, this message translates to:
  /// **'If this email is registered, reset instructions have been sent.'**
  String get vResetSent;

  /// No description provided for @vAccountManaged.
  ///
  /// In en, this message translates to:
  /// **'Volunteer accounts are provided by the event organizer.'**
  String get vAccountManaged;

  /// No description provided for @vRequired.
  ///
  /// In en, this message translates to:
  /// **'This field is required.'**
  String get vRequired;

  /// No description provided for @vInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get vInvalidEmail;

  /// No description provided for @vInvalidLogin.
  ///
  /// In en, this message translates to:
  /// **'Invalid email or password.'**
  String get vInvalidLogin;

  /// No description provided for @vNetworkError.
  ///
  /// In en, this message translates to:
  /// **'Check your Internet connection and try again.'**
  String get vNetworkError;

  /// No description provided for @vAccessDenied.
  ///
  /// In en, this message translates to:
  /// **'An authorized Volunteer account is required. Contact the event organizer.'**
  String get vAccessDenied;

  /// No description provided for @vActionFailed.
  ///
  /// In en, this message translates to:
  /// **'This action could not be completed. Please try again.'**
  String get vActionFailed;

  /// No description provided for @vNoMissingReport.
  ///
  /// In en, this message translates to:
  /// **'No missing-person report'**
  String get vNoMissingReport;

  /// No description provided for @vSearchJoinedHint.
  ///
  /// In en, this message translates to:
  /// **'You have started searching for this case.'**
  String get vSearchJoinedHint;

  /// No description provided for @vAdditionalReceived.
  ///
  /// In en, this message translates to:
  /// **'Additional information received'**
  String get vAdditionalReceived;

  /// No description provided for @vAgeValue.
  ///
  /// In en, this message translates to:
  /// **'Age {value}'**
  String vAgeValue(String value);

  /// No description provided for @vCount.
  ///
  /// In en, this message translates to:
  /// **'{count} cases'**
  String vCount(String count);

  /// No description provided for @vSimilarityValue.
  ///
  /// In en, this message translates to:
  /// **'{value}% Similarity'**
  String vSimilarityValue(String value);

  /// No description provided for @reportMissing.
  ///
  /// In en, this message translates to:
  /// **'Report Missing'**
  String get reportMissing;

  /// No description provided for @reportConfirm.
  ///
  /// In en, this message translates to:
  /// **'Report this individual as missing?'**
  String get reportConfirm;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @reportReceived.
  ///
  /// In en, this message translates to:
  /// **'Report Received'**
  String get reportReceived;

  /// No description provided for @searchInProgress.
  ///
  /// In en, this message translates to:
  /// **'Search in Progress'**
  String get searchInProgress;

  /// No description provided for @matchConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Match Confirmed'**
  String get matchConfirmed;

  /// No description provided for @awaitingVerification.
  ///
  /// In en, this message translates to:
  /// **'Awaiting Guardian Verification'**
  String get awaitingVerification;

  /// No description provided for @reunited.
  ///
  /// In en, this message translates to:
  /// **'Reunited'**
  String get reunited;

  /// No description provided for @unknownCaseStatus.
  ///
  /// In en, this message translates to:
  /// **'Status unavailable'**
  String get unknownCaseStatus;

  /// No description provided for @caseStatus.
  ///
  /// In en, this message translates to:
  /// **'Case Status'**
  String get caseStatus;

  /// No description provided for @viewStatus.
  ///
  /// In en, this message translates to:
  /// **'View Status'**
  String get viewStatus;

  /// No description provided for @trackStatus.
  ///
  /// In en, this message translates to:
  /// **'Track Status'**
  String get trackStatus;

  /// No description provided for @activeCases.
  ///
  /// In en, this message translates to:
  /// **'Active Cases'**
  String get activeCases;

  /// No description provided for @noCases.
  ///
  /// In en, this message translates to:
  /// **'No cases yet'**
  String get noCases;

  /// No description provided for @noCasesHint.
  ///
  /// In en, this message translates to:
  /// **'Your missing-person reports will appear here.'**
  String get noCasesHint;

  /// No description provided for @reportingAssistant.
  ///
  /// In en, this message translates to:
  /// **'Reporting Assistant'**
  String get reportingAssistant;

  /// No description provided for @sameLocationQuestion.
  ///
  /// In en, this message translates to:
  /// **'Is your current location the same as where the missing individual was last seen?'**
  String get sameLocationQuestion;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @lastSeenDescription.
  ///
  /// In en, this message translates to:
  /// **'Where was the individual last seen?'**
  String get lastSeenDescription;

  /// No description provided for @clothingQuestion.
  ///
  /// In en, this message translates to:
  /// **'What clothing was the individual wearing when last seen?'**
  String get clothingQuestion;

  /// No description provided for @distinctiveQuestion.
  ///
  /// In en, this message translates to:
  /// **'Was the individual carrying anything distinctive, such as a bag or toy?'**
  String get distinctiveQuestion;

  /// No description provided for @distinctiveDescription.
  ///
  /// In en, this message translates to:
  /// **'Describe the distinctive item'**
  String get distinctiveDescription;

  /// No description provided for @additionalQuestion.
  ///
  /// In en, this message translates to:
  /// **'Is there any additional information that could help Volunteers find the individual?'**
  String get additionalQuestion;

  /// No description provided for @saveReport.
  ///
  /// In en, this message translates to:
  /// **'Save report details'**
  String get saveReport;

  /// No description provided for @reportSaved.
  ///
  /// In en, this message translates to:
  /// **'Report details saved'**
  String get reportSaved;

  /// No description provided for @locationRequired.
  ///
  /// In en, this message translates to:
  /// **'Allow location access to use your current position, or select No and describe the last-seen location.'**
  String get locationRequired;

  /// No description provided for @locationReady.
  ///
  /// In en, this message translates to:
  /// **'Current location captured for this report'**
  String get locationReady;

  /// No description provided for @useCurrentLocation.
  ///
  /// In en, this message translates to:
  /// **'Use current location'**
  String get useCurrentLocation;

  /// No description provided for @noNotifications.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet'**
  String get noNotifications;

  /// No description provided for @notificationHint.
  ///
  /// In en, this message translates to:
  /// **'Updates about your cases will appear here.'**
  String get notificationHint;

  /// No description provided for @guardianVerification.
  ///
  /// In en, this message translates to:
  /// **'Guardian Verification QR'**
  String get guardianVerification;

  /// No description provided for @verificationExplanation.
  ///
  /// In en, this message translates to:
  /// **'Show this code to an authorized Volunteer to verify your connection to this case. It does not identify the missing individual.'**
  String get verificationExplanation;

  /// No description provided for @noEligibleCases.
  ///
  /// In en, this message translates to:
  /// **'No cases are awaiting Guardian verification.'**
  String get noEligibleCases;

  /// No description provided for @verificationExpired.
  ///
  /// In en, this message translates to:
  /// **'This code has expired. Generate a new code to continue.'**
  String get verificationExpired;

  /// No description provided for @refreshCode.
  ///
  /// In en, this message translates to:
  /// **'Generate new code'**
  String get refreshCode;

  /// No description provided for @showCaseIdentifier.
  ///
  /// In en, this message translates to:
  /// **'Show Case Identifier'**
  String get showCaseIdentifier;

  /// No description provided for @caseIdentifier.
  ///
  /// In en, this message translates to:
  /// **'Case Identifier'**
  String get caseIdentifier;

  /// No description provided for @caseIdentifierHint.
  ///
  /// In en, this message translates to:
  /// **'Share this reference with an authorized team member. The reference alone does not verify your identity.'**
  String get caseIdentifierHint;

  /// No description provided for @eventUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Reporting is temporarily unavailable because the current event has not been activated. Please try again later.'**
  String get eventUnavailable;

  /// No description provided for @guidedDetails.
  ///
  /// In en, this message translates to:
  /// **'Report details'**
  String get guidedDetails;

  /// No description provided for @lastUpdated.
  ///
  /// In en, this message translates to:
  /// **'Last updated'**
  String get lastUpdated;

  /// No description provided for @requiredAnswer.
  ///
  /// In en, this message translates to:
  /// **'Please complete this answer.'**
  String get requiredAnswer;

  /// No description provided for @activeCase.
  ///
  /// In en, this message translates to:
  /// **'Active Case'**
  String get activeCase;

  /// No description provided for @verificationExpires.
  ///
  /// In en, this message translates to:
  /// **'Valid until'**
  String get verificationExpires;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @vLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t load right now. Tap to try again.'**
  String get vLoadFailed;

  /// No description provided for @vContinueReport.
  ///
  /// In en, this message translates to:
  /// **'Continue report'**
  String get vContinueReport;

  /// No description provided for @vAiUnavailable.
  ///
  /// In en, this message translates to:
  /// **'AI matching is unavailable. Your report is saved; continue with manual review.'**
  String get vAiUnavailable;

  /// No description provided for @vQrRequired.
  ///
  /// In en, this message translates to:
  /// **'Ask the Guardian to display this case’s QR code in their signed-in Radd account. A case identifier alone cannot verify identity.'**
  String get vQrRequired;

  /// No description provided for @child.
  ///
  /// In en, this message translates to:
  /// **'Child'**
  String get child;

  /// No description provided for @specifyRelationship.
  ///
  /// In en, this message translates to:
  /// **'Specify relationship'**
  String get specifyRelationship;

  /// No description provided for @casesAwaitingVerification.
  ///
  /// In en, this message translates to:
  /// **'Cases awaiting verification'**
  String get casesAwaitingVerification;

  /// No description provided for @resolved.
  ///
  /// In en, this message translates to:
  /// **'Resolved'**
  String get resolved;

  /// No description provided for @cancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get cancelled;

  /// No description provided for @transferredToAuthority.
  ///
  /// In en, this message translates to:
  /// **'Transferred to Authority'**
  String get transferredToAuthority;

  /// No description provided for @casesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Track your missing-person cases'**
  String get casesSubtitle;

  /// No description provided for @resolveReport.
  ///
  /// In en, this message translates to:
  /// **'Resolve Report'**
  String get resolveReport;

  /// No description provided for @resolveReportConfirm.
  ///
  /// In en, this message translates to:
  /// **'Resolve this report? Only do this if you found the individual independently, outside of Radd.'**
  String get resolveReportConfirm;

  /// No description provided for @cancelReport.
  ///
  /// In en, this message translates to:
  /// **'Cancel Report'**
  String get cancelReport;

  /// No description provided for @cancelReportConfirm.
  ///
  /// In en, this message translates to:
  /// **'Cancel this report? Use this only if it was created by mistake.'**
  String get cancelReportConfirm;

  /// No description provided for @reunitedOutcome.
  ///
  /// In en, this message translates to:
  /// **'This individual has been reunited with their Guardian.'**
  String get reunitedOutcome;

  /// No description provided for @caseClosedNotice.
  ///
  /// In en, this message translates to:
  /// **'This report is closed and is no longer part of active search and matching.'**
  String get caseClosedNotice;

  /// No description provided for @caseDetails.
  ///
  /// In en, this message translates to:
  /// **'Case Details'**
  String get caseDetails;

  /// No description provided for @activeCaseLockNotice.
  ///
  /// In en, this message translates to:
  /// **'Editing and deletion are unavailable while an active case exists for this individual.'**
  String get activeCaseLockNotice;

  /// No description provided for @guidedAssistantRequired.
  ///
  /// In en, this message translates to:
  /// **'Please finish the required questions before leaving this screen.'**
  String get guidedAssistantRequired;

  /// No description provided for @caseClosedActionError.
  ///
  /// In en, this message translates to:
  /// **'This report is closed and can no longer be changed.'**
  String get caseClosedActionError;

  /// No description provided for @reportAlreadySubmitted.
  ///
  /// In en, this message translates to:
  /// **'This report has already been submitted and can no longer be edited.'**
  String get reportAlreadySubmitted;

  /// No description provided for @photoExpiredError.
  ///
  /// In en, this message translates to:
  /// **'This photo has expired and can no longer be used. Take a new photo to continue.'**
  String get photoExpiredError;

  /// No description provided for @photoExpiredNotice.
  ///
  /// In en, this message translates to:
  /// **'This photo has expired and is no longer usable. Take a new photo before reporting this individual missing.'**
  String get photoExpiredNotice;

  /// No description provided for @updatePhotoRequired.
  ///
  /// In en, this message translates to:
  /// **'Update Photo'**
  String get updatePhotoRequired;

  /// No description provided for @caseId.
  ///
  /// In en, this message translates to:
  /// **'Case ID'**
  String get caseId;

  /// No description provided for @updatedLabel.
  ///
  /// In en, this message translates to:
  /// **'Updated'**
  String get updatedLabel;

  /// No description provided for @ageYears.
  ///
  /// In en, this message translates to:
  /// **'{value} yrs'**
  String ageYears(String value);

  /// No description provided for @caseHistory.
  ///
  /// In en, this message translates to:
  /// **'Case History'**
  String get caseHistory;

  /// No description provided for @noActiveCasesHint.
  ///
  /// In en, this message translates to:
  /// **'No active cases right now.'**
  String get noActiveCasesHint;

  /// No description provided for @progressTimeline.
  ///
  /// In en, this message translates to:
  /// **'Progress Timeline'**
  String get progressTimeline;

  /// No description provided for @stageLabel.
  ///
  /// In en, this message translates to:
  /// **'Stage {number}'**
  String stageLabel(String number);

  /// No description provided for @stageStatus.
  ///
  /// In en, this message translates to:
  /// **'Stage {number}: {status}'**
  String stageStatus(String number, String status);

  /// No description provided for @activeLabel.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get activeLabel;

  /// No description provided for @completedLabel.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completedLabel;

  /// No description provided for @statusUpdatesAutomatically.
  ///
  /// In en, this message translates to:
  /// **'Status updates automatically'**
  String get statusUpdatesAutomatically;

  /// No description provided for @reportReceivedDescription.
  ///
  /// In en, this message translates to:
  /// **'Your report has been received and active Volunteers have been notified.'**
  String get reportReceivedDescription;

  /// No description provided for @searchInProgressDescription.
  ///
  /// In en, this message translates to:
  /// **'Volunteers are actively searching for the individual.'**
  String get searchInProgressDescription;

  /// No description provided for @matchConfirmedDescription.
  ///
  /// In en, this message translates to:
  /// **'A Volunteer has confirmed a match and will proceed to Guardian verification.'**
  String get matchConfirmedDescription;

  /// No description provided for @awaitingVerificationDescription.
  ///
  /// In en, this message translates to:
  /// **'Show your Guardian Verification QR to the Volunteer to confirm your identity.'**
  String get awaitingVerificationDescription;

  /// No description provided for @reunitedDescription.
  ///
  /// In en, this message translates to:
  /// **'The individual has been safely reunited with you.'**
  String get reunitedDescription;

  /// No description provided for @outcomeLabel.
  ///
  /// In en, this message translates to:
  /// **'Outcome'**
  String get outcomeLabel;

  /// No description provided for @lastSeenLocationLabel.
  ///
  /// In en, this message translates to:
  /// **'Last-seen location'**
  String get lastSeenLocationLabel;

  /// No description provided for @currentLocationConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Current location confirmed'**
  String get currentLocationConfirmed;

  /// No description provided for @clothingLabel.
  ///
  /// In en, this message translates to:
  /// **'Clothing'**
  String get clothingLabel;

  /// No description provided for @distinctiveLabel.
  ///
  /// In en, this message translates to:
  /// **'Distinctive item'**
  String get distinctiveLabel;

  /// No description provided for @additionalLabel.
  ///
  /// In en, this message translates to:
  /// **'Additional information'**
  String get additionalLabel;

  /// No description provided for @none.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get none;

  /// No description provided for @detailsPending.
  ///
  /// In en, this message translates to:
  /// **'Report details have not been completed yet.'**
  String get detailsPending;

  /// No description provided for @reportedByGuardian.
  ///
  /// In en, this message translates to:
  /// **'Reported by Guardian'**
  String get reportedByGuardian;

  /// No description provided for @todayJustNow.
  ///
  /// In en, this message translates to:
  /// **'Today • Just now'**
  String get todayJustNow;

  /// No description provided for @assistantIntro.
  ///
  /// In en, this message translates to:
  /// **'Your missing-person report for {name} has been submitted. I\'ll ask a few quick questions to help Volunteers with the search.'**
  String assistantIntro(String name);

  /// No description provided for @locationHint.
  ///
  /// In en, this message translates to:
  /// **'Used to coordinate nearby Volunteers.'**
  String get locationHint;

  /// No description provided for @answersAutoSave.
  ///
  /// In en, this message translates to:
  /// **'Answers save automatically to active case'**
  String get answersAutoSave;

  /// No description provided for @typeAnswer.
  ///
  /// In en, this message translates to:
  /// **'Type your answer…'**
  String get typeAnswer;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @qrSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show this code to the Volunteer for Guardian verification'**
  String get qrSubtitle;

  /// No description provided for @qrVerifiesAccount.
  ///
  /// In en, this message translates to:
  /// **'This QR code verifies that your authenticated Guardian account is associated with this case.'**
  String get qrVerifiesAccount;

  /// No description provided for @qrVerifiesAccountNoCase.
  ///
  /// In en, this message translates to:
  /// **'This QR code verifies your authenticated Guardian account. It does not identify any missing individual.'**
  String get qrVerifiesAccountNoCase;

  /// No description provided for @selectActiveCase.
  ///
  /// In en, this message translates to:
  /// **'Select Active Case'**
  String get selectActiveCase;

  /// No description provided for @scanInstruction.
  ///
  /// In en, this message translates to:
  /// **'Ask the Volunteer to scan this QR code using Radd.'**
  String get scanInstruction;

  /// No description provided for @cannotDisplayQr.
  ///
  /// In en, this message translates to:
  /// **'Can\'t display the QR code?'**
  String get cannotDisplayQr;

  /// No description provided for @caseIdentifierInstruction.
  ///
  /// In en, this message translates to:
  /// **'Show this identifier to the Volunteer for alternative verification.'**
  String get caseIdentifierInstruction;

  /// No description provided for @caseIdentifierUsage.
  ///
  /// In en, this message translates to:
  /// **'Used to locate and verify the active case when the QR code cannot be displayed or scanned.'**
  String get caseIdentifierUsage;

  /// No description provided for @activeCaseIdentifier.
  ///
  /// In en, this message translates to:
  /// **'Active case identifier'**
  String get activeCaseIdentifier;

  /// No description provided for @noActiveCaseQrNote.
  ///
  /// In en, this message translates to:
  /// **'You have no active cases right now. Your Guardian QR remains valid for verification.'**
  String get noActiveCaseQrNote;

  /// No description provided for @qrRefreshing.
  ///
  /// In en, this message translates to:
  /// **'Generating a new code…'**
  String get qrRefreshing;

  /// No description provided for @resetSentTitle.
  ///
  /// In en, this message translates to:
  /// **'Check your email'**
  String get resetSentTitle;

  /// No description provided for @backToLogin.
  ///
  /// In en, this message translates to:
  /// **'Back to Log In'**
  String get backToLogin;

  /// No description provided for @resendReset.
  ///
  /// In en, this message translates to:
  /// **'Send again'**
  String get resendReset;

  /// No description provided for @vAccountDeactivated.
  ///
  /// In en, this message translates to:
  /// **'Your Volunteer account is inactive. You have been signed out.'**
  String get vAccountDeactivated;

  /// No description provided for @vEndIdentification.
  ///
  /// In en, this message translates to:
  /// **'End Identification Attempt'**
  String get vEndIdentification;

  /// No description provided for @vEndIdentificationHint.
  ///
  /// In en, this message translates to:
  /// **'End this identification attempt and delete the captured photo? The missing-person case and search will continue.'**
  String get vEndIdentificationHint;

  /// No description provided for @locationNotRecorded.
  ///
  /// In en, this message translates to:
  /// **'Location could not be recorded. You can continue; the general alert remains active.'**
  String get locationNotRecorded;

  /// No description provided for @vCancelledAlert.
  ///
  /// In en, this message translates to:
  /// **'Case Cancelled'**
  String get vCancelledAlert;

  /// No description provided for @vResolvedAlert.
  ///
  /// In en, this message translates to:
  /// **'Person Found'**
  String get vResolvedAlert;

  /// No description provided for @vNewAlertMessage.
  ///
  /// In en, this message translates to:
  /// **'A new missing-person case has been reported.'**
  String get vNewAlertMessage;

  /// No description provided for @vPriorityAlertMessage.
  ///
  /// In en, this message translates to:
  /// **'A missing-person case has been reported within 500 meters of your available location.'**
  String get vPriorityAlertMessage;

  /// No description provided for @vMatchAlertMessage.
  ///
  /// In en, this message translates to:
  /// **'A match was confirmed for a case you joined. Guardian verification and handover are still required.'**
  String get vMatchAlertMessage;

  /// No description provided for @vCancelledAlertMessage.
  ///
  /// In en, this message translates to:
  /// **'The guardian cancelled this missing-person case.'**
  String get vCancelledAlertMessage;

  /// No description provided for @vResolvedAlertMessage.
  ///
  /// In en, this message translates to:
  /// **'The guardian found the individual and resolved this case.'**
  String get vResolvedAlertMessage;

  /// No description provided for @vReunitedAlertMessage.
  ///
  /// In en, this message translates to:
  /// **'The individual has been reunited with their guardian after verification.'**
  String get vReunitedAlertMessage;

  /// No description provided for @vLocationSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get vLocationSettings;

  /// No description provided for @vLocationDeniedForever.
  ///
  /// In en, this message translates to:
  /// **'Location permission is disabled. Enable it in Settings to receive nearby alerts. General alerts remain available.'**
  String get vLocationDeniedForever;

  /// No description provided for @vLocationServicesDisabled.
  ///
  /// In en, this message translates to:
  /// **'Turn on device location services to receive nearby alerts.'**
  String get vLocationServicesDisabled;

  /// No description provided for @vNotificationCaseUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This case is no longer available for an active search. Notifications and cases have been refreshed.'**
  String get vNotificationCaseUnavailable;
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
