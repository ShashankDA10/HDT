import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String id;
  final String name;
  final String email;
  final String role; // 'doctor' | 'patient'
  final String phone; // stored as '+91XXXXXXXXXX'
  final bool   profileCompleted;

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phone = '',
    this.profileCompleted = false,
  });

  bool get isDoctor  => role == 'doctor';
  bool get isPatient => role == 'patient';

  factory AppUser.fromFirestore(String id, Map<String, dynamic> data) => AppUser(
    id:               id,
    name:             data['name']             as String? ?? '',
    email:            data['email']            as String? ?? '',
    role:             data['role']             as String? ?? 'patient',
    phone:            data['phone']            as String? ?? '',
    profileCompleted: data['profileCompleted'] as bool?   ?? false,
  );

  Map<String, dynamic> toMap() => {
    'name':      name,
    'email':     email,
    'role':      role,
    'phone':     phone,
    'createdAt': FieldValue.serverTimestamp(),
  };
}
