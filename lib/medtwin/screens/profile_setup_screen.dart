import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../theme/app_theme.dart';
import '../../widgets/app_scaffold.dart';
import '../services/medtwin_service.dart';

// ─── Goal options (flat list — never split into categories) ───────────────────

const _kAllGoals = [
  'fat_loss',
  'muscle_gain',
  'weight_maintenance',
  'reduce_ldl',
  'improve_hdl',
  'lower_bp',
  'improve_blood_sugar',
  'improve_insulin_sensitivity',
  'heart_health',
  'liver_health',
  'kidney_function',
  'increase_strength',
  'improve_endurance',
  'improve_vo2max',
  'improve_sleep',
  'reduce_stress',
  'build_habits',
];

String _goalLabel(String goal) {
  const map = {
    'fat_loss': 'Fat Loss',
    'muscle_gain': 'Muscle Gain',
    'weight_maintenance': 'Weight Maintenance',
    'reduce_ldl': 'Reduce LDL',
    'improve_hdl': 'Improve HDL',
    'lower_bp': 'Lower BP',
    'improve_blood_sugar': 'Blood Sugar',
    'improve_insulin_sensitivity': 'Insulin Sensitivity',
    'heart_health': 'Heart Health',
    'liver_health': 'Liver Health',
    'kidney_function': 'Kidney Function',
    'increase_strength': 'Strength',
    'improve_endurance': 'Endurance',
    'improve_vo2max': 'VO₂ Max',
    'improve_sleep': 'Sleep',
    'reduce_stress': 'Stress',
    'build_habits': 'Habits',
  };
  return map[goal] ?? goal;
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  int _step = 0;
  bool _saving = false;

  // ── Text controllers ──────────────────────────────────────────────────────
  late final Map<String, TextEditingController> _ctrl;

  // ── Choice fields ─────────────────────────────────────────────────────────
  String? _gender;
  String? _workoutType;
  String? _smokingStatus;

  // ── Tag lists ─────────────────────────────────────────────────────────────
  final List<String> _conditions = [];
  final List<String> _medications = [];
  final List<String> _familyHistory = [];
  final List<String> _allergies = [];

  // ── Goals ─────────────────────────────────────────────────────────────────
  final Set<String> _selectedGoals = {};

  // ── Tag input controllers ─────────────────────────────────────────────────
  final _conditionCtrl = TextEditingController();
  final _medicationCtrl = TextEditingController();
  final _familyCtrl = TextEditingController();
  final _allergyCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ctrl = {
      // Basic
      'age': TextEditingController(),
      'height_cm': TextEditingController(),
      'weight_kg': TextEditingController(),
      'body_fat_pct': TextEditingController(),
      'waist_cm': TextEditingController(),
      // Vitals
      'resting_heart_rate': TextEditingController(),
      'bp_systolic': TextEditingController(),
      'bp_diastolic': TextEditingController(),
      'spo2_pct': TextEditingController(),
      'body_temp_c': TextEditingController(),
      // Labs
      'fasting_glucose': TextEditingController(),
      'hba1c': TextEditingController(),
      'fasting_insulin': TextEditingController(),
      'total_cholesterol': TextEditingController(),
      'ldl': TextEditingController(),
      'hdl': TextEditingController(),
      'triglycerides': TextEditingController(),
      'alt': TextEditingController(),
      'ast': TextEditingController(),
      'bilirubin': TextEditingController(),
      'creatinine': TextEditingController(),
      'bun': TextEditingController(),
      'egfr': TextEditingController(),
      'testosterone': TextEditingController(),
      'estrogen': TextEditingController(),
      'tsh': TextEditingController(),
      'cortisol': TextEditingController(),
      // Lifestyle
      'daily_steps': TextEditingController(),
      'workout_frequency_per_week': TextEditingController(),
      'sleep_duration_hrs': TextEditingController(),
      'sleep_quality': TextEditingController(),
      'stress_level': TextEditingController(),
      'water_intake_liters': TextEditingController(),
      'alcohol_units_per_week': TextEditingController(),
      // Nutrition
      'daily_calories': TextEditingController(),
      'protein_g': TextEditingController(),
      'fiber_g': TextEditingController(),
      'fat_g': TextEditingController(),
      'sugar_g': TextEditingController(),
    };
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final cached = await MedTwinService.getCachedProfile();
    if (cached == null || !mounted) return;
    final data = cached.toFirestore();
    for (final entry in _ctrl.entries) {
      final v = data[entry.key];
      if (v != null) entry.value.text = v.toString();
    }
    setState(() {
      _gender = data['gender'] as String?;
      _workoutType = data['workout_type'] as String?;
      _smokingStatus = data['smoking_status'] as String?;
      if (data['lifestyle_goals'] is List) {
        _selectedGoals.addAll(
            (data['lifestyle_goals'] as List).map((e) => e.toString()));
      }
    });
  }

  @override
  void dispose() {
    for (final c in _ctrl.values) { c.dispose(); }
    _conditionCtrl.dispose();
    _medicationCtrl.dispose();
    _familyCtrl.dispose();
    _allergyCtrl.dispose();
    super.dispose();
  }

  // ── Build payload (only non-empty fields) ─────────────────────────────────
  Map<String, dynamic> _buildPayload() {
    final data = <String, dynamic>{};

    void addNum(String key, {bool isInt = false}) {
      final t = _ctrl[key]?.text.trim() ?? '';
      if (t.isEmpty) return;
      if (isInt) {
        final v = int.tryParse(t);
        if (v != null) data[key] = v;
      } else {
        final v = double.tryParse(t);
        if (v != null) data[key] = v;
      }
    }

    addNum('age', isInt: true);
    if (_gender != null) data['gender'] = _gender;
    addNum('height_cm');
    addNum('weight_kg');
    addNum('body_fat_pct');
    addNum('waist_cm');
    addNum('resting_heart_rate', isInt: true);
    addNum('bp_systolic', isInt: true);
    addNum('bp_diastolic', isInt: true);
    addNum('spo2_pct');
    addNum('body_temp_c');
    addNum('fasting_glucose');
    addNum('hba1c');
    addNum('fasting_insulin');
    addNum('total_cholesterol');
    addNum('ldl');
    addNum('hdl');
    addNum('triglycerides');
    addNum('alt');
    addNum('ast');
    addNum('bilirubin');
    addNum('creatinine');
    addNum('bun');
    addNum('egfr');
    addNum('testosterone');
    addNum('estrogen');
    addNum('tsh');
    addNum('cortisol');
    addNum('daily_steps', isInt: true);
    addNum('workout_frequency_per_week', isInt: true);
    if (_workoutType != null) data['workout_type'] = _workoutType;
    addNum('sleep_duration_hrs');
    addNum('sleep_quality', isInt: true);
    addNum('stress_level', isInt: true);
    addNum('water_intake_liters');
    if (_smokingStatus != null) data['smoking_status'] = _smokingStatus;
    addNum('alcohol_units_per_week', isInt: true);
    addNum('daily_calories', isInt: true);
    addNum('protein_g');
    addNum('fiber_g');
    addNum('fat_g');
    addNum('sugar_g');
    if (_conditions.isNotEmpty) data['conditions'] = _conditions;
    if (_medications.isNotEmpty) data['medications'] = _medications;
    if (_familyHistory.isNotEmpty) data['family_history'] = _familyHistory;
    if (_allergies.isNotEmpty) data['allergies'] = _allergies;
    if (_selectedGoals.isNotEmpty) {
      data['lifestyle_goals'] = _selectedGoals.toList();
    }
    return data;
  }

  Future<void> _saveStep() async {
    setState(() => _saving = true);
    try {
      await MedTwinService.saveProfile(_buildPayload());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.danger,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _nextStep() async {
    await _saveStep();
    if (!mounted) return;
    if (_step < 4) {
      setState(() => _step++);
    } else {
      Navigator.of(context).pop();
    }
  }

  void _prevStep() {
    if (_step > 0) setState(() => _step--);
  }

  // ── Step titles ───────────────────────────────────────────────────────────
  static const _stepTitles = [
    'Basic Info',
    'Vitals',
    'Lab Results',
    'Lifestyle & Goals',
    'Medical History',
  ];

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        title: const Text('Profile Setup'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          // Step indicator
          _StepIndicator(current: _step, total: 5),
          const SizedBox(height: 4),
          Text(
            _stepTitles[_step],
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),

          // Step content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _buildCurrentStep(),
              ),
            ),
          ),

          // Navigation buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
            child: Row(
              children: [
                if (_step > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving ? null : _prevStep,
                      child: const Text('Back'),
                    ),
                  ),
                if (_step > 0) const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _nextStep,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.ink,
                            ),
                          )
                        : Text(_step < 4 ? 'Save & Next' : 'Save & Finish'),
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: _saving
                      ? null
                      : () {
                          if (_step < 4) {
                            setState(() => _step++);
                          } else {
                            Navigator.of(context).pop();
                          }
                        },
                  child: const Text('Skip'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_step) {
      case 0:
        return _Step0Basic(ctrl: _ctrl, gender: _gender, onGender: (v) => setState(() => _gender = v));
      case 1:
        return _Step1Vitals(ctrl: _ctrl);
      case 2:
        return _Step2Labs(ctrl: _ctrl);
      case 3:
        return _Step3Lifestyle(
          ctrl: _ctrl,
          workoutType: _workoutType,
          smokingStatus: _smokingStatus,
          selectedGoals: _selectedGoals,
          onWorkoutType: (v) => setState(() => _workoutType = v),
          onSmokingStatus: (v) => setState(() => _smokingStatus = v),
          onGoalToggle: (g, v) => setState(() => v ? _selectedGoals.add(g) : _selectedGoals.remove(g)),
        );
      case 4:
        return _Step4Medical(
          conditions: _conditions,
          medications: _medications,
          familyHistory: _familyHistory,
          allergies: _allergies,
          conditionCtrl: _conditionCtrl,
          medicationCtrl: _medicationCtrl,
          familyCtrl: _familyCtrl,
          allergyCtrl: _allergyCtrl,
          onUpdate: () => setState(() {}),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

// ─── Step indicator ───────────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  final int current;
  final int total;

  const _StepIndicator({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: List.generate(total, (i) {
          final active = i == current;
          final done = i < current;
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              height: 4,
              decoration: BoxDecoration(
                color: done || active ? AppColors.accent : AppColors.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─── Helper widgets ───────────────────────────────────────────────────────────

class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputType inputType;

  const _FormField({
    required this.controller,
    required this.label,
    this.hint,
    this.inputType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppColors.muted, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: inputType,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
        ),
        const SizedBox(height: 14),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.accent,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
      ),
    );
  }
}

Widget _choiceRow(
  BuildContext context, {
  required String label,
  required List<String> options,
  required String? selected,
  required void Function(String?) onChanged,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: AppColors.muted, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 6),
      Wrap(
        spacing: 8,
        children: options.map((opt) {
          final sel = selected == opt;
          return ChoiceChip(
            label: Text(opt),
            selected: sel,
            onSelected: (v) => onChanged(v ? opt : null),
            selectedColor: AppColors.accent.withOpacity(0.2),
            labelStyle: TextStyle(
              color: sel ? AppColors.accent : Colors.white70,
              fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
            ),
          );
        }).toList(),
      ),
      const SizedBox(height: 14),
    ],
  );
}

// ─── Tag input ────────────────────────────────────────────────────────────────

class _TagInput extends StatelessWidget {
  final String label;
  final List<String> tags;
  final TextEditingController controller;
  final VoidCallback onUpdate;

  const _TagInput({
    required this.label,
    required this.tags,
    required this.controller,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppColors.muted, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Type and press +',
                  hintStyle: const TextStyle(color: AppColors.muted, fontSize: 13),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.add_circle_outline,
                        color: AppColors.accent),
                    onPressed: () {
                      final v = controller.text.trim();
                      if (v.isNotEmpty && !tags.contains(v)) {
                        tags.add(v);
                        controller.clear();
                        onUpdate();
                      }
                    },
                  ),
                ),
                onSubmitted: (v) {
                  final t = v.trim();
                  if (t.isNotEmpty && !tags.contains(t)) {
                    tags.add(t);
                    controller.clear();
                    onUpdate();
                  }
                },
              ),
            ),
          ],
        ),
        if (tags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: tags.map((tag) {
              return Chip(
                label: Text(
                  tag,
                  style: const TextStyle(fontSize: 12),
                ),
                deleteIcon: const Icon(Icons.close, size: 14),
                onDeleted: () {
                  tags.remove(tag);
                  onUpdate();
                },
                backgroundColor: AppColors.surfaceElevated,
              );
            }).toList(),
          ),
        ],
        const SizedBox(height: 14),
      ],
    );
  }
}

// ─── Step 0 — Basic ───────────────────────────────────────────────────────────

class _Step0Basic extends StatelessWidget {
  final Map<String, TextEditingController> ctrl;
  final String? gender;
  final void Function(String?) onGender;

  const _Step0Basic({
    required this.ctrl,
    required this.gender,
    required this.onGender,
  });

  @override
  Widget build(BuildContext context) {
    const num = TextInputType.numberWithOptions(decimal: true);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FormField(controller: ctrl['age']!, label: 'Age', hint: 'e.g. 32', inputType: num),
        _choiceRow(context, label: 'Gender', options: ['Male', 'Female', 'Other'], selected: gender, onChanged: onGender),
        _FormField(controller: ctrl['height_cm']!, label: 'Height (cm)', hint: 'e.g. 175', inputType: num),
        _FormField(controller: ctrl['weight_kg']!, label: 'Weight (kg)', hint: 'e.g. 72.5', inputType: num),
        _FormField(controller: ctrl['body_fat_pct']!, label: 'Body fat % (optional)', hint: 'e.g. 18', inputType: num),
        _FormField(controller: ctrl['waist_cm']!, label: 'Waist circumference (cm, optional)', hint: 'e.g. 82', inputType: num),
        const SizedBox(height: 20),
      ],
    ).animate().fadeIn(duration: 300.ms);
  }
}

// ─── Step 1 — Vitals ─────────────────────────────────────────────────────────

class _Step1Vitals extends StatelessWidget {
  final Map<String, TextEditingController> ctrl;

  const _Step1Vitals({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    const num = TextInputType.numberWithOptions(decimal: true);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FormField(controller: ctrl['resting_heart_rate']!, label: 'Resting heart rate (bpm)', hint: 'e.g. 65', inputType: num),
        Row(
          children: [
            Expanded(child: _FormField(controller: ctrl['bp_systolic']!, label: 'BP Systolic', hint: '120', inputType: num)),
            const SizedBox(width: 12),
            Expanded(child: _FormField(controller: ctrl['bp_diastolic']!, label: 'BP Diastolic', hint: '80', inputType: num)),
          ],
        ),
        _FormField(controller: ctrl['spo2_pct']!, label: 'SpO₂ (%)', hint: 'e.g. 98', inputType: num),
        _FormField(controller: ctrl['body_temp_c']!, label: 'Body temperature (°C)', hint: 'e.g. 36.6', inputType: num),
        const SizedBox(height: 20),
      ],
    ).animate().fadeIn(duration: 300.ms);
  }
}

// ─── Step 2 — Labs ────────────────────────────────────────────────────────────

class _Step2Labs extends StatelessWidget {
  final Map<String, TextEditingController> ctrl;

  const _Step2Labs({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    const num = TextInputType.numberWithOptions(decimal: true);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Metabolic'),
        _FormField(controller: ctrl['fasting_glucose']!, label: 'Fasting glucose (mg/dL)', inputType: num),
        _FormField(controller: ctrl['hba1c']!, label: 'HbA1c (%)', hint: 'e.g. 5.4', inputType: num),
        _FormField(controller: ctrl['fasting_insulin']!, label: 'Fasting insulin (µIU/mL)', inputType: num),
        _FormField(controller: ctrl['total_cholesterol']!, label: 'Total cholesterol (mg/dL)', inputType: num),
        Row(
          children: [
            Expanded(child: _FormField(controller: ctrl['ldl']!, label: 'LDL (mg/dL)', inputType: num)),
            const SizedBox(width: 12),
            Expanded(child: _FormField(controller: ctrl['hdl']!, label: 'HDL (mg/dL)', inputType: num)),
          ],
        ),
        _FormField(controller: ctrl['triglycerides']!, label: 'Triglycerides (mg/dL)', inputType: num),

        const _SectionLabel('Liver'),
        Row(
          children: [
            Expanded(child: _FormField(controller: ctrl['alt']!, label: 'ALT (U/L)', inputType: num)),
            const SizedBox(width: 12),
            Expanded(child: _FormField(controller: ctrl['ast']!, label: 'AST (U/L)', inputType: num)),
          ],
        ),
        _FormField(controller: ctrl['bilirubin']!, label: 'Bilirubin (mg/dL)', inputType: num),

        const _SectionLabel('Kidney'),
        _FormField(controller: ctrl['creatinine']!, label: 'Creatinine (mg/dL)', inputType: num),
        Row(
          children: [
            Expanded(child: _FormField(controller: ctrl['bun']!, label: 'BUN (mg/dL)', inputType: num)),
            const SizedBox(width: 12),
            Expanded(child: _FormField(controller: ctrl['egfr']!, label: 'eGFR (mL/min)', inputType: num)),
          ],
        ),

        const _SectionLabel('Hormonal'),
        Row(
          children: [
            Expanded(child: _FormField(controller: ctrl['testosterone']!, label: 'Testosterone (ng/dL)', inputType: num)),
            const SizedBox(width: 12),
            Expanded(child: _FormField(controller: ctrl['estrogen']!, label: 'Estrogen (pg/mL)', inputType: num)),
          ],
        ),
        Row(
          children: [
            Expanded(child: _FormField(controller: ctrl['tsh']!, label: 'TSH (mIU/L)', inputType: num)),
            const SizedBox(width: 12),
            Expanded(child: _FormField(controller: ctrl['cortisol']!, label: 'Cortisol (µg/dL)', inputType: num)),
          ],
        ),
        const SizedBox(height: 20),
      ],
    ).animate().fadeIn(duration: 300.ms);
  }
}

// ─── Step 3 — Lifestyle & Goals ──────────────────────────────────────────────

class _Step3Lifestyle extends StatelessWidget {
  final Map<String, TextEditingController> ctrl;
  final String? workoutType;
  final String? smokingStatus;
  final Set<String> selectedGoals;
  final void Function(String?) onWorkoutType;
  final void Function(String?) onSmokingStatus;
  final void Function(String, bool) onGoalToggle;

  const _Step3Lifestyle({
    required this.ctrl,
    required this.workoutType,
    required this.smokingStatus,
    required this.selectedGoals,
    required this.onWorkoutType,
    required this.onSmokingStatus,
    required this.onGoalToggle,
  });

  @override
  Widget build(BuildContext context) {
    const num = TextInputType.numberWithOptions(decimal: true);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Activity'),
        _FormField(controller: ctrl['daily_steps']!, label: 'Daily steps', hint: 'e.g. 8000', inputType: num),
        _FormField(controller: ctrl['workout_frequency_per_week']!, label: 'Workouts per week', hint: 'e.g. 4', inputType: num),
        _choiceRow(context,
            label: 'Workout type',
            options: ['Cardio', 'Weights', 'Mixed', 'Yoga', 'Sports', 'None'],
            selected: workoutType,
            onChanged: onWorkoutType),

        const _SectionLabel('Sleep & Stress'),
        _FormField(controller: ctrl['sleep_duration_hrs']!, label: 'Sleep duration (hrs)', hint: 'e.g. 7.5', inputType: num),
        _FormField(controller: ctrl['sleep_quality']!, label: 'Sleep quality (1–10)', hint: 'e.g. 7', inputType: num),
        _FormField(controller: ctrl['stress_level']!, label: 'Stress level (1–10)', hint: 'e.g. 5', inputType: num),

        const _SectionLabel('Habits'),
        _FormField(controller: ctrl['water_intake_liters']!, label: 'Water intake (L/day)', hint: 'e.g. 2.5', inputType: num),
        _choiceRow(context,
            label: 'Smoking status',
            options: ['Never', 'Former', 'Current'],
            selected: smokingStatus,
            onChanged: onSmokingStatus),
        _FormField(controller: ctrl['alcohol_units_per_week']!, label: 'Alcohol (units/week)', hint: 'e.g. 3', inputType: num),

        const _SectionLabel('Nutrition'),
        _FormField(controller: ctrl['daily_calories']!, label: 'Daily calories (kcal)', hint: 'e.g. 2000', inputType: num),
        Row(
          children: [
            Expanded(child: _FormField(controller: ctrl['protein_g']!, label: 'Protein (g)', inputType: num)),
            const SizedBox(width: 12),
            Expanded(child: _FormField(controller: ctrl['fiber_g']!, label: 'Fiber (g)', inputType: num)),
          ],
        ),
        Row(
          children: [
            Expanded(child: _FormField(controller: ctrl['fat_g']!, label: 'Fat (g)', inputType: num)),
            const SizedBox(width: 12),
            Expanded(child: _FormField(controller: ctrl['sugar_g']!, label: 'Sugar (g)', inputType: num)),
          ],
        ),

        const _SectionLabel('Goals'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _kAllGoals.map((goal) {
            final selected = selectedGoals.contains(goal);
            return FilterChip(
              label: Text(_goalLabel(goal)),
              selected: selected,
              onSelected: (v) => onGoalToggle(goal, v),
              selectedColor: AppColors.accent.withOpacity(0.2),
              checkmarkColor: AppColors.accent,
              labelStyle: TextStyle(
                color: selected ? AppColors.accent : Colors.white70,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 12,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
      ],
    ).animate().fadeIn(duration: 300.ms);
  }
}

// ─── Step 4 — Medical ─────────────────────────────────────────────────────────

class _Step4Medical extends StatelessWidget {
  final List<String> conditions;
  final List<String> medications;
  final List<String> familyHistory;
  final List<String> allergies;
  final TextEditingController conditionCtrl;
  final TextEditingController medicationCtrl;
  final TextEditingController familyCtrl;
  final TextEditingController allergyCtrl;
  final VoidCallback onUpdate;

  const _Step4Medical({
    required this.conditions,
    required this.medications,
    required this.familyHistory,
    required this.allergies,
    required this.conditionCtrl,
    required this.medicationCtrl,
    required this.familyCtrl,
    required this.allergyCtrl,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TagInput(label: 'Medical conditions', tags: conditions, controller: conditionCtrl, onUpdate: onUpdate),
        _TagInput(label: 'Current medications', tags: medications, controller: medicationCtrl, onUpdate: onUpdate),
        _TagInput(label: 'Family history', tags: familyHistory, controller: familyCtrl, onUpdate: onUpdate),
        _TagInput(label: 'Allergies', tags: allergies, controller: allergyCtrl, onUpdate: onUpdate),
        const SizedBox(height: 20),
      ],
    ).animate().fadeIn(duration: 300.ms);
  }
}
