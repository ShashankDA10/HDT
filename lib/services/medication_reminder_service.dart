import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'notification_service.dart';

/// Manages daily medication dose reminder scheduling.
///
/// Slot index → label, time:
///   0 → Morning    9:30 AM
///   1 → Afternoon  1:00 PM
///   2 → Evening    6:00 PM
///   3 → Night      9:30 PM
///
/// The [_slotMap] defines which slot indices are active for each [timesPerDay]
/// value, matching the existing UI labels in medication_screen.dart:
///   1×/day → ['Daily']                           → slot 0 only
///   2×/day → ['Morning','Evening']               → slots 0, 2
///   3×/day → ['Morning','Afternoon','Evening']   → slots 0, 1, 2
///   4×/day → all four slots
class MedicationReminderService {
  static const _hours   = [9,  13, 18, 21];
  static const _minutes = [30,  0,  0, 30];
  static const _labels  = ['Morning', 'Afternoon', 'Evening', 'Night'];
  static const _times   = ['9:30 AM', '1:00 PM',  '6:00 PM', '9:30 PM'];

  static const Map<int, List<int>> _slotMap = {
    1: [0],
    2: [0, 2],
    3: [0, 1, 2],
    4: [0, 1, 2, 3],
  };

  // ── Schedule / cancel ─────────────────────────────────────────────────────

  /// Schedule (or refresh) daily reminders for one medication.
  ///
  /// - Cancels any existing notification for the slot BEFORE scheduling
  ///   to guarantee zero duplicates.
  /// - For every dose index that is already [checked], the notification is
  ///   cancelled instead of (re-)scheduled.
  /// - Passing [checked] = null schedules all slots unconditionally
  ///   (used on new medication add and daily reset).
  static Future<void> scheduleForMedication({
    required String    docId,
    required String    medName,
    required int       timesPerDay,
    List<bool>?        checked,
  }) async {
    final slots = _slotMap[timesPerDay] ?? [0];
    debugPrint('[MedReminder] scheduleForMedication "$medName" '
        '(docId=$docId, timesPerDay=$timesPerDay)');

    for (int i = 0; i < slots.length; i++) {
      final slotIdx      = slots[i];
      final notifId      = _idFor(docId, slotIdx);
      final alreadyTaken = checked != null && i < checked.length && checked[i];

      // Always cancel first to prevent duplicates before (re-)scheduling
      await NotificationService.cancel(notifId);

      if (alreadyTaken) {
        debugPrint('[MedReminder]   slot ${_labels[slotIdx]} — '
            'already taken, cancelled (id=$notifId)');
      } else {
        await NotificationService.scheduleDailyAt(
          id:          notifId,
          title:       '💊 Time to take $medName',
          body:        '${_labels[slotIdx]} dose is due (${_times[slotIdx]}). Open app to mark as taken.',
          hour:        _hours[slotIdx],
          minute:      _minutes[slotIdx],
          channelId:   'medication_reminders',
          channelName: 'Medication Reminders',
        );
        debugPrint('[MedReminder]   slot ${_labels[slotIdx]} — '
            'scheduled daily at ${_times[slotIdx]} (id=$notifId)');
      }
    }
  }

  /// Cancel the reminder for one specific dose slot (user just marked it taken).
  /// [doseIndex] is the checkbox index shown in the UI (0-based).
  static Future<void> cancelDose(
      String docId, int timesPerDay, int doseIndex) async {
    final slots = _slotMap[timesPerDay] ?? [0];
    if (doseIndex >= slots.length) return;
    final slotIdx = slots[doseIndex];
    final notifId = _idFor(docId, slotIdx);
    await NotificationService.cancel(notifId);
    debugPrint('[MedReminder] cancelDose — '
        '${_labels[slotIdx]} slot cancelled (id=$notifId)');
  }

  /// Reschedule the reminder for one dose slot (user un-checked it).
  /// Cancels the existing notification first to prevent duplicates.
  static Future<void> rescheduleDose({
    required String docId,
    required String medName,
    required int    timesPerDay,
    required int    doseIndex,
  }) async {
    final slots = _slotMap[timesPerDay] ?? [0];
    if (doseIndex >= slots.length) return;
    final slotIdx = slots[doseIndex];
    final notifId = _idFor(docId, slotIdx);

    // Cancel first to avoid any duplicate that might have lingered
    await NotificationService.cancel(notifId);

    await NotificationService.scheduleDailyAt(
      id:          notifId,
      title:       '💊 Time to take $medName',
      body:        '${_labels[slotIdx]} dose is due (${_times[slotIdx]}). Open app to mark as taken.',
      hour:        _hours[slotIdx],
      minute:      _minutes[slotIdx],
      channelId:   'medication_reminders',
      channelName: 'Medication Reminders',
    );
    debugPrint('[MedReminder] rescheduleDose — '
        '"$medName" ${_labels[slotIdx]} rescheduled at ${_times[slotIdx]} (id=$notifId)');
  }

  /// Cancel ALL reminders for a medication (expired or deleted).
  static Future<void> cancelAll(String docId) async {
    debugPrint('[MedReminder] cancelAll — cancelling all slots for docId=$docId');
    for (int i = 0; i < 4; i++) {
      final notifId = _idFor(docId, i);
      await NotificationService.cancel(notifId);
      debugPrint('[MedReminder]   cancelled slot ${_labels[i]} (id=$notifId)');
    }
  }

  // ── Daily reset ───────────────────────────────────────────────────────────

  /// Called on every app launch for the logged-in patient.
  ///
  /// Logic:
  ///   - If today's date != `lastMedResetDate` stored on the user Firestore doc:
  ///       → Reset all medication `checked` arrays to false.
  ///       → Update `lastMedResetDate` to today.
  ///       → Reschedule all notifications (everything unchecked).
  ///   - If same day (e.g. app restarted mid-day):
  ///       → Restore notifications to match current checked state.
  ///         (Previously-cancelled "taken" slots stay cancelled.)
  static Future<void> performDailyReset(String userId) async {
    final db  = FirebaseFirestore.instance;
    final now = DateTime.now();
    final todayStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final userDoc   = await db.collection('users').doc(userId).get();
    final lastReset = userDoc.data()?['lastMedResetDate'] as String?;

    final medsSnap = await db
        .collection('medications')
        .where('patientId', isEqualTo: userId)
        .get();

    debugPrint('[MedReminder] performDailyReset — '
        'today=$todayStr, lastReset=$lastReset, meds=${medsSnap.docs.length}');

    if (lastReset != todayStr) {
      debugPrint('[MedReminder] New day detected — resetting checked states');
      // ── New calendar day: reset checked states ────────────────────────────
      final batch = db.batch();
      for (final doc in medsSnap.docs) {
        final n = (doc.data()['timesPerDay'] as int?) ?? 1;
        batch.update(doc.reference, {'checked': List<bool>.filled(n, false)});
      }
      batch.update(
        db.collection('users').doc(userId),
        {'lastMedResetDate': todayStr},
      );
      await batch.commit();
      debugPrint('[MedReminder] Firestore checked states reset');

      // Reschedule everything (all unchecked → schedule all slots)
      for (final doc in medsSnap.docs) {
        final data = doc.data();
        await scheduleForMedication(
          docId:       doc.id,
          medName:     data['name']         as String? ?? 'Medication',
          timesPerDay: (data['timesPerDay'] as int?)   ?? 1,
          // checked = null → schedule all slots unconditionally
        );
      }
    } else {
      debugPrint('[MedReminder] Same day — restoring notification state');
      // ── Same day: restore notification state after app restart ────────────
      for (final doc in medsSnap.docs) {
        final data    = doc.data();
        final raw     = data['checked'];
        final checked = raw is List ? raw.map((e) => e == true).toList() : null;
        await scheduleForMedication(
          docId:       doc.id,
          medName:     data['name']         as String? ?? 'Medication',
          timesPerDay: (data['timesPerDay'] as int?)   ?? 1,
          checked:     checked,
        );
      }
    }

    debugPrint('[MedReminder] performDailyReset complete');
  }

  // ── Notification ID ───────────────────────────────────────────────────────

  /// Stable, collision-resistant ID derived from Firestore doc ID + slot index.
  /// Range: 1 000 000 – 1 999 999
  static int _idFor(String docId, int slotIndex) =>
      1000000 + docId.hashCode.abs() % 900000 + slotIndex;
}
