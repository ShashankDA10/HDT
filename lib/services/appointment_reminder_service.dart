import 'package:flutter/foundation.dart';
import '../models/appointment.dart';
import 'notification_service.dart';

/// Schedules and cancels 1-hour-before appointment reminders.
///
/// Patient notification ID range : 2 000 000 – 2 899 999
/// Doctor  notification ID range : 2 900 001 – 3 799 999
class AppointmentReminderService {
  /// Schedule a patient-side reminder (1 hour before the appointment).
  ///
  /// Always cancels the existing notification for this appointment first
  /// to guarantee no duplicates (safe to call multiple times with same ID).
  static Future<void> schedulePatientReminder(Appointment appt) async {
    final at = _reminderDateTime(appt);
    if (at == null) {
      debugPrint('[ApptReminder] schedulePatientReminder — '
          'skipped (time in past or parse error) apptId=${appt.id}');
      return;
    }

    // Cancel any prior notification for this slot before re-scheduling
    await NotificationService.cancel(_patientId(appt.id));

    await NotificationService.scheduleOnce(
      id:          _patientId(appt.id),
      title:       '📅 Appointment in 1 hour',
      body:        'With Dr. ${appt.doctorName} at ${appt.time}. Please get ready.',
      at:          at,
      channelId:   'appointment_reminders',
      channelName: 'Appointment Reminders',
    );
    debugPrint('[ApptReminder] schedulePatientReminder — '
        'scheduled for $at (id=${_patientId(appt.id)}) '
        'appt="${appt.doctorName}" at ${appt.time}');
  }

  /// Schedule a doctor-side reminder (1 hour before the appointment).
  ///
  /// Always cancels the existing notification for this appointment first
  /// to guarantee no duplicates.
  static Future<void> scheduleDoctorReminder(Appointment appt) async {
    final at = _reminderDateTime(appt);
    if (at == null) {
      debugPrint('[ApptReminder] scheduleDoctorReminder — '
          'skipped (time in past or parse error) apptId=${appt.id}');
      return;
    }

    // Cancel any prior notification for this slot before re-scheduling
    await NotificationService.cancel(_doctorId(appt.id));

    await NotificationService.scheduleOnce(
      id:          _doctorId(appt.id),
      title:       '📅 Patient appointment in 1 hour',
      body:        '${appt.patientName} at ${appt.time}. Prepare patient notes.',
      at:          at,
      channelId:   'appointment_reminders',
      channelName: 'Appointment Reminders',
    );
    debugPrint('[ApptReminder] scheduleDoctorReminder — '
        'scheduled for $at (id=${_doctorId(appt.id)}) '
        'patient="${appt.patientName}" at ${appt.time}');
  }

  /// Cancel all reminders for an appointment (patient + doctor sides).
  /// Call this when an appointment is rejected or cancelled.
  static Future<void> cancelReminders(String appointmentId) async {
    await NotificationService.cancel(_patientId(appointmentId));
    await NotificationService.cancel(_doctorId(appointmentId));
    debugPrint('[ApptReminder] cancelReminders — '
        'cancelled patient(id=${_patientId(appointmentId)}) '
        'and doctor(id=${_doctorId(appointmentId)}) '
        'for apptId=$appointmentId');
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Parse the appointment time string and return a DateTime 1 hour before.
  /// Returns null if the reminder time has already passed or parsing fails.
  static DateTime? _reminderDateTime(Appointment appt) {
    try {
      final parts  = appt.time.split(RegExp(r'[:\s]+'));
      var   hour   = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      final period = parts.length > 2 ? parts[2].toUpperCase() : 'AM';
      if (period == 'PM' && hour != 12) hour += 12;
      if (period == 'AM' && hour == 12) hour = 0;
      final apptDt   = DateTime(
        appt.date.year, appt.date.month, appt.date.day, hour, minute,
      );
      final reminder = apptDt.subtract(const Duration(hours: 1));
      return reminder.isBefore(DateTime.now()) ? null : reminder;
    } catch (e) {
      debugPrint('[ApptReminder] _reminderDateTime parse error: $e '
          '(time="${appt.time}")');
      return null;
    }
  }

  static int _patientId(String apptId) =>
      2000000 + apptId.hashCode.abs() % 900000;

  static int _doctorId(String apptId) =>
      2900001 + apptId.hashCode.abs() % 900000;
}
