import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/app_card.dart';
import '../services/medication_service.dart';
import '../services/medication_reminder_service.dart';

// In-memory model that mirrors a Firestore document
class _MedEntry {
  final String docId;
  final String name;
  final String dosage;
  final String frequency;
  final int timesPerDay;
  final DateTime? tillDate;
  List<bool> checked;

  _MedEntry({
    required this.docId,
    required this.name,
    required this.dosage,
    required this.frequency,
    required this.timesPerDay,
    this.tillDate,
    required this.checked,
  });

  factory _MedEntry.fromFirestore(Map<String, dynamic> data) {
    final timesPerDay = (data['timesPerDay'] as int?) ?? 1;
    final rawChecked = data['checked'];
    List<bool> checked;
    if (rawChecked is List) {
      checked = rawChecked.map((e) => e == true).toList();
      // Guard against length mismatch
      while (checked.length < timesPerDay) {
        checked.add(false);
      }
    } else {
      checked = List<bool>.filled(timesPerDay, false);
    }

    DateTime? tillDate;
    if (data['tillDate'] != null) {
      try {
        tillDate = (data['tillDate'] as dynamic).toDate() as DateTime?;
      } catch (_) {}
    }

    return _MedEntry(
      docId: data['id'] as String,
      name: data['name'] as String? ?? '',
      dosage: data['dosage'] as String? ?? '',
      frequency: data['frequency'] as String? ?? '',
      timesPerDay: timesPerDay,
      tillDate: tillDate,
      checked: checked,
    );
  }
}

class MedicationScreen extends StatefulWidget {
  const MedicationScreen({super.key});

  @override
  State<MedicationScreen> createState() => _MedicationScreenState();
}

class _MedicationScreenState extends State<MedicationScreen> {
  List<_MedEntry> _medications = [];
  bool _isLoading = true;
  AppUser? _currentUser;

  static const List<List<String>> _doseLabels = [
    ['Daily'],
    ['Morning', 'Evening'],
    ['Morning', 'Afternoon', 'Evening'],
    ['Morning', 'Afternoon', 'Evening', 'Night'],
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      _currentUser ??= await EmailPasswordAuthService.currentAppUser();
      final docs = await MedicationService.getMedications(
        patientId: _currentUser?.id,
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => [],
      );
      if (mounted) {
        setState(() {
          _medications = docs.map(_MedEntry.fromFirestore).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load: $e'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    }
  }

  void _openAddMedication() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _AddMedicationSheet(
        onAdd: (name, dosage, frequency, timesPerDay, tillDate) async {
          final docId = await MedicationService.addMedication(
            name: name,
            dosage: dosage,
            frequency: frequency,
            timesPerDay: timesPerDay,
            tillDate: tillDate,
            patientId: _currentUser?.id,
          );
          // Schedule daily reminders for every active dose slot
          debugPrint('[MedScreen] New medication "$name" added '
              '(docId=$docId, timesPerDay=$timesPerDay) — scheduling reminders');
          await MedicationReminderService.scheduleForMedication(
            docId:       docId,
            medName:     name,
            timesPerDay: timesPerDay,
          );
          debugPrint('[MedScreen] Reminders scheduled for "$name"');
          if (mounted) {
            setState(() {
              _medications.add(_MedEntry(
                docId: docId,
                name: name,
                dosage: dosage,
                frequency: frequency,
                timesPerDay: timesPerDay,
                tillDate: tillDate,
                checked: List<bool>.filled(timesPerDay, false),
              ));
            });
          }
        },
      ),
    );
  }

  Future<void> _toggleDose(int medIndex, int doseIndex) async {
    final med     = _medications[medIndex];
    final updated = List<bool>.from(med.checked);
    updated[doseIndex] = !updated[doseIndex];
    setState(() => med.checked = updated);
    await MedicationService.updateChecked(med.docId, updated);

    // Sync notification with new checked state
    if (updated[doseIndex]) {
      debugPrint('[MedScreen] Dose $doseIndex of "${med.name}" marked taken — '
          'cancelling reminder');
      await MedicationReminderService.cancelDose(
          med.docId, med.timesPerDay, doseIndex);
    } else {
      debugPrint('[MedScreen] Dose $doseIndex of "${med.name}" un-marked — '
          'rescheduling reminder');
      await MedicationReminderService.rescheduleDose(
        docId:       med.docId,
        medName:     med.name,
        timesPerDay: med.timesPerDay,
        doseIndex:   doseIndex,
      );
    }
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Medication'),
            Text(
              'Daily plan and upcoming doses',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.muted),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddMedication,
        tooltip: 'Add medication',
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            )
          : _medications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.medication_outlined,
                        size: 64,
                        color: Colors.white.withOpacity(0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No medications',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap + to add your medications',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  itemCount: _medications.length,
                  itemBuilder: (context, index) {
                    final med = _medications[index];
                    final labels = _doseLabels[med.timesPerDay - 1];
                    final allTaken = med.checked.every((c) => c);

                    return AppCard(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Header ───────────────────────────────────────
                          Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: AppColors.accentViolet.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.medication,
                                  color: AppColors.accentViolet,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      med.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      med.frequency.isNotEmpty
                                          ? '${med.dosage} · ${med.frequency}'
                                          : med.dosage,
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.7),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: allTaken
                                      ? AppColors.success.withOpacity(0.2)
                                      : AppColors.accentViolet.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  allTaken ? 'done' : 'active',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: allTaken
                                        ? AppColors.success
                                        : Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // ── Till date ─────────────────────────────────────
                          if (med.tillDate != null) ...[
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 13,
                                  color: Colors.white.withOpacity(0.45),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Till ${_formatDate(med.tillDate!)}',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.45),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],

                          // ── Dose checkboxes ───────────────────────────────
                          const SizedBox(height: 14),
                          const Divider(color: Colors.white12, height: 1),
                          const SizedBox(height: 12),
                          Text(
                            "Today's doses",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.45),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: List.generate(med.timesPerDay, (i) {
                              final taken = med.checked[i];
                              return Expanded(
                                child: GestureDetector(
                                  onTap: () => _toggleDose(index, i),
                                  child: Container(
                                    margin: EdgeInsets.only(
                                      right: i < med.timesPerDay - 1 ? 8 : 0,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: taken
                                          ? AppColors.accent.withOpacity(0.15)
                                          : AppColors.surfaceElevated,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: taken
                                            ? AppColors.accent.withOpacity(0.55)
                                            : Colors.white12,
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          taken
                                              ? Icons.check_circle_rounded
                                              : Icons.radio_button_unchecked,
                                          color: taken
                                              ? AppColors.accent
                                              : Colors.white30,
                                          size: 22,
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          labels[i],
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: taken
                                                ? AppColors.accent
                                                : Colors.white.withOpacity(0.45),
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: (60 * index).ms, duration: 350.ms);
                  },
                ),
    );
  }
}

// ── Add Medication bottom sheet ──────────────────────────────────────────────

class _AddMedicationSheet extends StatefulWidget {
  final Future<void> Function(
    String name,
    String dosage,
    String frequency,
    int timesPerDay,
    DateTime? tillDate,
  ) onAdd;

  const _AddMedicationSheet({required this.onAdd});

  @override
  State<_AddMedicationSheet> createState() => _AddMedicationSheetState();
}

class _AddMedicationSheetState extends State<_AddMedicationSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _dosageCtrl = TextEditingController();
  String _mealTiming = 'After Meals';
  int _timesPerDay = 1;
  DateTime? _tillDate;
  bool _saving = false;

  static const _timingOptions = [
    'Before Meals',
    'After Meals',
    'With Meals',
    'Empty Stomach',
    'At Bedtime',
    'As Needed',
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _dosageCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.accent,
            onPrimary: AppColors.ink,
            surface: AppColors.surfaceElevated,
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _tillDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.onAdd(
        _nameCtrl.text.trim(),
        _dosageCtrl.text.trim(),
        _mealTiming,
        _timesPerDay,
        _tillDate,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottom + 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Add Medication',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),

            _Field(
              controller: _nameCtrl,
              label: 'Medication name',
              hint: 'e.g. Paracetamol',
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 14),

            _Field(
              controller: _dosageCtrl,
              label: 'Dosage',
              hint: 'e.g. 500 mg',
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 14),

            // Intake Timing selector
            Text(
              'Intake Timing',
              style: TextStyle(
                color: Colors.white.withOpacity(0.65),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _timingOptions.map((opt) {
                final sel = _mealTiming == opt;
                return GestureDetector(
                  onTap: () => setState(() => _mealTiming = opt),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: sel
                          ? AppColors.accent.withOpacity(0.18)
                          : AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: sel ? AppColors.accent : Colors.white12,
                        width: sel ? 1.5 : 1,
                      ),
                    ),
                    child: Text(
                      opt,
                      style: TextStyle(
                        color: sel ? AppColors.accent : Colors.white.withOpacity(0.55),
                        fontSize: 13,
                        fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),

            // Times per day
            Text(
              'Times per day',
              style: TextStyle(
                color: Colors.white.withOpacity(0.65),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [1, 2, 3, 4].map((n) {
                final selected = _timesPerDay == n;
                return GestureDetector(
                  onTap: () => setState(() => _timesPerDay = n),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.only(right: 10),
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.accent.withOpacity(0.18)
                          : AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected ? AppColors.accent : Colors.white12,
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '$n×',
                        style: TextStyle(
                          color: selected
                              ? AppColors.accent
                              : Colors.white.withOpacity(0.45),
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),

            // Till when
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 18,
                      color: _tillDate != null
                          ? AppColors.accent
                          : Colors.white.withOpacity(0.45),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _tillDate == null
                          ? 'Till when (optional)'
                          : 'Till ${_tillDate!.day}/${_tillDate!.month}/${_tillDate!.year}',
                      style: TextStyle(
                        color: _tillDate == null ? Colors.white30 : Colors.white,
                        fontSize: 14,
                      ),
                    ),
                    if (_tillDate != null) ...[
                      const Spacer(),
                      GestureDetector(
                        onTap: () => setState(() => _tillDate = null),
                        child: Icon(
                          Icons.close,
                          size: 16,
                          color: Colors.white.withOpacity(0.4),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.ink,
                        ),
                      )
                    : const Text('Add Medication'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Reusable text field ──────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final String? Function(String?)? validator;

  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle:
            TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 13),
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.25)),
        filled: true,
        fillColor: AppColors.surfaceElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
        ),
      ),
    );
  }
}
