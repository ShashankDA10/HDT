import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../services/report_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/app_card.dart';
import 'report_detail_screen.dart';
import 'ocr_report_screen.dart';

// ── Category metadata ─────────────────────────────────────────────────────────

class _Cat {
  final String name;
  final IconData icon;
  final Color color;
  final List<String> types;
  const _Cat(this.name, this.icon, this.color, this.types);
}

const _categories = [
  _Cat('Laboratory Reports', Icons.biotech, Color(0xFF3b82f6), [
    'Blood Test (CBC, Lipid Profile, Glucose…)',
    'Urine Test',
    'Stool Test',
    'Biopsy / Histopathology',
    'Culture & Sensitivity',
    'Hormone Tests',
    'Allergy Tests',
  ]),
  _Cat('Radiology / Imaging', Icons.document_scanner, Color(0xFF8b5cf6), [
    'X-Ray',
    'CT Scan',
    'MRI',
    'Ultrasound',
    'PET Scan',
    'Mammography',
    'Doppler Study',
  ]),
  _Cat('Clinical Consultation', Icons.person_search, Color(0xFF06b6d4), [
    'General Physician Visit',
    'Specialist Consultation',
    'Follow-up Visit',
    'Teleconsultation',
  ]),
  _Cat('Prescription / Medication', Icons.medication, Color(0xFF10b981), [
    'New Prescription',
    'Ongoing Medication',
    'Refill Prescription',
  ]),
  _Cat('Hospitalization Records', Icons.local_hospital, Color(0xFFf43f5e), [
    'Admission Summary',
    'Discharge Summary',
    'ICU Records',
    'Emergency Visit',
  ]),
  _Cat('Surgical Reports', Icons.content_cut, Color(0xFFf97316), [
    'Pre-operative Report',
    'Operation Notes',
    'Post-operative Report',
  ]),
  _Cat('Vaccination Records', Icons.vaccines, Color(0xFF84cc16), [
    'Childhood Vaccines',
    'COVID-19 Vaccination',
    'Travel Vaccines',
    'Booster Doses',
  ]),
  _Cat('Vital Monitoring', Icons.monitor_heart, Color(0xFFec4899), [
    'Blood Pressure Log',
    'Blood Sugar Log',
    'Heart Rate Monitoring',
    'Weight Tracking',
    'Oxygen Saturation',
  ]),
  _Cat('Dental Records', Icons.sentiment_very_satisfied, Color(0xFFa78bfa), [
    'Oral Checkup',
    'Cleaning / Scaling',
    'Filling / Restoration',
    'Root Canal Treatment',
    'Orthodontic Records',
  ]),
  _Cat('Other Documents', Icons.folder_open, Color(0xFF94a3b8), [
    'Insurance Documents',
    'Medical Certificates',
    'Fitness Certificates',
    'Miscellaneous Reports',
  ]),
];

const _commonTags = [
  'Diabetes',
  'Hypertension',
  'Asthma',
  'Heart Disease',
  'Thyroid',
  'Anemia',
  'Obesity',
  'Arthritis',
];

// ── Reports Screen ────────────────────────────────────────────────────────────

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  List<Map<String, dynamic>> _reports = [];
  bool _isLoading = true;
  AppUser? _currentUser;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      _currentUser ??= await EmailPasswordAuthService.currentAppUser();
      final uid = _currentUser?.id;
      final List<Map<String, dynamic>> docs;
      if (_currentUser?.isDoctor == true && uid != null) {
        docs = await ReportService.getReportsByDoctor(uid).timeout(
          const Duration(seconds: 10), onTimeout: () => []);
      } else if (uid != null) {
        docs = await ReportService.getReportsByPatient(uid).timeout(
          const Duration(seconds: 10), onTimeout: () => []);
      } else {
        docs = [];
      }
      if (mounted) setState(() { _reports = docs; _isLoading = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load: $e'), backgroundColor: Colors.red.shade800),
        );
      }
    }
  }

  void _openAddReport() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AddReportSheet(
        currentUser: _currentUser,
        onSaved: () {
          Navigator.of(context).pop();
          _load();
        },
      ),
    );
  }

  String _formatDate(dynamic ts) {
    try {
      DateTime date;
      if (ts is Timestamp) {
        date = ts.toDate();
      } else {
        date = DateTime.parse(ts.toString());
      }
      const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${m[date.month - 1]} ${date.day}, ${date.year}';
    } catch (_) {
      return '';
    }
  }

  _Cat _catFor(String name) =>
      _categories.firstWhere((c) => c.name == name,
          orElse: () => _categories.last);

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
            const Text('Reports'),
            Text(
              'Your medical history',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted),
            ),
          ],
        ),
      ),
      floatingActionButton: _currentUser?.isDoctor == true
          ? FloatingActionButton(
              onPressed: _openAddReport,
              tooltip: 'Add report',
              child: const Icon(Icons.add),
            )
          : _currentUser?.isPatient == true
              ? FloatingActionButton(
                  onPressed: () => Navigator.of(context)
                      .push(MaterialPageRoute(
                          builder: (_) => const OcrReportScreen()))
                      .then((saved) { if (saved == true) _load(); }),
                  tooltip: 'Scan & add report',
                  child: const Icon(Icons.document_scanner_rounded),
                )
              : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : _reports.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.description_outlined, size: 64,
                          color: Colors.white.withOpacity(0.3)),
                      const SizedBox(height: 16),
                      Text('No reports yet',
                          style: TextStyle(color: Colors.white.withOpacity(0.8),
                              fontSize: 18, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text(
                          _currentUser?.isDoctor == true
                              ? 'Tap + to add your first report'
                              : 'Tap the scan button to add your own reports',
                          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  itemCount: _reports.length,
                  itemBuilder: (context, index) {
                    final r = _reports[index];
                    final cat = _catFor(r['category'] as String? ?? '');
                    final reportName = (r['reportName'] as String?)?.isNotEmpty == true
                        ? r['reportName'] as String
                        : r['type'] as String? ?? 'Report';
                    final hasMed = r['hasMedication'] == true;
                    final isSelfUploaded = r['source'] == 'patient_upload';

                    return AppCard(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: EdgeInsets.zero,
                      child: InkWell(
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => ReportDetailScreen(data: r),
                        )).then((_) => _load()),
                        borderRadius: BorderRadius.circular(18),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: cat.color.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(13),
                                ),
                                child: Icon(cat.icon, color: cat.color, size: 22),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      reportName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${r['category']} › ${r['type']}',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.5),
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      _formatDate(r['date']),
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.4),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Icon(Icons.chevron_right, color: Colors.white24, size: 20),
                                  if (hasMed) ...[
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppColors.accent.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: const Text('+ Med',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: AppColors.accent,
                                            fontWeight: FontWeight.w600,
                                          )),
                                    ),
                                  ],
                                  if (isSelfUploaded) ...[
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppColors.accentBlue.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: const Text('Self',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: AppColors.accentBlue,
                                            fontWeight: FontWeight.w600,
                                          )),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ).animate().fadeIn(delay: (50 * index).ms, duration: 300.ms);
                  },
                ),
    );
  }
}

// ── Multi-step Add Report Sheet ───────────────────────────────────────────────

class _AddReportSheet extends StatefulWidget {
  final VoidCallback onSaved;
  final AppUser? currentUser;
  const _AddReportSheet({required this.onSaved, this.currentUser});

  @override
  State<_AddReportSheet> createState() => _AddReportSheetState();
}

class _AddReportSheetState extends State<_AddReportSheet> {
  int _step = 0; // 0=category 1=type 2=fields 3=medication(optional)

  _Cat? _selectedCat;
  String? _selectedType;

  // Common fields
  final _reportNameCtrl = TextEditingController();
  final _doctorCtrl = TextEditingController();
  final _hospitalCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _diagnosisCtrl = TextEditingController();
  final _commentsCtrl = TextEditingController();
  DateTime _reportDate = DateTime.now();
  final List<String> _selectedTags = [];

  // Attachments
  final List<UploadResult> _attachments = [];
  bool _uploading = false;
  // Temp reportId used as the Storage folder name
  final String _tempReportId = DateTime.now().millisecondsSinceEpoch.toString();

  // Medication fields
  final _medNameCtrl = TextEditingController();
  final _medDosageCtrl = TextEditingController();
  final _medFreqCtrl = TextEditingController();
  final _patientEmailCtrl = TextEditingController();
  int _medTimesPerDay = 1;
  DateTime? _medTillDate;
  bool _addMedication = false;
  String? _resolvedPatientId;
  bool _lookingUpPatient = false;

  bool _saving = false;
  final _formKey = GlobalKey<FormState>();

  bool get _isPrescriptionCat =>
      _selectedCat?.name == 'Prescription / Medication';

  @override
  void dispose() {
    _reportNameCtrl.dispose();
    _doctorCtrl.dispose();
    _hospitalCtrl.dispose();
    _notesCtrl.dispose();
    _diagnosisCtrl.dispose();
    _commentsCtrl.dispose();
    _medNameCtrl.dispose();
    _medDosageCtrl.dispose();
    _medFreqCtrl.dispose();
    _patientEmailCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickReportDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _reportDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
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
    if (picked != null) setState(() => _reportDate = picked);
  }

  Future<void> _pickAndUpload() async {
    setState(() => _uploading = true);
    try {
      final result = await StorageService.pickAndUpload(reportId: _tempReportId);
      if (result != null && mounted) {
        setState(() => _attachments.add(result));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red.shade800),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _pickMedTillDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
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
    if (picked != null) setState(() => _medTillDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ReportService.addReport(
        category: _selectedCat!.name,
        type: _selectedType!,
        reportName: _reportNameCtrl.text.trim(),
        date: _reportDate,
        doctorName: _doctorCtrl.text.trim(),
        hospitalName: _hospitalCtrl.text.trim(),
        clinicalNotes: _notesCtrl.text.trim(),
        diagnosis: _diagnosisCtrl.text.trim(),
        additionalComments: _commentsCtrl.text.trim(),
        tags: _selectedTags,
        attachments: _attachments.map((a) => {'name': a.name, 'url': a.url}).toList(),
        doctorId: widget.currentUser?.isDoctor == true ? widget.currentUser!.id : null,
        patientId: widget.currentUser?.isPatient == true
            ? widget.currentUser!.id
            : _resolvedPatientId,
        patientName: widget.currentUser?.isPatient == true ? widget.currentUser!.name : null,
        medName: _addMedication ? _medNameCtrl.text.trim() : null,
        medDosage: _addMedication ? _medDosageCtrl.text.trim() : null,
        medFrequency: _addMedication ? _medFreqCtrl.text.trim() : null,
        medTimesPerDay: _addMedication ? _medTimesPerDay : null,
        medTillDate: _addMedication ? _medTillDate : null,
      );
      widget.onSaved();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e'),
              backgroundColor: Colors.red.shade800),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // drag handle
          Center(
            child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.white24,
                    borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 16),
          // step indicator
          _StepBar(current: _step, total: _isPrescriptionCat ? 4 : 3),
          const SizedBox(height: 20),
          Flexible(
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: _buildStep(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildBottomButtons(),
        ],
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _buildCategoryStep();
      case 1:
        return _buildTypeStep();
      case 2:
        return _buildFieldsStep();
      case 3:
        return _buildMedicationStep();
      default:
        return const SizedBox();
    }
  }

  // ── Step 0: Category ──────────────────────────────────────────────────────

  Widget _buildCategoryStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Select Category', style: Theme.of(context).textTheme.titleLarge
            ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _categories.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 2.4,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemBuilder: (_, i) {
            final cat = _categories[i];
            final selected = _selectedCat == cat;
            return GestureDetector(
              onTap: () => setState(() { _selectedCat = cat; _selectedType = null; }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  color: selected ? cat.color.withOpacity(0.18) : AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected ? cat.color : Colors.white12,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Icon(cat.icon, color: selected ? cat.color : Colors.white38, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(cat.name,
                          style: TextStyle(
                            color: selected ? Colors.white : Colors.white60,
                            fontSize: 12,
                            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                          ),
                          maxLines: 2),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // ── Step 1: Type ──────────────────────────────────────────────────────────

  Widget _buildTypeStep() {
    final types = _selectedCat!.types;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(_selectedCat!.icon, color: _selectedCat!.color, size: 20),
          const SizedBox(width: 8),
          Text(_selectedCat!.name,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 6),
        Text('Select the report type', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13)),
        const SizedBox(height: 16),
        ...types.map((t) {
          final selected = _selectedType == t;
          return GestureDetector(
            onTap: () => setState(() => _selectedType = t),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: selected ? _selectedCat!.color.withOpacity(0.15) : AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? _selectedCat!.color : Colors.white12,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      color: selected ? _selectedCat!.color : Colors.white30, size: 18),
                  const SizedBox(width: 12),
                  Text(t, style: TextStyle(
                    color: selected ? Colors.white : Colors.white70,
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  )),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  // ── Step 2: Common fields ─────────────────────────────────────────────────

  Widget _buildFieldsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Report Details', style: Theme.of(context).textTheme.titleLarge
            ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        _RField(controller: _reportNameCtrl, label: 'Report / Test Name',
            hint: 'e.g. CBC Blood Test',
            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null),
        const SizedBox(height: 12),
        // Date picker
        GestureDetector(
          onTap: _pickReportDate,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            decoration: BoxDecoration(color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white12)),
            child: Row(children: [
              const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.accent),
              const SizedBox(width: 10),
              Text(
                '${_reportDate.day}/${_reportDate.month}/${_reportDate.year}',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              const Spacer(),
              const Text('Date of Report', style: TextStyle(color: Colors.white38, fontSize: 12)),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        _RField(controller: _doctorCtrl, label: 'Doctor Name', hint: 'e.g. Dr. Sharma'),
        const SizedBox(height: 12),
        _RField(controller: _hospitalCtrl, label: 'Hospital / Lab Name',
            hint: 'e.g. Apollo Hospital'),
        const SizedBox(height: 12),
        _RField(controller: _notesCtrl, label: 'Clinical Notes',
            hint: 'Patient symptoms, observations…', maxLines: 3),
        const SizedBox(height: 12),
        _RField(controller: _diagnosisCtrl, label: 'Diagnosis',
            hint: 'e.g. Iron deficiency anaemia'),
        const SizedBox(height: 12),
        _RField(controller: _commentsCtrl, label: 'Additional Comments',
            hint: 'Any extra notes', maxLines: 2),
        const SizedBox(height: 18),
        // Tags
        Text('Chronic Condition Tags',
            style: TextStyle(color: Colors.white.withOpacity(0.65),
                fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _commonTags.map((tag) {
            final on = _selectedTags.contains(tag);
            return GestureDetector(
              onTap: () => setState(() => on ? _selectedTags.remove(tag) : _selectedTags.add(tag)),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: on ? AppColors.accent.withOpacity(0.18) : AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: on ? AppColors.accent : Colors.white12),
                ),
                child: Text(tag, style: TextStyle(
                  fontSize: 12,
                  color: on ? AppColors.accent : Colors.white54,
                  fontWeight: on ? FontWeight.w600 : FontWeight.normal,
                )),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 18),
        // Toggle medication
        GestureDetector(
          onTap: () => setState(() => _addMedication = !_addMedication),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: _addMedication
                  ? AppColors.accent.withOpacity(0.12)
                  : AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: _addMedication ? AppColors.accent : Colors.white12),
            ),
            child: Row(children: [
              Icon(Icons.medication_outlined,
                  color: _addMedication ? AppColors.accent : Colors.white38, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Also add medication from this report',
                    style: TextStyle(
                      color: _addMedication ? Colors.white : Colors.white60,
                      fontSize: 14,
                      fontWeight: _addMedication ? FontWeight.w600 : FontWeight.normal,
                    )),
              ),
              Icon(_addMedication ? Icons.toggle_on : Icons.toggle_off,
                  color: _addMedication ? AppColors.accent : Colors.white30, size: 28),
            ]),
          ),
        ),
        const SizedBox(height: 18),

        // ── Attachments ────────────────────────────────────────────────────
        Text('Attachments',
            style: TextStyle(color: Colors.white.withOpacity(0.65),
                fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        if (_attachments.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _attachments.asMap().entries.map((e) {
              final idx = e.key;
              final att = e.value;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.accentBlue.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.accentBlue.withOpacity(0.35)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(_fileIcon(att.name), color: AppColors.accentBlue, size: 16),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 160),
                    child: Text(att.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => setState(() => _attachments.removeAt(idx)),
                    child: const Icon(Icons.close, size: 14, color: Colors.white38),
                  ),
                ]),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
        ],
        GestureDetector(
          onTap: _uploading ? null : _pickAndUpload,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _uploading ? AppColors.accent : Colors.white12,
                width: _uploading ? 1.5 : 1,
              ),
            ),
            child: Row(children: [
              _uploading
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent))
                  : Icon(Icons.upload_file_outlined,
                      size: 18, color: Colors.white.withOpacity(0.5)),
              const SizedBox(width: 10),
              Text(
                _uploading ? 'Uploading…' : 'Upload PDF / Image',
                style: TextStyle(
                  color: _uploading ? AppColors.accent : Colors.white38,
                  fontSize: 14,
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }

  IconData _fileIcon(String name) {
    final ext = name.split('.').last.toLowerCase();
    if (ext == 'pdf') return Icons.picture_as_pdf;
    if (['jpg', 'jpeg', 'png'].contains(ext)) return Icons.image;
    return Icons.insert_drive_file;
  }

  // ── Step 3: Medication (optional) ─────────────────────────────────────────

  Widget _buildMedicationStep() {
    const labels = [
      ['Daily'],
      ['Morning', 'Evening'],
      ['Morning', 'Afternoon', 'Evening'],
      ['Morning', 'Afternoon', 'Evening', 'Night'],
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Medication Details', style: Theme.of(context).textTheme.titleLarge
            ?.copyWith(fontWeight: FontWeight.w700)),
        Text('This will also appear in the Medication tab',
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13)),
        const SizedBox(height: 16),

        // ── Doctor: patient email lookup ──────────────────────────────────
        if (widget.currentUser?.isDoctor == true) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _RField(
                  controller: _patientEmailCtrl,
                  label: "Patient's email",
                  hint: 'patient@gmail.com',
                  keyboardType: TextInputType.emailAddress,
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: _lookingUpPatient
                      ? null
                      : () async {
                          final email = _patientEmailCtrl.text.trim();
                          if (email.isEmpty) return;
                          setState(() => _lookingUpPatient = true);
                          final id = await EmailPasswordAuthService
                              .findPatientIdByEmail(email);
                          if (mounted) {
                            setState(() {
                              _resolvedPatientId = id;
                              _lookingUpPatient = false;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(id != null
                                  ? 'Patient found'
                                  : 'No patient found with that email'),
                              backgroundColor: id != null
                                  ? AppColors.success
                                  : Colors.red.shade800,
                            ));
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.surfaceElevated,
                    foregroundColor: AppColors.accent,
                    side: BorderSide(
                      color: _resolvedPatientId != null
                          ? AppColors.success
                          : AppColors.accent,
                    ),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _lookingUpPatient
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.accent))
                      : Icon(
                          _resolvedPatientId != null
                              ? Icons.check_circle
                              : Icons.search,
                          size: 20,
                        ),
                ),
              ),
            ],
          ),
          if (_resolvedPatientId != null) ...[
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.check_circle, size: 14, color: AppColors.success),
              const SizedBox(width: 6),
              Text('Patient linked — medication will appear on their screen',
                  style: TextStyle(
                      color: AppColors.success.withOpacity(0.85), fontSize: 12)),
            ]),
          ],
          const SizedBox(height: 16),
        ],

        _RField(controller: _medNameCtrl, label: 'Medication Name',
            hint: 'e.g. Paracetamol',
            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null),
        const SizedBox(height: 12),
        _RField(controller: _medDosageCtrl, label: 'Dosage',
            hint: 'e.g. 500 mg',
            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null),
        const SizedBox(height: 12),
        _RField(controller: _medFreqCtrl, label: 'Frequency',
            hint: 'e.g. After meals',
            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null),
        const SizedBox(height: 18),
        Text('Times per day',
            style: TextStyle(color: Colors.white.withOpacity(0.65),
                fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Row(
          children: [1, 2, 3, 4].map((n) {
            final selected = _medTimesPerDay == n;
            final slotLabels = labels[n - 1];
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _medTimesPerDay = n),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: EdgeInsets.only(right: n < 4 ? 8 : 0),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.accent.withOpacity(0.18) : AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: selected ? AppColors.accent : Colors.white12,
                        width: selected ? 1.5 : 1),
                  ),
                  child: Column(
                    children: [
                      Text('$n×', style: TextStyle(
                          color: selected ? AppColors.accent : Colors.white.withOpacity(0.45),
                          fontWeight: FontWeight.w700, fontSize: 16)),
                      const SizedBox(height: 3),
                      Text(slotLabels.join('\n'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: selected ? AppColors.accent.withOpacity(0.8)
                                  : Colors.white.withOpacity(0.3),
                              fontSize: 9)),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 18),
        // Till date
        GestureDetector(
          onTap: _pickMedTillDate,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(children: [
              Icon(Icons.calendar_today_outlined, size: 18,
                  color: _medTillDate != null ? AppColors.accent : Colors.white.withOpacity(0.45)),
              const SizedBox(width: 10),
              Text(
                _medTillDate == null
                    ? 'Till when (optional)'
                    : 'Till ${_medTillDate!.day}/${_medTillDate!.month}/${_medTillDate!.year}',
                style: TextStyle(color: _medTillDate == null ? Colors.white30 : Colors.white,
                    fontSize: 14),
              ),
              if (_medTillDate != null) ...[
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() => _medTillDate = null),
                  child: Icon(Icons.close, size: 16, color: Colors.white.withOpacity(0.4)),
                ),
              ],
            ]),
          ),
        ),
      ],
    );
  }

  // ── Bottom buttons ────────────────────────────────────────────────────────

  Widget _buildBottomButtons() {
    final maxStep = _addMedication ? 3 : 2;
    final isLast = _step == maxStep;

    bool canProceed() {
      if (_step == 0) return _selectedCat != null;
      if (_step == 1) return _selectedType != null;
      return true;
    }

    return Row(
      children: [
        if (_step > 0)
          Expanded(
            child: OutlinedButton(
              onPressed: () => setState(() => _step--),
              child: const Text('Back'),
            ),
          ),
        if (_step > 0) const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: canProceed()
                ? isLast
                    ? (_saving ? null : _save)
                    : () {
                        if (_step == 2 && _addMedication) {
                          setState(() => _step++);
                        } else if (_step == 2) {
                          _save();
                        } else {
                          setState(() => _step++);
                        }
                      }
                : null,
            child: _saving
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink))
                : Text(isLast ? 'Save Report' : _step == 2 && !_addMedication ? 'Save Report' : 'Next'),
          ),
        ),
      ],
    );
  }
}

// ── Step indicator bar ────────────────────────────────────────────────────────

class _StepBar extends StatelessWidget {
  final int current;
  final int total;
  const _StepBar({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    final labels = total == 4
        ? ['Category', 'Type', 'Details', 'Medication']
        : ['Category', 'Type', 'Details'];
    return Row(
      children: List.generate(total, (i) {
        final done = i < current;
        final active = i == current;
        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 3,
                      decoration: BoxDecoration(
                        color: done || active ? AppColors.accent : Colors.white12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(labels[i],
                        style: TextStyle(
                          fontSize: 10,
                          color: active ? AppColors.accent : Colors.white30,
                          fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                        )),
                  ],
                ),
              ),
              if (i < total - 1) const SizedBox(width: 6),
            ],
          ),
        );
      }),
    );
  }
}

// ── Reusable text field ───────────────────────────────────────────────────────

class _RField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final int maxLines;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;

  const _RField({
    required this.controller,
    required this.label,
    required this.hint,
    this.maxLines = 1,
    this.validator,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 13),
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.25)),
        filled: true,
        fillColor: AppColors.surfaceElevated,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.white12)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.white12)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.danger)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.danger, width: 1.5)),
      ),
    );
  }
}
