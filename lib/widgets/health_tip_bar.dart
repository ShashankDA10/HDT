import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_card.dart';

class HealthTipBar extends StatefulWidget {
  const HealthTipBar({super.key});

  @override
  State<HealthTipBar> createState() => _HealthTipBarState();
}

class _HealthTipBarState extends State<HealthTipBar>
    with SingleTickerProviderStateMixin {
  final List<String> tips = [
    "Drink water before you feel thirsty.",
    "Stretch your spine every hour.",
    "Sleep at the same time daily.",
    "Eat slowly for better digestion.",
    "Take 5 deep breaths when stressed."
  ];

  int index = 0;
  bool glow = false;

  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
  }

  void newTip() {
    setState(() {
      index = (index + 1) % tips.length;
      glow = true;
    });

    _controller.forward(from: 0);

    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() => glow = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const themeColor = AppColors.accent;

    return AppCard(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      glow: glow,
      glowColor: themeColor,
      child: Row(
        children: [
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, animation) {
                final slide = Tween<Offset>(
                  begin: const Offset(0, 0.3),
                  end: Offset.zero,
                ).animate(animation);
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(position: slide, child: child),
                );
              },
              child: Text(
                tips[index],
                key: ValueKey(index),
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.85),
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: newTip,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: themeColor.withOpacity(0.18),
                border: Border.all(color: themeColor.withOpacity(0.6)),
                boxShadow: glow
                    ? [
                        BoxShadow(
                          color: themeColor.withOpacity(0.4),
                          blurRadius: 18,
                          spreadRadius: 1,
                        )
                      ]
                    : [],
              ),
              child: const Icon(Icons.lightbulb, color: AppColors.accent),
            ),
          )
        ],
      ),
    );
  }
}
