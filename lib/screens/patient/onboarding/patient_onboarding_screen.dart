import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/app_user.dart';
import '../../../models/patient_profile.dart';
import '../../../services/patient_profile_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/app_scaffold.dart';
import '../../splash_screen.dart';

// ── Constants ─────────────────────────────────────────────────────────────────

const _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-', 'Unknown'];
const _genders     = ['Male', 'Female', 'Other', 'Prefer not to say'];
const _exerciseOpts = ['Never', '1–2x / week', '3–4x / week', '5+ / week', 'Daily'];

const _titles = [
  'Basic Information',
  'Pre-existing Conditions',
  'Allergies',
  'Current Medications',
  'Lifestyle',
  'Family History',
  'Emergency Contact',
  'Review & Submit',
];

const _icons = [
  Icons.person_outline,
  Icons.medical_information_outlined,
  Icons.warning_amber_outlined,
  Icons.medication_outlined,
  Icons.self_improvement,
  Icons.family_restroom,
  Icons.phone_outlined,
  Icons.check_circle_outline,
];

const _colors = [
  AppColors.accent,
  AppColors.accentBlue,
  AppColors.accentAmber,
  AppColors.accentViolet,
  AppColors.success,
  AppColors.accentRose,
  AppColors.accentBlue,
  AppColors.accent,
];

// ── Screen ────────────────────────────────────────────────────────────────────

class PatientOnboardingScreen extends StatefulWidget {
  final AppUser user;
  const PatientOnboardingScreen({super.key, required this.user});

  @override
  State<PatientOnboardingScreen> createState() => _PatientOnboardingScreenState();
}

class _PatientOnboardingScreenState extends State<PatientOnboardingScreen> {
  final _pageCtrl  = PageController();
  int  _page       = 0;
  bool _saving     = false;

  // ── Step 1 ─────────────────────────────────────────────────────────────────
  final _step1Key   = GlobalKey<FormState>();
  final _nameCtrl   = TextEditingController();
  DateTime? _dob;
  String _gender     = 'Male';
  String _bloodGroup = 'A+';
  final _heightCtrl  = TextEditingController();
  final _weightCtrl  = TextEditingController();

  // ── Step 2 ─────────────────────────────────────────────────────────────────
  bool   _diabetes    = false;
  bool   _hypertension = false;
  bool   _heartDisease = false;
  bool   _asthma      = false;
  bool   _thyroid     = false;
  final  _condOtherCtrl = TextEditingController();

  // ── Step 3 ─────────────────────────────────────────────────────────────────
  final _drugAllergyCtrl  = TextEditingController();
  final _foodAllergyCtrl  = TextEditingController();
  final _otherAllergyCtrl = TextEditingController();

  // ── Step 4 ─────────────────────────────────────────────────────────────────
  final List<MedicationEntry> _meds = [];

  // ── Step 5 ─────────────────────────────────────────────────────────────────
  bool   _smokes      = false;
  bool   _drinks      = false;
  String _exerciseFreq = 'Never';
  final  _sleepCtrl   = TextEditingController();

  // ── Step 6 ─────────────────────────────────────────────────────────────────
  bool   _famDiabetes = false;
  bool   _famHeart    = false;
  bool   _famCancer   = false;
  final  _famOtherCtrl = TextEditingController();

  // ── Step 7 ─────────────────────────────────────────────────────────────────
  final _step7Key   = GlobalKey<FormState>();
  final _ecNameCtrl = TextEditingController();
  final _ecRelCtrl  = TextEditingController();
  final _ecPhoneCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = widget.user.name;
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    for (final c in [
      _nameCtrl, _heightCtrl, _weightCtrl, _condOtherCtrl,
      _drugAllergyCtrl, _foodAllergyCtrl, _otherAllergyCtrl,
      _sleepCtrl, _famOtherCtrl, _ecNameCtrl, _ecRelCtrl, _ecPhoneCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  void _next() {
    if (_page == 0) {
      if (!(_step1Key.currentState?.validate() ?? false)) return;
      if (_dob == null) {
        _snack('Please select your date of birth', AppColors.danger);
        return;
      }
    }
    if (_page == 6 && !(_step7Key.currentState?.validate() ?? false)) return;

    _pageCtrl.animateToPage(
      _page + 1,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  void _back() => _pageCtrl.animateToPage(
        _page - 1,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );

  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      final profile = PatientProfile(
        fullName:            _nameCtrl.text.trim(),
        dateOfBirth:         _dob!,
        gender:              _gender,
        bloodGroup:          _bloodGroup,
        height:              _heightCtrl.text.trim(),
        weight:              _weightCtrl.text.trim(),
        hasDiabetes:         _diabetes,
        hasHypertension:     _hypertension,
        hasHeartDisease:     _heartDisease,
        hasAsthma:           _asthma,
        hasThyroid:          _thyroid,
        otherConditions:     _condOtherCtrl.text.trim(),
        drugAllergies:       _drugAllergyCtrl.text.trim(),
        foodAllergies:       _foodAllergyCtrl.text.trim(),
        otherAllergies:      _otherAllergyCtrl.text.trim(),
        medications:         _meds,
        smokes:              _smokes,
        drinksAlcohol:       _drinks,
        exerciseFrequency:   _exerciseFreq,
        sleepHours:          _sleepCtrl.text.trim(),
        familyDiabetes:      _famDiabetes,
        familyHeartDisease:  _famHeart,
        familyCancer:        _famCancer,
        familyOther:         _famOtherCtrl.text.trim(),
        emergencyName:       _ecNameCtrl.text.trim(),
        emergencyRelationship: _ecRelCtrl.text.trim(),
        emergencyPhone:      _ecPhoneCtrl.text.trim(),
      );
      await PatientProfileService.saveProfile(widget.user.id, profile);
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const SplashScreen()),
          (_) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _snack('Failed to save: $e', AppColors.danger);
      }
    }
  }

  void _snack(String msg, Color bg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: bg),
    );
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 25),
      firstDate: DateTime(now.year - 120),
      lastDate: DateTime(now.year - 1),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary:   AppColors.accent,
            onPrimary: AppColors.ink,
            surface:   AppColors.surfaceElevated,
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dob = picked);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: PageView(
                controller: _pageCtrl,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _buildStep1(),
                  _buildStep2(),
                  _buildStep3(),
                  _buildStep4(),
                  _buildStep5(),
                  _buildStep6(),
                  _buildStep7(),
                  _buildReview(),
                ],
              ),
            ),
            _buildNavBar(),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final color    = _colors[_page];
    final progress = (_page + 1) / 8;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_icons[_page], color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_titles[_page],
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                Text('Step ${_page + 1} of 8',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12)),
              ]),
            ),
          ]),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  // ── Nav Bar ───────────────────────────────────────────────────────────────

  Widget _buildNavBar() {
    final isLast = _page == 7;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Colors.white10))),
      child: Row(children: [
        if (_page > 0) ...[
          Expanded(
            child: OutlinedButton(
              onPressed: _back,
              child: const Text('Back'),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: _saving ? null : (isLast ? _submit : _next),
            child: _saving
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink))
                : Text(isLast ? 'Submit' : 'Continue',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }

  // ── Step 1 · Basic Information ────────────────────────────────────────────

  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Form(
        key: _step1Key,
        child: Column(children: [
          // Name
          TextFormField(
            controller: _nameCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: _decor('Full Name', 'Jane Doe'),
            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 14),

          // Date of Birth
          GestureDetector(
            onTap: _pickDob,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(children: [
                Icon(Icons.calendar_today,
                    size: 16, color: Colors.white.withValues(alpha: 0.45)),
                const SizedBox(width: 10),
                Text(
                  _dob == null
                      ? 'Date of Birth'
                      : '${_dob!.day} / ${_dob!.month} / ${_dob!.year}',
                  style: TextStyle(
                    color: _dob == null
                        ? Colors.white.withValues(alpha: 0.3)
                        : Colors.white,
                    fontSize: 15,
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 14),

          // Gender
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Gender',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55), fontSize: 13)),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _genders.map((g) {
              final sel = _gender == g;
              return ChoiceChip(
                label: Text(g),
                selected: sel,
                onSelected: (_) => setState(() => _gender = g),
                selectedColor: AppColors.accent.withValues(alpha: 0.2),
                backgroundColor: AppColors.surfaceElevated,
                side: BorderSide(
                    color: sel ? AppColors.accent : Colors.white12),
                labelStyle: TextStyle(
                  color: sel ? AppColors.accent : Colors.white60,
                  fontWeight:
                      sel ? FontWeight.w700 : FontWeight.w400,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // Blood Group
          DropdownButtonFormField<String>(
            initialValue: _bloodGroup,
            dropdownColor: AppColors.surfaceElevated,
            style: const TextStyle(color: Colors.white),
            decoration: _decor('Blood Group', ''),
            items: _bloodGroups
                .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                .toList(),
            onChanged: (v) => setState(() => _bloodGroup = v ?? _bloodGroup),
          ),
          const SizedBox(height: 14),

          // Height + Weight
          Row(children: [
            Expanded(
              child: TextFormField(
                controller: _heightCtrl,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: _decor('Height (cm)', '170'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _weightCtrl,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: _decor('Weight (kg)', '65'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  // ── Step 2 · Conditions ───────────────────────────────────────────────────

  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(children: [
        AppCard(
          child: Column(children: [
            _YesNoTile('Diabetes',
                _diabetes, (v) => setState(() => _diabetes = v)),
            _divider(),
            _YesNoTile('Hypertension',
                _hypertension, (v) => setState(() => _hypertension = v)),
            _divider(),
            _YesNoTile('Heart Disease',
                _heartDisease, (v) => setState(() => _heartDisease = v)),
            _divider(),
            _YesNoTile('Asthma',
                _asthma, (v) => setState(() => _asthma = v)),
            _divider(),
            _YesNoTile('Thyroid Issues',
                _thyroid, (v) => setState(() => _thyroid = v)),
          ]),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _condOtherCtrl,
          style: const TextStyle(color: Colors.white),
          maxLines: 3,
          decoration: _decor('Other conditions (optional)',
              'List any other medical conditions…'),
        ),
      ]),
    );
  }

  // ── Step 3 · Allergies ────────────────────────────────────────────────────

  Widget _buildStep3() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(children: [
        TextFormField(
          controller: _drugAllergyCtrl,
          style: const TextStyle(color: Colors.white),
          maxLines: 2,
          decoration: _decor('Drug Allergies', 'e.g. Penicillin, Aspirin…'),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _foodAllergyCtrl,
          style: const TextStyle(color: Colors.white),
          maxLines: 2,
          decoration: _decor('Food Allergies', 'e.g. Nuts, Dairy, Shellfish…'),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _otherAllergyCtrl,
          style: const TextStyle(color: Colors.white),
          maxLines: 2,
          decoration: _decor('Other Allergies', 'e.g. Latex, Pollen…'),
        ),
        const SizedBox(height: 14),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(children: [
            Icon(Icons.info_outline,
                color: AppColors.accentAmber.withValues(alpha: 0.8), size: 16),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Leave blank if you have no known allergies.',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55), fontSize: 13),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  // ── Step 4 · Medications ──────────────────────────────────────────────────

  Widget _buildStep4() {
    return Column(children: [
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          children: [
            if (_meds.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Text(
                    'No medications added.\nTap Add Medication below.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4), height: 1.6),
                  ),
                ),
              ),
            ..._meds.map((med) {
              return AppCard(
                key: ValueKey(med.uid),
                margin: const EdgeInsets.only(bottom: 12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(children: [
                    const Text('Medication',
                        style: TextStyle(
                            color: AppColors.accentViolet,
                            fontWeight: FontWeight.w700,
                            fontSize: 13)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => setState(() => _meds.remove(med)),
                      child: const Icon(Icons.close,
                          color: AppColors.danger, size: 18),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  _MedField(
                    label: 'Medication Name',
                    hint: 'e.g. Metformin',
                    initial: med.name,
                    onChanged: (v) => med.name = v,
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: _MedField(
                        label: 'Dosage',
                        hint: 'e.g. 500mg',
                        initial: med.dosage,
                        onChanged: (v) => med.dosage = v,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MedField(
                        label: 'Frequency',
                        hint: 'e.g. Twice daily',
                        initial: med.frequency,
                        onChanged: (v) => med.frequency = v,
                      ),
                    ),
                  ]),
                ]),
              );
            }),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => setState(() => _meds.add(MedicationEntry())),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Medication'),
          ),
        ),
      ),
    ]);
  }

  // ── Step 5 · Lifestyle ────────────────────────────────────────────────────

  Widget _buildStep5() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(children: [
        AppCard(
          child: Column(children: [
            _YesNoTile('Smoking',
                _smokes, (v) => setState(() => _smokes = v)),
            _divider(),
            _YesNoTile('Alcohol Consumption',
                _drinks, (v) => setState(() => _drinks = v)),
          ]),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          initialValue: _exerciseFreq,
          dropdownColor: AppColors.surfaceElevated,
          style: const TextStyle(color: Colors.white),
          decoration: _decor('Exercise Frequency', ''),
          items: _exerciseOpts
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: (v) => setState(() => _exerciseFreq = v ?? _exerciseFreq),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _sleepCtrl,
          style: const TextStyle(color: Colors.white),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: _decor('Average Sleep Hours / Night', 'e.g. 7'),
        ),
      ]),
    );
  }

  // ── Step 6 · Family History ───────────────────────────────────────────────

  Widget _buildStep6() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(children: [
        AppCard(
          child: Column(children: [
            _YesNoTile('Diabetes',
                _famDiabetes, (v) => setState(() => _famDiabetes = v)),
            _divider(),
            _YesNoTile('Heart Disease',
                _famHeart, (v) => setState(() => _famHeart = v)),
            _divider(),
            _YesNoTile('Cancer',
                _famCancer, (v) => setState(() => _famCancer = v)),
          ]),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _famOtherCtrl,
          style: const TextStyle(color: Colors.white),
          maxLines: 3,
          decoration: _decor(
              'Other Family History (optional)', 'e.g. Alzheimer\'s, Stroke…'),
        ),
      ]),
    );
  }

  // ── Step 7 · Emergency Contact ────────────────────────────────────────────

  Widget _buildStep7() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Form(
        key: _step7Key,
        child: Column(children: [
          TextFormField(
            controller: _ecNameCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: _decor('Full Name', 'e.g. John Doe'),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _ecRelCtrl,
            style: const TextStyle(color: Colors.white),
            decoration:
                _decor('Relationship', 'e.g. Spouse, Parent, Sibling'),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _ecPhoneCtrl,
            style: const TextStyle(color: Colors.white),
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: _decor('Phone Number', '10-digit number'),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Required';
              if (!RegExp(r'^\d{10}$').hasMatch(v.trim())) {
                return 'Enter a valid 10-digit number';
              }
              return null;
            },
          ),
        ]),
      ),
    );
  }

  // ── Step 8 · Review & Submit ──────────────────────────────────────────────

  Widget _buildReview() {
    final months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    final dobStr = _dob == null
        ? '—'
        : '${_dob!.day} ${months[_dob!.month - 1]} ${_dob!.year}';

    String yesNo(bool v) => v ? 'Yes' : 'No';
    String orDash(String v) => v.trim().isEmpty ? '—' : v;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _Section('Basic Info', AppColors.accent, [
          _Row('Name', orDash(_nameCtrl.text)),
          _Row('Date of Birth', dobStr),
          _Row('Gender', _gender),
          _Row('Blood Group', _bloodGroup),
          _Row('Height', _heightCtrl.text.isEmpty ? '—' : '${_heightCtrl.text} cm'),
          _Row('Weight', _weightCtrl.text.isEmpty ? '—' : '${_weightCtrl.text} kg'),
        ]),
        const SizedBox(height: 10),
        _Section('Conditions', AppColors.accentBlue, [
          _Row('Diabetes', yesNo(_diabetes)),
          _Row('Hypertension', yesNo(_hypertension)),
          _Row('Heart Disease', yesNo(_heartDisease)),
          _Row('Asthma', yesNo(_asthma)),
          _Row('Thyroid', yesNo(_thyroid)),
          if (_condOtherCtrl.text.trim().isNotEmpty)
            _Row('Other', _condOtherCtrl.text),
        ]),
        const SizedBox(height: 10),
        _Section('Allergies', AppColors.accentAmber, [
          _Row('Drug', orDash(_drugAllergyCtrl.text)),
          _Row('Food', orDash(_foodAllergyCtrl.text)),
          _Row('Other', orDash(_otherAllergyCtrl.text)),
        ]),
        const SizedBox(height: 10),
        _Section('Medications (${_meds.length})', AppColors.accentViolet,
          _meds.isEmpty
              ? [const _Row('', 'None listed')]
              : _meds.map((m) => _Row(m.name.isNotEmpty ? m.name : '—',
                  '${m.dosage} · ${m.frequency}')).toList(),
        ),
        const SizedBox(height: 10),
        _Section('Lifestyle', AppColors.success, [
          _Row('Smoking', yesNo(_smokes)),
          _Row('Alcohol', yesNo(_drinks)),
          _Row('Exercise', _exerciseFreq),
          _Row('Sleep', _sleepCtrl.text.isEmpty ? '—' : '${_sleepCtrl.text} hrs / night'),
        ]),
        const SizedBox(height: 10),
        _Section('Family History', AppColors.accentRose, [
          _Row('Diabetes', yesNo(_famDiabetes)),
          _Row('Heart Disease', yesNo(_famHeart)),
          _Row('Cancer', yesNo(_famCancer)),
          if (_famOtherCtrl.text.trim().isNotEmpty)
            _Row('Other', _famOtherCtrl.text),
        ]),
        const SizedBox(height: 10),
        _Section('Emergency Contact', AppColors.accentBlue, [
          _Row('Name', orDash(_ecNameCtrl.text)),
          _Row('Relationship', orDash(_ecRelCtrl.text)),
          _Row('Phone', orDash(_ecPhoneCtrl.text)),
        ]),
      ]),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  InputDecoration _decor(String label, String hint) => InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle:
            TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 13),
        hintStyle:
            TextStyle(color: Colors.white.withValues(alpha: 0.25)),
        filled: true,
        fillColor: AppColors.surfaceElevated,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.white12)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.white12)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                const BorderSide(color: AppColors.accent, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.danger)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                const BorderSide(color: AppColors.danger, width: 1.5)),
      );

  Widget _divider() => const Divider(color: Colors.white10, height: 1);
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _YesNoTile extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _YesNoTile(this.label, this.value, this.onChanged);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500)),
        ),
        _Toggle('No', !value, () => onChanged(false), AppColors.danger),
        const SizedBox(width: 8),
        _Toggle('Yes', value, () => onChanged(true), AppColors.success),
      ]),
    );
  }
}

class _Toggle extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;

  const _Toggle(this.label, this.selected, this.onTap, this.color);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.18) : AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? color : Colors.white12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? color : Colors.white38,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _MedField extends StatelessWidget {
  final String label;
  final String hint;
  final String initial;
  final ValueChanged<String> onChanged;

  const _MedField({
    required this.label,
    required this.hint,
    required this.initial,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: initial,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
        labelStyle:
            TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 12),
        hintStyle:
            TextStyle(color: Colors.white.withValues(alpha: 0.2), fontSize: 12),
        filled: true,
        fillColor: AppColors.surfaceSoft,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.white12)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.white12)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                const BorderSide(color: AppColors.accentViolet, width: 1.5)),
      ),
    );
  }
}

// ── Review helpers ────────────────────────────────────────────────────────────

class _Row {
  final String label;
  final String value;
  const _Row(this.label, this.value);
}

class _Section extends StatelessWidget {
  final String title;
  final Color  color;
  final List<_Row> rows;

  const _Section(this.title, this.color, this.rows);

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(title,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 13)),
        ]),
        const SizedBox(height: 10),
        ...rows.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (r.label.isNotEmpty)
                      SizedBox(
                        width: 112,
                        child: Text(r.label,
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.45),
                                fontSize: 12)),
                      ),
                    Expanded(
                      child: Text(r.value,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500)),
                    ),
                  ]),
            )),
      ]),
    );
  }
}
