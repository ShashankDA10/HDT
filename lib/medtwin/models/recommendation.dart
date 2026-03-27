class OTCSuggestion {
  final String name;
  final String purpose;
  final String dosage;
  final String notes;

  const OTCSuggestion({
    required this.name,
    required this.purpose,
    required this.dosage,
    this.notes = '',
  });

  factory OTCSuggestion.fromJson(Map<String, dynamic> json) => OTCSuggestion(
        name: json['name'] as String? ?? '',
        purpose: json['purpose'] as String? ?? '',
        dosage: json['dosage'] as String? ?? '',
        notes: json['notes'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'purpose': purpose,
        'dosage': dosage,
        'notes': notes,
      };
}

class ActionPlan {
  final List<String> diet;
  final List<String> training;
  final List<String> lifestyle;

  const ActionPlan({
    required this.diet,
    required this.training,
    required this.lifestyle,
  });

  factory ActionPlan.fromJson(Map<String, dynamic> json) => ActionPlan(
        diet: _strings(json['diet']),
        training: _strings(json['training']),
        lifestyle: _strings(json['lifestyle']),
      );

  Map<String, dynamic> toJson() => {
        'diet': diet,
        'training': training,
        'lifestyle': lifestyle,
      };
}

class AIRecommendation {
  final List<String> keyIssues;
  final List<String> rootCauses;
  final ActionPlan actionPlan;
  final List<OTCSuggestion> otcSuggestions;
  final String expectedTimeline;
  final List<String> warnings;
  final bool suggestAppointment;

  const AIRecommendation({
    required this.keyIssues,
    required this.rootCauses,
    required this.actionPlan,
    this.otcSuggestions = const [],
    required this.expectedTimeline,
    required this.warnings,
    this.suggestAppointment = false,
  });

  factory AIRecommendation.fromJson(Map<String, dynamic> json) =>
      AIRecommendation(
        keyIssues: _strings(json['key_issues']),
        rootCauses: _strings(json['root_causes']),
        actionPlan: ActionPlan.fromJson(
            (json['action_plan'] as Map<String, dynamic>?) ?? {}),
        otcSuggestions: (json['otc_suggestions'] as List<dynamic>?)
                ?.map((e) => OTCSuggestion.fromJson(
                    Map<String, dynamic>.from(e as Map)))
                .toList() ??
            [],
        expectedTimeline: json['expected_timeline'] as String? ?? '',
        warnings: _strings(json['warnings']),
        suggestAppointment: json['suggest_appointment'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'key_issues': keyIssues,
        'root_causes': rootCauses,
        'action_plan': actionPlan.toJson(),
        'otc_suggestions': otcSuggestions.map((s) => s.toJson()).toList(),
        'expected_timeline': expectedTimeline,
        'warnings': warnings,
        'suggest_appointment': suggestAppointment,
      };
}

List<String> _strings(dynamic raw) =>
    (raw as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
