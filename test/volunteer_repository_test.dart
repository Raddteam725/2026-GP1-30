import 'package:flutter_test/flutter_test.dart';
import 'package:radd/features/volunteer/data/mock_volunteer_repository.dart';
import 'package:radd/features/volunteer/data/volunteer_repository.dart';
import 'package:radd/features/volunteer/domain/volunteer_models.dart';

void main() {
  const a = MockVolunteerRepository.account;
  const b = VolunteerAccount(
    uid: 'second-volunteer',
    name: LocalizedData('Second Volunteer', 'المتطوع الثاني'),
    volunteerId: 'VOL-2',
    active: true,
  );
  late MockVolunteerRepository repo;
  setUp(() => repo = MockVolunteerRepository());
  tearDown(() => repo.dispose());
  test(
    'multiple volunteers independently join; only first changes the status',
    () async {
      final item = repo.caseById('RD-8042')!;
      expect(item.status, CaseStatus.reportReceived);
      await repo.startSearch(a, item);
      final firstTime = item.updatedAt;
      expect(item.status, CaseStatus.searchInProgress);
      expect(repo.myCases(a.uid), contains(item));
      expect(repo.availableFor(a.uid), isNot(contains(item)));
      expect(repo.availableFor(b.uid), contains(item));
      await repo.startSearch(b, item);
      await repo.startSearch(b, item);
      expect(item.joinedBy, {a.uid, b.uid});
      expect(item.updatedAt, firstTime);
      expect(repo.myCases(b.uid), contains(item));
    },
  );
  test('confirmation retains only confirming volunteer and notifies other participants', () async {
    final item = repo.caseById('RD-8042')!;
    await repo.startSearch(a, item);
    await repo.startSearch(b, item);
    final report = await repo.submitFound(a);
    await repo.confirmMatch(a, report, item.person);
    expect(item.status, CaseStatus.matchConfirmed);
    expect(item.confirmedBy, a.uid);
    expect(repo.availableFor(b.uid), isNot(contains(item)));
    expect(repo.myCases(b.uid), isNot(contains(item)));
    expect(repo.myCases(a.uid), contains(item));
    expect(repo.alertsFor(b.uid).single.status, CaseStatus.matchConfirmed);
    await expectLater(repo.startSearch(b, item), throwsStateError);
    final second = await repo.submitFound(b);
    await expectLater(
      repo.confirmMatch(b, second, item.person),
      throwsStateError,
    );
    expect(item.status, isNot(CaseStatus.reunited));
  });
  test(
    'found report can identify a registered person with no missing case',
    () async {
      final person = repo.profiles.last;
      expect(repo.caseForPerson(person.id), isNull);
      final report = await repo.submitFound(a);
      await repo.confirmMatch(a, report, person);
      expect(report.status, CaseStatus.matchConfirmed);
      expect(report.matchedPerson, person);
      expect(repo.caseForPerson(person.id), isNull);
    },
  );
  test('ranked candidates do not change case status', () async {
    final report = await repo.submitFound(a);
    final results = await repo.findMatches(report);
    expect(results.map((m) => m.similarity), [.94, .88, .76]);
    expect(report.matchedPerson, isNull);
    expect(repo.caseById('RD-8042')!.status, CaseStatus.reportReceived);
  });
  test(
    'identifier verification requires authenticated guardian and exact match',
    () async {
      final item = repo.caseById('RD-8042')!,
          report = await repo.submitFound(a);
      await expectLater(repo.beginVerification(a, report), throwsStateError);
      await repo.confirmMatch(a, report, item.person);
      await repo.beginVerification(a, report);
      // The Guardian reads the case's 6-digit code; the RD-… id is not it.
      expect(
        await repo.verify(
          a,
          report,
          VerificationMethod.caseIdentifier,
          item.verificationCode!,
        ),
        isFalse, // authenticated account not confirmed as shown
      );
      expect(
        await repo.verify(
          a,
          report,
          VerificationMethod.caseIdentifier,
          item.id,
          authenticatedAccountShown: true,
        ),
        isFalse,
      );
      expect(
        await repo.verify(
          a,
          report,
          VerificationMethod.caseIdentifier,
          '804900', // another case's code
          authenticatedAccountShown: true,
        ),
        isFalse,
      );
      await expectLater(repo.handover(a, report), throwsStateError);
      expect(item.status, CaseStatus.awaitingGuardianVerification);
      expect(
        await repo.verify(
          a,
          report,
          VerificationMethod.caseIdentifier,
          item.verificationCode!,
          authenticatedAccountShown: true,
        ),
        isTrue,
      );
      expect(report.verification!.method, VerificationMethod.caseIdentifier);
      await expectLater(repo.handover(b, report), throwsStateError);
      await repo.handover(a, report);
      expect(item.status, CaseStatus.reunited);
      expect(item.handedOverBy, a.uid);
      expect(item.handedOverAt, isNotNull);
      await expectLater(repo.handover(a, report), throwsStateError);
      await expectLater(repo.startSearch(b, item), throwsStateError);
    },
  );
  test('QR verification is case and guardian specific; failed retry clears success', () async {
    final item = repo.caseById('RD-8042')!, report = await repo.submitFound(a);
    await repo.confirmMatch(a, report, item.person);
    await repo.beginVerification(a, report);
    expect(
      await repo.verify(
        a,
        report,
        VerificationMethod.qr,
        'preview-qr:${item.id}:wrong-guardian',
      ),
      isFalse,
    );
    expect(
      await repo.verify(
        a,
        report,
        VerificationMethod.qr,
        'preview-qr:${item.id}:${item.person.guardian.id}',
      ),
      isTrue,
    );
    expect(report.verification!.method, VerificationMethod.qr);
    expect(
      await repo.verify(a, report, VerificationMethod.qr, 'invalid'),
      isFalse,
    );
    expect(report.verification, isNull);
    await expectLater(repo.handover(a, report), throwsStateError);
  });
  test(
    'initial report has no last seen; guardian update preserves ongoing search',
    () async {
      final item = repo.caseById('RD-8042')!;
      expect(item.information, isNull);
      await repo.startSearch(a, item);
      repo.receiveGuardianDetails(
        item.id,
        MockVolunteerRepository.updatedInformation,
      );
      expect(item.information!.lastSeen, isNotNull);
      expect(item.status, CaseStatus.searchInProgress);
      expect(item.joinedBy, contains(a.uid));
    },
  );
  test('disabled volunteers cannot join or submit reports', () async {
    await expectLater(
      repo.startSearch(
        MockVolunteerRepository.inactiveAccount,
        repo.cases.first,
      ),
      throwsStateError,
    );
    await expectLater(
      repo.submitFound(MockVolunteerRepository.inactiveAccount),
      throwsStateError,
    );
  });
  test(
    'live unconnected repository never exposes fixtures or simulates success',
    () async {
      final live = UnconnectedVolunteerRepository();
      addTearDown(live.dispose);
      expect(live.isPreview, isFalse);
      expect(live.cases, isEmpty);
      expect(live.profiles, isEmpty);
      expect(live.alertsFor(a.uid), isEmpty);
      await expectLater(live.submitFound(a), throwsStateError);
    },
  );
  test('500 meter distance boundary for nearby cases', () {
    const origin = Coordinates(0, 0);
    expect(origin.distanceTo(origin), 0);
    expect(
      origin.distanceTo(const Coordinates(.00449, 0)),
      lessThanOrEqualTo(500),
    );
    expect(origin.distanceTo(const Coordinates(.00450, 0)), greaterThan(500));
  });
}
