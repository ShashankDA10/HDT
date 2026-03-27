import 'package:cloud_firestore/cloud_firestore.dart';

class MedicationService {
  static final _col = FirebaseFirestore.instance.collection('medications');

  /// Save a medication. Pass [patientId] and [doctorId] when known.
  static Future<String> addMedication({
    required String name,
    required String dosage,
    required String frequency,
    required int timesPerDay,
    DateTime? tillDate,
    String? patientId,   // uid of the patient this belongs to
    String? doctorId,    // uid of the prescribing doctor (null = self-added)
    String? doctorName,
  }) async {
    final doc = await _col.add({
      'name':        name,
      'dosage':      dosage,
      'frequency':   frequency,
      'timesPerDay': timesPerDay,
      'tillDate':    tillDate != null ? Timestamp.fromDate(tillDate) : null,
      'checked':     List<bool>.filled(timesPerDay, false),
      'patientId':   patientId,
      'doctorId':    doctorId,
      'doctorName':  doctorName,
      'createdAt':   FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  /// Fetch medications filtered by [patientId].
  /// If [patientId] is null, returns all (admin/debug use only).
  static Future<List<Map<String, dynamic>>> getMedications({
    String? patientId,
  }) async {
    Query<Map<String, dynamic>> q = _col;
    if (patientId != null) {
      q = q.where('patientId', isEqualTo: patientId);
    }
    final snapshot = await q.get();
    final docs = snapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data()})
        .toList();
    docs.sort((a, b) {
      final aTs = a['createdAt'];
      final bTs = b['createdAt'];
      if (aTs == null || bTs == null) return 0;
      return (aTs as Timestamp).compareTo(bTs as Timestamp);
    });
    return docs;
  }

  /// Fetch medications prescribed BY a doctor.
  static Future<List<Map<String, dynamic>>> getMedicationsByDoctor(
      String doctorId) async {
    final snapshot =
        await _col.where('doctorId', isEqualTo: doctorId).get();
    final docs = snapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data()})
        .toList();
    docs.sort((a, b) {
      final aTs = a['createdAt'];
      final bTs = b['createdAt'];
      if (aTs == null || bTs == null) return 0;
      return (bTs as Timestamp).compareTo(aTs as Timestamp);
    });
    return docs;
  }

  /// Toggle dose checkbox state.
  static Future<void> updateChecked(String docId, List<bool> checked) async {
    await _col.doc(docId).update({'checked': checked});
  }

  /// Delete a medication document.
  static Future<void> deleteMedication(String docId) async {
    await _col.doc(docId).delete();
  }
}
