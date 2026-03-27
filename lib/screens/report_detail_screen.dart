import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/app_card.dart';

// Category colour/icon lookup (must match reports_screen.dart)
const _catMeta = {
  'Laboratory Reports':       {'icon': Icons.biotech,              'color': Color(0xFF3b82f6)},
  'Radiology / Imaging':      {'icon': Icons.document_scanner,     'color': Color(0xFF8b5cf6)},
  'Clinical Consultation':    {'icon': Icons.person_search,        'color': Color(0xFF06b6d4)},
  'Prescription / Medication':{'icon': Icons.medication,           'color': Color(0xFF10b981)},
  'Hospitalization Records':  {'icon': Icons.local_hospital,       'color': Color(0xFFf43f5e)},
  'Surgical Reports':         {'icon': Icons.content_cut,          'color': Color(0xFFf97316)},
  'Vaccination Records':      {'icon': Icons.vaccines,             'color': Color(0xFF84cc16)},
  'Vital Monitoring':         {'icon': Icons.monitor_heart,        'color': Color(0xFFec4899)},
  'Dental Records':           {'icon': Icons.sentiment_very_satisfied, 'color': Color(0xFFa78bfa)},
  'Other Documents':          {'icon': Icons.folder_open,          'color': Color(0xFF94a3b8)},
};

class ReportDetailScreen extends StatelessWidget {
  final Map<String, dynamic> data;

  const ReportDetailScreen({super.key, required this.data});

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
      return ts?.toString() ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final category  = data['category'] as String? ?? 'Other Documents';
    final type      = data['type']     as String? ?? '';
    final name      = (data['reportName'] as String?)?.isNotEmpty == true
        ? data['reportName'] as String
        : type;

    final meta  = _catMeta[category] ?? _catMeta['Other Documents']!;
    final color = meta['color'] as Color;
    final icon  = meta['icon']  as IconData;

    final tags           = List<String>.from(data['tags'] as List? ?? []);
    final hasMed         = data['hasMedication'] == true;
    final isSelfUploaded = data['source'] == 'patient_upload';

    return AppScaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(name, overflow: TextOverflow.ellipsis),
      ),
      body: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        builder: (_, v, child) => Opacity(
          opacity: v,
          child: Transform.translate(offset: Offset(0, (1 - v) * 12), child: child),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header card ───────────────────────────────────────────────
              AppCard(
                glow: true,
                glowColor: color,
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, color: color, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 18,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text('$category › $type',
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.55), fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(_formatDate(data['date']),
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.45), fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // ── Self-uploaded banner ───────────────────────────────────────
              if (isSelfUploaded) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.accentBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.accentBlue.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.document_scanner_rounded,
                          color: AppColors.accentBlue, size: 16),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Self-uploaded — scanned and added by you',
                          style: TextStyle(
                            color: AppColors.accentBlue,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // ── Tags ──────────────────────────────────────────────────────
              if (tags.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: tags.map((t) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: color.withOpacity(0.35)),
                    ),
                    child: Text(t, style: TextStyle(
                        color: color, fontSize: 12, fontWeight: FontWeight.w600)),
                  )).toList(),
                ),
                const SizedBox(height: 14),
              ],

              // ── Detail sections ───────────────────────────────────────────
              if (_notEmpty(data['doctorName']))
                _Section(label: 'Doctor', value: data['doctorName'], icon: Icons.person, color: color),

              if (_notEmpty(data['hospitalName']))
                _Section(label: 'Hospital / Lab', value: data['hospitalName'],
                    icon: Icons.local_hospital, color: color),

              if (_notEmpty(data['clinicalNotes']))
                _Section(label: 'Clinical Notes', value: data['clinicalNotes'],
                    icon: Icons.notes, color: color),

              if (_notEmpty(data['diagnosis']))
                _Section(label: 'Diagnosis', value: data['diagnosis'],
                    icon: Icons.assignment, color: color),

              if (_notEmpty(data['additionalComments']))
                _Section(label: 'Additional Comments', value: data['additionalComments'],
                    icon: Icons.comment, color: color),

              // ── Attachments ───────────────────────────────────────────────
              if ((data['attachments'] as List?)?.isNotEmpty == true) ...[
                const SizedBox(height: 4),
                AppCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.attach_file, color: color, size: 16),
                        const SizedBox(width: 8),
                        Text('Attachments',
                            style: TextStyle(color: color, fontSize: 12,
                                fontWeight: FontWeight.w700, letterSpacing: 0.3)),
                      ]),
                      const SizedBox(height: 10),
                      ...(data['attachments'] as List).map((a) {
                        final att = a as Map;
                        final name = att['name']?.toString() ?? 'File';
                        final url  = att['url']?.toString() ?? '';
                        IconData icon;
                        final ext = name.split('.').last.toLowerCase();
                        if (ext == 'pdf') {
                          icon = Icons.picture_as_pdf;
                        } else if (['jpg', 'jpeg', 'png'].contains(ext)) {
                          icon = Icons.image;
                        } else {
                          icon = Icons.insert_drive_file;
                        }
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(children: [
                            Icon(icon, color: Colors.white54, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(name,
                                  style: const TextStyle(color: Colors.white, fontSize: 13)),
                            ),
                            if (url.isNotEmpty)
                              GestureDetector(
                                onTap: () {
                                  // URL is ready — integrate url_launcher if needed
                                },
                                child: Icon(Icons.open_in_new,
                                    color: color, size: 16),
                              ),
                          ]),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // ── Medication badge ──────────────────────────────────────────
              if (hasMed) ...[
                const SizedBox(height: 4),
                AppCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 38, height: 38,
                        decoration: BoxDecoration(
                          color: AppColors.accent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.medication, color: AppColors.accent, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Medication added',
                                style: TextStyle(color: Colors.white,
                                    fontWeight: FontWeight.w600, fontSize: 14)),
                            const SizedBox(height: 2),
                            Text('Saved to your Medication tab',
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.5), fontSize: 12)),
                          ],
                        ),
                      ),
                      const Icon(Icons.check_circle_rounded,
                          color: AppColors.accent, size: 22),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  bool _notEmpty(dynamic v) => v != null && v.toString().trim().isNotEmpty;
}

// ── Detail section widget ─────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String label;
  final dynamic value;
  final IconData icon;
  final Color color;

  const _Section({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w700,
                  letterSpacing: 0.3)),
            ]),
            const SizedBox(height: 8),
            Text(value.toString(),
                style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 14, height: 1.5)),
          ],
        ),
      ),
    );
  }
}
