import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/patient_profile.dart';

class PatientProfileService {
  static final _db = FirebaseFirestore.instance;

  /// Returns true if the patient has already completed onboarding.
  static Future<bool> isProfileCompleted(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.data()?['profileCompleted'] == true;
  }

  /// Saves the full profile and sets profileCompleted = true.
  static Future<void> saveProfile(String uid, PatientProfile profile) async {
    await _db.collection('users').doc(uid).update(profile.toFirestore());
  }
}
