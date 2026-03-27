import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/app_card.dart';
import '../widgets/digital_twin_logo.dart';
import 'avatar_screen.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const DigitalTwinLogo(size: 44, animated: true, color: Colors.white),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bodyclone',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      Text(
                        'Digital twin platform',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.muted,
                            ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  const _StatusPill(label: 'Live', color: AppColors.accent),
                ],
              ).animate().fadeIn(duration: 400.ms),
              const SizedBox(height: 24),
              Text(
                'Make your health\nfeel alive.',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.05,
                    ),
              ).animate().fadeIn(delay: 120.ms, duration: 450.ms),
              const SizedBox(height: 10),
              Text(
                'A cinematic, real-time view of your body — synced from devices, reports, and AI.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.muted,
                    ),
              ).animate().fadeIn(delay: 220.ms, duration: 450.ms),
              const SizedBox(height: 20),
              const Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _Pill(label: 'Realtime sync'),
                  _Pill(label: 'Adaptive insights'),
                  _Pill(label: 'Private by design'),
                ],
              ).animate().fadeIn(delay: 320.ms, duration: 450.ms),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: AppCard(
                      padding: const EdgeInsets.all(16),
                      glow: true,
                      glowColor: AppColors.accentBlue,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _MetricHeader(label: 'Vital score', icon: Icons.favorite),
                          const SizedBox(height: 8),
                          Text(
                            '92',
                            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          Text(
                            'Excellent range',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.muted,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppCard(
                      padding: const EdgeInsets.all(16),
                      glow: true,
                      glowColor: AppColors.accentRose,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _MetricHeader(label: 'Recovery', icon: Icons.auto_awesome),
                          const SizedBox(height: 8),
                          Text(
                            '7.4h',
                            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          Text(
                            'Sleep tracked',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.muted,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ).animate().fadeIn(delay: 420.ms, duration: 450.ms),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
<<<<<<< HEAD
                    Navigator.of(context).push(
=======
                    Navigator.of(context).pushReplacement(
>>>>>>> 2ea837fd8ac6cd2eabb1da670b0294a2aee12495
                      MaterialPageRoute(
                        builder: (context) => const AvatarScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.ink,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Enter your twin'),
                ),
              ).animate().fadeIn(delay: 520.ms, duration: 450.ms),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    showDialog<void>(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: AppColors.surface,
                        title: const Text('Digital Twin'),
                        content: Text(
                          'A living, secure view of your health story, updated by your devices, reports, and clinical notes.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.white.withOpacity(0.8),
                              ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Got it'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text('What is a digital twin?'),
                ),
              ).animate().fadeIn(delay: 620.ms, duration: 450.ms),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _MetricHeader extends StatelessWidget {
  final String label;
  final IconData icon;

  const _MetricHeader({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.accent),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.muted,
              ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;

  const _Pill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated.withOpacity(0.8),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.outline.withOpacity(0.6)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white.withOpacity(0.85),
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
