import 'package:cloud_firestore/cloud_firestore.dart';
import 'medication_service.dart';

class ReportService {
  static final _col = FirebaseFirestore.instance.collection('reports');

  static Future<String> addReport({
    required String category,
    required String type,
    required String reportName,
    required DateTime date,
    required String doctorName,
    required String hospitalName,
    required String clinicalNotes,
    required String diagnosis,
    required String additionalComments,
    required List<String> tags,
    required List<Map<String, String>> attachments,
    // Who created and who it belongs to
    String? doctorId,
    String? patientId,
    String? patientName,
    // Optional inline medication
    String? medName,
    String? medDosage,
    String? medFrequency,
    int? medTimesPerDay,
    DateTime? medTillDate,
    // 'doctor' (default) or 'patient_upload' for self-scanned reports
    String source = 'doctor',
    String? rawOcrText,
  }) async {
    String? medicationDocId;

    if (medName != null && medName.isNotEmpty) {
      medicationDocId = await MedicationService.addMedication(
        name:        medName,
        dosage:      medDosage ?? '',
        frequency:   medFrequency ?? '',
        timesPerDay: medTimesPerDay ?? 1,
        tillDate:    medTillDate,
        patientId:   patientId,
        doctorId:    doctorId,
        doctorName:  doctorName,
      );
    }

    final doc = await _col.add({
      'category':           category,
      'type':               type,
      'reportName':         reportName,
      'date':               Timestamp.fromDate(date),
      'doctorName':         doctorName,
      'doctorId':           doctorId,
      'patientId':          patientId,
      'patientName':        patientName,
      'hospitalName':       hospitalName,
      'clinicalNotes':      clinicalNotes,
      'diagnosis':          diagnosis,
      'additionalComments': additionalComments,
      'tags':               tags,
      'attachments':        attachments,
      'hasMedication':      medicationDocId != null,
      'medicationDocId':    medicationDocId,
      'source':             source,
      if (rawOcrText != null && rawOcrText.isNotEmpty) 'rawOcrText': rawOcrText,
      'createdAt':          FieldValue.serverTimestamp(),
    });

    return doc.id;
  }

  /// Fetch reports for a patient (read-only view).
  static Future<List<Map<String, dynamic>>> getReportsByPatient(
      String patientId) async {
    final snapshot =
        await _col.where('patientId', isEqualTo: patientId).get();
    return _sorted(snapshot);
  }

  /// Fetch reports written BY a doctor.
  static Future<List<Map<String, dynamic>>> getReportsByDoctor(
      String doctorId) async {
    final snapshot =
        await _col.where('doctorId', isEqualTo: doctorId).get();
    return _sorted(snapshot);
  }

  /// Fetch all reports (kept for backward-compat / admin).
  static Future<List<Map<String, dynamic>>> getReports() async {
    final snapshot = await _col.get();
    return _sorted(snapshot);
  }

  static List<Map<String, dynamic>> _sorted(
      QuerySnapshot<Map<String, dynamic>> snapshot) {
    final docs = snapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data()})
        .toList();
    docs.sort((a, b) {
      final aTs = a['createdAt'];
      final bTs = b['createdAt'];
      if (aTs == null || bTs == null) return 0;
      return (bTs as Timestamp).compareTo(aTs as Timestamp); // newest first
    });
    return docs;
  }

  static Future<void> deleteReport(String docId) async {
    await _col.doc(docId).delete();
  }
}
