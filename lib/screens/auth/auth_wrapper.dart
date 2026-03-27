import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../services/medication_reminder_service.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';
import '../doctor/doctor_dashboard.dart';
import '../patient/onboarding/patient_onboarding_screen.dart';
import '../splash_screen.dart';
import 'login_screen.dart';

/// Listens to Firebase auth state and routes to the correct screen based on role.
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  // ── Auth / user state ─────────────────────────────────────────────────────
  String?        _lastUid;
  Future<AppUser?>? _userFuture;

  // ── Notification state ────────────────────────────────────────────────────
  /// Guard: notification setup runs once per user session.
  bool _notifSetupDone = false;

  /// Firestore listener for new patient reports (patient sessions only).
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _reportSub;

  /// Timestamp when the report listener was started; used to ignore
  /// pre-existing documents and only notify on newly-added reports.
  DateTime? _reportListenerStarted;

  @override
  void dispose() {
    _reportSub?.cancel();
    super.dispose();
  }

  // ── Auth routing helpers ──────────────────────────────────────────────────

  void _updateFuture(String uid) {
    if (uid != _lastUid) {
      _lastUid          = uid;
      _userFuture       = EmailPasswordAuthService.currentAppUser();
      // Reset notification state for the new session
      _notifSetupDone   = false;
      _reportSub?.cancel();
      _reportSub        = null;
      _reportListenerStarted = null;
    }
  }

  // ── Notification initialisation ───────────────────────────────────────────

  /// Called once per user session (guarded by [_notifSetupDone]).
  /// Uses addPostFrameCallback so we never call async work during build.
  void _maybeSetupNotifications(AppUser user) {
    if (_notifSetupDone) return;
    _notifSetupDone = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      // Request permissions and save FCM token for all users
      debugPrint('[AuthWrapper] Requesting notification permissions '
          'for uid=${user.id} role=${user.role}');
      await NotificationService.requestPermissions();
      debugPrint('[AuthWrapper] Permissions requested');

      debugPrint('[AuthWrapper] Saving FCM token');
      await NotificationService.saveFcmToken();
      debugPrint('[AuthWrapper] FCM token saved');

      // Patient-only: daily medication reset + new-report listener
      if (!user.isDoctor) {
        debugPrint('[AuthWrapper] Patient session — starting daily reset '
            'and report listener');
        MedicationReminderService.performDailyReset(user.id)
            .catchError((e) => debugPrint('[AuthWrapper] Daily reset error: $e'));
        _startReportListener(user.id);
      }
    });
  }

  /// Listen to the patient's `reports` collection; show a local notification
  /// whenever a **new** document is added after this session started.
  void _startReportListener(String patientId) {
    _reportListenerStarted = DateTime.now();
    _reportSub = FirebaseFirestore.instance
        .collection('reports')
        .where('patientId', isEqualTo: patientId)
        .snapshots()
        .listen((snap) {
      for (final change in snap.docChanges) {
        if (change.type != DocumentChangeType.added) continue;
        final data = change.doc.data();
        if (data == null) continue;

        // Only notify for reports created AFTER the listener started.
        // This prevents flooding notifications for all historical reports
        // on every app launch.
        final createdAt = data['createdAt'];
        if (createdAt is Timestamp) {
          if (createdAt.toDate().isBefore(_reportListenerStarted!)) continue;
        }

        final reportName = data['reportName'] as String? ?? 'New Report';
        final doctorName = data['doctorName'] as String? ?? 'Your doctor';

        debugPrint('[AuthWrapper] New report detected — '
            '"$reportName" by Dr. $doctorName (docId=${change.doc.id})');
        NotificationService.showImmediate(
          id:          change.doc.id.hashCode.abs() % 2000000,
          title:       '📋 New Report Added',
          body:        '$reportName — Dr. $doctorName',
          channelId:   'report_updates',
          channelName: 'Report Updates',
        );
        debugPrint('[AuthWrapper] Report notification shown');
      }
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnap) {
        if (authSnap.connectionState == ConnectionState.waiting) {
          return const _Loader();
        }

        if (authSnap.data == null) {
          _lastUid    = null;
          _userFuture = null;
          return const LoginScreen();
        }

        _updateFuture(authSnap.data!.uid);

        return FutureBuilder<AppUser?>(
          future: _userFuture,
          builder: (context, userSnap) {
            if (userSnap.connectionState == ConnectionState.waiting) {
              return const _Loader();
            }

            final user = userSnap.data;
            if (user == null) {
              FirebaseAuth.instance.signOut();
              return const LoginScreen();
            }

            // Kick off notification setup (idempotent)
            _maybeSetupNotifications(user);

            if (user.isDoctor) return DoctorDashboard(doctor: user);
            if (!user.profileCompleted) return PatientOnboardingScreen(user: user);
            return const SplashScreen();
          },
        );
      },
    );
  }
}

class _Loader extends StatelessWidget {
  const _Loader();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.ink,
      body: Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      ),
    );
  }
}
