import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/appointment.dart';
import '../../models/app_user.dart';
import '../../services/appointment_reminder_service.dart';
import '../../services/appointment_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_scaffold.dart';
import 'book_appointment_screen.dart';

class PatientAppointmentsScreen extends StatefulWidget {
  const PatientAppointmentsScreen({super.key});

  @override
  State<PatientAppointmentsScreen> createState() => _PatientAppointmentsScreenState();
}

class _PatientAppointmentsScreenState extends State<PatientAppointmentsScreen> {
  AppUser? _me;
  bool     _loadingUser = true;

  /// Separate subscription used only for reminder management (not UI rendering).
  StreamSubscription<List<Appointment>>? _reminderSub;

  /// Tracks IDs of appointments whose reminders have been cancelled so we
  /// don't call cancel repeatedly on every stream emission.
  final Set<String> _cancelledReminderIds = {};

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  @override
  void dispose() {
    _reminderSub?.cancel();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final user = await EmailPasswordAuthService.currentAppUser();
    if (mounted) {
      setState(() { _me = user; _loadingUser = false; });
      if (user != null) _startReminderSync(user.id);
    }
  }

  /// Listens to the patient's appointments and cancels reminders whenever
  /// an appointment is rejected or cancelled by the doctor.
  void _startReminderSync(String patientId) {
    _reminderSub = AppointmentService.patientStream(patientId).listen((appts) {
      for (final appt in appts) {
        if ((appt.isRejected || appt.status == 'cancelled') &&
            !_cancelledReminderIds.contains(appt.id)) {
          _cancelledReminderIds.add(appt.id);
          AppointmentReminderService.cancelReminders(appt.id);
        }
      }
    });
  }

  // ── Status helpers ─────────────────────────────────────────────────────────

  static Color _statusColor(String status) {
    switch (status) {
      case 'approved':   return const Color(0xFF10b981);
      case 'rejected':   return const Color(0xFFf43f5e);
      case 'cancelled':  return const Color(0xFF94a3b8);
      default:           return const Color(0xFFf59e0b); // pending
    }
  }

  static IconData _statusIcon(String status) {
    switch (status) {
      case 'approved':   return Icons.check_circle;
      case 'rejected':   return Icons.cancel;
      case 'cancelled':  return Icons.remove_circle;
      default:           return Icons.hourglass_empty;
    }
  }

  static String _statusLabel(String status) {
    switch (status) {
      case 'approved':   return 'Approved';
      case 'rejected':   return 'Rejected';
      case 'cancelled':  return 'Cancelled';
      default:           return 'Pending';
    }
  }

  String _formatDate(DateTime d) {
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${m[d.month - 1]} ${d.day}, ${d.year}';
  }

  Future<void> _cancel(Appointment appt) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancel Appointment',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: Text(
          'Cancel your appointment with Dr. ${appt.doctorName} on ${_formatDate(appt.date)} at ${appt.time}?',
          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Keep', style: TextStyle(color: Colors.white.withOpacity(0.6))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel it', style: TextStyle(color: Color(0xFFf43f5e))),
          ),
        ],
      ),
    );
    if (confirmed == true) await AppointmentService.cancel(appt.id);
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
            const Text('Appointments'),
            Text('Your booking history',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const BookAppointmentScreen()),
        ),
        tooltip: 'Book appointment',
        child: const Icon(Icons.add),
      ),
      body: _loadingUser
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : _me == null
              ? const Center(child: Text('Not logged in', style: TextStyle(color: Colors.white54)))
              : StreamBuilder<List<Appointment>>(
                  stream: AppointmentService.patientStream(_me!.id),
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return Center(
                        child: Text('Error loading appointments: ${snap.error}',
                            style: const TextStyle(color: Colors.white54, fontSize: 13),
                            textAlign: TextAlign.center),
                      );
                    }
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator(color: AppColors.accent));
                    }
                    final all = snap.data ?? [];
                    if (all.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.calendar_month_outlined, size: 64,
                                color: Colors.white.withOpacity(0.25)),
                            const SizedBox(height: 16),
                            Text('No appointments yet',
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 18, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            Text('Tap + to book your first appointment',
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.5), fontSize: 14)),
                          ],
                        ),
                      );
                    }

                    // Split into upcoming and past
                    final upcoming = all.where((a) => !a.isPast && a.status != 'cancelled').toList();
                    final past     = all.where((a) => a.isPast  || a.status == 'cancelled').toList();

                    return ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      children: [
                        if (upcoming.isNotEmpty) ...[
                          _SectionTitle('Upcoming', upcoming.length),
                          const SizedBox(height: 10),
                          ...upcoming.asMap().entries.map((e) =>
                            _AppointmentCard(
                              appt: e.value,
                              statusColor: _statusColor(e.value.status),
                              statusIcon:  _statusIcon(e.value.status),
                              statusLabel: _statusLabel(e.value.status),
                              dateLabel:   _formatDate(e.value.date),
                              showCancel:  e.value.isPending,
                              onCancel:    () => _cancel(e.value),
                              index:       e.key,
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                        if (past.isNotEmpty) ...[
                          _SectionTitle('Past', past.length),
                          const SizedBox(height: 10),
                          ...past.asMap().entries.map((e) =>
                            _AppointmentCard(
                              appt: e.value,
                              statusColor: _statusColor(e.value.status),
                              statusIcon:  _statusIcon(e.value.status),
                              statusLabel: _statusLabel(e.value.status),
                              dateLabel:   _formatDate(e.value.date),
                              showCancel:  false,
                              onCancel:    () {},
                              index:       e.key,
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
    );
  }
}

// ── Appointment card ───────────────────────────────────────────────────────────

class _AppointmentCard extends StatelessWidget {
  final Appointment appt;
  final Color       statusColor;
  final IconData    statusIcon;
  final String      statusLabel;
  final String      dateLabel;
  final bool        showCancel;
  final VoidCallback onCancel;
  final int         index;

  const _AppointmentCard({
    required this.appt,
    required this.statusColor,
    required this.statusIcon,
    required this.statusLabel,
    required this.dateLabel,
    required this.showCancel,
    required this.onCancel,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(Icons.person, color: AppColors.accent, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Dr. ${appt.doctorName}',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 3),
                Row(children: [
                  Icon(Icons.calendar_today, size: 11,
                      color: Colors.white.withOpacity(0.45)),
                  const SizedBox(width: 4),
                  Text(dateLabel,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.55), fontSize: 12)),
                  const SizedBox(width: 10),
                  Icon(Icons.access_time, size: 11,
                      color: Colors.white.withOpacity(0.45)),
                  const SizedBox(width: 4),
                  Text(appt.time,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.55), fontSize: 12)),
                ]),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: statusColor.withOpacity(0.35)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(statusIcon, color: statusColor, size: 12),
                const SizedBox(width: 5),
                Text(statusLabel,
                    style: TextStyle(
                        color: statusColor, fontSize: 11, fontWeight: FontWeight.w700)),
              ]),
            ),
          ]),

          if (showCancel) ...[
            const SizedBox(height: 12),
            const Divider(color: Colors.white10, height: 1),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: onCancel,
              child: Row(children: [
                Icon(Icons.close, size: 14, color: Colors.white.withOpacity(0.35)),
                const SizedBox(width: 6),
                Text('Cancel appointment',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.35),
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
              ]),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(delay: (50 * index).ms, duration: 300.ms);
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final int    count;
  const _SectionTitle(this.title, this.count);

  @override
  Widget build(BuildContext context) => Row(children: [
    Text(title,
        style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
    const SizedBox(width: 8),
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text('$count',
          style: const TextStyle(
              color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.w700)),
    ),
  ]);
}
