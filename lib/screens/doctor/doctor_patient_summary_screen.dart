import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/app_user.dart';
import '../../services/medication_service.dart';
import '../../services/report_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_scaffold.dart';

class DoctorPatientSummaryScreen extends StatefulWidget {
  final AppUser doctor;
  final AppUser patient;

  const DoctorPatientSummaryScreen({
    super.key,
    required this.doctor,
    required this.patient,
  });

  @override
  State<DoctorPatientSummaryScreen> createState() =>
      _DoctorPatientSummaryScreenState();
}

class _DoctorPatientSummaryScreenState
    extends State<DoctorPatientSummaryScreen> {
  // Profile from users/{uid}
  Map<String, dynamic> _profile = {};
  // From reports + medications collections
  List<Map<String, dynamic>> _reports  = [];
  List<Map<String, dynamic>> _meds     = [];
  bool _loading = true;
  bool _pastExpanded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        FirebaseFirestore.instance
            .collection('users')
            .doc(widget.patient.id)
            .get(),
        ReportService.getReportsByPatient(widget.patient.id),
        MedicationService.getMedications(patientId: widget.patient.id),
      ]);

      final doc = results[0] as DocumentSnapshot<Map<String, dynamic>>;
      if (mounted) {
        setState(() {
          _profile = doc.data() ?? {};
          _reports = List<Map<String, dynamic>>.from(
              results[1] as List);
          _meds = List<Map<String, dynamic>>.from(
              results[2] as List);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  Map<String, dynamic> get _basic =>
      (_profile['basicInfo'] as Map<String, dynamic>?) ?? {};

  Map<String, dynamic> get _conditions =>
      (_profile['conditions'] as Map<String, dynamic>?) ?? {};

  Map<String, dynamic> get _allergies =>
      (_profile['allergies'] as Map<String, dynamic>?) ?? {};

  Map<String, dynamic> get _emergency =>
      (_profile['emergencyContact'] as Map<String, dynamic>?) ?? {};

  int? get _age {
    final dob = _basic['dateOfBirth'];
    if (dob == null) return null;
    try {
      final dt = (dob as Timestamp).toDate();
      final now = DateTime.now();
      int age = now.year - dt.year;
      if (now.month < dt.month ||
          (now.month == dt.month && now.day < dt.day)) age--;
      return age;
    } catch (_) {
      return null;
    }
  }

  List<String> get _activeConditions {
    final list = <String>[];
    if (_conditions['diabetes']    == true) list.add('Diabetes');
    if (_conditions['hypertension'] == true) list.add('Hypertension');
    if (_conditions['heartDisease'] == true) list.add('Heart Disease');
    if (_conditions['asthma']      == true) list.add('Asthma');
    if (_conditions['thyroid']     == true) list.add('Thyroid');
    final other = _conditions['other'] as String? ?? '';
    if (other.trim().isNotEmpty) list.add(other.trim());
    return list;
  }

  List<String> get _allergyList {
    final list = <String>[];
    final drug  = _allergies['drug']  as String? ?? '';
    final food  = _allergies['food']  as String? ?? '';
    final other = _allergies['other'] as String? ?? '';
    if (drug.trim().isNotEmpty)  list.add('Drug: $drug');
    if (food.trim().isNotEmpty)  list.add('Food: $food');
    if (other.trim().isNotEmpty) list.add('Other: $other');
    return list;
  }

  List<Map<String, dynamic>> get _activeMeds {
    final now = DateTime.now();
    return _meds.where((m) {
      final td = m['tillDate'];
      if (td == null) return true;
      try {
        return (td as Timestamp).toDate().isAfter(now);
      } catch (_) {
        return true;
      }
    }).toList();
  }

  List<Map<String, dynamic>> get _pastMeds {
    final now = DateTime.now();
    return _meds.where((m) {
      final td = m['tillDate'];
      if (td == null) return false;
      try {
        return (td as Timestamp).toDate().isBefore(now);
      } catch (_) {
        return false;
      }
    }).toList();
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.patient.name,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            Text('Patient Summary',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.muted)),
          ],
        ),
      ),
      bottomNavigationBar: _buildActionBar(),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                _buildOverviewCard().animate().fadeIn(duration: 350.ms),
                const SizedBox(height: 12),
                if (_allergyList.isNotEmpty) ...[
                  _buildAllergyCard()
                      .animate()
                      .fadeIn(delay: 60.ms, duration: 350.ms),
                  const SizedBox(height: 12),
                ],
                _buildReportsSection()
                    .animate()
                    .fadeIn(delay: 100.ms, duration: 350.ms),
                const SizedBox(height: 12),
                _buildMedicationsSection()
                    .animate()
                    .fadeIn(delay: 140.ms, duration: 350.ms),
                const SizedBox(height: 12),
                _buildVitalsSection()
                    .animate()
                    .fadeIn(delay: 180.ms, duration: 350.ms),
                const SizedBox(height: 12),
                if (_emergency['name']?.toString().isNotEmpty == true)
                  _buildEmergencyCard()
                      .animate()
                      .fadeIn(delay: 220.ms, duration: 350.ms),
              ],
            ),
    );
  }

  // ── Action bar ───────────────────────────────────────────────────────────

  Widget _buildActionBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Row(children: [
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
    );
  }

  // ── Overview card ────────────────────────────────────────────────────────

  Widget _buildOverviewCard() {
    final age        = _age;
    final gender     = _basic['gender']     as String? ?? '';
    final bloodGroup = _basic['bloodGroup'] as String? ?? '';
    final height     = _basic['height']     as String? ?? '';
    final weight     = _basic['weight']     as String? ?? '';
    final conds      = _activeConditions;

    return AppCard(
      glow: true,
      glowColor: AppColors.accent,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header row
        Row(children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.person, color: AppColors.accent, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.patient.name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 17)),
              if (widget.patient.phone.isNotEmpty)
                Text(widget.patient.phone,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 12)),
            ]),
          ),
        ]),
        const SizedBox(height: 16),

        // Quick stats grid
        Wrap(spacing: 10, runSpacing: 10, children: [
          if (age != null)    _StatChip('Age', '$age yrs', AppColors.accent),
          if (gender.isNotEmpty)   _StatChip('Gender', gender, AppColors.accentBlue),
          if (bloodGroup.isNotEmpty) _StatChip('Blood', bloodGroup, AppColors.accentRose),
          if (height.isNotEmpty) _StatChip('Height', '${height}cm', AppColors.accentViolet),
          if (weight.isNotEmpty) _StatChip('Weight', '${weight}kg', AppColors.accentAmber),
        ]),

        if (conds.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Divider(color: Colors.white10),
          const SizedBox(height: 10),
          Text('Conditions',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: conds.map((c) => _CondChip(c)).toList(),
          ),
        ],
      ]),
    );
  }

  // ── Allergy card ─────────────────────────────────────────────────────────

  Widget _buildAllergyCard() {
    return AppCard(
      borderColor: AppColors.accentAmber,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: AppColors.accentAmber.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.warning_amber_rounded,
                color: AppColors.accentAmber, size: 16),
          ),
          const SizedBox(width: 10),
          const Text('Allergies ⚠️',
              style: TextStyle(
                  color: AppColors.accentAmber,
                  fontWeight: FontWeight.w700,
                  fontSize: 14)),
        ]),
        const SizedBox(height: 10),
        ..._allergyList.map((a) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(children: [
                Container(
                  width: 6, height: 6,
                  margin: const EdgeInsets.only(right: 8, top: 1),
                  decoration: const BoxDecoration(
                    color: AppColors.accentAmber, shape: BoxShape.circle),
                ),
                Expanded(
                  child: Text(a,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13)),
                ),
              ]),
            )),
      ]),
    );
  }

  // ── Reports section ──────────────────────────────────────────────────────

  Widget _buildReportsSection() {
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _SecHeader(Icons.description_outlined, 'Reports',
            _reports.length, AppColors.accentBlue),
        const SizedBox(height: 10),
        if (_reports.isEmpty)
          _EmptyTxt('No reports on file')
        else
          ..._reports.map((r) => _ReportTile(
                report: r,
                onTap: () => _showReportDetail(r),
              )),
      ]),
    );
  }

  void _showReportDetail(Map<String, dynamic> r) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _ReportDetailSheet(report: r),
    );
  }

  // ── Medications section ──────────────────────────────────────────────────

  Widget _buildMedicationsSection() {
    final active = _activeMeds;
    final past   = _pastMeds;

    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _SecHeader(Icons.medication_outlined, 'Medications',
            _meds.length, AppColors.accentViolet),
        const SizedBox(height: 10),

        // Active
        if (active.isEmpty)
          const _EmptyTxt('No active medications')
        else ...[
          Text('Active',
              style: TextStyle(
                  color: AppColors.success.withValues(alpha: 0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          ...active.map((m) => _MedTile(med: m, isActive: true)),
        ],

        // Past (collapsible)
        if (past.isNotEmpty) ...[
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () => setState(() => _pastExpanded = !_pastExpanded),
            child: Row(children: [
              Text('Past Medications (${past.length})',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              const SizedBox(width: 4),
              Icon(
                _pastExpanded
                    ? Icons.expand_less
                    : Icons.expand_more,
                size: 16,
                color: Colors.white38,
              ),
            ]),
          ),
          if (_pastExpanded) ...[
            const SizedBox(height: 6),
            ...past.map((m) => _MedTile(med: m, isActive: false)),
          ],
        ],
      ]),
    );
  }

  // ── Vitals section ───────────────────────────────────────────────────────

  Widget _buildVitalsSection() {
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _SecHeader(Icons.monitor_heart_outlined, 'Vitals',
            0, AppColors.accentRose),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.accentRose.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: AppColors.accentRose.withValues(alpha: 0.18)),
          ),
          child: Column(children: [
            Icon(Icons.devices_outlined,
                color: AppColors.accentRose.withValues(alpha: 0.6), size: 32),
            const SizedBox(height: 10),
            Text('Patient vitals come from their wearable device.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 13,
                    height: 1.4)),
            const SizedBox(height: 4),
            Text('They are visible on the patient\'s Digital Twin screen.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 12)),
          ]),
        ),
      ]),
    );
  }

  // ── Emergency contact ────────────────────────────────────────────────────

  Widget _buildEmergencyCard() {
    final name = _emergency['name']         as String? ?? '';
    final rel  = _emergency['relationship'] as String? ?? '';
    final ph   = _emergency['phone']        as String? ?? '';

    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _SecHeader(Icons.phone_outlined, 'Emergency Contact',
            0, AppColors.accentAmber),
        const SizedBox(height: 10),
        _InfoRow('Name', name),
        if (rel.isNotEmpty) _InfoRow('Relation', rel),
        if (ph.isNotEmpty)  _InfoRow('Phone', ph),
      ]),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color  color;
  const _StatChip(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(value,
            style: TextStyle(
                color: color, fontWeight: FontWeight.w700, fontSize: 13)),
        Text(label,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45), fontSize: 10)),
      ]),
    );
  }
}

class _CondChip extends StatelessWidget {
  final String label;
  const _CondChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.accentBlue.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.accentBlue.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: const TextStyle(
              color: AppColors.accentBlue, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class _SecHeader extends StatelessWidget {
  final IconData icon;
  final String   label;
  final int      count;
  final Color    color;
  const _SecHeader(this.icon, this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, color: color, size: 15),
      const SizedBox(width: 6),
      Text(label,
          style: TextStyle(
              color: color, fontSize: 13, fontWeight: FontWeight.w700)),
      if (count > 0) ...[
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text('$count',
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ),
      ],
    ]);
  }
}

class _EmptyTxt extends StatelessWidget {
  final String text;
  const _EmptyTxt(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(text,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35), fontSize: 13)),
      );
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        SizedBox(
          width: 80,
          child: Text(label,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45), fontSize: 12)),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(
                  color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
        ),
      ]),
    );
  }
}

class _ReportTile extends StatelessWidget {
  final Map<String, dynamic> report;
  final VoidCallback onTap;
  const _ReportTile({required this.report, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = report['reportName'] as String? ??
        report['type'] as String? ?? 'Report';
    final cat  = report['category'] as String? ?? '';
    String dateStr = '';
    final dateField = report['date'];
    if (dateField != null) {
      try {
        final dt = (dateField as Timestamp).toDate();
        dateStr = '${dt.day}/${dt.month}/${dt.year}';
      } catch (_) {}
    }
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(children: [
          const Icon(Icons.description_outlined,
              color: AppColors.accentBlue, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis),
              if (cat.isNotEmpty)
                Text(cat,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 11),
                    overflow: TextOverflow.ellipsis),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            if (dateStr.isNotEmpty)
              Text(dateStr,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35), fontSize: 11)),
            const SizedBox(height: 2),
            Icon(Icons.chevron_right,
                color: Colors.white.withValues(alpha: 0.3), size: 16),
          ]),
        ]),
      ),
    );
  }
}

class _MedTile extends StatelessWidget {
  final Map<String, dynamic> med;
  final bool isActive;
  const _MedTile({required this.med, required this.isActive});

  @override
  Widget build(BuildContext context) {
    final name      = med['name']      as String? ?? 'Medication';
    final dosage    = med['dosage']    as String? ?? '';
    final frequency = med['frequency'] as String? ?? '';
    final detail    =
        [dosage, frequency].where((s) => s.isNotEmpty).join(' · ');
    final color =
        isActive ? AppColors.accentViolet : Colors.white38;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isActive ? 0.08 : 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Icon(Icons.medication_outlined, color: color, size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(name,
                style: TextStyle(
                    color: isActive ? Colors.white : Colors.white54,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
            if (detail.isNotEmpty)
              Text(detail,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 11),
                  overflow: TextOverflow.ellipsis),
          ]),
        ),
      ]),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    color;
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
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 6),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 13)),
        ]),
      ),
    );
  }
}

// ── Report detail sheet ───────────────────────────────────────────────────────

class _ReportDetailSheet extends StatelessWidget {
  final Map<String, dynamic> report;
  const _ReportDetailSheet({required this.report});

  String _dateStr(dynamic d) {
    if (d == null) return '—';
    try {
      final dt = (d as Timestamp).toDate();
      const m = ['Jan','Feb','Mar','Apr','May','Jun',
                  'Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${dt.day} ${m[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return '—';
    }
  }

  @override
  Widget build(BuildContext context) {
    final name     = report['reportName']         as String? ?? 'Report';
    final cat      = report['category']           as String? ?? '';
    final type     = report['type']               as String? ?? '';
    final doctor   = report['doctorName']         as String? ?? '';
    final hospital = report['hospitalName']       as String? ?? '';
    final notes    = report['clinicalNotes']      as String? ?? '';
    final diag     = report['diagnosis']          as String? ?? '';
    final comments = report['additionalComments'] as String? ?? '';
    final tags     = (report['tags']   as List<dynamic>?)
        ?.map((e) => e.toString()).toList() ?? [];

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, ctrl) => ListView(
        controller: ctrl,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Text(name,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 18)),
          const SizedBox(height: 4),
          if (cat.isNotEmpty)
            Text(cat,
                style: TextStyle(
                    color: AppColors.accentBlue.withValues(alpha: 0.8),
                    fontSize: 13)),
          const SizedBox(height: 16),
          _DetailRow('Type', type),
          _DetailRow('Date', _dateStr(report['date'])),
          _DetailRow('Doctor', doctor),
          _DetailRow('Hospital', hospital),
          if (diag.isNotEmpty)   _DetailRow('Diagnosis', diag),
          if (notes.isNotEmpty)  _DetailRow('Clinical Notes', notes),
          if (comments.isNotEmpty) _DetailRow('Comments', comments),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: tags.map((t) => Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accentBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: AppColors.accentBlue.withValues(alpha: 0.3)),
                ),
                child: Text(t,
                    style: const TextStyle(
                        color: AppColors.accentBlue, fontSize: 12)),
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty || value == '—') return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 11,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 3),
        Text(value,
            style: const TextStyle(color: Colors.white, fontSize: 14)),
        const Divider(color: Colors.white10, height: 16),
      ]),
    );
  }
}
