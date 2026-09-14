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
      'Keep the case-specific code steady within the frame.';

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
      'Allow location while using Radd to check whether you are within 500 meters of a reported location. General alerts remain available without location.';

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
}
