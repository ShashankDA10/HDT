import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';

abstract class AuthService {
  Stream<User?> get authStateChanges;
  Future<AppUser?> signIn(String email, String password);
  Future<AppUser?> signUp({
    required String email,
    required String password,
    required String name,
    required String role,
    String phone,
  });
  Future<void> signOut();
}

class EmailPasswordAuthService implements AuthService {
  static final _auth = FirebaseAuth.instance;
  static final _db   = FirebaseFirestore.instance;

  @override
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  @override
  Future<AppUser?> signIn(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim(), password: password);
    return _fetchUser(cred.user!.uid);
  }

  @override
  Future<AppUser?> signUp({
    required String email,
    required String password,
    required String name,
    required String role,
    String phone = '',
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(), password: password);
    await cred.user!.updateDisplayName(name.trim());

    final user = AppUser(
      id:    cred.user!.uid,
      name:  name.trim(),
      email: email.trim().toLowerCase(),
      role:  role,
      phone: phone,
    );
    await _db.collection('users').doc(user.id).set(user.toMap());
    return user;
  }

  @override
  Future<void> signOut() => _auth.signOut();

  Future<AppUser?> _fetchUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return AppUser.fromFirestore(doc.id, doc.data()!);
  }

  static User? get firebaseUser => _auth.currentUser;

  static Future<AppUser?> currentAppUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final doc = await _db.collection('users').doc(user.uid).get();
    if (!doc.exists) return null;
    return AppUser.fromFirestore(doc.id, doc.data()!);
  }

  /// Search patients by phone (exact) and/or name (partial, case-insensitive).
  /// If both are provided, both must match (AND condition).
  static Future<List<AppUser>> searchPatients({
    String? phone,
    String? name,
  }) async {
    Query<Map<String, dynamic>> query =
        _db.collection('users').where('role', isEqualTo: 'patient');

    if (phone != null && phone.isNotEmpty) {
      query = query.where('phone', isEqualTo: phone.trim());
    }

    final snap = await query.get();
    List<AppUser> results = snap.docs
        .map((d) => AppUser.fromFirestore(d.id, d.data()))
        .toList();

    if (name != null && name.isNotEmpty) {
      final lowerName = name.trim().toLowerCase();
      results = results
          .where((u) => u.name.toLowerCase().contains(lowerName))
          .toList();
    }

    return results;
  }

  /// Find a patient by their full phone number (e.g. '+919876543210').
  static Future<AppUser?> findPatientByPhone(String phone) async {
    final snap = await _db
        .collection('users')
        .where('phone', isEqualTo: phone.trim())
        .where('role',  isEqualTo: 'patient')
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return AppUser.fromFirestore(snap.docs.first.id, snap.docs.first.data());
  }

  /// Fetch any user document by UID.
  static Future<AppUser?> fetchUserById(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return AppUser.fromFirestore(doc.id, doc.data()!);
  }

  /// Persist a doctor → patient link so the patient appears in the doctor's list
  /// even before any report or medication is written.
  static Future<void> linkPatientToDoctor({
    required String doctorId,
    required String patientId,
    required String patientName,
  }) async {
    await _db
        .collection('doctor_patients')
        .doc('${doctorId}_$patientId')
        .set({
      'doctorId':    doctorId,
      'patientId':   patientId,
      'patientName': patientName,
      'linkedAt':    FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Fetch all patients linked to a doctor.
  static Future<List<Map<String, dynamic>>> getLinkedPatients(
      String doctorId) async {
    final snap = await _db
        .collection('doctor_patients')
        .where('doctorId', isEqualTo: doctorId)
        .get();
    return snap.docs.map((d) => d.data()).toList();
  }

  /// Find a doctor by their full phone number (e.g. '+919876543210').
  static Future<AppUser?> findDoctorByPhone(String phone) async {
    final snap = await _db
        .collection('users')
        .where('phone', isEqualTo: phone.trim())
        .where('role',  isEqualTo: 'doctor')
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return AppUser.fromFirestore(snap.docs.first.id, snap.docs.first.data());
  }

  /// Look up a patient's Firestore UID by their email.
  static Future<String?> findPatientIdByEmail(String email) async {
    final snap = await _db
        .collection('users')
        .where('email', isEqualTo: email.trim().toLowerCase())
        .where('role',  isEqualTo: 'patient')
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return snap.docs.first.id;
  }
}
