import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:health/health.dart';

import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/health_tip_bar.dart';
import '../widgets/app_card.dart';

class VitalsScreen extends StatefulWidget {
  const VitalsScreen({super.key});

  @override
  State<VitalsScreen> createState() => _VitalsScreenState();
}

class _VitalsScreenState extends State<VitalsScreen> {
  final Health health = Health();

  // Today's vitals
  String _watchSteps = "--";
  String _activeCalories = "--";
  String _totalCalories = "--";
  String _heartRate = "--";
  String _sleepHours = "--";

  // Steps history graph
  List<int> _graphSteps = [];
  int _avgSteps = 0;
  bool _showMonthGraph = false;

  bool _isSyncing = false;
  String _connectionStatus = "Sync live vitals from your wearable.";

  @override
  void initState() {
    super.initState();
    syncData();
  }

  Future<void> syncData() async {
    if (_isSyncing) return;

    setState(() {
      _isSyncing = true;
      _connectionStatus = "Syncing data from watch...";
    });

    // Calories are fetched separately in calRaw below — not included here
    var types = [
      HealthDataType.STEPS,
      HealthDataType.HEART_RATE,
      HealthDataType.SLEEP_ASLEEP,
    ];

    await health.requestAuthorization([
      ...types,
      HealthDataType.TOTAL_CALORIES_BURNED,
      HealthDataType.ACTIVE_ENERGY_BURNED,
    ]);

    try {
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);

      // Returns true for Samsung Health / Galaxy Watch data points
      bool isSamsung(HealthDataPoint p) {
        final src = p.sourceName.toLowerCase();
        final id = p.sourceId.toLowerCase();
        return src.contains("samsung") ||
            src.contains("galaxy") ||
            src.contains("shealth") ||
            id.contains("samsung") ||
            id.contains("shealth") ||
            id.contains("sec.android");
      }

      double numVal(HealthDataPoint p) => p.value is NumericHealthValue
          ? (p.value as NumericHealthValue).numericValue.toDouble()
          : 0.0;

      // ── TODAY'S DATA ──────────────────────────────────────────
      List<HealthDataPoint> data = await health.getHealthDataFromTypes(
        types: types,
        startTime: midnight,
        endTime: now,
      );
      data = health.removeDuplicates(data);
      data.sort((a, b) => a.dateFrom.compareTo(b.dateFrom));

      // Steps — sum Samsung-only incremental interval records
      final stepPoints =
          data.where((p) => p.type == HealthDataType.STEPS).toList();
      final relevantSteps = stepPoints.any(isSamsung)
          ? stepPoints.where(isSamsung).toList()
          : stepPoints;
      double totalSteps = 0;
      for (var p in relevantSteps) {
        totalSteps += numVal(p);
      }

      // ── CALORIES ─────────────────────────────────────────────────
      // Fetched raw (no removeDuplicates) to preserve all interval records.
      final calRaw = await health.getHealthDataFromTypes(
        types: [
          HealthDataType.TOTAL_CALORIES_BURNED,
          HealthDataType.ACTIVE_ENERGY_BURNED
        ],
        startTime: midnight,
        endTime: now,
      );

      // TOTAL CALORIES
      // Google Fit writes two kinds of TOTAL_CALORIES_BURNED records:
      //   1. Past intervals (short, 5–60 min) — actual calories already burned.
      //   2. One future projection (long, hours to midnight) — BMR estimate for
      //      the rest of the day. Google Fit hasn't written the current gap yet.
      //
      // Strategy: sum past records + interpolate the elapsed portion of the
      // projection. This gives a live running total matching Samsung Health.
      final cutoff = now.add(const Duration(hours: 1));
      final pastCalRecords = calRaw
          .where((p) =>
              p.type == HealthDataType.TOTAL_CALORIES_BURNED &&
              p.dateTo.isBefore(cutoff))
          .toList();
      final projectionRecords = calRaw
          .where((p) =>
              p.type == HealthDataType.TOTAL_CALORIES_BURNED &&
              p.dateTo.isAfter(cutoff))
          .toList();

      final pastTotal = pastCalRecords.fold(0.0, (s, p) => s + numVal(p));

      // Interpolate elapsed portion of the projection record
      double projContribution = 0;
      if (projectionRecords.isNotEmpty) {
        final proj = projectionRecords.first;
        final totalSecs =
            proj.dateTo.difference(proj.dateFrom).inSeconds.toDouble();
        final elapsedSecs = now
            .difference(proj.dateFrom)
            .inSeconds
            .toDouble()
            .clamp(0, totalSecs);
        if (totalSecs > 0) {
          projContribution = numVal(proj) * (elapsedSecs / totalSecs);
        }
      }

      final totalCaloriesVal = pastTotal + projContribution;

      debugPrint("Total cal: past=${pastTotal.toStringAsFixed(1)}"
          " + proj=${projContribution.toStringAsFixed(1)}"
          " = ${totalCaloriesVal.toStringAsFixed(1)}");

      // ACTIVE CALORIES — Neither Google Fit nor Samsung Health writes
      // ACTIVE_ENERGY_BURNED to Health Connect for background daily movement.
      // Estimate from step count: Samsung's activity calories ≈ steps × 0.033
      // (validated from user data: 3000 steps ≈ 101 kcal on their Samsung watch).
      final activeCaloriesVal = totalSteps > 0 ? totalSteps * 0.033 : 0.0;

      // ── HEART RATE (last 24 h — watch syncs infrequently) ─────
      final hrData = await health.getHealthDataFromTypes(
        types: [HealthDataType.HEART_RATE],
        startTime: now.subtract(const Duration(hours: 24)),
        endTime: now,
      );
      hrData.sort((a, b) => a.dateFrom.compareTo(b.dateFrom));
      final relevantHr =
          hrData.any(isSamsung) ? hrData.where(isSamsung).toList() : hrData;
      double lastHR = 0;
      if (relevantHr.isNotEmpty) {
        lastHR = numVal(relevantHr.last);
      }

      // ── SLEEP (yesterday 6 pm → today noon) ──────────────────
      final sleepStart = midnight.subtract(const Duration(hours: 6));
      final sleepEnd = midnight.add(const Duration(hours: 12));
      final sleepData = await health.getHealthDataFromTypes(
        types: [HealthDataType.SLEEP_ASLEEP],
        startTime: sleepStart,
        endTime: sleepEnd,
      );
      int sleepMinutes = 0;
      for (var p in sleepData) {
        sleepMinutes += p.dateTo.difference(p.dateFrom).inMinutes;
      }
      final sleepStr = sleepMinutes > 0
          ? '${(sleepMinutes / 60).toStringAsFixed(1)}h'
          : '--';

      // ── 30-DAY STEPS HISTORY (for graph) ─────────────────────
      final historyStart = midnight.subtract(const Duration(days: 29));
      final historyData = await health.getHealthDataFromTypes(
        types: [HealthDataType.STEPS],
        startTime: historyStart,
        endTime: now,
      );

      // Group by calendar day, Samsung source only
      final Map<String, double> stepsByDay = {};
      for (var p in historyData) {
        if (!isSamsung(p)) continue;
        final key = '${p.dateFrom.year}-${p.dateFrom.month}-${p.dateFrom.day}';
        stepsByDay[key] = (stepsByDay[key] ?? 0) + numVal(p);
      }

      // Build ordered list: index 0 = 29 days ago, index 29 = today
      final List<int> monthSteps = List.generate(30, (i) {
        final day = midnight.subtract(Duration(days: 29 - i));
        final key = '${day.year}-${day.month}-${day.day}';
        return (stepsByDay[key] ?? 0).toInt();
      });

      // Average over the past 29 days (exclude today which is incomplete)
      final pastDays = monthSteps.sublist(0, 29);
      final nonZero = pastDays.where((s) => s > 0).toList();
      final avg = nonZero.isNotEmpty
          ? (nonZero.reduce((a, b) => a + b) / nonZero.length).round()
          : 0;

      debugPrint(
          "Health Connect sources: ${data.map((p) => '${p.type.name}: ${p.sourceName}').toSet()}");

      setState(() {
        _watchSteps = totalSteps > 0 ? totalSteps.toInt().toString() : "--";
        _activeCalories =
            activeCaloriesVal > 0 ? activeCaloriesVal.toInt().toString() : "--";
        _totalCalories =
            totalCaloriesVal > 0 ? totalCaloriesVal.toInt().toString() : "--";
        _heartRate = lastHR > 0 ? lastHR.toInt().toString() : "--";
        _sleepHours = sleepStr;
        _graphSteps = monthSteps;
        _avgSteps = avg;
        _connectionStatus = "Successfully synced just now.";
        _isSyncing = false;
      });
    } catch (e) {
      setState(() {
        _connectionStatus = "Sync failed. Tap to try again.";
        _isSyncing = false;
      });
      debugPrint("Health Connect Error: $e");
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
            const Text("Vitals"),
            Text(
              "Today at a glance",
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.muted,
                  ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                // ── Hero card: steps ──────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: AppCard(
                      padding: const EdgeInsets.all(20),
                      glow: true,
                      glowColor: AppColors.accent,
                      gradient: AppDecorations.heroGradient,
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Steps Walked Today',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium),
                                const SizedBox(height: 8),
                                Text(
                                  _watchSteps,
                                  style: Theme.of(context)
                                      .textTheme
                                      .displaySmall
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 6),
                                Text('Live sync via Watch',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: AppColors.muted)),
                              ],
                            ),
                          ),
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.directions_walk,
                                color: AppColors.accent),
                          ),
                        ],
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 450.ms)
                        .slideY(begin: 0.08, end: 0),
                  ),
                ),

                // ── Mini stats ────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _miniStat('Active Cal', _activeCalories, 'kcal active',
                            AppColors.accentAmber),
                        _miniStat('Total Cal', _totalCalories, 'kcal burned',
                            AppColors.accentViolet),
                        _miniStat('Sleep', _sleepHours, 'last night',
                            AppColors.accentBlue),
                        _miniStat('Heart Rate', _heartRate, 'bpm',
                            AppColors.accentRose),
                      ],
                    ).animate().fadeIn(delay: 120.ms, duration: 450.ms),
                  ),
                ),

                // ── Steps history graph ───────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: AppCard(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Steps History',
                                  style:
                                      Theme.of(context).textTheme.titleSmall),
                              // Week / Month toggle
                              Row(
                                children: [
                                  _graphToggle(
                                      'Week',
                                      !_showMonthGraph,
                                      () => setState(
                                          () => _showMonthGraph = false)),
                                  const SizedBox(width: 6),
                                  _graphToggle(
                                      'Month',
                                      _showMonthGraph,
                                      () => setState(
                                          () => _showMonthGraph = true)),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _avgSteps > 0
                                ? 'Avg $_avgSteps steps/day'
                                : 'No history yet',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppColors.muted),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            height: 80,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceSoft,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color:
                                      AppColors.outline.withValues(alpha: 0.5)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: _buildStepsGraph(),
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 220.ms, duration: 450.ms),
                  ),
                ),

                // ── Sync tile ─────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: AppCard(
                      child: ListTile(
                        onTap: syncData,
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.accentBlue.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.watch,
                              color: AppColors.accentBlue),
                        ),
                        title: const Text("Connect Smartwatch"),
                        subtitle: Text(
                          _connectionStatus,
                          style: TextStyle(
                            color: _isSyncing
                                ? AppColors.accent
                                : Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                        trailing: _isSyncing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.chevron_right,
                                color: Colors.white54),
                      ),
                    ).animate().fadeIn(delay: 320.ms, duration: 450.ms),
                  ),
                ),
              ],
            ),
          ),
          const HealthTipBar(),
        ],
      ),
    );
  }

  Widget _buildStepsGraph() {
    final display = _showMonthGraph
        ? _graphSteps
        : (_graphSteps.length >= 7
            ? _graphSteps.sublist(_graphSteps.length - 7)
            : _graphSteps);

    if (display.isEmpty || display.every((s) => s == 0)) {
      return Center(
        child: Text('No step data yet',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.muted)),
      );
    }

    final maxVal = display.reduce(max).toDouble();

    return LayoutBuilder(builder: (context, constraints) {
      final barAreaHeight = constraints.maxHeight;
      return Stack(
        children: [
          // Bars
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: display.map((steps) {
              final ratio = maxVal > 0 ? steps / maxVal : 0.0;
              final barH = _isSyncing
                  ? 4.0
                  : (ratio * barAreaHeight).clamp(3.0, barAreaHeight);
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1.5),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutBack,
                    height: barH,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          // Average line
          if (!_isSyncing && _avgSteps > 0 && maxVal > 0)
            Positioned.fill(
              child: CustomPaint(
                painter: _AverageLinePainter(
                  ratio: (_avgSteps / maxVal).clamp(0.0, 1.0),
                  color: AppColors.accentAmber,
                ),
              ),
            ),
        ],
      );
    });
  }

  Widget _graphToggle(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active
              ? AppColors.accent.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? AppColors.accent : AppColors.outline,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: active ? AppColors.accent : AppColors.muted,
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
              ),
        ),
      ),
    );
  }

  Widget _miniStat(String label, String value, String hint, Color color) {
    return SizedBox(
      width: 160,
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.bolt, color: color, size: 16),
                ),
                const SizedBox(width: 8),
                Text(label, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            Text(
              hint,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Draws a dashed horizontal average line at the given ratio from the bottom.
class _AverageLinePainter extends CustomPainter {
  final double ratio;
  final Color color;

  _AverageLinePainter({required this.ratio, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * (1 - ratio);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const dashW = 5.0;
    const gapW = 4.0;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, y),
        Offset((x + dashW).clamp(0, size.width), y),
        paint,
      );
      x += dashW + gapW;
    }
  }

  @override
  bool shouldRepaint(_AverageLinePainter old) =>
      old.ratio != ratio || old.color != color;
}
