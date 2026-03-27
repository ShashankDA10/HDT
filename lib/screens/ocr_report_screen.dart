import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';

import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../services/ocr_report_service.dart';
import '../services/report_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/app_scaffold.dart';

// ── Category metadata (mirrors reports_screen.dart) ───────────────────────────

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
    'X-Ray', 'CT Scan', 'MRI', 'Ultrasound', 'PET Scan', 'Mammography', 'Doppler Study',
  ]),
  _Cat('Clinical Consultation', Icons.person_search, Color(0xFF06b6d4), [
    'General Physician Visit', 'Specialist Consultation', 'Follow-up Visit', 'Teleconsultation',
  ]),
  _Cat('Prescription / Medication', Icons.medication, Color(0xFF10b981), [
    'New Prescription', 'Ongoing Medication', 'Refill Prescription',
  ]),
  _Cat('Hospitalization Records', Icons.local_hospital, Color(0xFFf43f5e), [
    'Admission Summary', 'Discharge Summary', 'ICU Records', 'Emergency Visit',
  ]),
  _Cat('Surgical Reports', Icons.content_cut, Color(0xFFf97316), [
    'Pre-operative Report', 'Operation Notes', 'Post-operative Report',
  ]),
  _Cat('Vaccination Records', Icons.vaccines, Color(0xFF84cc16), [
    'Childhood Vaccines', 'COVID-19 Vaccination', 'Travel Vaccines', 'Booster Doses',
  ]),
  _Cat('Vital Monitoring', Icons.monitor_heart, Color(0xFFec4899), [
    'Blood Pressure Log', 'Blood Sugar Log', 'Heart Rate Monitoring',
    'Weight Tracking', 'Oxygen Saturation',
  ]),
  _Cat('Dental Records', Icons.sentiment_very_satisfied, Color(0xFFa78bfa), [
    'Oral Checkup', 'Cleaning / Scaling', 'Filling / Restoration',
    'Root Canal Treatment', 'Orthodontic Records',
  ]),
  _Cat('Other Documents', Icons.folder_open, Color(0xFF94a3b8), [
    'Insurance Documents', 'Medical Certificates', 'Fitness Certificates', 'Miscellaneous Reports',
  ]),
];

const _commonTags = [
  'Diabetes', 'Hypertension', 'Asthma', 'Heart Disease',
  'Thyroid', 'Anemia', 'Obesity', 'Arthritis',
];

// ── Screen steps ──────────────────────────────────────────────────────────────

enum _OcrStep { source, scanning, review }

// ── Main screen ───────────────────────────────────────────────────────────────

class OcrReportScreen extends StatefulWidget {
  const OcrReportScreen({super.key});

  @override
  State<OcrReportScreen> createState() => _OcrReportScreenState();
}

class _OcrReportScreenState extends State<OcrReportScreen>
    with TickerProviderStateMixin {

  _OcrStep _step = _OcrStep.source;
  XFile? _imageFile;
  OcrParsedReport? _parsed;
  String? _ocrError;

  // Scanning animation
  late final AnimationController _scanAnim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  // Success animation (briefly shown after scan completes)
  late final AnimationController _successAnim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );

  // ── Form state ───────────────────────────────────────────────────────────────
  AppUser? _currentUser;

  final _reportNameCtrl = TextEditingController();
  final _doctorCtrl     = TextEditingController();
  final _hospitalCtrl   = TextEditingController();
  final _notesCtrl      = TextEditingController();
  final _diagnosisCtrl  = TextEditingController();
  final _commentsCtrl   = TextEditingController();
  DateTime _reportDate  = DateTime.now();
  final List<String> _selectedTags = [];

  _Cat? _selectedCat;
  String? _selectedType;

  bool _saving = false;
  final _formKey = GlobalKey<FormState>();
  // Temp id for Storage folder
  final String _tempId = DateTime.now().millisecondsSinceEpoch.toString();

  @override
  void initState() {
    super.initState();
    EmailPasswordAuthService.currentAppUser().then((u) {
      if (mounted) setState(() => _currentUser = u);
    });
  }

  @override
  void dispose() {
    _scanAnim.dispose();
    _successAnim.dispose();
    _reportNameCtrl.dispose();
    _doctorCtrl.dispose();
    _hospitalCtrl.dispose();
    _notesCtrl.dispose();
    _diagnosisCtrl.dispose();
    _commentsCtrl.dispose();
    super.dispose();
  }

  // ── Image capture ─────────────────────────────────────────────────────────────

  Future<void> _capture(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 2048,
        maxHeight: 2048,
      );
      if (file == null || !mounted) return;
      setState(() {
        _imageFile = file;
        _step = _OcrStep.scanning;
        _ocrError = null;
      });
      await _runOcr(file);
    } catch (e) {
      if (mounted) {
        _showError('Could not open camera/gallery: $e');
      }
    }
  }

  Future<void> _runOcr(XFile file) async {
    try {
      final rawText = await OcrReportService.extractText(file);
      if (!mounted) return;

      if (rawText == null || rawText.trim().isEmpty) {
        // No text found — go to blank review form
        setState(() {
          _parsed = OcrParsedReport(
            rawText: '',
            doctorName: '',
            hospitalName: '',
            clinicalNotes: '',
            diagnosis: '',
            additionalComments: '',
            suggestedCategory: 'Other Documents',
            suggestedType: 'Miscellaneous Reports',
            suggestedTags: [],
          );
          _ocrError = 'No text could be extracted. Please fill in the fields manually.';
        });
        _applyParsedData(_parsed!);
        setState(() => _step = _OcrStep.review);
        return;
      }

      final parsed = OcrReportService.parseFields(rawText);
      if (!mounted) return;

      // Brief success flash before transitioning
      await _successAnim.forward();
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;

      setState(() => _parsed = parsed);
      _applyParsedData(parsed);
      setState(() => _step = _OcrStep.review);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _ocrError = 'OCR failed. Please check your internet connection for the first scan, '
            'then try again.\n\nError: $e';
        _step = _OcrStep.review;
        _parsed = OcrParsedReport(
          rawText: '',
          doctorName: '',
          hospitalName: '',
          clinicalNotes: '',
          diagnosis: '',
          additionalComments: '',
          suggestedCategory: 'Other Documents',
          suggestedType: 'Miscellaneous Reports',
          suggestedTags: [],
        );
      });
    }
  }

  void _applyParsedData(OcrParsedReport p) {
    _doctorCtrl.text   = p.doctorName;
    _hospitalCtrl.text = p.hospitalName;
    _notesCtrl.text    = p.clinicalNotes;
    _diagnosisCtrl.text = p.diagnosis;
    _commentsCtrl.text  = p.additionalComments;
    if (p.reportDate != null) _reportDate = p.reportDate!;

    final catMatch = _categories.where((c) => c.name == p.suggestedCategory).toList();
    if (catMatch.isNotEmpty) {
      _selectedCat = catMatch.first;
      if (_selectedCat!.types.contains(p.suggestedType)) {
        _selectedType = p.suggestedType;
      } else {
        _selectedType = _selectedCat!.types.first;
      }
    }

    _selectedTags.clear();
    for (final t in p.suggestedTags) {
      if (_commonTags.contains(t)) _selectedTags.add(t);
    }
  }

  // ── Save ──────────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (_selectedCat == null || _selectedType == null) {
      _showError('Please select a report category and type.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      // Upload the photo to Firebase Storage as an attachment
      final attachments = <Map<String, String>>[];
      if (_imageFile != null) {
        final bytes = await File(_imageFile!.path).readAsBytes();
        final fileName =
            'scan_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final ref = FirebaseStorage.instance
            .ref('reports/$_tempId/$fileName');
        await ref.putData(bytes,
            SettableMetadata(contentType: 'image/jpeg'));
        final url = await ref.getDownloadURL();
        attachments.add({'name': fileName, 'url': url});
      }

      await ReportService.addReport(
        category:           _selectedCat!.name,
        type:               _selectedType!,
        reportName:         _reportNameCtrl.text.trim(),
        date:               _reportDate,
        doctorName:         _doctorCtrl.text.trim(),
        hospitalName:       _hospitalCtrl.text.trim(),
        clinicalNotes:      _notesCtrl.text.trim(),
        diagnosis:          _diagnosisCtrl.text.trim(),
        additionalComments: _commentsCtrl.text.trim(),
        tags:               List.from(_selectedTags),
        attachments:        attachments,
        patientId:          _currentUser?.id,
        patientName:        _currentUser?.name,
        source:             'patient_upload',
        rawOcrText:         _parsed?.rawText,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true); // return true → trigger reload
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _showError('Failed to save report: $e');
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.danger,
    ));
  }

  // ── Date picker ───────────────────────────────────────────────────────────────

  Future<void> _pickDate() async {
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

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_step == _OcrStep.review) {
              setState(() { _step = _OcrStep.source; _imageFile = null; });
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
        title: Text(_appBarTitle),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
            child: child,
          ),
        ),
        child: switch (_step) {
          _OcrStep.source   => _buildSourceStep(),
          _OcrStep.scanning => _buildScanningStep(),
          _OcrStep.review   => _buildReviewStep(),
        },
      ),
    );
  }

  String get _appBarTitle => switch (_step) {
    _OcrStep.source   => 'Scan Report',
    _OcrStep.scanning => 'Scanning…',
    _OcrStep.review   => 'Review & Save',
  };

  // ── Step 0: source ─────────────────────────────────────────────────────────

  Widget _buildSourceStep() {
    return SingleChildScrollView(
      key: const ValueKey('source'),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text('Add Your Own Report',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            'Take a clear photo of any medical report you have — '
            'lab results, prescriptions, imaging, consultations — '
            'and we\'ll read the details automatically.',
            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 32),

          // Camera option (primary)
          _SourceCard(
            icon: Icons.camera_alt_rounded,
            color: AppColors.accent,
            title: 'Take a Photo',
            subtitle: 'Open camera and photograph your report',
            onTap: () => _capture(ImageSource.camera),
          ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.08, end: 0),
          const SizedBox(height: 14),

          // Gallery option (secondary)
          _SourceCard(
            icon: Icons.photo_library_rounded,
            color: AppColors.accentBlue,
            title: 'Choose from Gallery',
            subtitle: 'Pick an existing photo from your phone',
            onTap: () => _capture(ImageSource.gallery),
          ).animate().fadeIn(delay: 80.ms, duration: 300.ms).slideY(begin: 0.08, end: 0),

          const SizedBox(height: 32),
          _TipBanner(
            icon: Icons.lightbulb_outline,
            color: AppColors.accentAmber,
            message: 'Tip: Make sure the report is flat, well-lit and fully in frame for best results.',
          ).animate().fadeIn(delay: 160.ms, duration: 300.ms),
        ],
      ),
    );
  }

  // ── Step 1: scanning ────────────────────────────────────────────────────────

  Widget _buildScanningStep() {
    return Column(
      key: const ValueKey('scanning'),
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // The captured image
              if (_imageFile != null)
                Image.file(
                  File(_imageFile!.path),
                  fit: BoxFit.contain,
                ),

              // Scanning overlay
              AnimatedBuilder(
                animation: _scanAnim,
                builder: (_, __) => CustomPaint(
                  painter: _ScannerPainter(
                    progress: _scanAnim.value,
                    color: AppColors.accent,
                    successFraction: _successAnim.value,
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Row(
            children: [
              AnimatedBuilder(
                animation: _successAnim,
                builder: (_, __) {
                  if (_successAnim.value > 0.5) {
                    return const Icon(Icons.check_circle_rounded,
                        color: AppColors.accent, size: 28);
                  }
                  return const SizedBox(
                    width: 28, height: 28,
                    child: CircularProgressIndicator(
                        color: AppColors.accent, strokeWidth: 2.5),
                  );
                },
              ),
              const SizedBox(width: 16),
              Expanded(
                child: AnimatedBuilder(
                  animation: _successAnim,
                  builder: (_, __) {
                    final done = _successAnim.value > 0.5;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          done ? 'Scan complete!' : 'Analyzing your report…',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          done
                              ? 'Preparing your review form'
                              : 'Reading text and identifying medical fields',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 12),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Step 2: review ──────────────────────────────────────────────────────────

  Widget _buildReviewStep() {
    final extracted = _parsed?.extractedFieldCount ?? 0;

    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        key: const ValueKey('review'),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // OCR result banner
            if (_ocrError != null)
              _TipBanner(
                icon: Icons.warning_amber_rounded,
                color: AppColors.accentAmber,
                message: _ocrError!,
              )
            else if (extracted > 0)
              _TipBanner(
                icon: Icons.auto_fix_high_rounded,
                color: AppColors.accent,
                message: '$extracted field${extracted == 1 ? '' : 's'} auto-extracted. '
                    'Review and correct if needed before saving.',
              ),
            const SizedBox(height: 16),

            // Image thumbnail + retake
            if (_imageFile != null)
              AppCard(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(
                        File(_imageFile!.path),
                        width: 72, height: 72,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Scanned Image',
                              style: TextStyle(color: Colors.white,
                                  fontWeight: FontWeight.w600, fontSize: 14)),
                          const SizedBox(height: 4),
                          Text('Attached as report image',
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 12)),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => setState(() {
                        _imageFile = null;
                        _step = _OcrStep.source;
                      }),
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Retake'),
                      style: TextButton.styleFrom(
                          foregroundColor: AppColors.accentBlue),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),

            // ── Category ─────────────────────────────────────────────────────
            _SectionHeader(
                label: 'Category',
                required: true,
                hint: _selectedCat == null ? 'Select one below' : null),
            const SizedBox(height: 10),
            _buildCategoryGrid(),
            const SizedBox(height: 20),

            // ── Type ─────────────────────────────────────────────────────────
            if (_selectedCat != null) ...[
              _SectionHeader(label: 'Report Type', required: true),
              const SizedBox(height: 10),
              _buildTypeList(),
              const SizedBox(height: 20),
            ],

            // ── Report name ───────────────────────────────────────────────────
            _SectionHeader(label: 'Report Name', hint: 'Optional — e.g. "Annual Blood Test"'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _reportNameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDec('e.g. Annual Blood Test'),
            ),
            const SizedBox(height: 16),

            // ── Date ──────────────────────────────────────────────────────────
            _SectionHeader(
                label: 'Report Date',
                required: true,
                autoExtracted: _parsed?.reportDate != null),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, color: AppColors.accent, size: 18),
                    const SizedBox(width: 10),
                    Text(
                      _formatDate(_reportDate),
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                    ),
                    const Spacer(),
                    Icon(Icons.edit_calendar_rounded,
                        color: Colors.white.withOpacity(0.35), size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Doctor ────────────────────────────────────────────────────────
            _SectionHeader(
                label: 'Doctor Name',
                hint: 'Optional',
                autoExtracted: _parsed != null && _parsed!.doctorName.isNotEmpty),
            const SizedBox(height: 8),
            TextFormField(
              controller: _doctorCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDec('e.g. Dr. Sharma'),
            ),
            const SizedBox(height: 16),

            // ── Hospital ──────────────────────────────────────────────────────
            _SectionHeader(
                label: 'Hospital / Lab',
                hint: 'Optional',
                autoExtracted: _parsed != null && _parsed!.hospitalName.isNotEmpty),
            const SizedBox(height: 8),
            TextFormField(
              controller: _hospitalCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDec('e.g. City Diagnostic Centre'),
            ),
            const SizedBox(height: 16),

            // ── Clinical notes ────────────────────────────────────────────────
            _SectionHeader(
                label: 'Clinical Notes / Findings',
                hint: 'Optional',
                autoExtracted: _parsed != null && _parsed!.clinicalNotes.isNotEmpty),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesCtrl,
              maxLines: 4,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDec('Test findings, results, observations…'),
            ),
            const SizedBox(height: 16),

            // ── Diagnosis ─────────────────────────────────────────────────────
            _SectionHeader(
                label: 'Diagnosis / Impression',
                hint: 'Optional',
                autoExtracted: _parsed != null && _parsed!.diagnosis.isNotEmpty),
            const SizedBox(height: 8),
            TextFormField(
              controller: _diagnosisCtrl,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDec('Doctor\'s diagnosis or clinical impression…'),
            ),
            const SizedBox(height: 16),

            // ── Additional comments ───────────────────────────────────────────
            _SectionHeader(
                label: 'Additional Comments',
                hint: 'Optional',
                autoExtracted: _parsed != null && _parsed!.additionalComments.isNotEmpty),
            const SizedBox(height: 8),
            TextFormField(
              controller: _commentsCtrl,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDec('Remarks, advice, recommendations…'),
            ),
            const SizedBox(height: 20),

            // ── Tags ──────────────────────────────────────────────────────────
            _SectionHeader(
                label: 'Tags',
                hint: 'Tap to select',
                autoExtracted: _selectedTags.isNotEmpty),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _commonTags.map((tag) {
                final selected = _selectedTags.contains(tag);
                return FilterChip(
                  label: Text(tag),
                  selected: selected,
                  onSelected: (_) => setState(() {
                    if (selected) {
                      _selectedTags.remove(tag);
                    } else {
                      _selectedTags.add(tag);
                    }
                  }),
                  backgroundColor: AppColors.surfaceElevated,
                  selectedColor: AppColors.accent.withOpacity(0.2),
                  checkmarkColor: AppColors.accent,
                  labelStyle: TextStyle(
                    color: selected ? AppColors.accent : Colors.white70,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 13,
                  ),
                  side: BorderSide(
                    color: selected
                        ? AppColors.accent.withOpacity(0.5)
                        : AppColors.outline.withOpacity(0.5),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),

            // ── Save button ───────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.ink))
                    : const Icon(Icons.save_rounded, size: 20),
                label: Text(_saving ? 'Saving…' : 'Save Report',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.ink,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Category grid ─────────────────────────────────────────────────────────────

  Widget _buildCategoryGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.8,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: _categories.length,
      itemBuilder: (_, i) {
        final cat = _categories[i];
        final selected = _selectedCat?.name == cat.name;
        return InkWell(
          onTap: () => setState(() {
            _selectedCat = cat;
            _selectedType = cat.types.first;
          }),
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: selected
                  ? cat.color.withOpacity(0.18)
                  : AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? cat.color.withOpacity(0.6)
                    : AppColors.outline.withOpacity(0.3),
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(cat.icon, color: selected ? cat.color : Colors.white38, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    cat.name,
                    style: TextStyle(
                      color: selected ? cat.color : Colors.white60,
                      fontSize: 11,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Type list ─────────────────────────────────────────────────────────────────

  Widget _buildTypeList() {
    final types = _selectedCat!.types;
    return AppCard(
      padding: const EdgeInsets.all(4),
      child: Column(
        children: types.map((t) {
          final selected = _selectedType == t;
          return InkWell(
            onTap: () => setState(() => _selectedType = t),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 18, height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected
                          ? _selectedCat!.color
                          : Colors.transparent,
                      border: Border.all(
                        color: selected
                            ? _selectedCat!.color
                            : Colors.white24,
                        width: 1.5,
                      ),
                    ),
                    child: selected
                        ? const Icon(Icons.check, color: Colors.white, size: 11)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(t,
                        style: TextStyle(
                          color: selected ? Colors.white : Colors.white70,
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.normal,
                          fontSize: 13,
                        )),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  InputDecoration _inputDec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14),
        filled: true,
        fillColor: AppColors.surfaceSoft,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      );

  String _formatDate(DateTime d) {
    const m = ['Jan','Feb','Mar','Apr','May','Jun',
                'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${m[d.month - 1]} ${d.day}, ${d.year}';
  }
}

// ── Scanner overlay painter ────────────────────────────────────────────────────

class _ScannerPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double successFraction;

  const _ScannerPainter({
    required this.progress,
    required this.color,
    required this.successFraction,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Dimming overlay that strengthens on success
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.black.withOpacity(0.35 * (1 - successFraction)),
    );

    final bracketColor = Color.lerp(color, AppColors.success, successFraction)!;
    const margin = 16.0;
    const len = 28.0;
    final bPaint = Paint()
      ..color = bracketColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    // Corner brackets
    void bracket(double x, double y, double dx, double dy) {
      canvas.drawPath(
        Path()
          ..moveTo(x, y + dy * len)
          ..lineTo(x, y)
          ..lineTo(x + dx * len, y),
        bPaint,
      );
    }

    bracket(margin, margin, 1, 1);
    bracket(size.width - margin, margin, -1, 1);
    bracket(margin, size.height - margin, 1, -1);
    bracket(size.width - margin, size.height - margin, -1, -1);

    // Animated scan line (hidden when success)
    if (successFraction < 0.5) {
      final y = size.height * progress;
      final glowPaint = Paint()
        ..color = color.withOpacity(0.35 * (1 - successFraction * 2))
        ..strokeWidth = 10
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      final linePaint = Paint()
        ..color = color.withOpacity(1 - successFraction * 2)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(margin, y), Offset(size.width - margin, y), glowPaint);
      canvas.drawLine(Offset(margin, y), Offset(size.width - margin, y), linePaint);
    }

    // Success check circle
    if (successFraction > 0.3) {
      final opacity = ((successFraction - 0.3) / 0.7).clamp(0.0, 1.0);
      final cx = size.width / 2;
      final cy = size.height / 2;
      final radius = 36.0;
      canvas.drawCircle(
        Offset(cx, cy),
        radius,
        Paint()..color = AppColors.success.withOpacity(0.9 * opacity),
      );
      final checkPaint = Paint()
        ..color = Colors.white.withOpacity(opacity)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      final path = Path()
        ..moveTo(cx - 14, cy)
        ..lineTo(cx - 4, cy + 10)
        ..lineTo(cx + 14, cy - 10);
      canvas.drawPath(path, checkPaint);
    }
  }

  @override
  bool shouldRepaint(_ScannerPainter old) =>
      old.progress != progress || old.successFraction != successFraction;
}

// ── Reusable small widgets ────────────────────────────────────────────────────

class _SourceCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SourceCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(color: Colors.white,
                          fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: TextStyle(color: Colors.white.withOpacity(0.5),
                          fontSize: 13)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                color: color.withOpacity(0.7), size: 16),
          ],
        ),
      ),
    );
  }
}

class _TipBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String message;

  const _TipBanner({
    required this.icon,
    required this.color,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 13,
                    height: 1.5)),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final String? hint;
  final bool required;
  final bool autoExtracted;

  const _SectionHeader({
    required this.label,
    this.hint,
    this.required = false,
    this.autoExtracted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
        if (required)
          const Text(' *',
              style: TextStyle(color: AppColors.danger, fontSize: 14)),
        const Spacer(),
        if (autoExtracted)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.auto_fix_high_rounded,
                    color: AppColors.accent, size: 11),
                const SizedBox(width: 4),
                const Text('Auto-extracted',
                    style: TextStyle(
                        color: AppColors.accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          )
        else if (hint != null)
          Text(hint!,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.4), fontSize: 12)),
      ],
    );
  }
}

