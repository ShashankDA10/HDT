import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_scaffold.dart';
import '../models/health_profile.dart';
import '../services/medtwin_service.dart';
import 'chat_screen.dart';
import 'logs_screen.dart';
import 'profile_setup_screen.dart';

class MedTwinHomeScreen extends StatefulWidget {
  const MedTwinHomeScreen({super.key});

  @override
  State<MedTwinHomeScreen> createState() => _MedTwinHomeScreenState();
}

class _MedTwinHomeScreenState extends State<MedTwinHomeScreen> {
  int _tabIndex = 0;
  HealthProfile? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    // Show cached data immediately
    final cached = await MedTwinService.getCachedProfile();
    if (cached != null && mounted) {
      setState(() {
        _profile = cached;
        _loading = false;
      });
    }
    // Refresh from network in background
    try {
      final fresh = await MedTwinService.getProfile();
      if (mounted) setState(() { _profile = fresh; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _goToChat() => setState(() => _tabIndex = 1);

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.biotech, color: AppColors.accent, size: 20),
            const SizedBox(width: 8),
            const Text('MedTwin AI'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Edit profile',
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(
                  builder: (_) => const ProfileSetupScreen(),
                ))
                .then((_) => _loadProfile()),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.accent.withOpacity(0.2),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard, color: AppColors.accent),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble, color: AppColors.accent),
            label: 'Chat',
          ),
          NavigationDestination(
            icon: Icon(Icons.show_chart),
            selectedIcon: Icon(Icons.show_chart, color: AppColors.accent),
            label: 'Logs',
          ),
        ],
      ),
      body: IndexedStack(
        index: _tabIndex,
        children: [
          _DashboardTab(
            profile: _profile,
            loading: _loading,
            onRefresh: _loadProfile,
            onChatTap: _goToChat,
          ),
          const ChatTab(),
          const LogsTab(),
        ],
      ),
    );
  }
}

// ─── Dashboard tab ────────────────────────────────────────────────────────────

class _DashboardTab extends StatelessWidget {
  final HealthProfile? profile;
  final bool loading;
  final Future<void> Function() onRefresh;
  final VoidCallback onChatTap;

  const _DashboardTab({
    required this.profile,
    required this.loading,
    required this.onRefresh,
    required this.onChatTap,
  });

  @override
  Widget build(BuildContext context) {
    if (loading && profile == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (profile == null || _isEmpty(profile!)) ...[
                  _EmptyProfileCard().animate().fadeIn(duration: 400.ms),
                  const SizedBox(height: 16),
                ],

                // Metric cards grid
                if (profile != null) ...[
                  _MetricGrid(profile: profile!)
                      .animate()
                      .fadeIn(duration: 400.ms),
                  const SizedBox(height: 16),

                  // BMI card
                  if (profile!.bmi != null)
                    _BmiCard(profile: profile!)
                        .animate()
                        .fadeIn(delay: 80.ms, duration: 400.ms),
                  if (profile!.bmi != null) const SizedBox(height: 16),

                  // Cholesterol chart
                  if (profile!.ldl != null || profile!.hdl != null)
                    _CholesterolChart(profile: profile!)
                        .animate()
                        .fadeIn(delay: 160.ms, duration: 400.ms),
                  if (profile!.ldl != null || profile!.hdl != null)
                    const SizedBox(height: 16),

                  // Active goals
                  if (profile!.lifestyleGoals.isNotEmpty)
                    _GoalsCard(goals: profile!.lifestyleGoals)
                        .animate()
                        .fadeIn(delay: 240.ms, duration: 400.ms),
                  if (profile!.lifestyleGoals.isNotEmpty)
                    const SizedBox(height: 16),
                ],

                // Ask MedTwin AI CTA
                _AskCta(onTap: onChatTap)
                    .animate()
                    .fadeIn(delay: 320.ms, duration: 400.ms),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  bool _isEmpty(HealthProfile p) =>
      p.weightKg == null &&
      p.restingHeartRate == null &&
      p.ldl == null &&
      p.sleepDurationHrs == null;
}

// ─── Empty profile ────────────────────────────────────────────────────────────

class _EmptyProfileCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.person_outline,
                    color: AppColors.accent, size: 22),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Set up your Digital Twin',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    'Tap the profile icon to add health data.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.muted),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Metric grid ──────────────────────────────────────────────────────────────

class _MetricGrid extends StatelessWidget {
  final HealthProfile profile;

  const _MetricGrid({required this.profile});

  @override
  Widget build(BuildContext context) {
    final metrics = <_Metric>[
      if (profile.weightKg != null)
        _Metric('Weight', '${profile.weightKg!.toStringAsFixed(1)} kg',
            Icons.monitor_weight_outlined, AppColors.accentBlue),
      if (profile.restingHeartRate != null)
        _Metric('Resting HR', '${profile.restingHeartRate} bpm',
            Icons.favorite_border, AppColors.accentRose),
      if (profile.ldl != null)
        _Metric('LDL', '${profile.ldl!.toStringAsFixed(0)} mg/dL',
            Icons.water_drop_outlined, AppColors.accentAmber),
      if (profile.hdl != null)
        _Metric('HDL', '${profile.hdl!.toStringAsFixed(0)} mg/dL',
            Icons.water_drop, AppColors.success),
      if (profile.fastingGlucose != null)
        _Metric('Glucose', '${profile.fastingGlucose!.toStringAsFixed(0)} mg/dL',
            Icons.bloodtype_outlined, AppColors.accentViolet),
      if (profile.sleepDurationHrs != null)
        _Metric('Sleep', '${profile.sleepDurationHrs!.toStringAsFixed(1)} hrs',
            Icons.bedtime_outlined, AppColors.accentBlue),
    ];

    if (metrics.isEmpty) return const SizedBox.shrink();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.6,
      ),
      itemCount: metrics.length,
      itemBuilder: (_, i) => _MetricCard(metric: metrics[i]),
    );
  }
}

class _Metric {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _Metric(this.label, this.value, this.icon, this.color);
}

class _MetricCard extends StatelessWidget {
  final _Metric metric;

  const _MetricCard({required this.metric});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      glow: true,
      glowColor: metric.color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(metric.icon, size: 14, color: metric.color),
              const SizedBox(width: 5),
              Text(
                metric.label,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.muted),
              ),
            ],
          ),
          Text(
            metric.value,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

// ─── BMI card ─────────────────────────────────────────────────────────────────

class _BmiCard extends StatelessWidget {
  final HealthProfile profile;

  const _BmiCard({required this.profile});

  Color _bmiColor(String category) {
    switch (category) {
      case 'Normal':
        return AppColors.success;
      case 'Underweight':
        return AppColors.accentBlue;
      case 'Overweight':
        return AppColors.accentAmber;
      default:
        return AppColors.danger;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bmi = profile.bmi!;
    final cat = profile.bmiCategory;
    final color = _bmiColor(cat);

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                bmi.toStringAsFixed(1),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'BMI',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.muted),
              ),
              Text(
                cat,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Cholesterol chart ────────────────────────────────────────────────────────

class _CholesterolChart extends StatelessWidget {
  final HealthProfile profile;

  const _CholesterolChart({required this.profile});

  @override
  Widget build(BuildContext context) {
    final bars = <BarChartGroupData>[];
    final labels = <String>[];
    int idx = 0;

    void addBar(String label, double value, Color color) {
      labels.add(label);
      bars.add(
        BarChartGroupData(
          x: idx++,
          barRods: [
            BarChartRodData(
              toY: value,
              color: color,
              width: 24,
              borderRadius: BorderRadius.circular(6),
            ),
          ],
        ),
      );
    }

    if (profile.ldl != null) addBar('LDL', profile.ldl!, AppColors.accentRose);
    if (profile.hdl != null) addBar('HDL', profile.hdl!, AppColors.success);
    if (profile.totalCholesterol != null) addBar('Total', profile.totalCholesterol!, AppColors.accentBlue);
    if (profile.triglycerides != null) addBar('TG', profile.triglycerides!, AppColors.accentAmber);

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart, size: 16, color: AppColors.accent),
              const SizedBox(width: 6),
              Text(
                'Lipid Panel',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: BarChart(
              BarChartData(
                barGroups: bars,
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) => Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          labels[v.toInt()],
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      reservedSize: 24,
                    ),
                  ),
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
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

// ─── Goals card ───────────────────────────────────────────────────────────────

class _GoalsCard extends StatelessWidget {
  final List<String> goals;

  const _GoalsCard({required this.goals});

  String _label(String g) {
    const map = {
      'fat_loss': 'Fat Loss',
      'muscle_gain': 'Muscle Gain',
      'weight_maintenance': 'Weight Maintenance',
      'reduce_ldl': 'Reduce LDL',
      'improve_hdl': 'Improve HDL',
      'lower_bp': 'Lower BP',
      'improve_blood_sugar': 'Blood Sugar',
      'improve_insulin_sensitivity': 'Insulin Sensitivity',
      'heart_health': 'Heart Health',
      'liver_health': 'Liver Health',
      'kidney_function': 'Kidney Function',
      'increase_strength': 'Strength',
      'improve_endurance': 'Endurance',
      'improve_vo2max': 'VO₂ Max',
      'improve_sleep': 'Sleep',
      'reduce_stress': 'Stress',
      'build_habits': 'Habits',
    };
    return map[g] ?? g;
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flag_outlined,
                  size: 14, color: AppColors.accent),
              const SizedBox(width: 6),
              Text(
                'Active goals',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: goals.map((g) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.accent.withOpacity(0.3)),
                ),
                child: Text(
                  _label(g),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ─── Ask MedTwin AI CTA ───────────────────────────────────────────────────────

class _AskCta extends StatelessWidget {
  final VoidCallback onTap;

  const _AskCta({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.accent.withOpacity(0.15),
              AppColors.accentBlue.withOpacity(0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.accent.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.biotech, color: AppColors.accent, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ask MedTwin AI',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  Text(
                    'Get personalised recommendations based on your data.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: AppColors.accent),
          ],
        ),
      ),
    );
  }
}
