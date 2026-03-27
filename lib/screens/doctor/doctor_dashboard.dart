import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../services/medication_service.dart';
import '../../services/report_service.dart';
import '../../services/storage_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/auth_field.dart';
import '../appointments/doctor_appointments_screen.dart';
import 'doctor_patient_summary_screen.dart';
import 'qr_scanner_screen.dart';

// ── Patient summary ────────────────────────────────────────────────────────────

class _PatientSummary {
  final String id;
  final String name;
  const _PatientSummary({required this.id, required this.name});
}

// ── Category metadata ─────────────────────────────────────────────────────────

class _Cat {
  final String name;
  final IconData icon;
  final Color color;
  final List<String> types;
  const _Cat(this.name, this.icon, this.color, this.types);
}

const _reportCategories = [
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
  _Cat('Vital Monitoring Reports', Icons.monitor_heart, Color(0xFFec4899), [
    'Blood Pressure Log', 'Blood Sugar Log', 'Heart Rate Monitoring', 'Weight Tracking', 'Oxygen Saturation',
  ]),
  _Cat('Dental Records', Icons.sentiment_very_satisfied, Color(0xFFa78bfa), [
    'Oral Checkup', 'Cleaning / Scaling', 'Filling / Restoration', 'Root Canal Treatment', 'Orthodontic Records',
  ]),
  _Cat('Other Medical Documents', Icons.folder_open, Color(0xFF94a3b8), [
    'Insurance Documents', 'Medical Certificates', 'Fitness Certificates', 'Miscellaneous Reports',
  ]),
];

// Meal timing options shared across patient and doctor medication forms
const _mealTimingOptions = [
  'Before Meals',
  'After Meals',
  'With Meals',
  'Empty Stomach',
  'At Bedtime',
  'As Needed',
];

// ── Main dashboard ─────────────────────────────────────────────────────────────

class DoctorDashboard extends StatefulWidget {
  final AppUser doctor;
  const DoctorDashboard({super.key, required this.doctor});

  @override
  State<DoctorDashboard> createState() => _DoctorDashboardState();
}

class _DoctorDashboardState extends State<DoctorDashboard> {
  List<Map<String, dynamic>> _reports     = [];
  List<Map<String, dynamic>> _medications = [];
  List<_PatientSummary>      _patients    = [];
  bool _loadingPatients = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loadingPatients = true);
    try {
      final results = await Future.wait([
        ReportService.getReportsByDoctor(widget.doctor.id),
        MedicationService.getMedicationsByDoctor(widget.doctor.id),
        EmailPasswordAuthService.getLinkedPatients(widget.doctor.id),
      ]);
      if (mounted) {
        setState(() {
          _reports     = List<Map<String, dynamic>>.from(results[0]);
          _medications = List<Map<String, dynamic>>.from(results[1]);
          _loadingPatients = false;
        });
        _derivePatients(linked: List<Map<String, dynamic>>.from(results[2]));
      }
    } catch (_) {
      if (mounted) setState(() => _loadingPatients = false);
    }
  }

  void _derivePatients({List<Map<String, dynamic>> linked = const []}) {
    final seen = <String>{};
    final list  = <_PatientSummary>[];
    // Linked patients always come first (added via search)
    for (final l in linked) {
      final pid  = l['patientId']   as String?;
      final name = l['patientName'] as String? ?? 'Patient';
      if (pid != null && seen.add(pid)) list.add(_PatientSummary(id: pid, name: name));
    }
    // Then patients derived from reports/medications
    for (final r in _reports) {
      final pid  = r['patientId']   as String?;
      final name = r['patientName'] as String? ?? 'Unknown';
      if (pid != null && seen.add(pid)) list.add(_PatientSummary(id: pid, name: name));
    }
    for (final m in _medications) {
      final pid  = m['patientId']   as String?;
      final name = m['patientName'] as String? ?? 'Patient';
      if (pid != null && seen.add(pid)) list.add(_PatientSummary(id: pid, name: name));
    }
    if (mounted) setState(() => _patients = list);
  }

  Future<void> _signOut() async {
    await EmailPasswordAuthService().signOut();
  }

  void _openPatientSearch() async {
    final selected = await showModalBottomSheet<AppUser>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _PatientSearchSheet(
        doctor: widget.doctor,
        onPatientLinked: _loadAll,
      ),
    );
    if (!mounted || selected == null) return;
    // Persist the link so patient always shows in the list
    EmailPasswordAuthService.linkPatientToDoctor(
      doctorId:    widget.doctor.id,
      patientId:   selected.id,
      patientName: selected.name,
    );
    _loadAll();
    // Open patient summary screen
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => DoctorPatientSummaryScreen(
          doctor: widget.doctor,
          patient: selected,
        ),
      ),
    );
    if (!mounted) return;
    if (result == 'report')    _openReportForm(patient: selected);
    if (result == 'prescribe') _openMedForm(patient: selected);
  }

  Future<AppUser?> _fetchPatientUser(String uid) async {
    try { return await EmailPasswordAuthService.fetchUserById(uid); }
    catch (_) { return null; }
  }

  void _openReportForm({required AppUser patient}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _DoctorReportForm(
        doctor: widget.doctor,
        patient: patient,
        onSaved: () { Navigator.of(context).pop(); _loadAll(); },
        onPrescribeAfter: () => _openMedForm(patient: patient),
      ),
    );
  }

  void _openMedForm({required AppUser patient}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _DoctorMedForm(
        doctor: widget.doctor,
        patient: patient,
        onSaved: () { Navigator.of(context).pop(); _loadAll(); },
      ),
    );
  }

  void _openPatientDetail(_PatientSummary patient) async {
    final patientUser = await _fetchPatientUser(patient.id);
    if (!mounted) return;
    final resolved = AppUser(
      id: patient.id, name: patient.name, email: '', phone: '', role: 'patient',
    );
    final fullPatient = patientUser ?? resolved;
    // Push summary screen; returns 'report' | 'prescribe' | null
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => DoctorPatientSummaryScreen(
          doctor: widget.doctor,
          patient: fullPatient,
        ),
      ),
    );
    if (!mounted) return;
    if (result == 'report')    _openReportForm(patient: fullPatient);
    if (result == 'prescribe') _openMedForm(patient: fullPatient);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dr. ${widget.doctor.name}',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            Text('Doctor Dashboard',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AppColors.muted)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined, color: Colors.white70),
            tooltip: 'Appointment Requests',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => DoctorAppointmentsScreen(doctor: widget.doctor),
            )),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white54),
            tooltip: 'Sign out',
            onPressed: _signOut,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openPatientSearch,
        tooltip: 'Find Patient',
        child: const Icon(Icons.person_add_outlined),
      ),
      body: _loadingPatients
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : _patients.isEmpty
              ? const _Empty(
                  icon: Icons.people_outline,
                  message: 'No patients yet',
                  sub: 'Tap + to find a patient by phone number',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  itemCount: _patients.length,
                  itemBuilder: (context, i) {
                    final p = _patients[i];
                    return AppCard(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: EdgeInsets.zero,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => _openPatientDetail(p),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(children: [
                            Container(
                              width: 44, height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.accent.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: const Icon(Icons.person, color: AppColors.accent, size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(p.name,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15)),
                            ),
                            Icon(Icons.chevron_right,
                                color: Colors.white.withOpacity(0.3), size: 20),
                          ]),
                        ),
                      ),
                    ).animate().fadeIn(delay: (50 * i).ms, duration: 300.ms);
                  },
                ),
    );
  }
}

// ── Patient Detail Sheet ────────────────────────────────────────────────────────

class _PatientDetailSheet extends StatefulWidget {
  final AppUser patient;
  const _PatientDetailSheet({required this.patient});

  @override
  State<_PatientDetailSheet> createState() => _PatientDetailSheetState();
}

class _PatientDetailSheetState extends State<_PatientDetailSheet> {
  List<Map<String, dynamic>> _reports = [];
  List<Map<String, dynamic>> _meds    = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        ReportService.getReportsByPatient(widget.patient.id),
        MedicationService.getMedications(patientId: widget.patient.id),
      ]);
      if (mounted) {
        setState(() {
          _reports = List<Map<String, dynamic>>.from(results[0]);
          _meds    = List<Map<String, dynamic>>.from(results[1]);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Handle(),
          const SizedBox(height: 20),

          // Patient header row
          Row(children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.18),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.person, color: AppColors.accent, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.patient.name,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                if (widget.patient.email.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(widget.patient.email,
                      style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 12),
                      overflow: TextOverflow.ellipsis),
                ],
                if (widget.patient.phone.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(widget.patient.phone,
                      style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 12)),
                ],
              ]),
            ),
          ]),
          const SizedBox(height: 20),

          // Reports + Medications
          ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.42),
            child: _loading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(
                          color: AppColors.accent, strokeWidth: 2),
                    ),
                  )
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionHeader(
                          icon: Icons.description_outlined,
                          label: 'Reports',
                          count: _reports.length,
                          color: AppColors.accentBlue,
                        ),
                        const SizedBox(height: 8),
                        if (_reports.isEmpty)
                          const _EmptySectionText('No reports yet')
                        else
                          ..._reports.take(5).map((r) => _PatientReportRow(report: r)),
                        const SizedBox(height: 16),
                        _SectionHeader(
                          icon: Icons.medication_outlined,
                          label: 'Medications',
                          count: _meds.length,
                          color: AppColors.accentViolet,
                        ),
                        const SizedBox(height: 8),
                        if (_meds.isEmpty)
                          const _EmptySectionText('No medications prescribed')
                        else
                          ..._meds.take(5).map((m) => _PatientMedRow(med: m)),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 20),

          // Action buttons
          Row(children: [
            Expanded(
              child: _ActionBtn(
                icon: Icons.description_outlined,
                label: 'Add Report',
                color: AppColors.accentBlue,
                onTap: () => Navigator.of(context).pop('report'),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _ActionBtn(
                icon: Icons.medication_outlined,
                label: 'Prescribe',
                color: AppColors.accentViolet,
                onTap: () => Navigator.of(context).pop('prescribe'),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

// ── Patient detail data rows ───────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String   label;
  final int      count;
  final Color    color;
  const _SectionHeader(
      {required this.icon, required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, color: color, size: 15),
    const SizedBox(width: 6),
    Text(label,
        style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
    const SizedBox(width: 6),
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
          color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
      child: Text('$count',
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    ),
  ]);
}

class _EmptySectionText extends StatelessWidget {
  final String text;
  const _EmptySectionText(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Text(text,
        style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 13)),
  );
}

class _PatientReportRow extends StatelessWidget {
  final Map<String, dynamic> report;
  const _PatientReportRow({required this.report});

  @override
  Widget build(BuildContext context) {
    final name = report['reportName'] as String? ??
        report['type'] as String? ?? 'Report';
    final cat  = report['category'] as String? ?? '';
    String dateStr = '';
    final dateField = report['date'];
    if (dateField != null) {
      try {
        final dt = (dateField as dynamic).toDate() as DateTime;
        dateStr = '${dt.day}/${dt.month}/${dt.year}';
      } catch (_) {}
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(children: [
        const Icon(Icons.description_outlined, color: AppColors.accentBlue, size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name,
                style: const TextStyle(
                    color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
            if (cat.isNotEmpty)
              Text(cat,
                  style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
                  overflow: TextOverflow.ellipsis),
          ]),
        ),
        if (dateStr.isNotEmpty)
          Text(dateStr,
              style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 11)),
      ]),
    );
  }
}

class _PatientMedRow extends StatelessWidget {
  final Map<String, dynamic> med;
  const _PatientMedRow({required this.med});

  @override
  Widget build(BuildContext context) {
    final name      = med['name']      as String? ?? 'Medication';
    final dosage    = med['dosage']    as String? ?? '';
    final frequency = med['frequency'] as String? ?? '';
    final detail    = [dosage, frequency].where((s) => s.isNotEmpty).join(' · ');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(children: [
        const Icon(Icons.medication_outlined, color: AppColors.accentViolet, size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name,
                style: const TextStyle(
                    color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
            if (detail.isNotEmpty)
              Text(detail,
                  style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
                  overflow: TextOverflow.ellipsis),
          ]),
        ),
      ]),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.w700, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

// ── Patient search sheet ──────────────────────────────────────────────────────

class _PatientSearchSheet extends StatefulWidget {
  final AppUser doctor;
  final VoidCallback onPatientLinked;
  const _PatientSearchSheet({required this.doctor, required this.onPatientLinked});

  @override
  State<_PatientSearchSheet> createState() => _PatientSearchSheetState();
}

class _PatientSearchSheetState extends State<_PatientSearchSheet> {
  final _phoneCtrl = TextEditingController();
  final _nameCtrl  = TextEditingController();
  List<AppUser> _results = [];
  bool _searching = false;
  bool _searched  = false;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final phone = _phoneCtrl.text.trim();
    final name  = _nameCtrl.text.trim();
    if (phone.isEmpty && name.isEmpty) return;
    setState(() { _searching = true; _searched = false; _results = []; });
    try {
      final results = await EmailPasswordAuthService.searchPatients(
        phone: phone.isNotEmpty ? '+91$phone' : null,
        name:  name.isNotEmpty  ? name        : null,
      );
      if (mounted) setState(() { _results = results; _searched = true; _searching = false; });
    } catch (_) {
      if (mounted) setState(() { _searching = false; _searched = true; });
    }
  }

  void _openActions(AppUser patient) {
    Navigator.of(context).pop(patient);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Handle(),
            const SizedBox(height: 16),
            const Text('Find Patient',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 18),

            // Phone row
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white12),
                ),
                child: const Center(
                  child: Text('+91', style: TextStyle(
                      color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AuthField(
                  controller: _phoneCtrl,
                  label: 'Phone number',
                  hint: '10-digit mobile number',
                  keyboardType: TextInputType.phone,
                ),
              ),
            ]),
            const SizedBox(height: 10),

            // Name row
            AuthField(
              controller: _nameCtrl,
              label: 'Name (optional)',
              hint: 'Partial name search',
            ),
            const SizedBox(height: 14),

            // Search + Scan buttons
            Row(children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _searching ? null : _search,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.ink,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _searching
                        ? const SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink))
                        : const Text('Search', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final patient = await Navigator.of(context).push<AppUser>(
                      MaterialPageRoute(
                        builder: (_) => QrScannerScreen(doctor: widget.doctor),
                      ),
                    );
                    if (patient != null && context.mounted) {
                      widget.onPatientLinked();
                      Navigator.of(context).pop(patient);
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  icon: const Icon(Icons.qr_code_scanner, size: 20),
                  label: const Text('Scan QR'),
                ),
              ),
            ]),

            const SizedBox(height: 20),

            if (_searched && _results.isEmpty)
              Text(
                'No patients found',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14),
              ),

            ..._results.map((patient) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                child: Row(children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(Icons.person, color: AppColors.accent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(patient.name, style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                      const SizedBox(height: 3),
                      Text(patient.email, style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
                    ]),
                  ),
                  ElevatedButton(
                    onPressed: () => _openActions(patient),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.ink,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    child: const Text('Open', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ]),
              ),
            )),
          ],
        ),
      ),
    );
  }
}

// ── Doctor → Report form (multi-step) ────────────────────────────────────────

class _DoctorReportForm extends StatefulWidget {
  final AppUser doctor;
  final AppUser? patient;
  final VoidCallback onSaved;
  final VoidCallback? onPrescribeAfter;
  const _DoctorReportForm({required this.doctor, this.patient, required this.onSaved, this.onPrescribeAfter});

  @override
  State<_DoctorReportForm> createState() => _DoctorReportFormState();
}

class _DoctorReportFormState extends State<_DoctorReportForm> {
  // Steps: 0=category, 1=type, 2=details
  int    _step     = 0;
  _Cat?  _selCat;
  String _selType  = '';

  final _formKey         = GlobalKey<FormState>();
  final _reportNameCtrl  = TextEditingController();
  final _hospitalCtrl    = TextEditingController();
  final _notesCtrl       = TextEditingController();
  final _diagnosisCtrl   = TextEditingController();
  final _commentsCtrl    = TextEditingController();

  DateTime _date    = DateTime.now();
  bool _saving      = false;
  bool _uploading   = false;
  bool _saved       = false;
  final List<UploadResult> _attachments = [];
  final String _tempId = DateTime.now().millisecondsSinceEpoch.toString();

  @override
  void dispose() {
    _reportNameCtrl.dispose();
    _hospitalCtrl.dispose();
    _notesCtrl.dispose();
    _diagnosisCtrl.dispose();
    _commentsCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.accent, onPrimary: AppColors.ink,
            surface: AppColors.surfaceElevated, onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickFile() async {
    setState(() => _uploading = true);
    try {
      final result = await StorageService.pickAndUpload(reportId: _tempId);
      if (result != null && mounted) setState(() => _attachments.add(result));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e'), backgroundColor: AppColors.danger));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ReportService.addReport(
        category:           _selCat!.name,
        type:               _selType,
        reportName:         _reportNameCtrl.text.trim(),
        date:               _date,
        doctorName:         widget.doctor.name,
        doctorId:           widget.doctor.id,
        patientId:          widget.patient?.id,
        patientName:        widget.patient?.name ?? '',
        hospitalName:       _hospitalCtrl.text.trim(),
        clinicalNotes:      _notesCtrl.text.trim(),
        diagnosis:          _diagnosisCtrl.text.trim(),
        additionalComments: _commentsCtrl.text.trim(),
        tags:               [],
        attachments: _attachments.map((a) => {'name': a.name, 'url': a.url}).toList(),
      );
      if (mounted) setState(() { _saving = false; _saved = true; });
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.danger));
      }
    }
  }

  // ── Step 0: Category grid ──────────────────────────────────────────────────
  Widget _buildCategoryStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Handle(),
        const SizedBox(height: 16),
        const Text('Select Category',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('Step 1 of 3 · Choose a report category',
            style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 13)),
        const SizedBox(height: 20),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.8,
          ),
          itemCount: _reportCategories.length,
          itemBuilder: (_, i) {
            final cat = _reportCategories[i];
            return GestureDetector(
              onTap: () => setState(() { _selCat = cat; _step = 1; }),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: cat.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cat.color.withOpacity(0.35)),
                ),
                child: Row(children: [
                  Icon(cat.icon, color: cat.color, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(cat.name,
                        style: TextStyle(
                            color: cat.color, fontSize: 11.5, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis, maxLines: 2),
                  ),
                ]),
              ),
            );
          },
        ),
      ],
    );
  }

  // ── Step 1: Type list ──────────────────────────────────────────────────────
  Widget _buildTypeStep() {
    final cat = _selCat!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Handle(),
        const SizedBox(height: 16),
        Row(children: [
          GestureDetector(
            onTap: () => setState(() { _step = 0; _selCat = null; }),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.arrow_back, color: Colors.white.withOpacity(0.7), size: 18),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(cat.name,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
              Text('Step 2 of 3 · Select type',
                  style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 12)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: cat.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(cat.icon, color: cat.color, size: 20),
          ),
        ]),
        const SizedBox(height: 16),
        ...cat.types.map((type) => GestureDetector(
          onTap: () => setState(() { _selType = type; _step = 2; }),
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(children: [
              Expanded(
                child: Text(type,
                    style: const TextStyle(color: Colors.white, fontSize: 14)),
              ),
              Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.3), size: 18),
            ]),
          ),
        )).toList(),
      ],
    );
  }

  // ── Step 2: Details form ───────────────────────────────────────────────────
  Widget _buildDetailsStep() {
    final cat = _selCat!;
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Handle(),
          const SizedBox(height: 16),

          Row(children: [
            GestureDetector(
              onTap: () => setState(() => _step = 1),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.arrow_back, color: Colors.white.withOpacity(0.7), size: 18),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Report Details',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                Text('Step 3 of 3',
                    style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 12)),
              ]),
            ),
          ]),
          const SizedBox(height: 10),

          // Category + type chips
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: cat.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(cat.icon, color: cat.color, size: 12),
                const SizedBox(width: 5),
                Text(cat.name,
                    style: TextStyle(color: cat.color, fontSize: 11, fontWeight: FontWeight.w600)),
              ]),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_selType,
                    style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11),
                    overflow: TextOverflow.ellipsis),
              ),
            ),
          ]),
          const SizedBox(height: 16),

          // Doctor chip
          _DoctorChip(name: widget.doctor.name),
          const SizedBox(height: 16),

          // Patient info (read-only if pre-filled)
          if (widget.patient != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(children: [
                const Icon(Icons.person_outline, color: AppColors.accent, size: 18),
                const SizedBox(width: 10),
                Text(widget.patient!.name,
                    style: const TextStyle(color: Colors.white, fontSize: 14)),
              ]),
            ),
          const SizedBox(height: 12),

          AuthField(
            controller: _reportNameCtrl,
            label: 'Report / Test Name',
            hint: 'e.g. CBC Blood Test',
            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          AuthField(controller: _hospitalCtrl, label: 'Hospital / Lab Name', hint: 'Where issued'),
          const SizedBox(height: 12),

          // Date picker
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(children: [
                const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.accent),
                const SizedBox(width: 10),
                Text('${_date.day}/${_date.month}/${_date.year}',
                    style: const TextStyle(color: Colors.white, fontSize: 14)),
              ]),
            ),
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: _notesCtrl, maxLines: 3,
            style: const TextStyle(color: Colors.white),
            decoration: _areaDecor('Clinical Notes', 'Symptoms, observations…'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _diagnosisCtrl, maxLines: 2,
            style: const TextStyle(color: Colors.white),
            decoration: _areaDecor('Diagnosis', 'Findings…'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _commentsCtrl, maxLines: 2,
            style: const TextStyle(color: Colors.white),
            decoration: _areaDecor('Additional Comments', 'Optional notes…'),
          ),
          const SizedBox(height: 14),

          // Attachments
          const _Label('Attachments'),
          const SizedBox(height: 8),
          if (_attachments.isNotEmpty) ...[
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _attachments.asMap().entries.map((e) => _AttachChip(
                name: e.value.name,
                onRemove: () => setState(() => _attachments.removeAt(e.key)),
              )).toList(),
            ),
            const SizedBox(height: 8),
          ],
          GestureDetector(
            onTap: _uploading ? null : _pickFile,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(children: [
                _uploading
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent))
                    : Icon(Icons.upload_file_outlined, size: 18,
                        color: Colors.white.withOpacity(0.45)),
                const SizedBox(width: 10),
                Text(_uploading ? 'Uploading…' : 'Upload PDF / Image',
                    style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14)),
              ]),
            ),
          ),
          const SizedBox(height: 24),

          if (_saved) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF10b981).withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF10b981).withOpacity(0.35)),
              ),
              child: const Row(children: [
                Icon(Icons.check_circle_outline, color: Color(0xFF10b981), size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text('Report saved successfully',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            if (widget.onPrescribeAfter != null)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.medication_outlined, size: 18),
                  label: const Text('Also Prescribe Medication',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accentViolet,
                    side: const BorderSide(color: AppColors.accentViolet),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    widget.onSaved();
                    widget.onPrescribeAfter!();
                  },
                ),
              ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: widget.onSaved,
                child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ] else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink))
                    : const Text('Save Report', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
        ],
      ),
    );
  }

  InputDecoration _areaDecor(String label, String hint) => InputDecoration(
    labelText: label, hintText: hint,
    labelStyle: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 13),
    hintStyle: TextStyle(color: Colors.white.withOpacity(0.25)),
    filled: true, fillColor: AppColors.surfaceElevated,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.white12)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.white12)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
  );

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottom + 24),
      child: SingleChildScrollView(
        child: _step == 0
            ? _buildCategoryStep()
            : _step == 1
                ? _buildTypeStep()
                : _buildDetailsStep(),
      ),
    );
  }
}

// ── Doctor → Medication (prescribe) form ─────────────────────────────────────

class _DoctorMedForm extends StatefulWidget {
  final AppUser doctor;
  final AppUser? patient;
  final VoidCallback onSaved;
  const _DoctorMedForm({required this.doctor, this.patient, required this.onSaved});

  @override
  State<_DoctorMedForm> createState() => _DoctorMedFormState();
}

class _DoctorMedFormState extends State<_DoctorMedForm> {
  final _formKey      = GlobalKey<FormState>();
  final _medNameCtrl  = TextEditingController();
  final _dosageCtrl   = TextEditingController();

  int       _timesPerDay = 1;
  String    _mealTiming  = 'After Meals';
  DateTime? _tillDate;
  bool      _saving      = false;

  static const _doseLabels = [
    ['Daily'], ['Morning', 'Evening'], ['Morning', 'Afternoon', 'Evening'],
    ['Morning', 'Afternoon', 'Evening', 'Night'],
  ];

  @override
  void dispose() {
    _medNameCtrl.dispose();
    _dosageCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.accent, onPrimary: AppColors.ink,
            surface: AppColors.surfaceElevated, onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _tillDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await MedicationService.addMedication(
        name:        _medNameCtrl.text.trim(),
        dosage:      _dosageCtrl.text.trim(),
        frequency:   _mealTiming,
        timesPerDay: _timesPerDay,
        tillDate:    _tillDate,
        patientId:   widget.patient?.id,
        doctorId:    widget.doctor.id,
        doctorName:  widget.doctor.name,
      );
      widget.onSaved();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.danger));
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
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Handle(),
              const SizedBox(height: 16),
              const Text('Prescribe Medication',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              _DoctorChip(name: widget.doctor.name),
              const SizedBox(height: 16),

              // Patient (read-only)
              if (widget.patient != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(children: [
                    const Icon(Icons.person_outline, color: AppColors.accent, size: 18),
                    const SizedBox(width: 10),
                    Text(widget.patient!.name,
                        style: const TextStyle(color: Colors.white, fontSize: 14)),
                  ]),
                ),
                const SizedBox(height: 12),
              ],

              AuthField(
                controller: _medNameCtrl,
                label: 'Medication Name',
                hint: 'e.g. Amoxicillin',
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              AuthField(
                controller: _dosageCtrl,
                label: 'Dosage',
                hint: 'e.g. 500 mg',
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 18),

              // Intake Timing selector
              const _Label('Intake Timing'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: _mealTimingOptions.map((opt) {
                  final sel = _mealTiming == opt;
                  return GestureDetector(
                    onTap: () => setState(() => _mealTiming = opt),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: sel ? AppColors.accent.withOpacity(0.18) : AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: sel ? AppColors.accent : Colors.white12,
                          width: sel ? 1.5 : 1,
                        ),
                      ),
                      child: Text(opt,
                          style: TextStyle(
                            color: sel ? AppColors.accent : Colors.white.withOpacity(0.55),
                            fontSize: 13,
                            fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                          )),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),

              // Times per day
              const _Label('Times per day'),
              const SizedBox(height: 10),
              Row(
                children: [1, 2, 3, 4].map((n) {
                  final labels = _doseLabels[n - 1];
                  final sel    = _timesPerDay == n;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _timesPerDay = n),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: EdgeInsets.only(right: n < 4 ? 8 : 0),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: sel ? AppColors.accent.withOpacity(0.18) : AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: sel ? AppColors.accent : Colors.white12,
                              width: sel ? 1.5 : 1),
                        ),
                        child: Column(children: [
                          Text('$n×', style: TextStyle(
                              color: sel ? AppColors.accent : Colors.white38,
                              fontWeight: FontWeight.w700, fontSize: 15)),
                          const SizedBox(height: 3),
                          Text(labels.first, style: TextStyle(
                              color: sel ? AppColors.accent : Colors.white30, fontSize: 9)),
                        ]),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Till date
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(children: [
                    Icon(Icons.calendar_today_outlined, size: 18,
                        color: _tillDate != null ? AppColors.accent : Colors.white38),
                    const SizedBox(width: 10),
                    Text(
                      _tillDate == null
                          ? 'Till when (optional)'
                          : 'Till ${_tillDate!.day}/${_tillDate!.month}/${_tillDate!.year}',
                      style: TextStyle(
                          color: _tillDate == null ? Colors.white30 : Colors.white,
                          fontSize: 14),
                    ),
                    if (_tillDate != null) ...[
                      const Spacer(),
                      GestureDetector(
                        onTap: () => setState(() => _tillDate = null),
                        child: const Icon(Icons.close, size: 16, color: Colors.white38),
                      ),
                    ],
                  ]),
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink))
                      : const Text('Prescribe', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shared helpers ─────────────────────────────────────────────────────────────

class _Handle extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 40, height: 4,
      decoration: BoxDecoration(
          color: Colors.white24, borderRadius: BorderRadius.circular(2)),
    ),
  );
}

class _DoctorChip extends StatelessWidget {
  final String name;
  const _DoctorChip({required this.name});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: AppColors.accent.withOpacity(0.12),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.accent.withOpacity(0.3)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.person, color: AppColors.accent, size: 16),
      const SizedBox(width: 8),
      Text('Dr. $name',
          style: const TextStyle(
              color: AppColors.accent, fontWeight: FontWeight.w600, fontSize: 13)),
    ]),
  );
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(
          color: Colors.white.withOpacity(0.65),
          fontSize: 13,
          fontWeight: FontWeight.w600));
}

class _AttachChip extends StatelessWidget {
  final String name;
  final VoidCallback onRemove;
  const _AttachChip({required this.name, required this.onRemove});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: AppColors.accent.withOpacity(0.12),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppColors.accent.withOpacity(0.3)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.attach_file, color: AppColors.accent, size: 14),
      const SizedBox(width: 5),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 120),
        child: Text(name,
            style: const TextStyle(color: AppColors.accent, fontSize: 12),
            overflow: TextOverflow.ellipsis),
      ),
      const SizedBox(width: 6),
      GestureDetector(
        onTap: onRemove,
        child: Icon(Icons.close, size: 14, color: AppColors.accent.withOpacity(0.6)),
      ),
    ]),
  );
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String message;
  final String sub;
  const _Empty({required this.icon, required this.message, required this.sub});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, size: 64, color: Colors.white.withOpacity(0.25)),
      const SizedBox(height: 16),
      Text(message, style: TextStyle(
          color: Colors.white.withOpacity(0.8), fontSize: 18, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Text(sub, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14)),
    ]),
  );
}
