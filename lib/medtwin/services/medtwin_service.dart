import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/health_log.dart';
import '../models/health_profile.dart';
import '../models/recommendation.dart';

// ─── Base URL ─────────────────────────────────────────────────────────────────
// Physical device on same Wi-Fi as the dev machine.
// Production: replace with your Render.com URL.
const String _kBaseUrl = 'http://172.17.30.92:8000';
const String _kProfileCacheKey = 'medtwin_profile_cache';

// ─── Auth interceptor ─────────────────────────────────────────────────────────

class _AuthInterceptor extends Interceptor {
  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final token =
          await FirebaseAuth.instance.currentUser?.getIdToken(false);
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    } catch (_) {
      // If token fetch fails, let the request proceed — the server will 401.
    }
    handler.next(options);
  }
}

// ─── MedTwin service ──────────────────────────────────────────────────────────

class MedTwinService {
  MedTwinService._();

  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: _kBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 45),
      headers: {'Content-Type': 'application/json'},
    ),
  )..interceptors.add(_AuthInterceptor());

  // ── Profile ────────────────────────────────────────────────────────────────

  /// Fetch the profile from the network and update the cache.
  static Future<HealthProfile> getProfile() async {
    try {
      final res = await _dio.get('/profile');
      final profile = HealthProfile.fromFirestore(
        Map<String, dynamic>.from(res.data as Map),
      );
      await _cacheProfile(profile);
      return profile;
    } on DioException catch (e) {
      throw _friendlyError(e);
    }
  }

  /// Return the locally cached profile without hitting the network.
  static Future<HealthProfile?> getCachedProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_kProfileCacheKey);
      if (json == null) return null;
      return HealthProfile.fromFirestore(
        Map<String, dynamic>.from(jsonDecode(json) as Map),
      );
    } catch (_) {
      return null;
    }
  }

  /// Merge [data] into the existing profile (PATCH semantics).
  static Future<void> saveProfile(Map<String, dynamic> data) async {
    try {
      await _dio.patch('/profile', data: data);
    } on DioException catch (e) {
      throw _friendlyError(e);
    }
  }

  // ── Logs ──────────────────────────────────────────────────────────────────

  static Future<List<HealthLog>> getLogs() async {
    try {
      final res = await _dio.get('/logs');
      final list = (res.data as List<dynamic>).cast<Map<String, dynamic>>();
      return list.map((m) => HealthLog.fromFirestore(m['id'] as String, m)).toList();
    } on DioException catch (e) {
      throw _friendlyError(e);
    }
  }

  static Future<HealthLog> addLog(HealthLog log) async {
    try {
      final res = await _dio.post('/logs', data: {
        'type': log.type,
        'label': log.label,
        'value': log.value,
        'unit': log.unit,
      });
      final data = Map<String, dynamic>.from(res.data as Map);
      return HealthLog.fromFirestore(data['id'] as String, data);
    } on DioException catch (e) {
      throw _friendlyError(e);
    }
  }

  // ── Recommend ─────────────────────────────────────────────────────────────

  /// Fetches medications, reports and appointments from Firestore then calls
  /// the AI backend with the full context.
  static Future<AIRecommendation> getRecommendation(String question) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final appContext = uid != null ? await _buildAppContext(uid) : null;

    try {
      final body = <String, dynamic>{'question': question};
      if (appContext != null) {
        body['app_context'] = appContext;
      }
      final res = await _dio.post('/recommend', data: body);
      return AIRecommendation.fromJson(
        Map<String, dynamic>.from(res.data as Map),
      );
    } on DioException catch (e) {
      throw _friendlyError(e);
    }
  }

  // ── App context builder ───────────────────────────────────────────────────

  static Future<Map<String, dynamic>> _buildAppContext(String uid) async {
    final db = FirebaseFirestore.instance;
    final queryResults = await Future.wait([
      db.collection('medications').where('patientId', isEqualTo: uid).get(),
      db.collection('reports').where('patientId', isEqualTo: uid)
          .orderBy('createdAt', descending: true).limit(5).get(),
      db.collection('appointments').where('patientId', isEqualTo: uid)
          .orderBy('date', descending: true).limit(5).get(),
    ]);
    final userDoc = await db.collection('users').doc(uid).get();

    final medsDocs = queryResults[0].docs;
    final reportDocs = queryResults[1].docs;
    final apptDocs = queryResults[2].docs;
    final userData = userDoc.data() ?? {};

    final medications = medsDocs.map((d) {
      final data = d.data();
      return {
        'name': data['name'] ?? '',
        'dosage': data['dosage'] ?? '',
        'frequency': data['frequency'] ?? '',
      };
    }).toList();

    final reports = reportDocs.map((d) {
      final data = d.data();
      final dateRaw = data['date'];
      String dateStr = '';
      if (dateRaw is Timestamp) {
        final dt = dateRaw.toDate();
        dateStr = '${dt.day}/${dt.month}/${dt.year}';
      }
      return {
        'category': data['category'] ?? '',
        'report_type': data['type'] ?? '',
        'diagnosis': data['diagnosis'] ?? '',
        'clinical_notes': data['clinicalNotes'] ?? '',
        'date': dateStr,
        'doctor_name': data['doctorName'] ?? '',
      };
    }).toList();

    final appointments = apptDocs.map((d) {
      final data = d.data();
      final dateRaw = data['date'];
      String dateStr = '';
      if (dateRaw is Timestamp) {
        final dt = dateRaw.toDate();
        dateStr = '${dt.day}/${dt.month}/${dt.year}';
      }
      return {
        'doctor_name': data['doctorName'] ?? '',
        'date': dateStr,
        'time': data['time'] ?? '',
        'status': data['status'] ?? '',
      };
    }).toList();

    // ── Conditions from user profile ─────────────────────────────────────
    final condsMap = userData['conditions'] as Map<String, dynamic>? ?? {};
    final conditions = <String>[
      if (condsMap['diabetes'] == true) 'Diabetes',
      if (condsMap['hypertension'] == true) 'Hypertension',
      if (condsMap['heartDisease'] == true) 'Heart Disease',
      if (condsMap['asthma'] == true) 'Asthma',
      if (condsMap['thyroid'] == true) 'Thyroid disorder',
      if ((condsMap['other'] as String? ?? '').trim().isNotEmpty)
        condsMap['other'] as String,
    ];

    // ── Allergies from user profile ───────────────────────────────────────
    final allergyMap = userData['allergies'] as Map<String, dynamic>? ?? {};
    final allergies = <String>[
      if ((allergyMap['drug'] as String? ?? '').trim().isNotEmpty)
        'Drug: ${allergyMap['drug']}',
      if ((allergyMap['food'] as String? ?? '').trim().isNotEmpty)
        'Food: ${allergyMap['food']}',
      if ((allergyMap['other'] as String? ?? '').trim().isNotEmpty)
        'Other: ${allergyMap['other']}',
    ];

    return {
      'medications': medications,
      'recent_reports': reports,
      'appointments': appointments,
      'conditions': conditions,
      'allergies': allergies,
    };
  }

  // ── Chat history ──────────────────────────────────────────────────────────

  /// Save a completed AI exchange to Firestore for later review in Logs.
  static Future<void> saveChatHistory({
    required String question,
    required AIRecommendation recommendation,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('medtwin_profiles')
          .doc(uid)
          .collection('chat_history')
          .add({
        'question': question,
        ...recommendation.toJson(),
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Non-critical — don't surface to user
    }
  }

  /// Fetch chat history from Firestore (newest first).
  static Future<List<Map<String, dynamic>>> getChatHistory() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return [];
    try {
      final snap = await FirebaseFirestore.instance
          .collection('medtwin_profiles')
          .doc(uid)
          .collection('chat_history')
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();
      return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Cache helpers ─────────────────────────────────────────────────────────

  static Future<void> _cacheProfile(HealthProfile profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _kProfileCacheKey,
        jsonEncode(profile.toFirestore()..remove('updated_at')),
      );
    } catch (_) {}
  }

  // ── Error helper ──────────────────────────────────────────────────────────

  static Exception _friendlyError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError) {
      return Exception('No connection. Check your internet and try again.');
    }
    final status = e.response?.statusCode;
    if (status == 401) return Exception('Session expired. Please sign in again.');
    if (status == 429) return Exception('Too many requests. Wait a moment and try again.');
    if (status == 502 || status == 503) {
      return Exception('AI service is temporarily unavailable. Try again shortly.');
    }
    final detail = e.response?.data is Map
        ? (e.response!.data as Map)['detail'] as String?
        : null;
    return Exception(detail ?? 'Something went wrong. Please try again.');
  }
}
