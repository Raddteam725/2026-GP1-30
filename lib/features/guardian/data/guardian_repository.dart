import 'dart:typed_data';

class GuardianProfile {
  const GuardianProfile({
    required this.fullName,
    required this.email,
    required this.phone,
  });
  final String fullName, email, phone;
  factory GuardianProfile.fromJson(Map<String, dynamic> j) => GuardianProfile(
    fullName: j['full_name'] as String,
    email: j['email'] as String,
    phone: j['phone'] as String,
  );
}

class Individual {
  const Individual({
    required this.id,
    required this.fullName,
    required this.age,
    required this.gender,
    required this.relationship,
  });
  final String id, fullName, gender, relationship;
  final int age;
  factory Individual.fromJson(Map<String, dynamic> j) => Individual(
    id: j['id'] as String,
    fullName: j['full_name'] as String,
    age: j['age'] as int,
    gender: j['gender'] as String,
    relationship: j['relationship'] as String,
  );
}

class IndividualInput {
  const IndividualInput({
    required this.fullName,
    required this.age,
    required this.gender,
    required this.relationship,
  });
  final String fullName, gender, relationship;
  final int age;
  Map<String, dynamic> toJson() => {
    'full_name': fullName.trim(),
    'age': age,
    'gender': gender,
    'relationship': relationship,
  };
}

class AppFailure implements Exception {
  const AppFailure(this.code);
  final String code;
}

abstract class GuardianRepository {
  /// Server-owned role, resolved without assuming a Guardian profile.
  Future<String> accountRole();
  Future<GuardianProfile> profile();
  Future<GuardianProfile> createProfile(String name, String phone);
  Future<GuardianProfile> updateProfile(String name, String phone);
  Future<List<Individual>> individuals();
  Future<Individual> individual(String id);
  Future<Individual> saveIndividual(
    IndividualInput input, {
    String? id,
    Uint8List? photo,
  });
  Future<void> deleteIndividual(String id);
  Future<Uint8List> photo(String id);
}
