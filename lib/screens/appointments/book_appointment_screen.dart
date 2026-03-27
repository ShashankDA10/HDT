import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/app_user.dart';
import '../../models/appointment.dart';
import '../../services/appointment_reminder_service.dart';
import '../../services/appointment_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_scaffold.dart';

// ── Time slots available per day ──────────────────────────────────────────────

const _slots = [
  '09:00 AM', '09:30 AM', '10:00 AM', '10:30 AM',
  '11:00 AM', '11:30 AM', '12:00 PM', '12:30 PM',
  '02:00 PM', '02:30 PM', '03:00 PM', '03:30 PM',
  '04:00 PM', '04:30 PM', '05:00 PM', '05:30 PM',
];

class BookAppointmentScreen extends StatefulWidget {
  const BookAppointmentScreen({super.key});

  @override
  State<BookAppointmentScreen> createState() => _BookAppointmentScreenState();
}

class _BookAppointmentScreenState extends State<BookAppointmentScreen> {
  // Steps: 0=select doctor, 1=pick date+slot, 2=confirm
  int _step = 0;

  // Step 0
  AppUser?             _doctor;
  late Future<List<AppUser>> _doctorsFuture;

  // Step 1
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  String?  _selectedSlot;

  // Submission
  bool _saving = false;

  AppUser? _me;

  @override
  void initState() {
    super.initState();
    _loadMe();
    _doctorsFuture = _fetchAllDoctors();
  }

  Future<void> _loadMe() async {
    _me = await EmailPasswordAuthService.currentAppUser();
  }

  Future<List<AppUser>> _fetchAllDoctors() async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'doctor')
        .get();
    return snap.docs
        .map((d) => AppUser.fromFirestore(d.id, d.data()))
        .toList();
  }

  // ── Pick date ──────────────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 90)),
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
    if (picked != null) setState(() { _selectedDate = picked; _selectedSlot = null; });
  }

  // ── Submit ─────────────────────────────────────────────────────────────────

  Future<void> _confirm() async {
    if (_me == null || _doctor == null || _selectedSlot == null) return;
    setState(() => _saving = true);
    try {
      final apptId = await AppointmentService.createAppointment(
        patientId:   _me!.id,
        doctorId:    _doctor!.id,
        patientName: _me!.name,
        doctorName:  _doctor!.name,
        date:        _selectedDate,
        time:        _selectedSlot!,
      );
      // Schedule a 1-hour-before reminder on the patient's device.
      // The appointment starts as 'pending' so this fires regardless;
      // if the doctor rejects it, the patient_appointments_screen will
      // cancel the reminder via its stream listener.
      debugPrint('[BookAppt] Appointment created (id=$apptId) — '
          'scheduling patient reminder for $_selectedSlot on $_selectedDate');
      await AppointmentReminderService.schedulePatientReminder(
        Appointment(
          id:          apptId,
          patientId:   _me!.id,
          doctorId:    _doctor!.id,
          patientName: _me!.name,
          doctorName:  _doctor!.name,
          date:        _selectedDate,
          time:        _selectedSlot!,
          status:      'pending',
          createdAt:   DateTime.now(),
        ),
      );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Appointment request sent!'),
            backgroundColor: Color(0xFF10b981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _step == 0
              ? () => Navigator.of(context).pop()
              : () => setState(() => _step--),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Book Appointment'),
            Text(
              _step == 0 ? 'Step 1 · Select a doctor'
                         : _step == 1 ? 'Step 2 · Pick date & time'
                                      : 'Step 3 · Confirm',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: AppColors.muted),
            ),
          ],
        ),
      ),
      body: _step == 0
          ? _buildFindDoctor()
          : _step == 1
              ? _buildPickDateTime()
              : _buildConfirm(),
    );
  }

  // ── Step 0: Select Doctor ─────────────────────────────────────────────────

  Widget _buildFindDoctor() {
    return FutureBuilder<List<AppUser>>(
      future: _doctorsFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.accent));
        }
        if (snap.hasError || !snap.hasData || snap.data!.isEmpty) {
          return Center(
            child: Text(
              snap.data?.isEmpty == true
                  ? 'No doctors available at the moment.'
                  : 'Failed to load doctors. Please try again.',
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
              textAlign: TextAlign.center,
            ),
          );
        }
        final doctors = snap.data!;
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
          itemCount: doctors.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            if (i == 0) {
              return const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: _SectionHeader(
                  icon: Icons.person_search,
                  color: AppColors.accent,
                  title: 'Select a doctor',
                  sub: 'Tap a doctor to book an appointment',
                ),
              );
            }
            final doc = doctors[i - 1];
            return AppCard(
              child: Row(children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.person, color: AppColors.accent, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Dr. ${doc.name}',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 3),
                    Text(doc.email,
                        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                  ]),
                ),
                ElevatedButton(
                  onPressed: () => setState(() { _doctor = doc; _step = 1; }),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.ink,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  child: const Text('Select', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ]),
            ).animate().fadeIn(delay: Duration(milliseconds: 60 * (i - 1)), duration: 300.ms);
          },
        );
      },
    );
  }

  // ── Step 1: Pick Date + Slot ──────────────────────────────────────────────

  Widget _buildPickDateTime() {
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final days   = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppCard(
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.person, color: AppColors.accent, size: 22),
              ),
              const SizedBox(width: 12),
              Text('Dr. ${_doctor!.name}',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
            ]),
          ),
          const SizedBox(height: 20),

          // Date picker row
          Row(children: [
            Expanded(
              child: _SectionHeader(
                icon: Icons.calendar_today,
                color: AppColors.accentBlue,
                title: '${months[_selectedDate.month - 1]} ${_selectedDate.day}, ${_selectedDate.year}',
                sub: days[_selectedDate.weekday - 1],
              ),
            ),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.accentBlue.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.accentBlue.withOpacity(0.35)),
                ),
                child: const Text('Change',
                    style: TextStyle(
                        color: AppColors.accentBlue,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
              ),
            ),
          ]),
          const SizedBox(height: 20),

          Text('Available Slots',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.65),
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.4,
            ),
            itemCount: _slots.length,
            itemBuilder: (_, i) {
              final slot = _slots[i];
              final sel  = _selectedSlot == slot;
              return GestureDetector(
                onTap: () => setState(() => _selectedSlot = slot),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  decoration: BoxDecoration(
                    color: sel
                        ? AppColors.accent.withOpacity(0.18)
                        : AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: sel ? AppColors.accent : Colors.white12,
                      width: sel ? 1.5 : 1,
                    ),
                  ),
                  child: Center(
                    child: Text(slot,
                        style: TextStyle(
                          color: sel ? AppColors.accent : Colors.white.withOpacity(0.65),
                          fontSize: 12,
                          fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                        )),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selectedSlot == null ? null : () => setState(() => _step = 2),
              child: const Text('Continue', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 2: Confirm ────────────────────────────────────────────────────────

  Widget _buildConfirm() {
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: Icons.check_circle_outline,
            color: AppColors.accent,
            title: 'Confirm Appointment',
            sub: 'Review details before submitting',
          ),
          const SizedBox(height: 24),

          AppCard(
            child: Column(
              children: [
                _ConfirmRow(
                  icon: Icons.person,
                  color: AppColors.accent,
                  label: 'Doctor',
                  value: 'Dr. ${_doctor!.name}',
                ),
                const Divider(color: Colors.white10, height: 24),
                _ConfirmRow(
                  icon: Icons.calendar_today,
                  color: AppColors.accentBlue,
                  label: 'Date',
                  value: '${months[_selectedDate.month - 1]} ${_selectedDate.day}, ${_selectedDate.year}',
                ),
                const Divider(color: Colors.white10, height: 24),
                _ConfirmRow(
                  icon: Icons.access_time,
                  color: AppColors.accentViolet,
                  label: 'Time',
                  value: _selectedSlot!,
                ),
                const Divider(color: Colors.white10, height: 24),
                const _ConfirmRow(
                  icon: Icons.hourglass_empty,
                  color: AppColors.accentAmber,
                  label: 'Status',
                  value: 'Pending approval',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.accentAmber.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.accentAmber.withOpacity(0.25)),
            ),
            child: Row(children: [
              Icon(Icons.info_outline, color: AppColors.accentAmber.withOpacity(0.8), size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Your request will be sent to the doctor for approval.',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.6), fontSize: 12, height: 1.4),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _confirm,
              child: _saving
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink))
                  : const Text('Send Request', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared widgets ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final String   title;
  final String   sub;

  const _SectionHeader({
    required this.icon,
    required this.color,
    required this.title,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
        Text(sub,
            style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 12)),
      ]),
    ]);
  }
}

class _ConfirmRow extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final String   label;
  final String   value;

  const _ConfirmRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
      const SizedBox(width: 14),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 11)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
      ]),
    ]);
  }
}
