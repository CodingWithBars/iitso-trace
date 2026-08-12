import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared_widgets.dart';
import '../../services/student_service.dart';
import '../../services/auth_service.dart';
import '../../services/student_session_service.dart';

class WebStudentLoginScreen extends ConsumerStatefulWidget {
  const WebStudentLoginScreen({super.key});

  @override
  ConsumerState<WebStudentLoginScreen> createState() =>
      _WebStudentLoginScreenState();
}

class _WebStudentLoginScreenState extends ConsumerState<WebStudentLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _pinController = TextEditingController();

  bool _isLoading = false;
  bool _isAdmin = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _idController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      if (_isAdmin) {
        final authService = ref.read(authServiceProvider);
        final error = await authService.signIn(
          _emailController.text.trim(),
          _passwordController.text,
        );
        if (!mounted) return;
        if (error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error), backgroundColor: TraceColors.error),
          );
        } else {
          context.go('/admin/dashboard');
        }
      } else {
        final result = await StudentService.studentLogin(
          _idController.text.trim(),
          _emailController.text.trim(),
          _pinController.text.trim(),
        );

        if (!mounted) return;

        switch (result.status) {
          case LoginStatus.success:
            await ref
                .read(studentSessionProvider.notifier)
                .login(result.student!.studentId);
            if (!mounted) return;
            context.push('/student/id/${result.student!.studentId}');

          case LoginStatus.needsPinSetup:
            if (!mounted) return;
            _showPinSetupDialog(result.student!.id, result.student!.studentId);

          case LoginStatus.wrongPin:
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Incorrect PIN. Please try again.'),
                backgroundColor: TraceColors.error,
              ),
            );

          case LoginStatus.notFound:
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Invalid Student ID or Email.'),
                backgroundColor: TraceColors.error,
              ),
            );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: TraceColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showPinSetupDialog(String docId, String studentId) {
    final pinCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool obscurePin = true;
    bool obscureConfirm = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        String? error;
        return StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            title: Text(
              'Set Your PIN',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'For your security, please set a 4–6 digit PIN. You will need this PIN to log in from now on.',
                  style: GoogleFonts.inter(fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: pinCtrl,
                  keyboardType: TextInputType.number,
                  obscureText: obscurePin,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'New PIN (4–6 digits)',
                    counterText: '',
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscurePin ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: TraceColors.medGrey,
                      ),
                      onPressed: () => setLocal(() => obscurePin = !obscurePin),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmCtrl,
                  keyboardType: TextInputType.number,
                  obscureText: obscureConfirm,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'Confirm PIN',
                    counterText: '',
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: TraceColors.medGrey,
                      ),
                      onPressed: () => setLocal(() => obscureConfirm = !obscureConfirm),
                    ),
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                ],
              ],
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: TraceColors.navyBlue),
                onPressed: () async {
                  final pin = pinCtrl.text.trim();
                  final confirm = confirmCtrl.text.trim();
                  if (pin.length < 4) {
                    setLocal(() => error = 'PIN must be at least 4 digits.');
                    return;
                  }
                  if (pin != confirm) {
                    setLocal(() => error = 'PINs do not match.');
                    return;
                  }
                  await StudentService.setStudentPin(docId, pin);
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('PIN set successfully! Logging in...'), backgroundColor: TraceColors.success),
                    );
                    await ref.read(studentSessionProvider.notifier).login(studentId);
                    if (mounted) context.push('/student/id/$studentId');
                  }
                },
                child: Text('Save PIN', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TraceColors.offWhite,
      appBar: TraceAppBar(
        title: 'Login',
        actions: [
          TextButton.icon(
            onPressed: () => context.go('/'),
            icon: const Icon(
              Icons.home_outlined,
              color: TraceColors.gold,
              size: 18,
            ),
            label: Text(
              'Home',
              style: GoogleFonts.inter(color: TraceColors.gold, fontSize: 13),
            ),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: TraceCard(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: TraceColors.navyBlue.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isAdmin ? Icons.admin_panel_settings : Icons.person,
                        size: 48,
                        color: TraceColors.navyBlue,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _isAdmin ? 'Admin Portal' : 'View My ID',
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: TraceColors.navyBlue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isAdmin
                          ? 'Sign in to access management dashboard'
                          : 'Enter your details to view your Digital ID',
                      style: GoogleFonts.inter(color: TraceColors.medGrey),
                    ),
                    const SizedBox(height: 32),

                    // Tab switch
                    Container(
                      decoration: BoxDecoration(
                        color: TraceColors.lightGrey.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() {
                                _isAdmin = false;
                                _formKey.currentState?.reset();
                              }),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: !_isAdmin
                                      ? TraceColors.navyBlue
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    'Student',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w700,
                                      color: !_isAdmin
                                          ? Colors.white
                                          : TraceColors.navyBlue,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() {
                                _isAdmin = true;
                                _formKey.currentState?.reset();
                              }),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: _isAdmin
                                      ? TraceColors.navyBlue
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    'Admin',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w700,
                                      color: _isAdmin
                                          ? Colors.white
                                          : TraceColors.navyBlue,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    if (!_isAdmin) ...[
                      TextFormField(
                        controller: _idController,
                        decoration: const InputDecoration(
                          labelText: 'Student ID',
                          prefixIcon: Icon(Icons.badge_outlined),
                          hintText: 'e.g. 2024-00001',
                        ),
                        validator: (v) => v == null || v.isEmpty
                            ? 'Student ID is required'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email Address',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Email is required';
                          }
                          if (!v.contains('@')) return 'Enter a valid email';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _pinController,
                        obscureText: _obscurePassword,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          labelText: 'PIN (Leave blank if old account)',
                          hintText: '4-6 digit PIN',
                          prefixIcon: const Icon(Icons.password_outlined),
                          counterText: '',
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: TraceColors.medGrey,
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                        ),
                        validator: (v) {
                          if (v != null && v.isNotEmpty && v.length < 4) {
                            return 'PIN must be at least 4 digits';
                          }
                          return null;
                        },
                      ),
                    ] else ...[
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Admin Email',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Email is required';
                          }
                          if (!v.contains('@')) return 'Enter a valid email';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: TraceColors.medGrey,
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                        ),
                        validator: (v) => v == null || v.isEmpty
                            ? 'Password is required'
                            : null,
                        onFieldSubmitted: (_) => _login(),
                      ),
                    ],

                    const SizedBox(height: 32),
                    GoldButton(
                      label: _isAdmin ? 'Sign In' : 'View ID',
                      icon: Icons.login,
                      isLoading: _isLoading,
                      fullWidth: true,
                      onPressed: _login,
                    ),

                    if (!_isAdmin) ...[
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => context.go('/register'),
                        child: Text(
                          "Don't have an account yet? Register here",
                          style: GoogleFonts.inter(
                            color: TraceColors.navyBlue,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
