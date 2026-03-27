import 'package:cloud_firestore/cloud_firestore.dart';

class HealthLog {
  final String? id;
  final String type;   // 'weight' | 'sleep' | 'activity' | 'biomarker'
  final String label;  // e.g. "Weight", "Sleep", "Steps", "LDL"
  final double value;
  final String unit;   // e.g. "kg", "hrs", "steps", "mg/dL"
  final DateTime timestamp;

  const HealthLog({
    this.id,
    required this.type,
    required this.label,
    required this.value,
    required this.unit,
    required this.timestamp,
  });

  factory HealthLog.fromFirestore(String id, Map<String, dynamic> data) {
    return HealthLog(
      id: id,
      type: data['type'] as String? ?? 'weight',
      label: data['label'] as String? ?? '',
      value: (data['value'] as num?)?.toDouble() ?? 0,
      unit: data['unit'] as String? ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'type': type,
        'label': label,
        'value': value,
        'unit': unit,
        'timestamp': Timestamp.fromDate(timestamp),
      };
}
