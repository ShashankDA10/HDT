import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/appointment.dart';

class AppointmentService {
  static final _col = FirebaseFirestore.instance.collection('appointments');

  // ── Create ────────────────────────────────────────────────────────────────

  static Future<String> createAppointment({
    required String patientId,
    required String doctorId,
    required String patientName,
    required String doctorName,
    required DateTime date,
    required String time,
  }) async {
    final doc = await _col.add({
      'patientId':   patientId,
      'doctorId':    doctorId,
      'patientName': patientName,
      'doctorName':  doctorName,
      'date':        Timestamp.fromDate(DateTime(date.year, date.month, date.day)),
      'time':        time,
      'status':      'pending',
      'createdAt':   FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  // ── Read – Patient (real-time stream) ─────────────────────────────────────

  static Stream<List<Appointment>> patientStream(String patientId) {
    return _col
        .where('patientId', isEqualTo: patientId)
        .snapshots()
        .map((s) {
          final list = s.docs
              .map((d) => Appointment.fromFirestore(d.id, d.data()))
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  // ── Read – Doctor (real-time stream) ──────────────────────────────────────

  static Stream<List<Appointment>> doctorStream(String doctorId) {
    return _col
        .where('doctorId', isEqualTo: doctorId)
        .snapshots()
        .map((s) {
          final list = s.docs
              .map((d) => Appointment.fromFirestore(d.id, d.data()))
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  // ── Update status ─────────────────────────────────────────────────────────

  static Future<void> updateStatus(String id, String status) =>
      _col.doc(id).update({'status': status});

  // ── Cancel (patient) ─────────────────────────────────────────────────────

  static Future<void> cancel(String id) =>
      _col.doc(id).update({'status': 'cancelled'});
}
