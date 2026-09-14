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
