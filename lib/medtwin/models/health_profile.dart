import 'package:cloud_firestore/cloud_firestore.dart';

class HealthProfile {
  // Basic
  final int? age;
  final String? gender;
  final double? heightCm;
  final double? weightKg;
  final double? bodyFatPct;
  final double? waistCm;

  // Vitals
  final int? restingHeartRate;
  final int? bpSystolic;
  final int? bpDiastolic;
  final double? spo2Pct;
  final double? bodyTempC;

  // Metabolic
  final double? fastingGlucose;
  final double? hba1c;
  final double? fastingInsulin;
  final double? totalCholesterol;
  final double? ldl;
  final double? hdl;
  final double? triglycerides;

  // Liver
  final double? alt;
  final double? ast;
  final double? bilirubin;

  // Kidney
  final double? creatinine;
  final double? bun;
  final double? egfr;

  // Hormonal
  final double? testosterone;
  final double? estrogen;
  final double? tsh;
  final double? cortisol;

  // Lifestyle
  final int? dailySteps;
  final int? workoutFrequencyPerWeek;
  final String? workoutType;
  final double? sleepDurationHrs;
  final int? sleepQuality;
  final int? stressLevel;
  final double? waterIntakeLiters;
  final String? smokingStatus;
  final int? alcoholUnitsPerWeek;

  // Nutrition
  final int? dailyCalories;
  final double? proteinG;
  final double? fiberG;
  final double? fatG;
  final double? sugarG;

  // Medical
  final List<String> conditions;
  final List<String> medications;
  final List<String> familyHistory;
  final List<String> allergies;

  // Goals — single flat list, never split into categories
  final List<String> lifestyleGoals;

  const HealthProfile({
    this.age,
    this.gender,
    this.heightCm,
    this.weightKg,
    this.bodyFatPct,
    this.waistCm,
    this.restingHeartRate,
    this.bpSystolic,
    this.bpDiastolic,
    this.spo2Pct,
    this.bodyTempC,
    this.fastingGlucose,
    this.hba1c,
    this.fastingInsulin,
    this.totalCholesterol,
    this.ldl,
    this.hdl,
    this.triglycerides,
    this.alt,
    this.ast,
    this.bilirubin,
    this.creatinine,
    this.bun,
    this.egfr,
    this.testosterone,
    this.estrogen,
    this.tsh,
    this.cortisol,
    this.dailySteps,
    this.workoutFrequencyPerWeek,
    this.workoutType,
    this.sleepDurationHrs,
    this.sleepQuality,
    this.stressLevel,
    this.waterIntakeLiters,
    this.smokingStatus,
    this.alcoholUnitsPerWeek,
    this.dailyCalories,
    this.proteinG,
    this.fiberG,
    this.fatG,
    this.sugarG,
    this.conditions = const [],
    this.medications = const [],
    this.familyHistory = const [],
    this.allergies = const [],
    this.lifestyleGoals = const [],
  });

  double? get bmi {
    if (weightKg == null || heightCm == null || heightCm! <= 0) return null;
    final h = heightCm! / 100;
    return weightKg! / (h * h);
  }

  String get bmiCategory {
    final b = bmi;
    if (b == null) return '';
    if (b < 18.5) return 'Underweight';
    if (b < 25) return 'Normal';
    if (b < 30) return 'Overweight';
    return 'Obese';
  }

  factory HealthProfile.fromFirestore(Map<String, dynamic> data) {
    double? d(String k) => (data[k] as num?)?.toDouble();
    int? i(String k) => (data[k] as num?)?.toInt();
    String? s(String k) => data[k] as String?;
    List<String> lst(String k) =>
        (data[k] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

    return HealthProfile(
      age: i('age'),
      gender: s('gender'),
      heightCm: d('height_cm'),
      weightKg: d('weight_kg'),
      bodyFatPct: d('body_fat_pct'),
      waistCm: d('waist_cm'),
      restingHeartRate: i('resting_heart_rate'),
      bpSystolic: i('bp_systolic'),
      bpDiastolic: i('bp_diastolic'),
      spo2Pct: d('spo2_pct'),
      bodyTempC: d('body_temp_c'),
      fastingGlucose: d('fasting_glucose'),
      hba1c: d('hba1c'),
      fastingInsulin: d('fasting_insulin'),
      totalCholesterol: d('total_cholesterol'),
      ldl: d('ldl'),
      hdl: d('hdl'),
      triglycerides: d('triglycerides'),
      alt: d('alt'),
      ast: d('ast'),
      bilirubin: d('bilirubin'),
      creatinine: d('creatinine'),
      bun: d('bun'),
      egfr: d('egfr'),
      testosterone: d('testosterone'),
      estrogen: d('estrogen'),
      tsh: d('tsh'),
      cortisol: d('cortisol'),
      dailySteps: i('daily_steps'),
      workoutFrequencyPerWeek: i('workout_frequency_per_week'),
      workoutType: s('workout_type'),
      sleepDurationHrs: d('sleep_duration_hrs'),
      sleepQuality: i('sleep_quality'),
      stressLevel: i('stress_level'),
      waterIntakeLiters: d('water_intake_liters'),
      smokingStatus: s('smoking_status'),
      alcoholUnitsPerWeek: i('alcohol_units_per_week'),
      dailyCalories: i('daily_calories'),
      proteinG: d('protein_g'),
      fiberG: d('fiber_g'),
      fatG: d('fat_g'),
      sugarG: d('sugar_g'),
      conditions: lst('conditions'),
      medications: lst('medications'),
      familyHistory: lst('family_history'),
      allergies: lst('allergies'),
      lifestyleGoals: lst('lifestyle_goals'),
    );
  }

  Map<String, dynamic> toFirestore() {
    final map = <String, dynamic>{};
    void add(String k, dynamic v) {
      if (v != null) map[k] = v;
    }
    void addList(String k, List<String> v) {
      if (v.isNotEmpty) map[k] = v;
    }

    add('age', age);
    add('gender', gender);
    add('height_cm', heightCm);
    add('weight_kg', weightKg);
    add('body_fat_pct', bodyFatPct);
    add('waist_cm', waistCm);
    add('resting_heart_rate', restingHeartRate);
    add('bp_systolic', bpSystolic);
    add('bp_diastolic', bpDiastolic);
    add('spo2_pct', spo2Pct);
    add('body_temp_c', bodyTempC);
    add('fasting_glucose', fastingGlucose);
    add('hba1c', hba1c);
    add('fasting_insulin', fastingInsulin);
    add('total_cholesterol', totalCholesterol);
    add('ldl', ldl);
    add('hdl', hdl);
    add('triglycerides', triglycerides);
    add('alt', alt);
    add('ast', ast);
    add('bilirubin', bilirubin);
    add('creatinine', creatinine);
    add('bun', bun);
    add('egfr', egfr);
    add('testosterone', testosterone);
    add('estrogen', estrogen);
    add('tsh', tsh);
    add('cortisol', cortisol);
    add('daily_steps', dailySteps);
    add('workout_frequency_per_week', workoutFrequencyPerWeek);
    add('workout_type', workoutType);
    add('sleep_duration_hrs', sleepDurationHrs);
    add('sleep_quality', sleepQuality);
    add('stress_level', stressLevel);
    add('water_intake_liters', waterIntakeLiters);
    add('smoking_status', smokingStatus);
    add('alcohol_units_per_week', alcoholUnitsPerWeek);
    add('daily_calories', dailyCalories);
    add('protein_g', proteinG);
    add('fiber_g', fiberG);
    add('fat_g', fatG);
    add('sugar_g', sugarG);
    addList('conditions', conditions);
    addList('medications', medications);
    addList('family_history', familyHistory);
    addList('allergies', allergies);
    addList('lifestyle_goals', lifestyleGoals);
    map['updated_at'] = FieldValue.serverTimestamp();
    return map;
  }
}
