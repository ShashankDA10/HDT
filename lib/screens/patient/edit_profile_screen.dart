import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import '../../models/patient_profile.dart';
import '../../services/patient_profile_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_scaffold.dart';

class EditProfileScreen extends StatefulWidget {
  final AppUser user;
  const EditProfileScreen({super.key, required this.user});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = true;
  bool _saving  = false;

  // ── Basic Info ──────────────────────────────────────────────────────────────
  final _nameCtrl   = TextEditingController();
  DateTime? _dob;
  String _gender     = '';
  String _bloodGroup = '';
  final _heightCtrl  = TextEditingController();
  final _weightCtrl  = TextEditingController();

  // ── Conditions ──────────────────────────────────────────────────────────────
  bool _hasDiabetes     = false;
  bool _hasHypertension = false;
  bool _hasHeartDisease = false;
  bool _hasAsthma       = false;
  bool _hasThyroid      = false;
  final _otherCondCtrl  = TextEditingController();

  // ── Allergies ───────────────────────────────────────────────────────────────
  final _drugAllergyCtrl  = TextEditingController();
  final _foodAllergyCtrl  = TextEditingController();
  final _otherAllergyCtrl = TextEditingController();

  // ── Medications ─────────────────────────────────────────────────────────────
  final List<MedicationEntry> _meds = [];

  // ── Lifestyle ───────────────────────────────────────────────────────────────
  bool   _smokes        = false;
  bool   _drinksAlcohol = false;
  String _exerciseFreq  = '';
  String _sleepHours    = '';

  // ── Family History ──────────────────────────────────────────────────────────
  bool  _famDiabetes = false;
  bool  _famHeart    = false;
  bool  _famCancer   = false;
  final _famOtherCtrl = TextEditingController();

  // ── Emergency Contact ───────────────────────────────────────────────────────
  final _emergNameCtrl  = TextEditingController();
  final _emergRelCtrl   = TextEditingController();
  final _emergPhoneCtrl = TextEditingController();

  // ── Options ─────────────────────────────────────────────────────────────────
  static const _genders      = ['Male', 'Female', 'Other', 'Prefer not to say'];
  static const _bloodGroups  = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
  static const _exerciseOpts = ['Daily', '3–4 times/week', '1–2 times/week', 'Rarely', 'Never'];
  static const _sleepOpts    = ['<5 hours', '5–6 hours', '6–7 hours', '7–8 hours', '8+ hours'];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _otherCondCtrl.dispose();
    _drugAllergyCtrl.dispose();
    _foodAllergyCtrl.dispose();
    _otherAllergyCtrl.dispose();
    _famOtherCtrl.dispose();
    _emergNameCtrl.dispose();
    _emergRelCtrl.dispose();
    _emergPhoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.id)
          .get();
      final d = snap.data() ?? {};

      final basic   = d['basicInfo']        as Map<String, dynamic>? ?? {};
      final conds   = d['conditions']       as Map<String, dynamic>? ?? {};
      final allerg  = d['allergies']        as Map<String, dynamic>? ?? {};
      final medsRaw = d['medications']      as List<dynamic>?         ?? [];
      final life    = d['lifestyle']        as Map<String, dynamic>? ?? {};
      final fam     = d['familyHistory']    as Map<String, dynamic>? ?? {};
      final emerg   = d['emergencyContact'] as Map<String, dynamic>? ?? {};

      _nameCtrl.text   = (basic['fullName'] as String?)?.isNotEmpty == true
          ? basic['fullName'] as String
          : widget.user.name;
      final dobTs = basic['dateOfBirth'];
      if (dobTs is Timestamp) _dob = dobTs.toDate();
      _gender     = basic['gender']     as String? ?? '';
      _bloodGroup = basic['bloodGroup'] as String? ?? '';
      _heightCtrl.text = basic['height'] as String? ?? '';
      _weightCtrl.text = basic['weight'] as String? ?? '';

      _hasDiabetes     = conds['diabetes']     as bool? ?? false;
      _hasHypertension = conds['hypertension'] as bool? ?? false;
      _hasHeartDisease = conds['heartDisease'] as bool? ?? false;
      _hasAsthma       = conds['asthma']       as bool? ?? false;
      _hasThyroid      = conds['thyroid']      as bool? ?? false;
      _otherCondCtrl.text = conds['other'] as String? ?? '';

      _drugAllergyCtrl.text  = allerg['drug']  as String? ?? '';
      _foodAllergyCtrl.text  = allerg['food']  as String? ?? '';
      _otherAllergyCtrl.text = allerg['other'] as String? ?? '';

      for (final m in medsRaw) {
        if (m is Map) {
          final entry = MedicationEntry();
          entry.name      = m['name']      as String? ?? '';
          entry.dosage    = m['dosage']    as String? ?? '';
          entry.frequency = m['frequency'] as String? ?? '';
          _meds.add(entry);
        }
      }

      _smokes        = life['smokes']            as bool?   ?? false;
      _drinksAlcohol = life['drinksAlcohol']     as bool?   ?? false;
      _exerciseFreq  = life['exerciseFrequency'] as String? ?? '';
      _sleepHours    = life['sleepHours']        as String? ?? '';

      _famDiabetes = fam['diabetes']    as bool? ?? false;
      _famHeart    = fam['heartDisease'] as bool? ?? false;
      _famCancer   = fam['cancer']      as bool? ?? false;
      _famOtherCtrl.text = fam['other'] as String? ?? '';

      _emergNameCtrl.text  = emerg['name']         as String? ?? '';
      _emergRelCtrl.text   = emerg['relationship'] as String? ?? '';
      _emergPhoneCtrl.text = emerg['phone']        as String? ?? '';
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_dob == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please select your date of birth')));
      return;
    }
    setState(() => _saving = true);
    try {
      final profile = PatientProfile(
        fullName:             _nameCtrl.text.trim(),
        dateOfBirth:          _dob!,
        gender:               _gender,
        bloodGroup:           _bloodGroup,
        height:               _heightCtrl.text.trim(),
        weight:               _weightCtrl.text.trim(),
        hasDiabetes:          _hasDiabetes,
        hasHypertension:      _hasHypertension,
        hasHeartDisease:      _hasHeartDisease,
        hasAsthma:            _hasAsthma,
        hasThyroid:           _hasThyroid,
        otherConditions:      _otherCondCtrl.text.trim(),
        drugAllergies:        _drugAllergyCtrl.text.trim(),
        foodAllergies:        _foodAllergyCtrl.text.trim(),
        otherAllergies:       _otherAllergyCtrl.text.trim(),
        medications:          _meds.where((m) => m.name.isNotEmpty).toList(),
        smokes:               _smokes,
        drinksAlcohol:        _drinksAlcohol,
        exerciseFrequency:    _exerciseFreq,
        sleepHours:           _sleepHours,
        familyDiabetes:       _famDiabetes,
        familyHeartDisease:   _famHeart,
        familyCancer:         _famCancer,
        familyOther:          _famOtherCtrl.text.trim(),
        emergencyName:        _emergNameCtrl.text.trim(),
        emergencyRelationship: _emergRelCtrl.text.trim(),
        emergencyPhone:       _emergPhoneCtrl.text.trim(),
      );
      await PatientProfileService.saveProfile(widget.user.id, profile);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Profile updated'),
        backgroundColor: AppColors.success,
      ));
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          if (!_loading)
            TextButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.accent))
                  : const Text('Save',
                      style: TextStyle(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                children: [
                  _buildBasicInfo(),
                  const SizedBox(height: 14),
                  _buildConditions(),
                  const SizedBox(height: 14),
                  _buildAllergies(),
                  const SizedBox(height: 14),
                  _buildMedications(),
                  const SizedBox(height: 14),
                  _buildLifestyle(),
                  const SizedBox(height: 14),
                  _buildFamilyHistory(),
                  const SizedBox(height: 14),
                  _buildEmergencyContact(),
                ],
              ),
            ),
    );
  }

  // ── Section builders ────────────────────────────────────────────────────────

  Widget _buildBasicInfo() {
    return _Section(
      icon: Icons.person_outline,
      title: 'Basic Info',
      color: AppColors.accent,
      children: [
        _field(_nameCtrl, 'Full Name',
            validator: (v) => v!.trim().isEmpty ? 'Required' : null),
        const SizedBox(height: 12),
        _dobPicker(),
        const SizedBox(height: 12),
        _dropdown('Gender', _genders, _gender, (v) => setState(() => _gender = v ?? '')),
        const SizedBox(height: 12),
        _dropdown('Blood Group', _bloodGroups, _bloodGroup,
            (v) => setState(() => _bloodGroup = v ?? '')),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _field(_heightCtrl, 'Height (cm)',
              keyboardType: TextInputType.number)),
          const SizedBox(width: 12),
          Expanded(child: _field(_weightCtrl, 'Weight (kg)',
              keyboardType: TextInputType.number)),
        ]),
      ],
    );
  }

  Widget _buildConditions() {
    return _Section(
      icon: Icons.medical_information_outlined,
      title: 'Medical Conditions',
      color: AppColors.accentBlue,
      children: [
        _toggle('Diabetes',     _hasDiabetes,     (v) => setState(() => _hasDiabetes = v)),
        _toggle('Hypertension', _hasHypertension, (v) => setState(() => _hasHypertension = v)),
        _toggle('Heart Disease',_hasHeartDisease, (v) => setState(() => _hasHeartDisease = v)),
        _toggle('Asthma',       _hasAsthma,       (v) => setState(() => _hasAsthma = v)),
        _toggle('Thyroid',      _hasThyroid,      (v) => setState(() => _hasThyroid = v)),
        const SizedBox(height: 8),
        _field(_otherCondCtrl, 'Other conditions (optional)'),
      ],
    );
  }

  Widget _buildAllergies() {
    return _Section(
      icon: Icons.warning_amber_outlined,
      title: 'Allergies',
      color: AppColors.accentAmber,
      children: [
        _field(_drugAllergyCtrl,  'Drug allergies'),
        const SizedBox(height: 12),
        _field(_foodAllergyCtrl,  'Food allergies'),
        const SizedBox(height: 12),
        _field(_otherAllergyCtrl, 'Other allergies'),
      ],
    );
  }

  Widget _buildMedications() {
    return _Section(
      icon: Icons.medication_outlined,
      title: 'Current Medications',
      color: AppColors.accentViolet,
      children: [
        ..._meds.asMap().entries.map((e) {
          final i   = e.key;
          final med = e.value;
          return Container(
            key: ValueKey(med.uid),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(children: [
              Row(children: [
                Expanded(
                  child: TextFormField(
                    initialValue: med.name,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: _inputDeco('Medication name'),
                    onChanged: (v) => med.name = v,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => setState(() => _meds.removeAt(i)),
                  child: const Icon(Icons.remove_circle_outline,
                      color: AppColors.danger, size: 20),
                ),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: TextFormField(
                    initialValue: med.dosage,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: _inputDeco('Dosage'),
                    onChanged: (v) => med.dosage = v,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    initialValue: med.frequency,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: _inputDeco('Frequency'),
                    onChanged: (v) => med.frequency = v,
                  ),
                ),
              ]),
            ]),
          );
        }),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () => setState(() => _meds.add(MedicationEntry())),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.accentViolet.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppColors.accentViolet.withValues(alpha: 0.3),
                  style: BorderStyle.solid),
            ),
            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.add, color: AppColors.accentViolet, size: 16),
              SizedBox(width: 6),
              Text('Add Medication',
                  style: TextStyle(
                      color: AppColors.accentViolet,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildLifestyle() {
    return _Section(
      icon: Icons.self_improvement_outlined,
      title: 'Lifestyle',
      color: AppColors.accentRose,
      children: [
        _toggle('Smoker',          _smokes,        (v) => setState(() => _smokes = v)),
        _toggle('Drinks Alcohol',  _drinksAlcohol, (v) => setState(() => _drinksAlcohol = v)),
        const SizedBox(height: 8),
        _dropdown('Exercise Frequency', _exerciseOpts, _exerciseFreq,
            (v) => setState(() => _exerciseFreq = v ?? '')),
        const SizedBox(height: 12),
        _dropdown('Sleep Hours', _sleepOpts, _sleepHours,
            (v) => setState(() => _sleepHours = v ?? '')),
      ],
    );
  }

  Widget _buildFamilyHistory() {
    return _Section(
      icon: Icons.family_restroom_outlined,
      title: 'Family History',
      color: AppColors.accentBlue,
      children: [
        _toggle('Diabetes',     _famDiabetes, (v) => setState(() => _famDiabetes = v)),
        _toggle('Heart Disease',_famHeart,    (v) => setState(() => _famHeart = v)),
        _toggle('Cancer',       _famCancer,   (v) => setState(() => _famCancer = v)),
        const SizedBox(height: 8),
        _field(_famOtherCtrl, 'Other family history'),
      ],
    );
  }

  Widget _buildEmergencyContact() {
    return _Section(
      icon: Icons.phone_outlined,
      title: 'Emergency Contact',
      color: AppColors.accentAmber,
      children: [
        _field(_emergNameCtrl,  'Contact name'),
        const SizedBox(height: 12),
        _field(_emergRelCtrl,   'Relationship'),
        const SizedBox(height: 12),
        _field(_emergPhoneCtrl, 'Phone number',
            keyboardType: TextInputType.phone),
      ],
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  Widget _dobPicker() {
    final label = _dob == null
        ? 'Date of Birth'
        : '${_dob!.day}/${_dob!.month}/${_dob!.year}';

    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _dob ?? DateTime(1990),
          firstDate: DateTime(1900),
          lastDate: DateTime.now(),
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: const ColorScheme.dark(
                primary: AppColors.accent,
                onPrimary: AppColors.ink,
                surface: AppColors.surface,
                onSurface: Colors.white,
              ),
            ),
            child: child!,
          ),
        );
        if (picked != null) setState(() => _dob = picked);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(children: [
          const Icon(Icons.calendar_today_outlined,
              color: AppColors.muted, size: 16),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
                color: _dob == null ? AppColors.muted : Colors.white,
                fontSize: 13),
          ),
        ]),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String hint, {
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: _inputDeco(hint),
    );
  }

  Widget _dropdown(
    String hint,
    List<String> options,
    String current,
    void Function(String?) onChanged,
  ) {
    return DropdownButtonFormField<String>(
      value: options.contains(current) ? current : null,
      hint: Text(hint, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
      dropdownColor: AppColors.surfaceElevated,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: _inputDeco(hint).copyWith(hintText: null, labelText: null),
      items: options
          .map((o) => DropdownMenuItem(value: o, child: Text(o)))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _toggle(String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Expanded(
          child: Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppColors.accent,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ]),
    );
  }

  InputDecoration _inputDeco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.muted, fontSize: 13),
        filled: true,
        fillColor: AppColors.surfaceElevated,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.accent),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
      );
}

// ── Section card ──────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final IconData     icon;
  final String       title;
  final Color        color;
  final List<Widget> children;

  const _Section({
    required this.icon,
    required this.title,
    required this.color,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 14),
          ),
          const SizedBox(width: 10),
          Text(title,
              style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 14),
        ...children,
      ]),
    );
  }
}
