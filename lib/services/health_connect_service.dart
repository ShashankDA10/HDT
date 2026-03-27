import 'package:health/health.dart';
import 'package:flutter/foundation.dart' show kDebugMode, defaultTargetPlatform, TargetPlatform;

class HealthConnectService {
  static Health? _health;
  bool _isAvailable = false;
  bool _hasPermissions = false;

  /// Health plugin only supports iOS and Android. On macOS/Windows/Linux/Web we skip it.
  static bool get _isHealthSupported =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  HealthConnectService() {
    if (_isHealthSupported) {
      _health = Health();
    } else {
      _health = null;
    }
  }

  /// Check if Health Connect is available on the device
  Future<bool> checkAvailability() async {
    if (_health == null) return false;
    try {
      _isAvailable = await _health!.hasPermissions(
        [
          HealthDataType.HEART_RATE,
          HealthDataType.STEPS,
        ],
      ) ?? false;
      return _isAvailable;
    } catch (e) {
      if (kDebugMode) {
        print('Health Connect availability check error: $e');
      }
      return false;
    }
  }

  /// Request permissions for health data types
  Future<bool> requestPermissions() async {
    if (_health == null) return false;
    try {
      final types = [
        HealthDataType.HEART_RATE,
        HealthDataType.STEPS,
        HealthDataType.BLOOD_OXYGEN,
        HealthDataType.SLEEP_ASLEEP,
        HealthDataType.ACTIVE_ENERGY_BURNED,
        HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
        HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
        HealthDataType.WEIGHT,
        HealthDataType.HEIGHT,
        HealthDataType.BODY_TEMPERATURE,
      ];

      _hasPermissions = await _health!.requestAuthorization(types);
      return _hasPermissions;
    } catch (e) {
      if (kDebugMode) {
        print('Health Connect permission request error: $e');
      }
      return false;
    }
  }

  /// Get heart rate data
  Future<List<HealthDataPoint>> getHeartRate({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (_health == null) return [];
    try {
      final now = endDate ?? DateTime.now();
      final start = startDate ?? now.subtract(const Duration(days: 1));

      final data = await _health!.getHealthDataFromTypes(
        types: [HealthDataType.HEART_RATE],
        startTime: start,
        endTime: now,
      );

      return data;
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching heart rate: $e');
      }
      return [];
    }
  }

  /// Get latest heart rate
  Future<int?> getLatestHeartRate() async {
    try {
      final data = await getHeartRate();
      if (data.isNotEmpty) {
        // Get the most recent heart rate
        data.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));
        final healthPoint = data.first;
        final value = healthPoint.value;
        // Extract numeric value from HealthValue - convert to string first
        final strValue = value.toString();
        return int.tryParse(strValue);
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting latest heart rate: $e');
      }
      return null;
    }
  }

  /// Get SpO2 (Blood Oxygen) data
  Future<List<HealthDataPoint>> getBloodOxygen({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (_health == null) return [];
    try {
      final now = endDate ?? DateTime.now();
      final start = startDate ?? now.subtract(const Duration(days: 1));

      final data = await _health!.getHealthDataFromTypes(
        types: [HealthDataType.BLOOD_OXYGEN],
        startTime: start,
        endTime: now,
      );

      return data;
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching blood oxygen: $e');
      }
      return [];
    }
  }

  /// Get latest SpO2
  Future<int?> getLatestBloodOxygen() async {
    try {
      final data = await getBloodOxygen();
      if (data.isNotEmpty) {
        data.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));
        final healthPoint = data.first;
        final value = healthPoint.value;
        // Extract numeric value from HealthValue - convert to string first
        final strValue = value.toString();
        return int.tryParse(strValue);
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting latest blood oxygen: $e');
      }
      return null;
    }
  }

  /// Get steps data
  Future<List<HealthDataPoint>> getSteps({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (_health == null) return [];
    try {
      final now = endDate ?? DateTime.now();
      final start = startDate ?? now.subtract(const Duration(days: 1));

      final data = await _health!.getHealthDataFromTypes(
        types: [HealthDataType.STEPS],
        startTime: start,
        endTime: now,
      );

      return data;
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching steps: $e');
      }
      return [];
    }
  }

  /// Get total steps for today
  Future<int> getTodaySteps() async {
    if (_health == null) return 0;
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);

      final steps = await _health!.getTotalStepsInInterval(
        startOfDay,
        now,
      );

      return steps ?? 0;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting today steps: $e');
      }
      return 0;
    }
  }

  /// Get blood pressure data
  Future<Map<String, double>?> getLatestBloodPressure() async {
    if (_health == null) return null;
    try {
      final now = DateTime.now();
      final start = now.subtract(const Duration(days: 7));

      final systolicData = await _health!.getHealthDataFromTypes(
        types: [HealthDataType.BLOOD_PRESSURE_SYSTOLIC],
        startTime: start,
        endTime: now,
      );

      final diastolicData = await _health!.getHealthDataFromTypes(
        types: [HealthDataType.BLOOD_PRESSURE_DIASTOLIC],
        startTime: start,
        endTime: now,
      );

      if (systolicData.isNotEmpty && diastolicData.isNotEmpty) {
        systolicData.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));
        diastolicData.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));

        final systolicValue = systolicData.first.value;
        final diastolicValue = diastolicData.first.value;
        
        double getDoubleValue(dynamic val) {
          // Convert HealthValue to string then parse
          return double.tryParse(val.toString()) ?? 0.0;
        }
        
        return {
          'systolic': getDoubleValue(systolicValue),
          'diastolic': getDoubleValue(diastolicValue),
        };
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting blood pressure: $e');
      }
      return null;
    }
  }

  /// Get body temperature
  Future<double?> getLatestTemperature() async {
    if (_health == null) return null;
    try {
      final now = DateTime.now();
      final start = now.subtract(const Duration(days: 1));

      final data = await _health!.getHealthDataFromTypes(
        types: [HealthDataType.BODY_TEMPERATURE],
        startTime: start,
        endTime: now,
      );

      if (data.isNotEmpty) {
        data.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));
        // Convert to Fahrenheit if needed (Health Connect stores in Celsius)
        final value = data.first.value;
        final celsius = double.tryParse(value.toString()) ?? 0.0;
        return (celsius * 9 / 5) + 32; // Convert to Fahrenheit
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting temperature: $e');
      }
      return null;
    }
  }

  /// Get calories burned
  Future<int> getTodayCalories() async {
    if (_health == null) return 0;
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);

      final data = await _health!.getHealthDataFromTypes(
        types: [HealthDataType.ACTIVE_ENERGY_BURNED],
        startTime: startOfDay,
        endTime: now,
      );

      int totalCalories = 0;
      for (var point in data) {
        final value = point.value;
        final parsed = int.tryParse(value.toString());
        if (parsed != null) {
          totalCalories += parsed;
        }
      }

      return totalCalories;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting calories: $e');
      }
      return 0;
    }
  }

  /// Get sleep data
  Future<Duration?> getLastNightSleep() async {
    if (_health == null) return null;
    try {
      final now = DateTime.now();
      final start = now.subtract(const Duration(days: 1));

      final data = await _health!.getHealthDataFromTypes(
        types: [HealthDataType.SLEEP_ASLEEP],
        startTime: start,
        endTime: now,
      );

      if (data.isNotEmpty) {
        data.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));
        final sleepPoint = data.first;
        final duration = sleepPoint.dateTo.difference(sleepPoint.dateFrom);
        return duration;
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting sleep: $e');
      }
      return null;
    }
  }

  /// Get all vitals summary
  Future<Map<String, dynamic>> getAllVitals() async {
    if (_health == null) return {};
    try {
      final vitals = <String, dynamic>{};

      final heartRate = await getLatestHeartRate();
      final bloodOxygen = await getLatestBloodOxygen();
      final bloodPressure = await getLatestBloodPressure();
      final temperature = await getLatestTemperature();
      final steps = await getTodaySteps();
      final calories = await getTodayCalories();
      final sleep = await getLastNightSleep();

      vitals['heartRate'] = heartRate;
      vitals['bloodOxygen'] = bloodOxygen;
      vitals['bloodPressureSystolic'] = bloodPressure?['systolic'];
      vitals['bloodPressureDiastolic'] = bloodPressure?['diastolic'];
      vitals['temperature'] = temperature;
      vitals['steps'] = steps;
      vitals['calories'] = calories;
      vitals['sleepHours'] = sleep?.inHours;
      vitals['lastUpdated'] = DateTime.now().toIso8601String();

      return vitals;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting all vitals: $e');
      }
      return {};
    }
  }

  bool get isAvailable => _isAvailable;
  bool get hasPermissions => _hasPermissions;
}

