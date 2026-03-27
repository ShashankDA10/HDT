import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../models/health_log.dart';
import '../services/medtwin_service.dart';

class LogsTab extends StatefulWidget {
  const LogsTab({super.key});

  @override
  State<LogsTab> createState() => _LogsTabState();
}

class _LogsTabState extends State<LogsTab> {
  List<HealthLog> _logs = [];
  List<Map<String, dynamic>> _chatHistory = [];
  bool _loading = true;
  String _filter = 'all';

  static const _types = ['all', 'weight', 'sleep', 'activity', 'biomarker', 'chat'];
  static const _typeLabels = {
    'all': 'All',
    'weight': 'Weight',
    'sleep': 'Sleep',
    'activity': 'Activity',
    'biomarker': 'Biomarker',
    'chat': 'AI Chats',
  };

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    await Future.wait([_loadLogs(), _loadChatHistory()]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadLogs() async {
    try {
      final logs = await MedTwinService.getLogs();
      if (mounted) setState(() => _logs = logs);
    } catch (_) {}
  }

  Future<void> _loadChatHistory() async {
    try {
      final history = await MedTwinService.getChatHistory();
      if (mounted) setState(() => _chatHistory = history);
    } catch (_) {}
  }

  List<HealthLog> get _filtered =>
      _filter == 'all' ? _logs : _logs.where((l) => l.type == _filter).toList();

  List<HealthLog> get _weightLogs =>
      _logs.where((l) => l.type == 'weight').toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

  IconData _iconFor(String type) {
    switch (type) {
      case 'weight':
        return Icons.monitor_weight_outlined;
      case 'sleep':
        return Icons.bedtime_outlined;
      case 'activity':
        return Icons.directions_run;
      default:
        return Icons.science_outlined;
    }
  }

  Color _colorFor(String type) {
    switch (type) {
      case 'weight':
        return AppColors.accentBlue;
      case 'sleep':
        return AppColors.accentViolet;
      case 'activity':
        return AppColors.success;
      default:
        return AppColors.accentAmber;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        RefreshIndicator(
          color: AppColors.accent,
          onRefresh: _loadAll,
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.accent),
                )
              : CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Weight trend chart (not shown in chat filter)
                            if (_filter != 'chat' && _weightLogs.length >= 2) ...[
                              _WeightChart(logs: _weightLogs)
                                  .animate()
                                  .fadeIn(duration: 400.ms),
                              const SizedBox(height: 16),
                            ],

                            // Filter chips
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: _types.map((t) {
                                  final selected = _filter == t;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: FilterChip(
                                      label: Text(_typeLabels[t]!),
                                      selected: selected,
                                      onSelected: (_) =>
                                          setState(() => _filter = t),
                                      selectedColor:
                                          AppColors.accent.withValues(alpha: 0.2),
                                      checkmarkColor: AppColors.accent,
                                      labelStyle: TextStyle(
                                        color: selected
                                            ? AppColors.accent
                                            : Colors.white70,
                                        fontWeight: selected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        fontSize: 12,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                    ),

                    // ── Chat history ───────────────────────────────────────
                    if (_filter == 'chat') ...[
                      if (_chatHistory.isEmpty)
                        const SliverFillRemaining(
                          child: Center(
                            child: Text(
                              'No AI chat history yet.\nAsk MedTwin AI a question to get started.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.muted),
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, i) {
                                return _ChatHistoryTile(
                                  data: _chatHistory[i],
                                ).animate().fadeIn(
                                      delay: (i * 40).ms,
                                      duration: 300.ms,
                                    );
                              },
                              childCount: _chatHistory.length,
                            ),
                          ),
                        ),
                    ] else ...[
                      // ── Health logs ────────────────────────────────────
                      if (_filtered.isEmpty)
                        const SliverFillRemaining(
                          child: Center(
                            child: Text(
                              'No logs yet.\nTap + to add your first entry.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.muted),
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, i) {
                                final log = _filtered[i];
                                return _LogTile(
                                  log: log,
                                  icon: _iconFor(log.type),
                                  color: _colorFor(log.type),
                                ).animate().fadeIn(
                                      delay: (i * 40).ms,
                                      duration: 300.ms,
                                    );
                              },
                              childCount: _filtered.length,
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
        ),

        // FAB — hidden in chat filter
        if (_filter != 'chat')
          Positioned(
            bottom: 20,
            right: 20,
            child: FloatingActionButton(
              heroTag: 'logs_fab',
              onPressed: () => _showAddSheet(context),
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.ink,
              child: const Icon(Icons.add),
            ),
          ),
      ],
    );
  }

  void _showAddSheet(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AddLogSheet(
        onSaved: (log) async {
          try {
            final saved = await MedTwinService.addLog(log);
            if (mounted) setState(() => _logs.insert(0, saved));
          } catch (e) {
            if (mounted) {
              messenger.showSnackBar(
                SnackBar(
                  content: Text(e.toString().replaceFirst('Exception: ', '')),
                  backgroundColor: AppColors.danger,
                ),
              );
            }
          }
        },
      ),
    );
  }
}

// ─── Chat history tile ────────────────────────────────────────────────────────

class _ChatHistoryTile extends StatefulWidget {
  final Map<String, dynamic> data;

  const _ChatHistoryTile({required this.data});

  @override
  State<_ChatHistoryTile> createState() => _ChatHistoryTileState();
}

class _ChatHistoryTileState extends State<_ChatHistoryTile> {
  bool _expanded = false;

  String _formatTimestamp() {
    final raw = widget.data['timestamp'];
    if (raw == null) return '';
    DateTime? dt;
    if (raw is DateTime) {
      dt = raw;
    } else {
      try {
        dt = (raw as dynamic).toDate() as DateTime;
      } catch (_) {
        return '';
      }
    }
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Today ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    if (diff.inDays == 1) return 'Yesterday';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final question = widget.data['question'] as String? ?? '';
    final keyIssues = _strings(widget.data['key_issues']);
    final warnings = _strings(widget.data['warnings']);
    final suggestAppt = widget.data['suggest_appointment'] as bool? ?? false;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.biotech,
                          color: AppColors.accent, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            question,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                            maxLines: _expanded ? null : 2,
                            overflow: _expanded
                                ? TextOverflow.visible
                                : TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                _formatTimestamp(),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: AppColors.muted),
                              ),
                              if (warnings.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                const Icon(Icons.warning_amber_rounded,
                                    color: AppColors.danger, size: 12),
                                const SizedBox(width: 2),
                                Text(
                                  '${warnings.length} flag${warnings.length > 1 ? 's' : ''}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: AppColors.danger),
                                ),
                              ],
                              if (suggestAppt) ...[
                                const SizedBox(width: 8),
                                const Icon(Icons.calendar_month_rounded,
                                    color: AppColors.accentViolet, size: 12),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      _expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: AppColors.muted,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
            if (_expanded && keyIssues.isNotEmpty) ...[
              const Divider(height: 1, color: AppColors.outline),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Key Issues',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.accentAmber,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 6),
                    ...keyIssues.map((issue) => Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text(
                            '• $issue',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.85)),
                          ),
                        )),
                    if (warnings.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Safety Flags',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.danger,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 4),
                      ...warnings.map((w) => Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Text(
                              '• $w',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                      color: AppColors.danger
                                          .withValues(alpha: 0.9)),
                            ),
                          )),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<String> _strings(dynamic raw) =>
      (raw as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
}

// ─── Weight trend chart ───────────────────────────────────────────────────────

class _WeightChart extends StatelessWidget {
  final List<HealthLog> logs;

  const _WeightChart({required this.logs});

  @override
  Widget build(BuildContext context) {
    final spots = logs.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.value);
    }).toList();

    final minY = logs.map((l) => l.value).reduce((a, b) => a < b ? a : b) - 2;
    final maxY = logs.map((l) => l.value).reduce((a, b) => a > b ? a : b) + 2;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.show_chart, size: 16, color: AppColors.accent),
              const SizedBox(width: 6),
              Text(
                'Weight trend',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.muted),
              ),
              const Spacer(),
              Text(
                '${logs.first.value.toStringAsFixed(1)} → ${logs.last.value.toStringAsFixed(1)} kg',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 100,
            child: LineChart(
              LineChartData(
                minY: minY,
                maxY: maxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: AppColors.accent,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.accent.withValues(alpha: 0.08),
                    ),
                  ),
                ],
                titlesData: const FlTitlesData(show: false),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                backgroundColor: Colors.transparent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Log tile ─────────────────────────────────────────────────────────────────

class _LogTile extends StatelessWidget {
  final HealthLog log;
  final IconData icon;
  final Color color;

  const _LogTile({
    required this.log,
    required this.icon,
    required this.color,
  });

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    log.label,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    _formatDate(log.timestamp),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.muted),
                  ),
                ],
              ),
            ),
            Text(
              '${log.value % 1 == 0 ? log.value.toInt() : log.value.toStringAsFixed(1)} ${log.unit}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Add log bottom sheet ─────────────────────────────────────────────────────

class _AddLogSheet extends StatefulWidget {
  final void Function(HealthLog log) onSaved;

  const _AddLogSheet({required this.onSaved});

  @override
  State<_AddLogSheet> createState() => _AddLogSheetState();
}

class _AddLogSheetState extends State<_AddLogSheet> {
  String _type = 'weight';
  final _labelCtrl = TextEditingController();
  final _valueCtrl = TextEditingController();
  final _unitCtrl = TextEditingController();
  bool _saving = false;

  static const _typeDefaults = {
    'weight': ('Weight', 'kg'),
    'sleep': ('Sleep', 'hrs'),
    'activity': ('Steps', 'steps'),
    'biomarker': ('', 'mg/dL'),
  };

  @override
  void initState() {
    super.initState();
    _applyDefaults();
  }

  void _applyDefaults() {
    final defaults = _typeDefaults[_type]!;
    _labelCtrl.text = defaults.$1;
    _unitCtrl.text = defaults.$2;
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _valueCtrl.dispose();
    _unitCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final value = double.tryParse(_valueCtrl.text.trim());
    if (value == null || _labelCtrl.text.trim().isEmpty) return;

    setState(() => _saving = true);
    widget.onSaved(
      HealthLog(
        type: _type,
        label: _labelCtrl.text.trim(),
        value: value,
        unit: _unitCtrl.text.trim(),
        timestamp: DateTime.now(),
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Add health log',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),

          Wrap(
            spacing: 8,
            children: ['weight', 'sleep', 'activity', 'biomarker'].map((t) {
              return ChoiceChip(
                label: Text(t[0].toUpperCase() + t.substring(1)),
                selected: _type == t,
                onSelected: (_) => setState(() {
                  _type = t;
                  _applyDefaults();
                }),
                selectedColor: AppColors.accent.withValues(alpha: 0.2),
                labelStyle: TextStyle(
                  color: _type == t ? AppColors.accent : Colors.white70,
                  fontWeight:
                      _type == t ? FontWeight.w700 : FontWeight.w500,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          _Field(controller: _labelCtrl, label: 'Label', hint: 'e.g. Weight'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _Field(
                  controller: _valueCtrl,
                  label: 'Value',
                  hint: '0.0',
                  inputType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Field(
                  controller: _unitCtrl,
                  label: 'Unit',
                  hint: 'kg',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.ink,
                      ),
                    )
                  : const Text('Save log'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType inputType;

  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    this.inputType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppColors.muted, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: inputType,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.muted),
          ),
        ),
      ],
    );
  }
}
