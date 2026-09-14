import 'dart:async';
import 'dart:typed_data';

import 'package:radd/features/auth/data/auth_service.dart';
import 'package:radd/features/guardian/data/guardian_repository.dart';

class TestAuth implements AuthService {
  bool active = false;
  int registrations = 0, logins = 0;
  final events = StreamController<bool>.broadcast();
  @override
  bool get signedIn => active;
  @override
  Future<bool> restoreSession() async => active;
  @override
  Stream<bool> get changes => events.stream;
  @override
  Future<void> login(String email, String password) async {
    logins++;
    active = true;
    events.add(true);
  }

  @override
  Future<void> register(String email, String password) async {
    registrations++;
    active = true;
    events.add(true);
  }

  @override
  Future<void> logout() async {
    active = false;
    events.add(false);
  }

  @override
  Future<void> resetPassword(String email) async {}
}

class TestRepository implements GuardianRepository {
  @override
  Future<String> accountRole() async => 'guardian';
  GuardianProfile person = const GuardianProfile(
    fullName: 'Test Guardian',
    email: 'test@example.test',
    phone: '+966500000001',
  );
  final List<Individual> records = [];
  @override
  Future<GuardianProfile> profile() async => person;
  @override
  Future<GuardianProfile> createProfile(String name, String phone) async =>
      person = GuardianProfile(
        fullName: name,
        email: person.email,
        phone: phone,
      );
  @override
  Future<GuardianProfile> updateProfile(String name, String phone) =>
      createProfile(name, phone);
  @override
  Future<List<Individual>> individuals() async => List.of(records);
  @override
  Future<Individual> individual(String id) async =>
      records.singleWhere((i) => i.id == id);
  @override
  Future<Individual> saveIndividual(
    IndividualInput input, {
    String? id,
    Uint8List? photo,
  }) async {
    final p = Individual(
      id: id ?? 'test-id',
      fullName: input.fullName,
      age: input.age,
      gender: input.gender,
      relationship: input.relationship,
    );
    records.removeWhere((i) => i.id == p.id);
    records.add(p);
    return p;
  }

  @override
  Future<void> deleteIndividual(String id) async {
    records.removeWhere((i) => i.id == id);
  }

  @override
  Future<Uint8List> photo(String id) async => Uint8List.fromList([
    137,
    80,
    78,
    71,
    13,
    10,
    26,
    10,
    0,
    0,
    0,
    13,
    73,
    72,
    68,
    82,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    1,
    8,
    6,
    0,
    0,
    0,
    31,
    21,
    196,
    137,
    0,
    0,
    0,
    11,
    73,
    68,
    65,
    84,
    120,
    156,
    99,
    96,
    0,
    2,
    0,
    0,
    5,
    0,
    1,
    165,
    246,
    69,
    64,
    0,
    0,
    0,
    0,
    73,
    69,
    78,
    68,
    174,
    66,
    96,
    130,
  ]);
}
