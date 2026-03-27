import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/app_user.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/app_card.dart';
import '../widgets/avatar_glb_view.dart';
import '../services/auth_service.dart';
import 'appointments/patient_appointments_screen.dart';
import 'auth/auth_wrapper.dart';
import 'medication_screen.dart';
import 'patient/edit_profile_screen.dart';
import 'patient/patient_qr_screen.dart';
import 'reports_screen.dart';
import 'vitals_screen.dart';
import 'avatar_creator_screen.dart';
<<<<<<< HEAD
import '../medtwin/widgets/animated_orbit_button.dart';
import '../medtwin/screens/medtwin_home_screen.dart';
=======
>>>>>>> 2ea837fd8ac6cd2eabb1da670b0294a2aee12495

class AvatarScreen extends StatefulWidget {
  const AvatarScreen({super.key});

  @override
  State<AvatarScreen> createState() => _AvatarScreenState();
}

class _AvatarScreenState extends State<AvatarScreen>
    with TickerProviderStateMixin {
  final ValueNotifier<double> _rotation = ValueNotifier(0.0);
  int _frontIndex = 0;
  int _tipIndex = 0;
  Offset? _lastPointerPos;
  bool _isPointerDown = false;

  // Snap animation
  late AnimationController _snapController;
  Animation<double>? _snapAnim;
  bool _isSnapping = false;

  // Ambient pulse for avatar glow + ring breathing
  late AnimationController _pulseController;

  // Velocity inertia
  Ticker? _inertiaTicker;
  double _velocity = 0.0;
  final List<_VelocitySample> _velocitySamples = [];

  final List<Map<String, dynamic>> _icons = [
    {
      'icon': Icons.favorite_rounded,
      'color': AppColors.accentRose,
      'label': 'Vitals'
    },
    {
      'icon': Icons.description_rounded,
      'color': AppColors.accentBlue,
      'label': 'Reports'
    },
    {
      'icon': Icons.local_hospital_rounded,
      'color': AppColors.accent,
      'label': 'Consult'
    },
    {
      'icon': Icons.medication_rounded,
      'color': AppColors.accentAmber,
      'label': 'Medication'
    },
    {
      'icon': Icons.calendar_month_rounded,
      'color': AppColors.accentViolet,
      'label': 'Appointments'
    },
  ];

  // Profile summary (loaded from Firestore on init / after edit)
  Map<String, dynamic> _profileData = {};
  AppUser? _currentUser;

  final List<String> _tips = [
    'Aim for 7–9 hours of sleep to support recovery and focus.',
    'Hydrate consistently; small sips throughout the day add up.',
    'A short walk after meals can help stabilize energy levels.',
    'Keep medications at the same time daily for better adherence.',
    'If your heart rate feels higher than usual, take a few deep breaths.',
    'Stretching for 5 minutes can reduce stiffness and improve circulation.',
    'Review your vitals weekly to notice trends early.',
    'Balanced meals with protein help steady energy and appetite.',
  ];

  @override
  void initState() {
    super.initState();
    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    ); // Removed ..repeat() to stop Android native rendering sync logs!
    _loadUserProfile();
  }

  @override
  void dispose() {
    _snapController.dispose();
    _pulseController.dispose();
    _rotation.dispose();
    _inertiaTicker?.dispose();
    super.dispose();
  }

  // ── Pointer handlers ────────────────────────────────────────────────────

  void _onPointerDown(PointerDownEvent event) {
<<<<<<< HEAD
    if (_isSnapping) return;
=======
>>>>>>> 2ea837fd8ac6cd2eabb1da670b0294a2aee12495
    _inertiaTicker?.stop();
    _isPointerDown = true;
    _lastPointerPos = event.position;
    _velocitySamples.clear();
    _velocity = 0.0;
  }

  void _onPointerMove(PointerMoveEvent event) {
<<<<<<< HEAD
    if (_isSnapping) return;
=======
>>>>>>> 2ea837fd8ac6cd2eabb1da670b0294a2aee12495
    if (!_isPointerDown || _lastPointerPos == null) return;
    final dx = event.position.dx - _lastPointerPos!.dx;
    _lastPointerPos = event.position;
    _velocitySamples.add(_VelocitySample(dx, DateTime.now()));
    if (_velocitySamples.length > 8) _velocitySamples.removeAt(0);
    _rotation.value -= dx * 0.006;
    _applyMagnet();
  }

  void _onPointerUp(PointerUpEvent event) {
<<<<<<< HEAD
    if (_isSnapping) return;
=======
>>>>>>> 2ea837fd8ac6cd2eabb1da670b0294a2aee12495
    _isPointerDown = false;
    _lastPointerPos = null;

    // Compute velocity from recent samples (px/ms, negative = rightward swipe)
    if (_velocitySamples.isNotEmpty) {
      final recent = _velocitySamples
          .where((s) => DateTime.now().difference(s.time).inMilliseconds < 120)
          .toList();
      if (recent.length >= 2) {
        final totalDx = recent.fold(0.0, (sum, s) => sum + s.dx);
        final ms =
            recent.last.time.difference(recent.first.time).inMilliseconds;
        _velocity = ms > 0 ? totalDx / ms * 16 : 0.0;
      }
    }
    _velocitySamples.clear();
    _startInertia();
  }

  // ── Inertia + snap ───────────────────────────────────────────────────────

  void _startInertia() {
    if (_velocity.abs() < 1.2) {
      _snapToFront();
      return;
    }
    _inertiaTicker?.dispose();
    DateTime? lastTick;
    _inertiaTicker = createTicker((elapsed) {
      final now = DateTime.now();
      final dt = lastTick != null
          ? now.difference(lastTick!).inMilliseconds / 16.67
          : 1.0;
      lastTick = now;

      if (_velocity.abs() < 0.5) {
        _inertiaTicker?.stop();
        _snapToFront();
        return;
      }
      _rotation.value -= _velocity * 0.006 * dt;
      _velocity *= pow(0.87, dt).toDouble();
      _applyMagnet();
    })
      ..start();
  }

  void _snapToFront() {
    final step = (2 * pi) / _icons.length;
    double minDelta = double.infinity;
    int closest = 0;
    double closestDelta = 0.0;

    for (int i = 0; i < _icons.length; i++) {
      final angle = _rotation.value + step * i;
      final delta = _wrapToPi(angle - pi / 2);
      final absDelta = delta.abs();
      if (absDelta < minDelta) {
        minDelta = absDelta;
        closest = i;
        closestDelta = delta;
      }
    }

    final target = _rotation.value - closestDelta;
    _frontIndex = closest;
    _isSnapping = true;

    _snapAnim = Tween<double>(begin: _rotation.value, end: target).animate(
      CurvedAnimation(parent: _snapController, curve: Curves.easeOutCubic),
    )
      ..addListener(() => _rotation.value = _snapAnim!.value)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _isSnapping = false;
      });

    _snapController
      ..reset()
      ..forward();
  }

  void _applyMagnet() {
    final step = (2 * pi) / _icons.length;
    double minDelta = double.infinity;
    double closestDelta = 0.0;
    int closest = 0;

    for (int i = 0; i < _icons.length; i++) {
      final angle = _rotation.value + step * i;
      final delta = _wrapToPi(angle - pi / 2);
      final absDelta = delta.abs();
      if (absDelta < minDelta) {
        minDelta = absDelta;
        closestDelta = delta;
        closest = i;
      }
    }

    _frontIndex = closest;
    final threshold = step * 0.18;
    if (minDelta < threshold) {
      _rotation.value -= closestDelta * 0.22;
    }
  }

  double _wrapToPi(double angle) {
    const twoPi = 2 * pi;
    angle = (angle + pi) % twoPi;
    if (angle < 0) angle += twoPi;
    return angle - pi;
  }

  int _findFrontIndex(double currentRotation) {
    final step = (2 * pi) / _icons.length;
    double minDelta = double.infinity;
    int closest = 0;

    for (int i = 0; i < _icons.length; i++) {
      final angle = currentRotation + step * i;
      final delta = _wrapToPi(angle - pi / 2).abs();
      if (delta < minDelta) {
        minDelta = delta;
        closest = i;
      }
    }
    return closest;
  }

  // ── Profile loading ──────────────────────────────────────────────────────

  Future<void> _loadUserProfile() async {
    final user = await EmailPasswordAuthService.currentAppUser();
    if (!mounted || user == null) return;
    _currentUser = user;
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.id)
        .get();
    if (mounted) setState(() => _profileData = snap.data() ?? {});
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final base = min(size.width, size.height);
    final avatarSize = base * 0.50;
    final orbitRadius = avatarSize * 0.84;

    return AppScaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Digital Twin',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    letterSpacing: 0.4,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            Text(
              'Your biometric orbit',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.muted),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Colors.white70),
            tooltip: 'Edit Profile',
            onPressed: () async {
              final user =
                  _currentUser ?? await EmailPasswordAuthService.currentAppUser();
              if (user == null || !context.mounted) return;
              await Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => EditProfileScreen(user: user)),
              );
              if (mounted) _loadUserProfile();
            },
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_rounded, color: Colors.white70),
            tooltip: 'My QR Code',
            onPressed: () async {
              final user = await EmailPasswordAuthService.currentAppUser();
              if (user != null && context.mounted) {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => PatientQrScreen(patient: user),
                ));
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white54),
            tooltip: 'Sign out',
            onPressed: () async {
              await EmailPasswordAuthService().signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const AuthWrapper()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: Listener(
        behavior: HitTestBehavior.translucent,
<<<<<<< HEAD
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerUp,
        onPointerCancel: (_) {
          if (_isSnapping) return;
          _isPointerDown = false;
          _lastPointerPos = null;
        },
=======
        onPointerDown: _isSnapping ? null : _onPointerDown,
        onPointerMove: _isSnapping ? null : _onPointerMove,
        onPointerUp: _isSnapping ? null : _onPointerUp,
        onPointerCancel: _isSnapping
            ? null
            : (_) {
                _isPointerDown = false;
                _lastPointerPos = null;
              },
>>>>>>> 2ea837fd8ac6cd2eabb1da670b0294a2aee12495
        child: LayoutBuilder(
          builder: (context, constraints) {
            final topPad = MediaQuery.of(context).padding.top;
            final bottomPad = MediaQuery.of(context).padding.bottom;
            const tipBarHeight = 84.0;
            final headerHeight = _profileData.isNotEmpty ? 152.0 : 92.0;
            final availableHeight = constraints.maxHeight -
                topPad -
                bottomPad -
                tipBarHeight -
                headerHeight -
                12;
            final availableWidth = constraints.maxWidth;
            final center = Offset(
              availableWidth / 2,
              topPad + headerHeight + availableHeight / 2 + 4,
            );
            final scaledAvatar = min(
              avatarSize,
              min(availableHeight * 0.64, availableWidth * 0.74),
            );
            final scaledOrbit = min(orbitRadius, scaledAvatar * 0.76);

            return Stack(
              children: [
                // ── Header card ──────────────────────────────────────────
                Positioned(
                  left: 20,
                  right: 20,
                  top: topPad + 8,
                  child: _headerCard(context),
                )
                    .animate()
                    .fadeIn(duration: 500.ms)
                    .slideY(begin: -0.1, end: 0),

                // ── Orbit rings + pulse glow ─────────────────────────────
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, _) {
                    final p = _pulseController.value;
                    return Stack(
                      children: [
                        // Ambient glow behind avatar
                        _glowDisc(center, scaledAvatar * 0.62, AppColors.accent,
                            0.06 + p * 0.10, 48 + p * 24),
                        _glowDisc(center, scaledAvatar * 0.52,
                            AppColors.accentBlue, 0.08 + p * 0.07, 36),
                        // Orbit rings
                        _ring(center, scaledOrbit * 0.92, AppColors.accentBlue,
                            0.14 + p * 0.12),
                        _ring(center, scaledOrbit * 0.68, AppColors.accent,
                            0.11 + p * 0.09),
                        _ring(center, scaledOrbit * 1.06,
                            AppColors.accentViolet, 0.09 + p * 0.07),
                      ],
                    );
                  },
                ),

                // ── Behind-avatar orbit items ────────────────────────────
                Positioned.fill(
                  child: ValueListenableBuilder<double>(
                    valueListenable: _rotation,
                    builder: (context, rot, _) {
                      return Stack(
                        children: _buildOrbit(
                          center, scaledOrbit, _findFrontIndex(rot), rot,
                          behind: true, pointerEnabled: false,
                        ),
                      );
                    },
                  ),
                ),

                // ── Avatar Background (Animated) ─────────────────────────
                Positioned(
                  left: center.dx - scaledAvatar / 2,
                  top: center.dy - scaledAvatar / 2,
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        final p = _pulseController.value;
                        return Container(
                          width: scaledAvatar,
                          height: scaledAvatar,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF0C1323),
                            border: Border.all(
                              color: AppColors.accent
                                  .withValues(alpha: 0.18 + p * 0.22),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.accent
                                    .withValues(alpha: 0.10 + p * 0.13),
                                blurRadius: 30 + p * 18,
                                spreadRadius: 2 + p * 5,
                                offset: const Offset(0, -4),
                              ),
                              BoxShadow(
                                color: AppColors.accentBlue
                                    .withValues(alpha: 0.22 + p * 0.12),
                                blurRadius: 36 + p * 14,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ).animate().fadeIn(duration: 700.ms, delay: 200.ms).scale(
                      begin: const Offset(0.90, 0.90),
                      end: const Offset(1.0, 1.0),
                      curve: Curves.easeOutBack,
                      duration: 700.ms,
                      delay: 200.ms,
                    ),

                // ── Avatar PlatformView (Static Sibling) ─────────────────
                Positioned(
                  left: center.dx - scaledAvatar / 2,
                  top: center.dy - scaledAvatar / 2,
                  child: IgnorePointer(
                    child: SizedBox(
                      width: scaledAvatar,
                      height: scaledAvatar,
                      child: AvatarGlbView(
                        avatarUrl: _profileData['avatarUrl'] as String?,
                      ),
                    ),
                  ),
                ),

                // ── Front-avatar orbit items (visual) ────────────────────
                Positioned.fill(
                  child: ValueListenableBuilder<double>(
                    valueListenable: _rotation,
                    builder: (context, rot, _) {
                      return Stack(
                        children: _buildOrbit(
                          center, scaledOrbit, _findFrontIndex(rot), rot,
                          behind: false, pointerEnabled: false,
                        ),
                      );
                    },
                  ),
                ),

<<<<<<< HEAD
                // ── MedTwin AI orbit button ──────────────────────────────
                Positioned(
                  right: 20,
                  bottom: bottomPad + tipBarHeight + 28,
                  child: AnimatedOrbitButton(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const MedTwinHomeScreen(),
                      ),
                    ),
                  ),
                ).animate().fadeIn(duration: 500.ms, delay: 500.ms),

=======
>>>>>>> 2ea837fd8ac6cd2eabb1da670b0294a2aee12495
                // ── Tip bar ──────────────────────────────────────────────
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: bottomPad + 16,
                  child: _tipBar(context, tipBarHeight),
                )
                    .animate()
                    .fadeIn(duration: 500.ms, delay: 350.ms)
                    .slideY(begin: 0.12, end: 0),

                // ── Front orbit items (pointer-enabled layer) ────────────
                Positioned.fill(
                  child: ValueListenableBuilder<double>(
                    valueListenable: _rotation,
                    builder: (context, rot, _) {
                      return Stack(
                        children: _buildOrbit(
                          center, scaledOrbit, _findFrontIndex(rot), rot,
                          behind: false, pointerEnabled: true,
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── Sub-builders ─────────────────────────────────────────────────────────

  Widget _headerCard(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      glow: true,
      glowColor: AppColors.accentBlue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.accentBlue.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.visibility_rounded,
                    color: AppColors.accentBlue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Live twin',
                        style: Theme.of(context).textTheme.titleSmall),
                    Text(
                      'Orbit to explore systems',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.face_retouching_natural_rounded, color: AppColors.accentBlue),
                tooltip: 'Customize Avatar',
                onPressed: () async {
                  await Navigator.push(
                    context, 
                    MaterialPageRoute(builder: (_) => const AvatarCreatorScreen()),
                  );
                  if (context.mounted) _loadUserProfile();
                },
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.4)),
                ),
                child: Text(
                  'Active',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          if (_profileData.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(color: Colors.white10, height: 1),
            const SizedBox(height: 10),
            _buildProfileChips(),
          ],
        ],
      ),
    );
  }

  Widget _buildProfileChips() {
    final basic   = _profileData['basicInfo']   as Map<String, dynamic>? ?? {};
    final conds   = _profileData['conditions']  as Map<String, dynamic>? ?? {};
    final allerg  = _profileData['allergies']   as Map<String, dynamic>? ?? {};
    final medsRaw = _profileData['medications'] as List<dynamic>? ?? [];

    final bg = basic['bloodGroup'] as String? ?? '';
    final condCount = [
          conds['diabetes'],
          conds['hypertension'],
          conds['heartDisease'],
          conds['asthma'],
          conds['thyroid'],
        ].where((v) => v == true).length +
        ((conds['other'] as String? ?? '').trim().isNotEmpty ? 1 : 0);
    final hasAllergy = [
      allerg['drug']  as String? ?? '',
      allerg['food']  as String? ?? '',
      allerg['other'] as String? ?? '',
    ].any((s) => s.trim().isNotEmpty);
    final medCount = medsRaw.length;

    return Wrap(spacing: 7, runSpacing: 5, children: [
      if (bg.isNotEmpty)
        _MiniChip(bg, AppColors.accentRose, Icons.water_drop_outlined),
      if (condCount > 0)
        _MiniChip(
            '$condCount condition${condCount > 1 ? 's' : ''}',
            AppColors.accentBlue,
            Icons.medical_information_outlined),
      if (hasAllergy)
<<<<<<< HEAD
        const _MiniChip('Allergies ⚠️', AppColors.accentAmber, null),
=======
        _MiniChip('Allergies ⚠️', AppColors.accentAmber, null),
>>>>>>> 2ea837fd8ac6cd2eabb1da670b0294a2aee12495
      if (medCount > 0)
        _MiniChip(
            '$medCount med${medCount > 1 ? 's' : ''}',
            AppColors.accentViolet,
            Icons.medication_outlined),
    ]);
  }

  Widget _tipBar(BuildContext context, double height) {
    return GestureDetector(
      onTap: () => setState(() => _tipIndex = (_tipIndex + 1) % _tips.length),
      child: SizedBox(
        height: height,
        child: AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          glow: true,
          glowColor: AppColors.accentBlue,
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.health_and_safety_rounded,
                    color: AppColors.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 320),
                  transitionBuilder: (child, animation) {
                    final slide = Tween<Offset>(
                      begin: const Offset(0, 0.4),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                        parent: animation, curve: Curves.easeOutCubic));
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(position: slide, child: child),
                    );
                  },
                  child: Text(
                    _tips[_tipIndex],
                    key: ValueKey(_tipIndex),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.82),
                          height: 1.4,
                        ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.refresh_rounded,
                  color: Colors.white54, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  /// A faint radial glow disc centred on [center].
  Widget _glowDisc(
      Offset center, double radius, Color color, double opacity, double blur) {
    return Positioned(
      left: center.dx - radius,
      top: center.dy - radius,
      child: IgnorePointer(
        child: Container(
          width: radius * 2,
          height: radius * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: opacity),
                blurRadius: blur,
                spreadRadius: blur * 0.3,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// A thin circle ring.
  Widget _ring(Offset center, double radius, Color color, double opacity) {
    return Positioned(
      left: center.dx - radius,
      top: center.dy - radius,
      child: IgnorePointer(
        child: Container(
          width: radius * 2,
          height: radius * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border:
                Border.all(color: color.withValues(alpha: opacity), width: 1.0),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildOrbit(
    Offset center,
    double radius,
    int frontIndex,
    double currentRotation, {
    required bool behind,
    required bool pointerEnabled,
  }) {
    final widgets = <Widget>[];
    final step = (2 * pi) / _icons.length;
    const itemContainerWidth = 100.0;
    const iconSize = 52.0;

    for (int i = 0; i < _icons.length; i++) {
      final angle = currentRotation + step * i;
      final depth = sin(angle); // –1 (top/back) → +1 (bottom/front)

      if (behind && depth > 0) continue;
      if (!behind && depth <= 0) continue;

      final x = center.dx + radius * cos(angle);
      final y = center.dy + radius * 0.44 * sin(angle);

      final t = (depth + 1) / 2; // 0 → 1 (back → front)
      final isFront = i == frontIndex && !behind;
      final color = _icons[i]['color'] as Color;

      widgets.add(
        Positioned(
          left: x - itemContainerWidth / 2,
          top: y - iconSize / 2,
          child: SizedBox(
            width: itemContainerWidth,
            child: Column(
              children: [
                Transform.scale(
                  scale: 0.72 + 0.28 * t,
                  child: Opacity(
                    opacity: 0.28 + 0.72 * t,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: pointerEnabled
                          ? () => _handleOrbitTap(_icons[i]['label'] as String)
                          : null,
                      child: Container(
                        width: iconSize,
                        height: iconSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              color.withValues(alpha: 0.22),
                              color.withValues(alpha: 0.08),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(
                            color: isFront
                                ? color.withValues(alpha: 0.7)
                                : Colors.white.withValues(alpha: 0.10),
                            width: isFront ? 1.5 : 1.0,
                          ),
                          boxShadow: isFront
                              ? [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.5),
                                    blurRadius: 18,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : (depth > 0
                                  ? [
                                      BoxShadow(
                                        color: color.withValues(alpha: 0.25),
                                        blurRadius: 8,
                                      ),
                                    ]
                                  : null),
                        ),
                        child: Icon(
                          _icons[i]['icon'] as IconData,
                          color: color,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ),
                if (isFront) ...[
                  const SizedBox(height: 8),
                  Text(
                    _icons[i]['label'] as String,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                      shadows: [
                        Shadow(
                          color: color.withValues(alpha: 0.6),
                          blurRadius: 8,
                        ),
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
    return widgets;
  }

  void _handleOrbitTap(String label) {
    switch (label) {
      case 'Vitals':
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const VitalsScreen()));
      case 'Reports':
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const ReportsScreen()));
      case 'Medication':
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const MedicationScreen()));
      case 'Appointments':
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const PatientAppointmentsScreen()));
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Consult coming soon.')),
        );
    }
  }
}

class _VelocitySample {
  final double dx;
  final DateTime time;
  const _VelocitySample(this.dx, this.time);
}

// ── Profile summary chip ──────────────────────────────────────────────────────

class _MiniChip extends StatelessWidget {
  final String   label;
  final Color    color;
  final IconData? icon;
  const _MiniChip(this.label, this.color, this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, color: color, size: 10),
          const SizedBox(width: 4),
        ],
        Text(label,
            style: TextStyle(
                color: color, fontSize: 10, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}
