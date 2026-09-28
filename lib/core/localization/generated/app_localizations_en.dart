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
  String get brandFooter => 'Radd · Bringing People Back Together';

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
      'Enter your email address to receive a password reset email.';

  @override
  String get sendReset => 'Send Reset Email';

  @override
  String get resetSent =>
      'If an account is associated with this email address, you\'ll receive a password reset email.';

  @override
  String get noAccount => 'Don\'t have an account?';

  @override
  String get rememberPassword => 'Remember your password?';

  @override
  String get ageConfirm => 'I confirm that I am 18 years of age or older.';

  @override
  String get privacyConfirm =>
      'I have read and agree to Radd\'s Privacy Notice.';

  @override
  String get privacyTitle => 'Privacy Notice';

  @override
  String get privacyIntro =>
      'At Radd, we respect your privacy and the privacy of individuals registered under your care. The data processed by the system may include personal information and photographs relating to children, older adults, or other individuals who may require assistance if they become separated during an event.\n\nThis notice explains what information Radd uses, why and how it is used during the search, identification, and reunification process, who may access it, how long it is retained, and when it is deleted.';

  @override
  String get privacyInfoTitle => 'Information We Collect and Use';

  @override
  String get privacyInfoBody =>
      'When you create a Guardian account and use Radd, the system processes information required to create and use your account, as well as information you provide about individuals registered under your care, including their identifying information and photographs.\n\nWhen a missing-person report is submitted, Radd may also process case-related information, such as details about the missing individual, descriptive information provided to support the search, and last-seen information. If you choose to use your device location as the last-seen location and grant location permission, location coordinates may be used for this purpose.\n\nThis information is used to support registration, reporting, searching, identification, verification, and reunification during the event.';

  @override
  String get privacyRegisteredPhotosTitle =>
      'Registered Individuals\' Photographs';

  @override
  String get privacyRegisteredPhotosBody =>
      'The reference photograph and facial embedding belong to the individual’s identifiable event information. Their availability follows the registration period selected from the Active Event’s configured options, or the longest valid option by default. They do not expire solely because of photo capture age.\n\nWhen the period expires, identifiable information is deleted unless an associated active missing-person case requires it. In that case deletion is deferred until the case is terminal. Replacing a photograph does not extend the registration. AI suggestions never replace human confirmation and Guardian verification.';

  @override
  String get privacyVolunteerPhotosTitle =>
      'Photographs Captured by Volunteers';

  @override
  String get privacyVolunteerPhotosBody =>
      'When a person is found or becomes separated, an authorized Volunteer may capture their photograph through Radd solely within the identification and reunification workflow.\n\nThe photograph may be used for identification, including comparison against eligible registered profiles to assist in identifying potential matches. Photograph capture is restricted to authorized Volunteers while assisting a found or separated individual.\n\nA photograph captured by a Volunteer is deleted when the identification attempt concludes, whether or not a match is confirmed.';

  @override
  String get privacyLocationTitle => 'Location Information';

  @override
  String get privacyLocationBody =>
      'Radd may use location information to support the search process and proximity-based alerts related to a reported last-seen location.\n\nFor a missing-person report, if the Guardian confirms that they are at the location where the individual was last seen and grants the application permission to access the device location, the available location may be recorded as the case\'s reported last-seen location. If permission is not granted or the location cannot be obtained, the device location is not used for this purpose. A textual description of the location may instead be provided as part of the case information.\n\nRadd also uses a Volunteer\'s location, when the required permission is granted, to determine whether the Volunteer is near a reported last-seen location and qualifies for a priority alert. The Volunteer\'s location may be updated while the application is running in the background when the required permission is available.';

  @override
  String get privacyUsageTitle =>
      'How Information Is Used During Search and Identification';

  @override
  String get privacyUsageBody =>
      'While a case is active, registered information, photographs, and case details may be used to assist authorized Volunteers in searching for the individual and reviewing potential matches.\n\nRadd uses AI-assisted face matching to help compare a photograph of a found individual against eligible registered profiles and may return potential matches for review. When face matching is insufficient, available case information and photographs may also be used for manual review.\n\nMatching results are an aid to identification and are not an automatic final identification. Human review and Guardian verification remain part of the reunification process.';

  @override
  String get privacyAccessTitle => 'Access to and Protection of Information';

  @override
  String get privacyAccessBody =>
      'Photographs and personal information are not available for unrestricted public browsing. Access to protected information is limited to authorized users according to their roles and only to the extent required to perform their functions within the search, identification, verification, and reunification process.\n\nAuthorization is enforced for requests that access or modify protected data rather than relying only on the visibility of interface controls.';

  @override
  String get privacyRetentionTitle =>
      'Retention and Deletion of Photographs and Case Data';

  @override
  String get privacyRetentionBody =>
      'Registered individual identifiable event information, including the reference photograph and facial embedding, follows the selected event registration period. If no shorter option is selected, the longest valid configured period applies, without exceeding the event end date. Replacing a photograph or extending the event does not extend an existing registration. Deletion is deferred while an associated missing-person case remains active and is performed after it becomes terminal.\n\nFound-person photographs are separate temporary identification images. They are deleted when the attempt ends without a confirmed match or immediately after match confirmation.\n\nCase records follow their applicable retention policy; only permitted non-identifying statistics remain afterward.';

  @override
  String get privacyStatisticsTitle =>
      'Data Retained for Statistics and Reporting';

  @override
  String get privacyStatisticsBody =>
      'After the case retention period ends and identifiable personal data is deleted, Radd retains only the minimum data required for statistical reporting.\n\nThis retained data includes the case identifier, final status, timestamps, age group, and the Volunteer reference required for per-Volunteer reunification statistics.\n\nThe retained data does not include names, photographs, contact information, facial data, or precise location.';

  @override
  String get privacyAgreementTitle => 'Your Agreement';

  @override
  String get privacyAgreementBody =>
      'By accepting this Privacy Notice, you confirm that you have read this notice and agree to the collection, use, access, retention, and deletion of information and photographs as described above.';

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
      'Use at least 8 characters, including an uppercase English letter, a lowercase English letter, a number, and a special character such as !, @, #, or \$.';

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
      'This individual cannot be edited or deleted while an active case exists. Resolve or cancel the case first.';

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
  String get other => 'Other';

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

  @override
  String get vApp => 'Radd Volunteer';

  @override
  String get vHome => 'Home';

  @override
  String get vCases => 'Cases';

  @override
  String get vReport => 'Report';

  @override
  String get vBadge => 'Badge';

  @override
  String get vProfile => 'Profile';

  @override
  String get vAccount => 'Volunteer Account';

  @override
  String get vActive => 'Active';

  @override
  String get vInactive => 'Inactive';

  @override
  String get vAvailable => 'Available Cases';

  @override
  String get vMyCases => 'My Cases';

  @override
  String get vPriorityCases => 'Priority Nearby Cases';

  @override
  String get vNearby => 'Within 500 m';

  @override
  String get vViewCase => 'View Case';

  @override
  String get vViewAll => 'View All';

  @override
  String get vQuickActions => 'Quick Actions';

  @override
  String get vReportFound => 'Report Found Individual';

  @override
  String get vDigitalId => 'Digital Volunteer ID';

  @override
  String get vVolunteerId => 'Volunteer ID';

  @override
  String get vStartSearch => 'Start Search';

  @override
  String get vReportReceived => 'Report Received';

  @override
  String get vSearchProgress => 'Search in Progress';

  @override
  String get vMatchConfirmed => 'Match Confirmed';

  @override
  String get vAwaitingGuardian => 'Awaiting Guardian Verification';

  @override
  String get vReunited => 'Reunited';

  @override
  String get vCaseDetails => 'Case Details';

  @override
  String get vMissingReport => 'Missing-person Report';

  @override
  String get vAge => 'Age';

  @override
  String get vGender => 'Gender';

  @override
  String get vMale => 'Male';

  @override
  String get vFemale => 'Female';

  @override
  String get vCaseId => 'Case ID';

  @override
  String get vStatus => 'Status';

  @override
  String get vReported => 'Reported';

  @override
  String get vUpdated => 'Updated';

  @override
  String get vPendingDetails => 'Additional details are being collected';

  @override
  String get vPendingHint =>
      'Additional information will appear when provided by the Guardian. You can start searching now.';

  @override
  String get vLastSeen => 'Last Seen';

  @override
  String get vCaseInformation => 'Case Information';

  @override
  String get vClothing => 'Clothing';

  @override
  String get vDistinctive => 'Distinctive Items / Features';

  @override
  String get vAdditional => 'Additional Information';

  @override
  String get vJoined => 'Added to My Cases';

  @override
  String get vNoCases => 'No cases here yet';

  @override
  String get vNoCasesHint => 'Cases will appear here when they are available.';

  @override
  String get vNotifications => 'Notifications';

  @override
  String get vAllAlerts => 'All Alerts';

  @override
  String get vPriorityOnly => 'Priority Cases';

  @override
  String get vRecentAlerts => 'Recent Alerts';

  @override
  String get vNewAlert => 'New Case Alert';

  @override
  String get vPriorityAlert => 'Priority Nearby Case';

  @override
  String get vStatusAlert => 'Case Status Update';

  @override
  String get vPriorityHint =>
      'Priority alerts depend on being within 500 meters of a reported last-seen location with available coordinates.';

  @override
  String get vNoAlerts => 'No notifications yet';

  @override
  String get vClose => 'Close';

  @override
  String get vCaptureNotice =>
      'Only capture a photo when assisting a found or separated individual.';

  @override
  String get vPositionFace => 'Position the face clearly';

  @override
  String get vPhotoHint => 'Make sure the face is visible and well lit.';

  @override
  String get vOpenCamera => 'Open Camera';

  @override
  String get vPhotoPurpose =>
      'The captured photo is used only to find possible matches.';

  @override
  String get vFinding => 'Finding a Match';

  @override
  String get vSearchingProfiles => 'Searching registered profiles…';

  @override
  String get vMatchingHint =>
      'Checking eligible registered profiles for possible matches.';

  @override
  String get vCancelSearch => 'Cancel Search';

  @override
  String get vPotentialMatches => 'Potential Matches';

  @override
  String get vPotentialMatch => 'Potential Match';

  @override
  String get vCandidateHint =>
      'These are possible matches, not confirmed identities. Review the individual’s information before selecting a match.';

  @override
  String get vSimilarity => 'Similarity';

  @override
  String get vViewDetails => 'View Details';

  @override
  String get vManualFallback => 'No useful match? Continue with manual review.';

  @override
  String get vManualReview => 'Manual Review';

  @override
  String get vSearchName => 'Search by name';

  @override
  String get vAll => 'All';

  @override
  String get vClearFilters => 'Clear Filters';

  @override
  String get vRegisteredIndividuals => 'Registered Individuals';

  @override
  String get vNoResults => 'No matching profiles';

  @override
  String get vMatchDetails => 'Match Details';

  @override
  String get vFoundIndividual => 'Found Individual';

  @override
  String get vRegisteredProfile => 'Registered Profile';

  @override
  String get vCompare => 'Compare Photographs';

  @override
  String get vMatchNotice =>
      'A potential match requires Volunteer review and Guardian verification. Identity is not confirmed automatically.';

  @override
  String get vConfirmMatch => 'Confirm Match';

  @override
  String get vConfirmMatchQuestion => 'Confirm Match?';

  @override
  String get vConfirmMatchHint =>
      'Select this individual as the match and proceed to Guardian Contact?';

  @override
  String get vCancel => 'Cancel';

  @override
  String get vBackResults => 'Back to Results';

  @override
  String get vGuardianContact => 'Guardian Contact';

  @override
  String get vMatchedIndividual => 'Matched Individual';

  @override
  String get vGuardianDetails => 'Guardian Details';

  @override
  String get vGuardianName => 'Guardian Name';

  @override
  String get vRelationship => 'Relationship';

  @override
  String get vMother => 'Mother';

  @override
  String get vFather => 'Father';

  @override
  String get vRegisteredContact => 'Registered Contact';

  @override
  String get vContactGuardian => 'Contact Guardian';

  @override
  String get vProceedVerification => 'Proceed to Verification';

  @override
  String get vVerifyGuardian => 'Verify Guardian';

  @override
  String get vScanInstruction =>
      'Scan the QR code displayed in the Guardian’s Radd case.';

  @override
  String get vScanHint =>
      'Keep the Guardian’s QR code steady within the frame.';

  @override
  String get vScanCode => 'Scan QR Code';

  @override
  String get vUnableScan => 'Unable to display the QR code?';

  @override
  String get vUseIdentifier => 'Use Case Identifier';

  @override
  String get vVerifyIdentifier => 'Verify Case Identifier';

  @override
  String get vIdentifierHelp =>
      'Ask the Guardian to display the case identifier from their authenticated Radd account when they cannot display the QR code.';

  @override
  String get vGuardianIdentifier => 'Guardian Case Identifier';

  @override
  String get vExactIdentifier =>
      'The identifiers must match. Compare it with the case shown on the Guardian’s own device.';

  @override
  String get vAuthenticatedAccount =>
      'The Guardian is showing this case in their authenticated Radd account.';

  @override
  String get vVerify => 'Verify Identifier';

  @override
  String get vVerificationFailed => 'Verification Failed';

  @override
  String get vVerificationMismatch =>
      'The code or identifier does not match the Guardian and case.';

  @override
  String get vNoHandover =>
      'Do not hand over the individual. Retry verification or use the case identifier.';

  @override
  String get vTryAgain => 'Try Again';

  @override
  String get vGuardianVerified => 'Guardian Verified';

  @override
  String get vVerificationSuccess => 'Verification Successful';

  @override
  String get vAccountCaseVerified =>
      'The Guardian’s account has been verified for this case.';

  @override
  String get vVerifiedTime => 'Verified Time';

  @override
  String get vVerificationMethod => 'Verification Method';

  @override
  String get vQrMethod => 'Case-specific QR code';

  @override
  String get vIdentifierMethod => 'Case identifier';

  @override
  String get vContinueHandover => 'Continue to Handover';

  @override
  String get vConfirmHandover => 'Confirm Handover';

  @override
  String get vHandoverHint =>
      'Confirm only after the individual has been handed over to the verified Guardian.';

  @override
  String get vHandoverQuestion => 'Confirm Reunification?';

  @override
  String get vHandoverConfirmHint =>
      'Confirm that the individual has been safely handed over to the verified Guardian.';

  @override
  String get vCompleted => 'Case Completed';

  @override
  String get vCompletedHint => 'The handover has been successfully confirmed.';

  @override
  String get vHandoverTime => 'Handover Time';

  @override
  String get vConfirmedBy => 'Confirmed By';

  @override
  String get vDone => 'Done';

  @override
  String get vAuthorized => 'Authorized Radd Volunteer';

  @override
  String get vVolunteerName => 'Volunteer Name';

  @override
  String get vAccountInformation => 'Account Information';

  @override
  String get vFullName => 'Full Name';

  @override
  String get vEmail => 'Email';

  @override
  String get vPhone => 'Phone Number';

  @override
  String get vLanguage => 'Language';

  @override
  String get vLogout => 'Log Out';

  @override
  String get vLogoutQuestion => 'End your volunteer session?';

  @override
  String get vPreview => 'Design preview · Sample data';

  @override
  String get vPreviewOpen => 'Preview Volunteer Designs';

  @override
  String get vPreviewCamera => 'Camera preview';

  @override
  String get vPreviewCameraHint =>
      'This preview uses the supplied sample photograph. No camera capture or AI request takes place.';

  @override
  String get vPreviewCapture => 'Simulate Capture';

  @override
  String get vPreviewQr => 'Preview QR verification';

  @override
  String get vPreviewQrHint =>
      'Choose a sample outcome. No QR code is scanned and no real Guardian is verified.';

  @override
  String get vPreviewValid => 'Matching Code';

  @override
  String get vPreviewInvalid => 'Non-matching Code';

  @override
  String get vPreviewCall =>
      'Sample contact only. No call is placed in design preview.';

  @override
  String get vUnavailable => 'This service is not connected yet.';

  @override
  String get vBackendHint =>
      'Case services will be available after the event server is connected.';

  @override
  String get vInactiveHint =>
      'This Volunteer account is inactive. Contact the event organizer.';

  @override
  String get vLocation => 'Nearby Case Alerts';

  @override
  String get vLocationHelp =>
      'Location permission and device location services are required to participate in the event. Radd uses your location to prioritize nearby case alerts. If a location estimate is temporarily unavailable, you can continue participating.';

  @override
  String get vAllowLocation => 'Allow Location';

  @override
  String get vLocationUnavailable =>
      'Location is unavailable. You can still use Radd and receive general alerts.';

  @override
  String get vLocationReady => 'Location is available while using Radd.';

  @override
  String get vLogin => 'Log In';

  @override
  String get vWelcome => 'Welcome Back';

  @override
  String get vLoginHint => 'Log in to your Volunteer account';

  @override
  String get vPassword => 'Password';

  @override
  String get vForgot => 'Forgot Password?';

  @override
  String get vReset => 'Reset Password';

  @override
  String get vResetHint =>
      'Enter your email to receive password reset instructions.';

  @override
  String get vSendReset => 'Send Instructions';

  @override
  String get vResetSent =>
      'If this email is registered, reset instructions have been sent.';

  @override
  String get vAccountManaged =>
      'Volunteer accounts are provided by the event organizer.';

  @override
  String get vRequired => 'This field is required.';

  @override
  String get vInvalidEmail => 'Enter a valid email address.';

  @override
  String get vInvalidLogin => 'Invalid email or password.';

  @override
  String get vNetworkError => 'Check your Internet connection and try again.';

  @override
  String get vAccessDenied =>
      'An authorized Volunteer account is required. Contact the event organizer.';

  @override
  String get vActionFailed =>
      'This action could not be completed. Please try again.';

  @override
  String get vNoMissingReport => 'No missing-person report';

  @override
  String get vSearchJoinedHint => 'You have started searching for this case.';

  @override
  String get vAdditionalReceived => 'Additional information received';

  @override
  String vAgeValue(String value) {
    return 'Age $value';
  }

  @override
  String vCount(String count) {
    return '$count cases';
  }

  @override
  String vSimilarityValue(String value) {
    return '$value% Similarity';
  }

  @override
  String get reportMissing => 'Report Missing';

  @override
  String get reportConfirm => 'Report this individual as missing?';

  @override
  String get confirm => 'Confirm';

  @override
  String get reportReceived => 'Report Received';

  @override
  String get searchInProgress => 'Search in Progress';

  @override
  String get matchConfirmed => 'Match Confirmed';

  @override
  String get awaitingVerification => 'Awaiting Guardian Verification';

  @override
  String get reunited => 'Reunited';

  @override
  String get unknownCaseStatus => 'Status unavailable';

  @override
  String get caseStatus => 'Case Status';

  @override
  String get viewStatus => 'View Status';

  @override
  String get trackStatus => 'Track Status';

  @override
  String get activeCases => 'Active Cases';

  @override
  String get noCases => 'No cases yet';

  @override
  String get noCasesHint => 'Your missing-person reports will appear here.';

  @override
  String get reportingAssistant => 'Reporting Assistant';

  @override
  String get sameLocationQuestion =>
      'Is your current location the same as where the missing individual was last seen?';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get lastSeenDescription => 'Where was the individual last seen?';

  @override
  String get clothingQuestion =>
      'What clothing was the individual wearing when last seen?';

  @override
  String get distinctiveQuestion =>
      'Was the individual carrying anything distinctive, such as a bag or toy?';

  @override
  String get distinctiveDescription => 'Describe the distinctive item';

  @override
  String get additionalQuestion =>
      'Is there any additional information that could help Volunteers find the individual?';

  @override
  String get saveReport => 'Save report details';

  @override
  String get reportSaved => 'Report details saved';

  @override
  String get locationRequired =>
      'Allow location access to use your current position, or select No and describe the last-seen location.';

  @override
  String get locationReady => 'Current location captured for this report';

  @override
  String get useCurrentLocation => 'Use current location';

  @override
  String get noNotifications => 'No notifications yet';

  @override
  String get notificationHint => 'Updates about your cases will appear here.';

  @override
  String get guardianVerification => 'Guardian Verification QR';

  @override
  String get verificationExplanation =>
      'Show this code to an authorized Volunteer to verify your connection to this case. It does not identify the missing individual.';

  @override
  String get noEligibleCases => 'No cases are awaiting Guardian verification.';

  @override
  String get verificationExpired =>
      'This code has expired. Generate a new code to continue.';

  @override
  String get refreshCode => 'Generate new code';

  @override
  String get showCaseIdentifier => 'Show Case Identifier';

  @override
  String get caseIdentifier => 'Case Identifier';

  @override
  String get caseIdentifierHint =>
      'Share this reference with an authorized team member. The reference alone does not verify your identity.';

  @override
  String get eventUnavailable =>
      'Reporting is temporarily unavailable because the current event has not been activated. Please try again later.';

  @override
  String get guidedDetails => 'Report details';

  @override
  String get lastUpdated => 'Last updated';

  @override
  String get requiredAnswer => 'Please complete this answer.';

  @override
  String get activeCase => 'Active Case';

  @override
  String get verificationExpires => 'Valid until';

  @override
  String get close => 'Close';

  @override
  String get vLoadFailed => 'Couldn’t load right now. Tap to try again.';

  @override
  String get vContinueReport => 'Continue report';

  @override
  String get vAiUnavailable =>
      'AI matching is unavailable. Your report is saved; continue with manual review.';

  @override
  String get vQrRequired =>
      'Ask the Guardian to display this case’s QR code in their signed-in Radd account. A case identifier alone cannot verify identity.';

  @override
  String get child => 'Child';

  @override
  String get specifyRelationship => 'Specify relationship';

  @override
  String get casesAwaitingVerification => 'Cases awaiting verification';

  @override
  String get resolved => 'Resolved';

  @override
  String get cancelled => 'Cancelled';

  @override
  String get transferredToAuthority => 'Transferred to Authority';

  @override
  String get casesSubtitle => 'Track your missing-person cases';

  @override
  String get resolveReport => 'Resolve Report';

  @override
  String get resolveReportConfirm =>
      'Resolve this report? Only do this if you found the individual independently, outside of Radd.';

  @override
  String get cancelReport => 'Cancel Report';

  @override
  String get cancelReportConfirm =>
      'Cancel this report? Use this only if it was created by mistake.';

  @override
  String get reunitedOutcome =>
      'This individual has been reunited with their Guardian.';

  @override
  String get caseClosedNotice =>
      'This report is closed and is no longer part of active search and matching.';

  @override
  String get caseDetails => 'Case Details';

  @override
  String get activeCaseLockNotice =>
      'Editing and deletion are unavailable while an active case exists for this individual.';

  @override
  String get guidedAssistantRequired =>
      'Please finish the required questions before leaving this screen.';

  @override
  String get caseClosedActionError =>
      'This report is closed and can no longer be changed.';

  @override
  String get reportAlreadySubmitted =>
      'This report has already been submitted and can no longer be edited.';

  @override
  String get photoExpiredError =>
      'This registration is expired or its retention period is unavailable. Create a new registration with a valid event period.';

  @override
  String get photoExpiredNotice =>
      'This registration is not eligible for a new missing-person report. A new photograph alone does not renew its registration period.';

  @override
  String get updatePhotoRequired => 'Update Photo';

  @override
  String get caseId => 'Case ID';

  @override
  String get updatedLabel => 'Updated';

  @override
  String ageYears(String value) {
    return '$value yrs';
  }

  @override
  String get caseHistory => 'Case History';

  @override
  String get noActiveCasesHint => 'No active cases right now.';

  @override
  String get progressTimeline => 'Progress Timeline';

  @override
  String stageLabel(String number) {
    return 'Stage $number';
  }

  @override
  String stageStatus(String number, String status) {
    return 'Stage $number: $status';
  }

  @override
  String get activeLabel => 'Active';

  @override
  String get completedLabel => 'Completed';

  @override
  String get statusUpdatesAutomatically => 'Status updates automatically';

  @override
  String get reportReceivedDescription =>
      'Your report has been received and active Volunteers have been notified.';

  @override
  String get searchInProgressDescription =>
      'Volunteers are actively searching for the individual.';

  @override
  String get matchConfirmedDescription =>
      'A Volunteer has confirmed a match and will proceed to Guardian verification.';

  @override
  String get awaitingVerificationDescription =>
      'Show your Guardian Verification QR to the Volunteer to confirm your identity.';

  @override
  String get reunitedDescription =>
      'The individual has been safely reunited with you.';

  @override
  String get outcomeLabel => 'Outcome';

  @override
  String get lastSeenLocationLabel => 'Last-seen location';

  @override
  String get currentLocationConfirmed => 'Current location confirmed';

  @override
  String get clothingLabel => 'Clothing';

  @override
  String get distinctiveLabel => 'Distinctive item';

  @override
  String get additionalLabel => 'Additional information';

  @override
  String get none => 'None';

  @override
  String get detailsPending => 'Report details have not been completed yet.';

  @override
  String get reportedByGuardian => 'Reported by Guardian';

  @override
  String get todayJustNow => 'Today • Just now';

  @override
  String assistantIntro(String name) {
    return 'Your missing-person report for $name has been submitted. I\'ll ask a few quick questions to help Volunteers with the search.';
  }

  @override
  String get locationHint => 'Used to coordinate nearby Volunteers.';

  @override
  String get answersAutoSave => 'Answers save automatically to active case';

  @override
  String get typeAnswer => 'Type your answer…';

  @override
  String get send => 'Send';

  @override
  String get qrSubtitle =>
      'Show this code to the Volunteer for Guardian verification';

  @override
  String get qrVerifiesAccount =>
      'This QR code verifies that your authenticated Guardian account is associated with this case.';

  @override
  String get qrVerifiesAccountNoCase =>
      'This QR code verifies your authenticated Guardian account. It does not identify any missing individual.';

  @override
  String get selectActiveCase => 'Select Active Case';

  @override
  String get scanInstruction =>
      'Ask the Volunteer to scan this QR code using Radd.';

  @override
  String get cannotDisplayQr => 'Can\'t display the QR code?';

  @override
  String get caseIdentifierInstruction =>
      'Show this identifier to the Volunteer for alternative verification.';

  @override
  String get caseIdentifierUsage =>
      'Used to locate and verify the active case when the QR code cannot be displayed or scanned.';

  @override
  String get activeCaseIdentifier => 'Active case identifier';

  @override
  String get noActiveCaseQrNote =>
      'You have no active cases right now. Your Guardian QR remains valid for verification.';

  @override
  String get qrRefreshing => 'Generating a new code…';

  @override
  String get resetSentTitle => 'Check your email';

  @override
  String get backToLogin => 'Back to Log In';

  @override
  String get resendReset => 'Send again';

  @override
  String get vAccountDeactivated =>
      'Your Volunteer account is inactive. You have been signed out.';

  @override
  String get vEndIdentification => 'End Identification Attempt';

  @override
  String get vEndIdentificationHint =>
      'End this identification attempt and delete the captured photo? The missing-person case and search will continue.';

  @override
  String get locationNotRecorded =>
      'Location could not be recorded. You can continue; the general alert remains active.';

  @override
  String get vCancelledAlert => 'Case Cancelled';

  @override
  String get vResolvedAlert => 'Person Found';

  @override
  String get vNewAlertMessage => 'A new missing-person case has been reported.';

  @override
  String get vPriorityAlertMessage =>
      'A missing-person case has been reported within 500 meters of your available location.';

  @override
  String get vMatchAlertMessage =>
      'A match was confirmed for a case you joined. Guardian verification and handover are still required.';

  @override
  String get vCancelledAlertMessage =>
      'The guardian cancelled this missing-person case.';

  @override
  String get vResolvedAlertMessage =>
      'The guardian found the individual and resolved this case.';

  @override
  String get vReunitedAlertMessage =>
      'The individual has been reunited with their guardian after verification.';

  @override
  String get vLocationSettings => 'Open Settings';

  @override
  String get vLocationDeniedForever =>
      'Enable location permission in Settings to continue participating in the event.';

  @override
  String get vLocationServicesDisabled =>
      'Turn on device location services to continue participating in the event.';

  @override
  String get vLocationServiceTitle => 'Radd event participation';

  @override
  String get vLocationServiceBody =>
      'Radd uses location for nearby case alerts during your authorized event participation, including while the app is in the background.';

  @override
  String get vLocationServiceChannel => 'Event location';

  @override
  String get vEventAuthorized => 'Authorized for Current Event';

  @override
  String get vEventUnassigned => 'Not Assigned to Current Event';

  @override
  String get vAccountStatus => 'Account status';

  @override
  String get vNotificationCaseUnavailable =>
      'This case is no longer available for an active search. Notifications and cases have been refreshed.';

  @override
  String get vJoinSearch => 'Join Search';

  @override
  String get vFindWithAi => 'Find Match with AI';

  @override
  String get vStandalonePending =>
      'No missing-person report is associated with this individual. Your found report is saved. Match confirmation, Guardian verification and handover for standalone found reports are not available yet.';

  @override
  String get vLocationRequired => 'Location is required to participate';

  @override
  String get vAiReady =>
      'Your found report is saved. Start AI-assisted identification, or use Manual Review when needed.';

  @override
  String get vAiError =>
      'Identification could not be completed. Please try again or continue with Manual Review.';

  @override
  String get vNoEligibleRegistrations =>
      'No registered individuals are currently eligible for review in this event.';

  @override
  String get registrationPeriodTitle => 'Registration period';

  @override
  String get registrationPeriodHint =>
      'The period starts when registration succeeds and cannot exceed the event end. Replacing the photograph does not extend it.';

  @override
  String get registrationPeriodDefault => 'Longest available period (default)';

  @override
  String registrationPeriodHours(int hours) {
    return '$hours hours';
  }

  @override
  String get registrationPeriodUnavailable =>
      'Registration periods are not available for this event. Please try again later.';

  @override
  String get vFoundReportTitle => 'Found Individual Report';

  @override
  String get vIdentityConfirmed => 'Identity Confirmed';

  @override
  String get vIdentificationInProgress => 'Identification in Progress';

  @override
  String get vFoundIdentifierHelp =>
      'Show the Found Report identifier from the Guardian’s signed-in Radd account. Compare the complete identifier before confirming verification.';

  @override
  String get vFoundReportIdentifier => 'Found Report Identifier';

  @override
  String get vConfirmIdentity => 'Confirm Identity';

  @override
  String get vTermsDocument =>
      '### Purpose and scope\nRadd supports event-based reporting, searching, identification, Guardian verification\nand reunification. It provides coordination tools; a possible identification result\nis not proof of identity or authorization to hand over a person. These draft terms\ncover the Guardian and Volunteer functions described below. The Admin interface and\nactual AI face-matching engine are not currently implemented.\n\n### Accounts and authorized roles\nGuardians use their authenticated accounts to manage individuals under their care\nand genuine missing-person reports. Volunteers use accounts provisioned through the\nproject\'s authorized account-management process; they do not self-register. Keep\naccount access private and use only the data and actions authorized for your role.\nDo not use another person\'s session, credentials or verification code to obtain\nunauthorized access.\n\nAn enabled Volunteer account is separate from assignment to an event. Volunteer\nevent participation requires authentication, an enabled account, assignment to the\ncurrent Active Event, required device location permission and enabled Location\nServices. Deactivation, removal of assignment or loss of the required device access\ncan stop participation. The Digital Volunteer ID reflects the account and assignment\nchecks; it does not replace Guardian verification.\n\n### Location as a participation condition\nLocation access is required during Volunteer Active Event participation for event\ncoordination and proximity-based prioritization. Where supported by the Android\nimplementation, location may continue updating while Radd is in the background,\nusing the required foreground location service and ongoing notification. Event-related\nlocation collection must stop when participation is no longer authorized, including\nlogout, deactivation, unassignment, loss of Active Event access, permission revocation\nor disabled Location Services.\n\nAndroid controls permission choices. Acceptance of these terms does not grant Android\npermission. If permission is denied/revoked or Location Services are off, event actions\nremain blocked until the conditions are restored. If permission and services are valid\nbut a location estimate is temporarily unavailable, participation and standard alerts\nremain available; proximity prioritization resumes when a suitable estimate returns.\n\nGuardian location follows a different rule. In the guided missing report, current\ncoordinates are used as the last-seen location only when the Guardian confirms that\nthey are at that location and permits access. This is not the Volunteer participation\nlocation-update rule.\n\n### Registration and reports\nGuardians should provide information they are authorized to provide about individuals\nunder their care and accurate details to support identification. Registration uses the\nsingle Active Event and its currently valid configured periods. The selected period,\nor the longest currently valid option if none is selected, determines the stored\nregistration expiry. Replacing a photograph or extending the event does not renew an\nexisting registration automatically.\n\nGuardian Missing Cases and Volunteer Found Individual Reports are distinct. Starting\nor joining a search participates in the same Missing Case; it does not create a new\ncase. A standalone Found Report can exist without a Guardian missing report and does\nnot count as a Guardian Missing Case. An actual later Guardian report may link to the\nexisting identification workflow without duplicating verification or handover.\n\n### Identification and handling information\nThe camera/AI path is the primary planned identification method. It requires an in-app\ncaptured photograph. AI is presently unavailable: Radd must not present invented\nmatches or scores. When integrated later, AI results will be possible matches requiring\nhuman review and explicit confirmation, not automatic identity confirmation.\n\nManual Review is an operational fallback and can be opened without camera capture or\nan AI failure. It searches eligible registrations for the Active Event. Browsing or\nselecting a profile does not confirm identity and does not authorize access to Guardian\ncontact details. Explicit manual confirmation can create a standalone Found Report\nwithout a photograph. Do not capture substitute or fabricated images for this purpose.\n\nUse personal information and authorized Guardian contact details only for the approved\nsearch, identification and reunification work. Do not share them outside that purpose\nor try to access another Volunteer\'s privately owned Found Report.\n\n### Verification and handover\nAfter identity confirmation, the authorized Volunteer may coordinate with the associated\nGuardian. The legitimate Guardian/context must be verified using the account QR or\napproved identifier fallback. The fallback requires viewing the relevant identifier\ninside the Guardian\'s authenticated Radd account on their own device. A failed check\nblocks handover. A successful check alone does not mark Reunited: the Volunteer must\nexplicitly confirm handover after reunification. Do not bypass these steps.\n\n### Notifications, availability and limitations\nStandard Missing Case alerts and nearby priority alerts support coordination; priority\nuses the configured prototype radius, currently 500 metres, and a suitable reported\nlast-seen location and Volunteer estimate. A priority alert does not create a separate\ncase. Notification delivery depends on an eligible authenticated session, Android\npermissions/settings, network connectivity and service availability. History may remain\nvisible without being replayed as a new alert. Radd does not guarantee instant delivery,\ncontinuous connectivity or an accurate location estimate at every moment.\n\n### Agreement and changes\nThese documents require review before they become an enforced consent requirement.\nThe planned Volunteer gate will request explicit acceptance of specified Terms and\nPrivacy versions; login alone will not constitute acceptance. A later required version\nmay require renewed acceptance. Acceptance will not bypass account, assignment,\nlocation, identification or Guardian verification requirements.';

  @override
  String get vPrivacyDocument =>
      '### Scope and people concerned\nThis draft describes data used by Radd\'s current Guardian and Volunteer workflows,\nincluding information about children, older adults and other people registered under\nGuardian care. It also identifies the future AI boundary rather than claiming an\noperational face-matching service. The project owner must provide the responsible\noperator\'s identity and a privacy contact before final approval.\n\n### Account and event data\nRadd processes account identifiers, names, email addresses, phone numbers and roles\nas needed for authentication and authorized coordination. Volunteer records additionally\ninclude the Volunteer ID, enabled status and event assignment. Authentication uses\nFirebase Authentication; the shared FastAPI service enforces role and event access\nagainst the shared Firebase data. Account provision/management is separate from a\nfuture consent record. The planned consent record contains accepted document versions\nand server acceptance times, not an assertion that Android permission was granted.\n\n### Registered individuals and photographs\nA Guardian supplies a registered individual\'s name, age, gender, relationship and\nreference photograph, with applicable descriptive information. Records belong to an\nevent and an established registration period. Photographs are identifiable information.\nAny future facial embedding derived from them must follow the same registration expiry\nand deletion controls. No actual AI matching engine is operating in the current build.\n\nThe server records registration start, expiry, period ID and duration. Only currently\nvalid event options may be selected; the longest valid option applies by default.\nNeither photo replacement nor event extension changes a previously established expiry.\nLegacy records with unknown retention periods are not silently made eligible.\n\n### Missing Cases, Found Reports and identification\nMissing Cases contain the information needed to search, status updates and participation\nrecords. Guided details may include clothing, distinguishing descriptions and last-seen\ninformation. A Found Report is a separate record of a Volunteer\'s identification work;\nit may exist before a Guardian submits a missing report.\n\nCamera-based Found photographs are temporary identification images. They are deleted\nwhen the attempt ends without a confirmed match or immediately after confirmed identity.\nInterrupted Storage deletion uses the existing retry mechanism; deleted Found photos\nare not required for subsequent verification/handover and do not become profile photos.\nManual-only confirmation may create a Found Report without any captured photograph.\n\nManual Review exposes eligible registered profile information for the current Active\nEvent. Selecting a profile is not confirmation. Guardian contact is available only after\nexplicit confirmation in an authorized identification/reunification context. Any future\nAI scores will be possible-match suggestions, subject to human confirmation.\n\n### Location\nVolunteer location permission and enabled services are mandatory for Active Event\nparticipation. Coordinates may update during valid participation, including in the\nbackground through the implemented Android location service. The purpose is event\ncoordination and proximity prioritization. Event-related location access stops when\nparticipation conditions cease. The device estimate may be unavailable or insufficiently\naccurate; this removes proximity eligibility temporarily without equating it to denied\npermission. Radd does not need a continuous historical movement trail for this purpose;\nthe implementation uses the latest available estimate and its freshness.\n\nGuardian device coordinates are used as a reported last-seen location only after the\nGuardian confirms that the device is at that location and grants permission through\nthe guided reporting flow. A textual last-seen description can be supplied instead.\nGuardian location is not subject to the continuous Volunteer participation rule.\n\n### Verification and completed outcomes\nQR/identifier checks bind verification to the legitimate Guardian and workflow. QR\nchallenges are short-lived and single-use. Verification receipts record the relevant\ncontext, participants, method and time. A successful check enables explicit handover;\nit does not complete reunification automatically.\n\nOn standalone Found Report Reunited, identifying report details are removed and the\nminimal record retains only the internal report identifier, origin, event, outcome,\nnecessary creation/update/completion timestamps, confirming Volunteer reference and\nverification method. It does not retain Guardian contact, person identity/snapshot,\nFound photograph or QR secret. A Volunteer reference is retained for approved\nper-Volunteer statistics; it must not be represented as fully anonymous data.\n\n### Retention and deletion holds\nRegistered identifiable event information, its photograph and any future embedding\nfollow the registration\'s stored expiry. If an approved active Missing Case or an\nidentified active Found Report still requires that information, deletion alone is\ndeferred. Expiry is not extended and the record is not generally eligible again for\nunrelated identification or new reporting. When no approved active hold remains, due\ncleanup can delete the expired identifiable registration. A still-valid registration\nis not deleted merely because one Found Report completes. Account records are not\ndeleted by these workflow cleanup operations.\n\nTerminal Missing Cases use their separate existing retention/minimization rules.\nThe current local cleanup worker checks periodically when enabled; access restrictions\nand deletion scheduling are separate, and a failed storage operation is retried rather\nthan falsely reported as deleted. No production scheduler has been selected. This draft\ndoes not invent a new retention duration for ended, unmatched report metadata, consent\nhistory or device presentation memory; those lifecycle details remain review items.\n\n### Notifications and service access\nRadd stores notification history and applicable read state with stable event IDs.\nFCM device registrations associate a token with the authenticated session, event,\nlanguage and available proximity estimate. Tokens are not passwords. Standard and\npriority Missing Case notifications may be displayed by Android in the background or\nby Radd in the foreground, subject to permissions and session eligibility. History\nfetches and device registration are not requests to replay old notifications. Local\npresentation memory stores handled event IDs, scoped to the user/event, to suppress\nrepeated foreground banners. Notification payloads avoid person/contact details;\nopening a case performs authenticated authorization checks.\n\n### Protection, providers and limits\nThe shared backend uses Firebase Authentication, Firestore, Storage and Cloud Messaging\nfor the implemented functions. Access is restricted by role, event and workflow rather\nthan by hiding buttons alone. Development diagnostics should exclude credentials and\npersonal payloads. Network/service failures and implementation limitations may occur;\nthis notice does not promise absolute security, guaranteed delivery or perfect matching.\nProduction hosting, operator contact, requests for access/correction/deletion, and any\nadditional required legal disclosures must be finalized before publication. No automatic\nrights-request service or production deployment is claimed by this draft.';

  @override
  String get vConsentTitle => 'Welcome to Radd';

  @override
  String get vConsentIntro =>
      'Before using Radd as a Volunteer, please review the following conditions and Radd’s Terms of Use and Privacy Policy.';

  @override
  String get vConsentConditions =>
      'By participating as a Volunteer, you acknowledge that:\n\n• Location access is required during active event participation.\n\n• Radd may update your location while you are actively participating, including while the app is running in the background, to support event coordination and proximity-based Volunteer prioritization.\n\n• If location permission is denied or revoked, or Location Services are disabled, you cannot access the event workflow until location access is restored.\n\n• You may access personal and Guardian information only when authorized and only for identification and reunification purposes.\n\n• Potential AI or Manual Review matches do not confirm identity automatically. Identity must be explicitly confirmed, and Guardian verification is required before handover.\n\n• You must use only your authorized Volunteer account and must not share protected information outside the approved Radd workflow.';

  @override
  String get vTermsTitle => 'Terms of Use';

  @override
  String get vPrivacyTitle => 'Privacy Policy';

  @override
  String get vConsentCheckbox =>
      'I have read and agree to Radd’s Terms of Use and Privacy Policy.';

  @override
  String get vConsentContinue => 'Accept & Continue';

  @override
  String get vConsentNotNow => 'Not Now';

  @override
  String get vDevelopmentPolicy =>
      'Development / academic project documents — not legally reviewed production policies.';

  @override
  String get vConsentUnavailable =>
      'The required document version is not available in this app. Please update Radd and try again.';
}
