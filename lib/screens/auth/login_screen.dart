import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/auth_field.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _authService = EmailPasswordAuthService();

  bool _loading = false;
  bool _obscurePass = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await _authService.signIn(_emailCtrl.text, _passCtrl.text);
      // AuthWrapper reacts to authStateChanges and routes automatically
    } on Exception catch (e) {
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
    if (raw.contains('user-not-found') ||
        raw.contains('wrong-password') ||
        raw.contains('invalid-credential')) {
      return 'Incorrect email or password.';
    }
    if (raw.contains('too-many-requests'))
      return 'Too many attempts. Try again later.';
    if (raw.contains('network')) return 'Network error. Check your connection.';
    return 'Sign in failed. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                Text('Welcome back',
                        style: Theme.of(context)
                            .textTheme
                            .displaySmall
                            ?.copyWith(fontWeight: FontWeight.w800))
                    .animate()
                    .fadeIn(duration: 400.ms),
                const SizedBox(height: 6),
                Text('Sign in to your Bodyclone account',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: AppColors.muted))
                    .animate()
                    .fadeIn(delay: 80.ms, duration: 400.ms),
                const SizedBox(height: 40),
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
                ).animate().fadeIn(delay: 160.ms, duration: 400.ms),
                const SizedBox(height: 16),
                AuthField(
                  controller: _passCtrl,
                  label: 'Password',
                  hint: '••••••••',
                  obscureText: _obscurePass,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePass ? Icons.visibility_off : Icons.visibility,
                      color: Colors.white38,
                      size: 20,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePass = !_obscurePass),
                  ),
                  validator: (v) =>
                      v == null || v.length < 6 ? 'Min 6 characters' : null,
                ).animate().fadeIn(delay: 220.ms, duration: 400.ms),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.ink,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.ink))
                        : const Text('Sign In',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                ).animate().fadeIn(delay: 300.ms, duration: 400.ms),
                const SizedBox(height: 24),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const SignupScreen())),
                    child: RichText(
                      text: TextSpan(
                        text: "Don't have an account? ",
                        style: TextStyle(color: Colors.white.withOpacity(0.5)),
                        children: const [
                          TextSpan(
                            text: 'Sign Up',
                            style: TextStyle(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ).animate().fadeIn(delay: 360.ms, duration: 400.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
