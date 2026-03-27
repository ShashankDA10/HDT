import 'package:cloud_firestore/cloud_firestore.dart';

class MedicationEntry {
  final int _uid; // unique identity per instance for widget keys
  String name;
  String dosage;
  String frequency;

  MedicationEntry()
      : _uid = DateTime.now().microsecondsSinceEpoch,
        name = '',
        dosage = '',
        frequency = '';

  int get uid => _uid;

  Map<String, dynamic> toMap() => {
        'name': name,
        'dosage': dosage,
        'frequency': frequency,
      };
}

class PatientProfile {
  // Step 1 – Basic Info
  final String   fullName;
  final DateTime dateOfBirth;
  final String   gender;
  final String   bloodGroup;
  final String   height; // cm
  final String   weight; // kg

  // Step 2 – Conditions
  final bool   hasDiabetes;
  final bool   hasHypertension;
  final bool   hasHeartDisease;
  final bool   hasAsthma;
  final bool   hasThyroid;
  final String otherConditions;

  // Step 3 – Allergies
  final String drugAllergies;
  final String foodAllergies;
  final String otherAllergies;

  // Step 4 – Medications
  final List<MedicationEntry> medications;

  // Step 5 – Lifestyle
  final bool   smokes;
  final bool   drinksAlcohol;
  final String exerciseFrequency;
  final String sleepHours;

  // Step 6 – Family History
  final bool   familyDiabetes;
  final bool   familyHeartDisease;
  final bool   familyCancer;
  final String familyOther;

  // Step 7 – Emergency Contact
  final String emergencyName;
  final String emergencyRelationship;
  final String emergencyPhone;

  const PatientProfile({
    required this.fullName,
    required this.dateOfBirth,
    required this.gender,
    required this.bloodGroup,
    required this.height,
    required this.weight,
    this.hasDiabetes      = false,
    this.hasHypertension  = false,
    this.hasHeartDisease  = false,
    this.hasAsthma        = false,
    this.hasThyroid       = false,
    this.otherConditions  = '',
    this.drugAllergies    = '',
    this.foodAllergies    = '',
    this.otherAllergies   = '',
    this.medications      = const [],
    this.smokes           = false,
    this.drinksAlcohol    = false,
    this.exerciseFrequency = '',
    this.sleepHours       = '',
    this.familyDiabetes   = false,
    this.familyHeartDisease = false,
    this.familyCancer     = false,
    this.familyOther      = '',
    required this.emergencyName,
    required this.emergencyRelationship,
    required this.emergencyPhone,
  });

  Map<String, dynamic> toFirestore() => {
        'profileCompleted': true,
        'basicInfo': {
          'fullName':     fullName,
          'dateOfBirth':  Timestamp.fromDate(dateOfBirth),
          'gender':       gender,
          'bloodGroup':   bloodGroup,
          'height':       height,
          'weight':       weight,
        },
        'conditions': {
          'diabetes':     hasDiabetes,
          'hypertension': hasHypertension,
          'heartDisease': hasHeartDisease,
          'asthma':       hasAsthma,
          'thyroid':      hasThyroid,
          'other':        otherConditions,
        },
        'allergies': {
          'drug':  drugAllergies,
          'food':  foodAllergies,
          'other': otherAllergies,
        },
        'medications': medications.map((m) => m.toMap()).toList(),
        'lifestyle': {
          'smokes':            smokes,
          'drinksAlcohol':     drinksAlcohol,
          'exerciseFrequency': exerciseFrequency,
          'sleepHours':        sleepHours,
        },
        'familyHistory': {
          'diabetes':    familyDiabetes,
          'heartDisease': familyHeartDisease,
          'cancer':      familyCancer,
          'other':       familyOther,
        },
        'emergencyContact': {
          'name':         emergencyName,
          'relationship': emergencyRelationship,
          'phone':        emergencyPhone,
        },
      };
}
