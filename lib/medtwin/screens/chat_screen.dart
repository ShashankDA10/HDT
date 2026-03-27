import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../screens/appointments/book_appointment_screen.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../models/recommendation.dart';
import '../services/medtwin_service.dart';

// ─── Chat message model ───────────────────────────────────────────────────────

class _ChatMessage {
  final String text;
  final bool isUser;
  final AIRecommendation? recommendation;
  final DateTime timestamp;

  const _ChatMessage({
    required this.text,
    required this.isUser,
    this.recommendation,
    required this.timestamp,
  });
}

// ─── Chat tab ─────────────────────────────────────────────────────────────────

class ChatTab extends StatefulWidget {
  const ChatTab({super.key});

  @override
  State<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<ChatTab> {
  final List<_ChatMessage> _messages = [];
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  bool _isTyping = false;

  static const _suggestions = [
    'What should I prioritize?',
    'Explain my lab results',
    'Give me a meal plan',
    'How to improve sleep?',
    'Best exercises for me?',
    'Review my medications',
  ];

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    final q = text.trim();
    if (q.isEmpty) return;

    setState(() {
      _messages.insert(
        0,
        _ChatMessage(text: q, isUser: true, timestamp: DateTime.now()),
      );
      _isTyping = true;
      _inputCtrl.clear();
    });

    try {
      final rec = await MedTwinService.getRecommendation(q);
      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _messages.insert(
          0,
          _ChatMessage(
            text: rec.expectedTimeline.isNotEmpty
                ? rec.expectedTimeline
                : 'Here are your personalised recommendations.',
            isUser: false,
            recommendation: rec,
            timestamp: DateTime.now(),
          ),
        );
      });
      // Save to Firestore chat history (fire-and-forget)
      MedTwinService.saveChatHistory(question: q, recommendation: rec);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _messages.insert(
          0,
          _ChatMessage(
            text: e.toString().replaceFirst('Exception: ', ''),
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Message list
        Expanded(
          child: _messages.isEmpty
              ? _EmptyState(
                  onSuggestion: _send,
                  suggestions: _suggestions,
                )
              : ListView.builder(
                  reverse: true,
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  itemCount: _messages.length + (_isTyping ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (_isTyping && i == 0) {
                      return const _TypingIndicator();
                    }
                    final msg = _messages[_isTyping ? i - 1 : i];
                    return _MessageItem(message: msg)
                        .animate()
                        .fadeIn(duration: 300.ms)
                        .slideY(begin: 0.06, end: 0);
                  },
                ),
        ),

        // Quick chips (shown when messages exist)
        if (_messages.isNotEmpty && !_isTyping)
          _SuggestionRow(
            suggestions: _suggestions,
            onTap: _send,
          ),

        // Input bar
        _InputBar(
          controller: _inputCtrl,
          enabled: !_isTyping,
          onSend: _send,
        ),
      ],
    );
  }
}

// ─── Message item ─────────────────────────────────────────────────────────────

class _MessageItem extends StatelessWidget {
  final _ChatMessage message;

  // ignore: unused_element_parameter
  const _MessageItem({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    if (message.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10, left: 48),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.2),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(4),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
          ),
          child: Text(
            message.text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                ),
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10, right: 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.recommendation != null)
              RecommendationCard(recommendation: message.recommendation!)
            else
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  border: Border.all(color: AppColors.outline),
                ),
                child: Text(
                  message.text,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Recommendation card ──────────────────────────────────────────────────────

class RecommendationCard extends StatefulWidget {
  final AIRecommendation recommendation;

  const RecommendationCard({super.key, required this.recommendation});

  @override
  State<RecommendationCard> createState() => _RecommendationCardState();
}

class _RecommendationCardState extends State<RecommendationCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final rec = widget.recommendation;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Safety warnings banner
          if (rec.warnings.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.15),
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16)),
                border: Border(
                  bottom: BorderSide(
                      color: AppColors.danger.withValues(alpha: 0.3)),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: AppColors.danger, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Safety flags',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.danger,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ...rec.warnings.map(
                    (w) => Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(
                        '• $w',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.danger.withValues(alpha: 0.9),
                            ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Header / toggle
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: rec.warnings.isEmpty
                ? const BorderRadius.vertical(top: Radius.circular(16))
                : BorderRadius.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.biotech, color: AppColors.accent, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'MedTwin AI Recommendation',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.accent,
                        ),
                  ),
                  const Spacer(),
                  Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: AppColors.muted,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          if (_expanded) ...[
            const Divider(height: 1, color: AppColors.outline),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Section(
                    title: 'Key Issues',
                    icon: Icons.warning_amber_rounded,
                    color: AppColors.accentAmber,
                    items: rec.keyIssues,
                  ),
                  _Section(
                    title: 'Root Causes',
                    icon: Icons.search_rounded,
                    color: AppColors.accentBlue,
                    items: rec.rootCauses,
                  ),
                  _ActionSection(plan: rec.actionPlan),
                  if (rec.otcSuggestions.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    _OTCSection(suggestions: rec.otcSuggestions),
                  ],
                  if (rec.expectedTimeline.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const _SectionHeader(
                      title: 'Expected Timeline',
                      icon: Icons.schedule_rounded,
                      color: AppColors.success,
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppColors.success.withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        rec.expectedTimeline,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                      ),
                    ),
                  ],

                  // Book appointment banner
                  if (rec.suggestAppointment) ...[
                    const SizedBox(height: 14),
                    _BookAppointmentBanner(),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Book appointment banner ──────────────────────────────────────────────────

// ─── OTC suggestions section ──────────────────────────────────────────────────

class _OTCSection extends StatelessWidget {
  final List<OTCSuggestion> suggestions;
  const _OTCSection({required this.suggestions});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
          title: 'Supplements & OTC',
          icon: Icons.medication_liquid_rounded,
          color: AppColors.accentRose,
        ),
        const SizedBox(height: 8),
        ...suggestions.map((s) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.accentRose.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.accentRose.withValues(alpha: 0.18)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.medication_rounded,
                          size: 13, color: AppColors.accentRose),
                      const SizedBox(width: 5),
                      Text(
                        s.name,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.accentRose,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    s.purpose,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.85),
                          height: 1.4,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.straighten_rounded,
                          size: 11, color: AppColors.muted),
                      const SizedBox(width: 4),
                      Text(
                        s.dosage,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.muted,
                              fontStyle: FontStyle.italic,
                            ),
                      ),
                    ],
                  ),
                  if (s.notes.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      '⚠ ${s.notes}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.accentAmber.withValues(alpha: 0.85),
                            fontSize: 10,
                          ),
                    ),
                  ],
                ],
              ),
            )),
      ],
    );
  }
}

// ─── Book appointment banner ──────────────────────────────────────────────────

class _BookAppointmentBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.accentViolet.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accentViolet.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_month_rounded,
                  color: AppColors.accentViolet, size: 16),
              const SizedBox(width: 6),
              Text(
                'Doctor visit recommended',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.accentViolet,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Based on your health data, speaking with a doctor would be beneficial.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.75),
                  height: 1.4,
                ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const BookAppointmentScreen(),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentViolet,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text(
                'Book Appointment',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section helpers ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;

  const _SectionHeader({
    required this.title,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(
          title,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<String> items;

  const _Section({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: title, icon: icon, color: color),
        const SizedBox(height: 6),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 4, left: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 4,
                  height: 4,
                  margin: const EdgeInsets.only(top: 7, right: 8),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Text(
                    item,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.85),
                          height: 1.5,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _ActionSection extends StatelessWidget {
  final ActionPlan plan;

  const _ActionSection({required this.plan});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
          title: 'Action Plan',
          icon: Icons.bolt_rounded,
          color: AppColors.accentViolet,
        ),
        const SizedBox(height: 8),
        if (plan.diet.isNotEmpty)
          _ActionGroup(
              label: 'Diet',
              icon: Icons.restaurant_menu,
              color: AppColors.success,
              items: plan.diet),
        if (plan.training.isNotEmpty)
          _ActionGroup(
              label: 'Training',
              icon: Icons.fitness_center,
              color: AppColors.accentBlue,
              items: plan.training),
        if (plan.lifestyle.isNotEmpty)
          _ActionGroup(
              label: 'Lifestyle',
              icon: Icons.self_improvement,
              color: AppColors.accentAmber,
              items: plan.lifestyle),
      ],
    );
  }
}

class _ActionGroup extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final List<String> items;

  const _ActionGroup({
    required this.label,
    required this.icon,
    required this.color,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 5),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                '• $item',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                      height: 1.4,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Typing indicator ─────────────────────────────────────────────────────────

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            return Container(
              width: 7,
              height: 7,
              margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
              decoration: const BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
              ),
            )
                .animate(onPlay: (c) => c.repeat())
                .scaleXY(
                  begin: 0.5,
                  end: 1.0,
                  delay: (i * 200).ms,
                  duration: 400.ms,
                  curve: Curves.easeInOut,
                )
                .then()
                .scaleXY(begin: 1.0, end: 0.5, duration: 400.ms);
          }),
        ),
      ),
    );
  }
}

// ─── Suggestion row ───────────────────────────────────────────────────────────

class _SuggestionRow extends StatelessWidget {
  final List<String> suggestions;
  final void Function(String) onTap;

  const _SuggestionRow({required this.suggestions, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: suggestions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => ActionChip(
          label: Text(suggestions[i]),
          onPressed: () => onTap(suggestions[i]),
          backgroundColor: AppColors.surfaceElevated,
          labelStyle: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: Colors.white70),
          side: BorderSide(color: AppColors.outline.withValues(alpha: 0.6)),
        ),
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final List<String> suggestions;
  final void Function(String) onSuggestion;

  const _EmptyState({
    required this.suggestions,
    required this.onSuggestion,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.biotech, size: 48, color: AppColors.accent),
          const SizedBox(height: 16),
          Text(
            'Ask MedTwin AI',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Get personalised recommendations based on your Digital Twin health profile, medications, reports and appointments.',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 32),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: suggestions.map((s) {
              return ActionChip(
                label: Text(s),
                onPressed: () => onSuggestion(s),
                backgroundColor: AppColors.surfaceElevated,
                labelStyle: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.white70),
                side: BorderSide(color: AppColors.outline.withValues(alpha: 0.6)),
              );
            }).toList(),
          ),
        ],
      )
          .animate()
          .fadeIn(duration: 400.ms),
    );
  }
}

// ─── Input bar ────────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final void Function(String) onSend;

  const _InputBar({
    required this.controller,
    required this.enabled,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.outline.withValues(alpha: 0.5))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              maxLines: 3,
              minLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: enabled ? onSend : null,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Ask MedTwin AI anything…',
                hintStyle: TextStyle(color: AppColors.muted),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          const SizedBox(width: 10),
          AnimatedOpacity(
            opacity: enabled ? 1.0 : 0.4,
            duration: const Duration(milliseconds: 200),
            child: FloatingActionButton.small(
              heroTag: 'send_fab',
              onPressed: enabled ? () => onSend(controller.text) : null,
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.ink,
              elevation: 0,
              child: const Icon(Icons.send_rounded, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}
