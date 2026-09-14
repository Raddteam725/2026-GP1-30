// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Radd';

  @override
  String get loading => 'Loading';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get pageNotFound => 'Page not found';

  @override
  String get chooseLanguage => 'Choose Your Language';

  @override
  String get continueLabel => 'Continue';

  @override
  String get chooseRole => 'Choose Your Role';

  @override
  String get guardianRole => 'Guardian';

  @override
  String get volunteerRole => 'Volunteer';

  @override
  String selectedRole(String role) {
    return 'Selected role: $role';
  }

  @override
  String get languageHint => 'Choose the language you prefer.';

  @override
  String get currentSelection => 'Current selection';

  @override
  String get englishLanguage => 'English language';

  @override
  String get arabicLanguage => 'Arabic language';

  @override
  String get brandFooter => 'Radd • Bringing People Back Together';

  @override
  String get joinRadd => 'Join Radd';

  @override
  String get roleHint => 'Choose how you would like to continue';

  @override
  String get guardianDescription =>
      'Register individuals under your care and manage their safety during the event.';

  @override
  String get volunteerDescription =>
      'Access your volunteer account and assist with active cases during the event.';

  @override
  String get welcomeBack => 'Welcome Back';

  @override
  String get loginHint => 'Log in to continue';

  @override
  String get email => 'Email Address';

  @override
  String get password => 'Password';

  @override
  String get fullName => 'Full Name';

  @override
  String get phone => 'Phone Number';

  @override
  String get phoneHelp => 'Include country code, e.g. +966501234567';

  @override
  String get login => 'Log In';

  @override
  String get createAccount => 'Create Account';

  @override
  String get createTitle => 'Create Your Account';

  @override
  String get createHint => 'Create your Guardian account to continue';

  @override
  String get forgotPassword => 'Forgot Password?';

  @override
  String get resetTitle => 'Forgot Password?';

  @override
  String get resetHint =>
      'Enter your email to request password reset instructions.';

  @override
  String get sendReset => 'Send Reset Instructions';

  @override
  String get resetSent =>
      'If an account exists for this email, password reset instructions will be sent.';

  @override
  String get noAccount => 'Don\'t have an account?';

  @override
  String get rememberPassword => 'Remember your password?';

  @override
  String get ageConfirm => 'I confirm that I am 18 years of age or older.';

  @override
  String get privacyConfirm => 'I have read and agree to the Privacy Notice.';

  @override
  String get privacyTitle => 'Privacy Notice';

  @override
  String get privacyBody =>
      'Project information — final notice pending approval.\n\nRadd processes information and photographs for event-specific reunification. Access is intended to follow system roles. Identifiable records and photographs are subject to the project\'s retention and deletion rules; anonymized aggregate information may be retained under the project design.\n\nThis interim notice will be replaced with the team\'s approved wording.';

  @override
  String get requiredField => 'This field is required.';

  @override
  String get invalidName => 'Use a name of no more than 120 characters.';

  @override
  String get invalidEmail => 'Enter a valid email address.';

  @override
  String get invalidPhone =>
      'Enter + followed by your country code and phone number (8–15 digits).';

  @override
  String get passwordHelp =>
      'Use 8+ characters with uppercase, lowercase, a number and a special character.';

  @override
  String get confirmRequired => 'Both confirmations are required.';

  @override
  String get invalidCredentials => 'Invalid email or password.';

  @override
  String get emailExists => 'This email is already registered.';

  @override
  String get networkError =>
      'Unable to connect. Check your connection and try again.';

  @override
  String get serviceError =>
      'The service is currently unavailable. Please try again.';

  @override
  String get rateLimit => 'Too many attempts. Please try again later.';

  @override
  String get roleError => 'This account cannot access Guardian services.';

  @override
  String get notFoundError => 'This record is no longer available.';

  @override
  String get activeCaseError =>
      'This individual cannot be deleted while an active case exists. Resolve or cancel the case first.';

  @override
  String get retry => 'Try Again';

  @override
  String get home => 'Home';

  @override
  String get myIndividuals => 'My Individuals';

  @override
  String get profile => 'Profile';

  @override
  String get registerIndividual => 'Register an Individual';

  @override
  String get registerHint => 'Add a person under your care';

  @override
  String get individualsHint => 'People registered under your care';

  @override
  String get emptyTitle => 'No individuals registered yet';

  @override
  String get emptyHint => 'Register someone under your care to get started.';

  @override
  String get addIndividual => 'Add Individual';

  @override
  String get editIndividual => 'Edit Individual';

  @override
  String get individualProfile => 'Individual Profile';

  @override
  String get photoLabel => 'Photograph';

  @override
  String get takePhoto => 'Take Photo';

  @override
  String get retakePhoto => 'Retake Photo';

  @override
  String get cameraOnly => 'Live in-app camera capture only';

  @override
  String get cameraGuide =>
      'Keep the face visible, use good lighting and avoid obstructions.';

  @override
  String get cameraDenied =>
      'Camera access was denied. Allow camera permission to take a photo. If requests are blocked, enable it in Android app permissions.';

  @override
  String get cameraUnavailable =>
      'The camera is unavailable. Please try again.';

  @override
  String get capture => 'Capture Photo';

  @override
  String get photoRequired => 'Take a photo before saving.';

  @override
  String get photoTooLarge => 'The photo is too large. Please retake it.';

  @override
  String get age => 'Age';

  @override
  String get invalidAge => 'Enter a whole-number age between 0 and 130.';

  @override
  String get gender => 'Gender';

  @override
  String get female => 'Female';

  @override
  String get male => 'Male';

  @override
  String get relationship => 'Relationship to Guardian';

  @override
  String get daughter => 'Daughter';

  @override
  String get son => 'Son';

  @override
  String get parent => 'Parent';

  @override
  String get sibling => 'Sibling';

  @override
  String get other => 'Other person under my care';

  @override
  String get save => 'Save';

  @override
  String get saveChanges => 'Save Changes';

  @override
  String get edit => 'Edit';

  @override
  String get deleteIndividual => 'Delete Individual';

  @override
  String get delete => 'Delete';

  @override
  String get cancel => 'Cancel';

  @override
  String get language => 'Language';

  @override
  String get logout => 'Log Out';

  @override
  String get logoutTitle => 'Log Out?';

  @override
  String get logoutMessage =>
      'Are you sure you want to log out of your account?';

  @override
  String get editProfile => 'Edit Profile';

  @override
  String get emailReadOnly =>
      'Email is managed by Firebase Authentication and cannot be edited here.';

  @override
  String get volunteerUnavailable =>
      'Volunteer access is not available in this build yet.';

  @override
  String get sessionExpired => 'Please log in to continue.';

  @override
  String get completeProfile => 'Complete your Guardian profile';

  @override
  String get completeProfileHint =>
      'Your account is signed in. Complete or retry saving your profile to continue.';

  @override
  String get brandTagline => 'Bringing People Back Together';

  @override
  String get splashSupport => 'A safer tomorrow for every journey';

  @override
  String get validationError => 'Please review the information and try again.';

  @override
  String greeting(String name) {
    return 'Hello, $name';
  }

  @override
  String deleteMessage(String name) {
    return 'Delete $name and their photograph? This cannot be undone.';
  }

  @override
  String get emailPlaceholder => 'name@example.com';

  @override
  String get alreadyAccount => 'Already have an account?';

  @override
  String get qrCode => 'QR Code';

  @override
  String get cases => 'Cases';

  @override
  String get comingLater => 'This feature will be available in a later sprint.';

  @override
  String get notifications => 'Notifications';

  @override
  String get greetingIntro => 'Welcome,';

  @override
  String get individualsTitle => 'Individuals';

  @override
  String get viewAll => 'View All';

  @override
  String get add => 'Add';

  @override
  String get addIndividualHint =>
      'Add the individual’s information for this event.';

  @override
  String get photoHeading => 'PHOTO';

  @override
  String get cameraRequired => 'Camera required';

  @override
  String get enterFullName => 'Enter full name';

  @override
  String get enterAge => 'Enter age';

  @override
  String get selectRelationship => 'Select relationship';

  @override
  String get personalInformation => 'Personal Information';

  @override
  String get accountInformation => 'Account Information';

  @override
  String get changePhotoCamera => 'Change Photo (Camera)';

  @override
  String get usePhoto => 'Use Photo';

  @override
  String get deleteIndividualTitle => 'Delete Individual?';

  @override
  String get volunteerLogin => 'Volunteer Login';

  @override
  String get restoringSession => 'Restoring your session';

  @override
  String get restoringSessionHint => 'Checking your account and role securely.';

  @override
  String get sessionRecovery => 'Account recovery';

  @override
  String get missingProfileRecovery =>
      'Your account is signed in, but its profile is incomplete. Complete your Guardian profile or choose your role to continue.';

  @override
  String get expiredSessionRecovery =>
      'Your session could not be verified. Choose your role to sign in again.';

  @override
  String get roleRecovery =>
      'This account could not be verified for the selected role. Return to role selection or sign in with the correct account.';

  @override
  String get sessionUnavailable =>
      'We could not verify your account profile because the account service is unavailable. Retry, or return to role selection to access sign-in. Your account has not been deleted.';

  @override
  String get completeGuardianProfile => 'Complete Guardian profile';

  @override
  String get returnToRoles => 'Return to Role Selection';

  @override
  String get startupFailed => 'Unable to start Radd';

  @override
  String get startupFailedHint =>
      'Initialization did not finish. Please try again.';
}
