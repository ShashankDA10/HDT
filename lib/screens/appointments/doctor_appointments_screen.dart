import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/appointment.dart';
import '../../services/appointment_reminder_service.dart';
import '../../services/appointment_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_scaffold.dart';
import '../../models/app_user.dart';

class DoctorAppointmentsScreen extends StatelessWidget {
  final AppUser doctor;
  const DoctorAppointmentsScreen({super.key, required this.doctor});

  String _formatDate(DateTime d) {
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${m[d.month - 1]} ${d.day}, ${d.year}';
  }

  Future<void> _updateStatus(
      BuildContext context, Appointment appt, String status, String label) async {
    try {
      await AppointmentService.updateStatus(appt.id, status);
      if (status == 'approved') {
        // Schedule a 1-hour-before reminder on the doctor's device
        await AppointmentReminderService.scheduleDoctorReminder(appt);
      } else {
        // Rejected: cancel any existing reminders (doctor + patient sides)
        await AppointmentReminderService.cancelReminders(appt.id);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Appointment $label.'),
          backgroundColor: status == 'approved'
              ? const Color(0xFF10b981)
              : const Color(0xFFf43f5e),
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed: $e'), backgroundColor: AppColors.danger));
      }
    }
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
            const Text('Appointment Requests'),
            Text('Manage incoming bookings',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted)),
          ],
        ),
      ),
      body: StreamBuilder<List<Appointment>>(
        stream: AppointmentService.doctorStream(doctor.id),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Text('Error loading appointments: ${snap.error}',
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                  textAlign: TextAlign.center),
            );
          }
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.accent));
          }

          final all = snap.data ?? [];
          if (all.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_available_outlined, size: 64,
                      color: Colors.white.withOpacity(0.25)),
                  const SizedBox(height: 16),
                  Text('No appointment requests',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text('Requests from patients will appear here',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.5), fontSize: 14)),
                ],
              ),
            );
          }

          final pending  = all.where((a) => a.status == 'pending').toList();
          final resolved = all.where((a) => a.status != 'pending').toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            children: [
              if (pending.isNotEmpty) ...[
                _SectionTitle('Pending', pending.length, AppColors.accentAmber),
                const SizedBox(height: 10),
                ...pending.asMap().entries.map((e) => _RequestCard(
                  appt:      e.value,
                  dateLabel: _formatDate(e.value.date),
                  index:     e.key,
                  onApprove: () => _updateStatus(context, e.value, 'approved', 'approved'),
                  onReject:  () => _updateStatus(context, e.value, 'rejected', 'rejected'),
                  showActions: true,
                )),
                const SizedBox(height: 20),
              ],
              if (resolved.isNotEmpty) ...[
                _SectionTitle('Resolved', resolved.length,
                    Colors.white.withOpacity(0.4)),
                const SizedBox(height: 10),
                ...resolved.asMap().entries.map((e) => _RequestCard(
                  appt:        e.value,
                  dateLabel:   _formatDate(e.value.date),
                  index:       e.key,
                  onApprove:   () {},
                  onReject:    () {},
                  showActions: false,
                )),
              ],
            ],
          );
        },
      ),
    );
  }
}

// ── Request card ──────────────────────────────────────────────────────────────

class _RequestCard extends StatelessWidget {
  final Appointment  appt;
  final String       dateLabel;
  final int          index;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final bool         showActions;

  const _RequestCard({
    required this.appt,
    required this.dateLabel,
    required this.index,
    required this.onApprove,
    required this.onReject,
    required this.showActions,
  });

  static Color _statusColor(String s) {
    switch (s) {
      case 'approved':  return const Color(0xFF10b981);
      case 'rejected':  return const Color(0xFFf43f5e);
      case 'cancelled': return const Color(0xFF94a3b8);
      default:          return const Color(0xFFf59e0b);
    }
  }

  static String _statusLabel(String s) {
    switch (s) {
      case 'approved':  return 'Approved';
      case 'rejected':  return 'Rejected';
      case 'cancelled': return 'Cancelled';
      default:          return 'Pending';
    }
  }

  @override
  Widget build(BuildContext context) {
    final sColor = _statusColor(appt.status);

    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Patient + status
          Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: AppColors.accentViolet.withOpacity(0.15),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(Icons.person, color: AppColors.accentViolet, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(appt.patientName,
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
                color: sColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: sColor.withOpacity(0.35)),
              ),
              child: Text(_statusLabel(appt.status),
                  style: TextStyle(
                      color: sColor, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ]),

          // Approve / Reject buttons
          if (showActions) ...[
            const SizedBox(height: 12),
            const Divider(color: Colors.white10, height: 1),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.check, size: 15),
                  label: const Text('Approve'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF10b981),
                    side: const BorderSide(color: Color(0xFF10b981)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: onApprove,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.close, size: 15),
                  label: const Text('Reject'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFf43f5e),
                    side: const BorderSide(color: Color(0xFFf43f5e)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: onReject,
                ),
              ),
            ]),
          ],
        ],
      ),
    ).animate().fadeIn(delay: (50 * index).ms, duration: 300.ms);
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final int    count;
  final Color  color;
  const _SectionTitle(this.title, this.count, this.color);

  @override
  Widget build(BuildContext context) => Row(children: [
    Text(title,
        style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
    const SizedBox(width: 8),
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text('$count',
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    ),
  ]);
}
