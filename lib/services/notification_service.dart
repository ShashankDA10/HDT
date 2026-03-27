import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Top-level FCM background handler — must be a top-level function.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase is pre-initialised by the OS before this runs.
  // FCM data-only messages are handled here; notification messages are
  // displayed automatically by the system tray.
}

/// Central service for all local and push notifications.
///
/// Call [initialize] once in `main()` after `Firebase.initializeApp()`.
class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  // ── Android notification channels ────────────────────────────────────────

  static const _channelMed = AndroidNotificationChannel(
    'medication_reminders',
    'Medication Reminders',
    description: 'Daily medication dose reminders',
    importance: Importance.high,
    playSound: true,
  );

  static const _channelAppt = AndroidNotificationChannel(
    'appointment_reminders',
    'Appointment Reminders',
    description: 'Reminders 1 hour before appointments',
    importance: Importance.max,
    playSound: true,
  );

  static const _channelReport = AndroidNotificationChannel(
    'report_updates',
    'Report Updates',
    description: 'Notifications when new medical reports are added',
    importance: Importance.high,
    playSound: true,
  );

  // ── Initialization ────────────────────────────────────────────────────────

  /// Call once in `main()` after `Firebase.initializeApp()`.
  static Future<void> initialize() async {
    if (kIsWeb || _initialized) return;
    _initialized = true;

    // Initialise timezone data
    tz_data.initializeTimeZones();
    try {
      final tzName = DateTime.now().timeZoneName;
      tz.setLocalLocation(tz.getLocation(tzName));
    } catch (_) {}

    // Plugin init settings
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings  = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
      ),
    );

    // Create Android channels
    if (Platform.isAndroid) {
      final impl = _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await impl?.createNotificationChannel(_channelMed);
      await impl?.createNotificationChannel(_channelAppt);
      await impl?.createNotificationChannel(_channelReport);
    }

    // FCM wiring
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    FirebaseMessaging.onMessage.listen(_onForegroundFcmMessage);
    FirebaseMessaging.instance.onTokenRefresh.listen(_persistFcmToken);
  }

  // ── Permissions ───────────────────────────────────────────────────────────

  /// Request all notification permissions. Call after the user is logged in.
  static Future<void> requestPermissions() async {
    if (kIsWeb) return;

    // FCM permission (covers notification permission on iOS + Android 13+)
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (Platform.isAndroid) {
      final impl = _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await impl?.requestNotificationsPermission();
      await impl?.requestExactAlarmsPermission();
    } else if (Platform.isIOS) {
      final impl = _plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      await impl?.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  // ── FCM token ─────────────────────────────────────────────────────────────

  /// Fetch and persist the FCM device token for the logged-in user.
  /// Call this after login so the backend can target push messages.
  static Future<void> saveFcmToken() async {
    if (kIsWeb) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _persistFcmToken(token);
    } catch (_) {}
  }

  // ── Show ──────────────────────────────────────────────────────────────────

  /// Show an immediate local notification (e.g. foreground report update).
  static Future<void> showImmediate({
    required int    id,
    required String title,
    required String body,
    required String channelId,
    required String channelName,
  }) async {
    if (kIsWeb) return;
    await _plugin.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  // ── Schedule ──────────────────────────────────────────────────────────────

  /// Schedule a **daily repeating** notification at a fixed time-of-day.
  /// Overwrites any existing notification with the same [id].
  static Future<void> scheduleDailyAt({
    required int    id,
    required String title,
    required String body,
    required int    hour,
    required int    minute,
    required String channelId,
    required String channelName,
  }) async {
    if (kIsWeb) return;
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      _nextInstanceOf(hour, minute),
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.wallClockTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Schedule a **one-shot** notification at a specific [DateTime].
  /// Silently skips if [at] is already in the past.
  static Future<void> scheduleOnce({
    required int      id,
    required String   title,
    required String   body,
    required DateTime at,
    required String   channelId,
    required String   channelName,
  }) async {
    if (kIsWeb) return;
    final tzTime = tz.TZDateTime.from(at, tz.local);
    if (tzTime.isBefore(tz.TZDateTime.now(tz.local))) return;
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tzTime,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          importance: Importance.max,
          priority: Priority.max,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // ── Cancel ────────────────────────────────────────────────────────────────

  /// Cancel a single notification by [id].
  static Future<void> cancel(int id) => _plugin.cancel(id);

  /// Cancel all pending/shown notifications.
  static Future<void> cancelAll() => _plugin.cancelAll();

  // ── Private helpers ───────────────────────────────────────────────────────

  static tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var t = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (t.isBefore(now)) t = t.add(const Duration(days: 1));
    return t;
  }

  static void _onForegroundFcmMessage(RemoteMessage message) {
    final n = message.notification;
    if (n == null) return;
    showImmediate(
      id: message.hashCode,
      title: n.title ?? 'New Update',
      body: n.body ?? '',
      channelId: 'report_updates',
      channelName: 'Report Updates',
    );
  }

  static Future<void> _persistFcmToken(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .update({'fcmToken': token})
        .catchError((_) {});
  }
}
