import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/auth_field.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey    = GlobalKey<FormState>();
  final _nameCtrl   = TextEditingController();
  final _emailCtrl  = TextEditingController();
  final _passCtrl   = TextEditingController();
  final _phoneCtrl  = TextEditingController();
  final _authService = EmailPasswordAuthService();

  String _role    = 'patient';
  bool   _loading = false;
  bool   _obscure = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await _authService.signUp(
        email:    _emailCtrl.text,
        password: _passCtrl.text,
        name:     _nameCtrl.text,
        role:     _role,
        phone:    '+91${_phoneCtrl.text.trim()}',
      );
      // Sign out so the user logs in manually after registration
      await _authService.signOut();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Account created successfully! Please sign in.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ));
        Navigator.of(context).pop();
      }
    } on Exception catch (e) {
      debugPrint('SIGNUP ERROR: $e'); // shows in Flutter debug console
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_friendlyError(e.toString())),
          backgroundColor: AppColors.danger,
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyError(String raw) {
    if (raw.contains('email-already-in-use')) {
      return 'An account with this email already exists.';
    }
    if (raw.contains('weak-password')) {
      return 'Password is too weak. Use at least 6 characters.';
    }
    if (raw.contains('invalid-email')) return 'Enter a valid email address.';
    if (raw.contains('network')) return 'Network error. Check your connection.';
    return 'Sign up failed. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Create account',
                    style: Theme.of(context).textTheme.displaySmall
                        ?.copyWith(fontWeight: FontWeight.w800))
                    .animate().fadeIn(duration: 400.ms),

                const SizedBox(height: 6),
                Text('Join Bodyclone as a doctor or patient',
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: AppColors.muted))
                    .animate().fadeIn(delay: 80.ms, duration: 400.ms),

                const SizedBox(height: 32),

                AuthField(
                  controller: _nameCtrl,
                  label: 'Full name',
                  hint: 'Dr. Smith / Jane Doe',
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ).animate().fadeIn(delay: 140.ms, duration: 400.ms),

                const SizedBox(height: 14),

                AuthField(
                  controller: _emailCtrl,
                  label: 'Email',
                  hint: 'you@gmail.com',
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (!v.contains('@')) return 'Enter a valid email';
                    return null;
                  },
                ).animate().fadeIn(delay: 200.ms, duration: 400.ms),

                const SizedBox(height: 14),

                AuthField(
                  controller: _passCtrl,
                  label: 'Password',
                  hint: 'Min 6 characters',
                  obscureText: _obscure,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_off : Icons.visibility,
                      color: Colors.white38, size: 20,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                  validator: (v) =>
                      v == null || v.length < 6 ? 'Min 6 characters' : null,
                ).animate().fadeIn(delay: 260.ms, duration: 400.ms),

                const SizedBox(height: 14),

                // Phone field with +91 prefix
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 56,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: const Center(
                        child: Text(
                          '+91',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AuthField(
                        controller: _phoneCtrl,
                        label: 'Phone number',
                        hint: '10-digit mobile number',
                        keyboardType: TextInputType.phone,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          if (!RegExp(r'^\d{10}$').hasMatch(v.trim())) return 'Enter valid 10-digit number';
                          return null;
                        },
                      ),
                    ),
                  ],
                ).animate().fadeIn(delay: 320.ms, duration: 400.ms),

                const SizedBox(height: 24),

                // ── Role selector ────────────────────────────────────────
                Text('I am a',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.65),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    )).animate().fadeIn(delay: 380.ms, duration: 400.ms),

                const SizedBox(height: 10),
                Row(
                  children: [
                    _RoleChip(
                      label: 'Patient',
                      icon: Icons.person,
                      selected: _role == 'patient',
                      onTap: () => setState(() => _role = 'patient'),
                    ),
                    const SizedBox(width: 12),
                    _RoleChip(
                      label: 'Doctor',
                      icon: Icons.medical_services,
                      selected: _role == 'doctor',
                      onTap: () => setState(() => _role = 'doctor'),
                    ),
                  ],
                ).animate().fadeIn(delay: 420.ms, duration: 400.ms),

                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _signup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.ink,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.ink))
                        : const Text('Create Account',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                ).animate().fadeIn(delay: 480.ms, duration: 400.ms),

                const SizedBox(height: 20),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: RichText(
                      text: TextSpan(
                        text: 'Already have an account? ',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.5)),
                        children: const [
                          TextSpan(
                            text: 'Sign In',
                            style: TextStyle(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ).animate().fadeIn(delay: 520.ms, duration: 400.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Role chip ─────────────────────────────────────────────────────────────────
class _RoleChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _RoleChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.accent.withOpacity(0.15)
                : AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.accent : Colors.white12,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: selected ? AppColors.accent : Colors.white38,
                  size: 28),
              const SizedBox(height: 8),
              Text(label,
                  style: TextStyle(
                    color: selected ? AppColors.accent : Colors.white54,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 14,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}
