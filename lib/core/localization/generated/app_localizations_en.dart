// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String vBadgeEventName(String name) {
    return 'Event: $name';
  }

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
  String get phoneHelp =>
      'Saudi phone number, e.g. 0501234567 or +966501234567';

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
      'When you create a Guardian account and use Radd, the system processes information required to create and use your account, as well as information you provide about individuals registered under your care, including their identifying information and photographs.\n\nWhen a missing-person report is submitted, Radd may also process case-related information, such as details about the missing individual, descriptive information provided to support the search, and last-seen information. If you choose to use your device location as the last-seen location and grant location permission, location coordinates may be used for this purpose.\n\nThis information is used to support registration, reporting, searching, identification, verification, and reunification during the event.\n\nYour account information (name, email address, and phone number) is kept for as long as your Guardian account exists. It is not deleted by the retention rules that apply to registered individuals\' data.';

  @override
  String get privacyRegisteredPhotosTitle =>
      'Registered Individuals\' Photographs';

  @override
  String get privacyRegisteredPhotosBody =>
      'The reference photograph taken when you register an individual, and any facial data derived from it, are part of that individual\'s registered data. They are kept for the retention period you choose at registration and are deleted together with the rest of that data when the period ends. Taking a new photograph later replaces the previous one but does not change the retention period.\n\nPhotographs are used only to help identify the individual during the event. AI suggestions never replace human review and Guardian verification.';

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
      'When you register an individual, you choose how long their data (identifying details, photograph, and facial data) is kept, from the options configured for the current event. If you do not choose, the longest available option applies. The retention period cannot go beyond the end of the event. You can change it later from the individual\'s profile, as long as the new deadline is still ahead and within the event.\n\nWhen the period ends, the data is deleted automatically. If a missing-person report is still active at that time, deletion waits until the report is closed.\n\nPhotographs taken by Volunteers of a found individual are temporary and are deleted as soon as the identification attempt ends.\n\nCase records are deleted after the case\'s retention period; only the limited statistical information described below remains.';

  @override
  String get privacyStatisticsTitle =>
      'Data Retained for Statistics and Reporting';

  @override
  String get privacyStatisticsBody =>
      'After a case\'s retention period ends and its identifying data is deleted, Radd keeps only the minimum information needed for statistical reporting: the case reference, its final outcome, when it was created and closed, the individual\'s age group, and the event. This information is aggregated or anonymized where applicable. For cases that ended in a reunion, the reference to the Volunteer who completed the handover may be kept so that reunification statistics per Volunteer can be reported.\n\nNo names, photographs, contact details, facial data, or precise locations are kept.';

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
      'Enter a valid Saudi phone number, e.g. 0501234567 or +966501234567.';

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
  String get photoRequired => 'Photo required.';

  @override
  String get photoTooLarge => 'The photo is too large. Please retake it.';

  @override
  String get age => 'Age';

  @override
  String get invalidAge => 'Enter a valid age.';

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
  String get accountDeactivated =>
      'This account has been deactivated by the event administration. Contact the event organizers for assistance.';

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
  String get vUseIdentifier => 'Use Verification Code';

  @override
  String get vVerifyIdentifier => 'Verify Code';

  @override
  String get vIdentifierHelp =>
      'Ask the Guardian to read the 6-digit verification code from their signed-in Radd account when they cannot display the QR code.';

  @override
  String get vGuardianIdentifier => 'Guardian Verification Code';

  @override
  String get vExactIdentifier =>
      'Ask the Guardian to read the 6-digit verification code shown for this case in their signed-in Radd account, and enter it exactly.';

  @override
  String get vAuthenticatedAccount =>
      'The Guardian is showing this case in their authenticated Radd account.';

  @override
  String get vVerify => 'Verify Code';

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
  String get vIdentifierMethod => 'Verification code';

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
  String get vFailureAlreadyMatched =>
      'This individual is already being reunited through another active report. Only that report can continue.';

  @override
  String get vFailureResumeExisting =>
      'You already have an active report for this individual. Continue it from Report instead of confirming the identity again.';

  @override
  String get vFailureProfileUnavailable =>
      'This registration is no longer eligible for identification.';

  @override
  String get vFailureIdentificationEnded =>
      'This identification attempt has already ended or been confirmed. The report has been refreshed.';

  @override
  String get vFailureMatchRequired =>
      'Confirm the individual\'s identity before continuing to Guardian verification.';

  @override
  String get vFailureStageUnavailable =>
      'This step is not available at the report\'s current stage. The report has been refreshed.';

  @override
  String get vFailureReportUnavailable =>
      'This report\'s details could not be loaded. Please try again.';

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
  String get showCaseIdentifier => 'Show Verification Code';

  @override
  String get caseIdentifier => 'Verification Code';

  @override
  String get caseIdentifierHint =>
      'Read this code to an authorized Volunteer when the QR code cannot be scanned. The code alone does not verify your identity.';

  @override
  String get caseUpdateBanner => 'Case Update';

  @override
  String get viewCase => 'View Case';

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
  String get referredToAuthority => 'Referred to Authority';

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
      'Read this 6-digit code to the Volunteer for alternative verification.';

  @override
  String get caseIdentifierUsage =>
      'Used to verify this active case when the QR code cannot be displayed or scanned. It belongs to this case only.';

  @override
  String get activeCaseIdentifier => 'Active case verification code';

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
  String get registrationPeriodTitle => 'Data retention period';

  @override
  String get registrationPeriodHint =>
      'Choose how long this individual\'s data should be kept. It will be deleted automatically when the selected period ends, in accordance with the Privacy Notice.';

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
  String get registrationPeriodBoundary =>
      'The period starts at registration and cannot go beyond the end of the event. If a missing-person report is still active when it ends, deletion waits until the report is closed.';

  @override
  String get retentionEditBoundary =>
      'Counted from the original registration date. You can extend it or shorten it, as long as the new deadline is still ahead and within the event.';

  @override
  String registrationPeriodDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String retentionUntil(String date) {
    return 'Data kept until $date';
  }

  @override
  String get retentionPassedError =>
      'That period would already have ended. Choose a longer period.';

  @override
  String get retentionInvalidError =>
      'The selected retention period is not available for this event.';

  @override
  String retentionOptionUnavailable(String label, String reason) {
    return '$label ($reason)';
  }

  @override
  String get retentionOptionPassed => 'already passed';

  @override
  String get retentionOptionBeyondEvent => 'after the event ends';

  @override
  String get currentEvent => 'Current event';

  @override
  String eventDates(String start, String end) {
    return '$start – $end';
  }

  @override
  String registeringForEvent(String event) {
    return 'Registering for the active event: $event';
  }

  @override
  String get vFoundReportTitle => 'Found Individual Report';

  @override
  String get vIdentityConfirmed => 'Identity Confirmed';

  @override
  String get vIdentificationInProgress => 'Identification in Progress';

  @override
  String get vFoundIdentifierHelp =>
      'Ask the Guardian to read the 6-digit verification code shown under Found Individual Report in their signed-in Radd account, and enter it exactly.';

  @override
  String get vFoundReportIdentifier => 'Guardian Verification Code';

  @override
  String get vVerificationCodeFormat => 'Enter the 6-digit verification code.';

  @override
  String get foundReportCode => 'Verification code';

  @override
  String get foundReportCodeHint =>
      'One of your registered individuals has been identified by a Volunteer. If the QR code cannot be scanned, read this code to the Volunteer. It belongs only to this active report.';

  @override
  String get foundReportCodeUnavailable =>
      'The verification code is not available yet. Refresh this screen or use the QR code.';

  @override
  String foundReportIndividual(String name) {
    return 'Found individual: $name';
  }

  @override
  String get vConfirmIdentity => 'Confirm Identity';

  @override
  String get vPrivacyDocument =>
      '### Account and participation information\nRadd processes your name, email address, phone number, account identifier, Volunteer ID, account status and event assignment to authenticate you and support authorized event work. Your account is provisioned by authorized administration. Volunteer selection, training and organizational agreements are handled outside Radd.\n\n### Required location access\nLocation access and enabled Location Services are required during Active Event participation. Radd uses your location for event coordination and proximity-based Volunteer prioritization. Location may continue updating while the app is in the background during authorized participation.\n\nEvent-related location access stops when you log out or participation is no longer authorized, including account deactivation, removal from the event, loss of Active Event access, permission revocation or disabled Location Services. Radd uses the latest available location estimate and its freshness for proximity prioritization, rather than a continuous movement history.\n\nThe location notice does not grant device permission. Android permission is requested separately. If permission is denied or revoked, or Location Services are disabled, event functions remain blocked until access is restored. If permission and services remain valid but a location estimate is temporarily unavailable, participation and standard alerts remain available; proximity prioritization resumes when a suitable estimate returns.\n\n### Registered individuals and Guardian information\nAuthorized Volunteers may view eligible registered individuals for the Active Event, including names, ages, gender, reference photographs and relevant identification details. Use this information only for authorized identification and reunification work. Browsing Manual Review or selecting a profile does not confirm identity or reveal Guardian contact details. Guardian contact becomes available only within an authorized, confirmed identification and reunification workflow.\n\n### Found Individual Reports\nA Found Individual Report records identification work and may exist without a Guardian Missing Case. Camera photographs used for identification are temporary: they are deleted when the identification attempt ends without a confirmed match or immediately after identity is confirmed. They do not become registered profile photographs. Manual identification may create a report without a photograph. Selecting a profile alone does not confirm identity.\n\n### Verification and handover\nGuardian verification is required before handover. Verification records identify the relevant workflow, participants, verification method and time. Successful verification enables handover but does not complete reunification automatically; handover must be confirmed separately.\n\n### Retention and deletion\nRegistered identifiable information and reference photographs follow the individual\'s established registration period. Replacing a photograph or extending the event does not extend an existing registration. If an approved active Missing Case or an identified Found Report still needs the information to complete verification or handover, deletion is deferred until that need ends. The registration expiry does not change, and expired information does not become generally available for new identification or reporting.\n\nAfter a standalone Found Report reaches Reunited, unnecessary identifying details are removed. A minimal outcome record remains for operational audit and statistics, including the event, necessary timestamps, verification method and the responsible Volunteer reference. Guardian contact details, individual identity details and the temporary Found photograph are not retained in that completed record. A registration that is still valid continues until its own expiry; registration cleanup does not delete Guardian or Volunteer accounts. Missing Cases follow their separate retention and minimization rules. Interrupted deletion is retried.\n\n### Notifications\nRadd uses device notification information, your authenticated session, event assignment, language and available location estimate to provide relevant case and proximity alerts. Notification history may remain available without replaying old alerts. Notification messages avoid individual and Guardian contact details; opening protected information requires authorized access. Delivery depends on device settings, connectivity and service availability.\n\n### Authorized use and protection\nAccess to personal information is restricted by authenticated role, account status, event assignment and the relevant workflow. Keep your account private and do not share protected information outside authorized Radd work. Radd uses authentication and access controls to protect information, but no service can guarantee absolute security or uninterrupted availability.';

  @override
  String get vPrivacyTitle => 'Privacy Policy';

  @override
  String get vLocationPrivacyTitle => 'Location & Privacy Notice';

  @override
  String get vLocationPrivacyBody =>
      'Location access is required while participating in the active event. Radd uses your location to support event coordination and proximity-based Volunteer prioritization. Location may continue updating in the background during active event participation.';

  @override
  String get vViewPrivacyPolicy => 'View Privacy Policy';
}
