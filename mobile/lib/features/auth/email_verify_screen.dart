import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import 'auth_provider.dart';

class EmailVerifyScreen extends StatefulWidget {
  const EmailVerifyScreen({super.key});

  @override
  State<EmailVerifyScreen> createState() => _EmailVerifyScreenState();
}

class _EmailVerifyScreenState extends State<EmailVerifyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();

  Timer? _timer;
  int _cooldown = 0;

  @override
  void dispose() {
    _timer?.cancel();
    _emailCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final arg = ModalRoute.of(context)?.settings.arguments;
    if (arg is String && arg.isNotEmpty && _emailCtrl.text.isEmpty) {
      _emailCtrl.text = arg;
    }
  }

  Future<void> _handleVerify() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final ok = await auth.verifyEmail(
      email: _emailCtrl.text.trim(),
      otp: _otpCtrl.text.trim(),
    );

    if (!mounted) return;
    if (ok) {
      AppUtils.showSnackbar(
        context,
        'Email verified. You can sign in now.',
      );
      Navigator.of(context)
          .pushReplacementNamed(AppConstants.loginRoute);
    }
  }

  Future<void> _handleResend() async {
    FocusScope.of(context).unfocus();
    if (_emailCtrl.text.trim().isEmpty) {
      AppUtils.showSnackbar(
        context,
        'Enter your email to resend the code.',
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final ok = await auth.resendOtp(email: _emailCtrl.text.trim());

    if (!mounted) return;
    if (ok) {
      _startCooldown(60);
      AppUtils.showSnackbar(
        context,
        'Verification code resent.',
      );
    }
  }

  void _startCooldown(int seconds) {
    _timer?.cancel();
    setState(() => _cooldown = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_cooldown <= 1) {
        timer.cancel();
        setState(() => _cooldown = 0);
        return;
      }
      setState(() => _cooldown -= 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        title: const Text('Verify Email'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Check your inbox', style: AppTextStyles.heading1),
              const SizedBox(height: 6),
              Text(
                'Enter the 6-digit code we sent to your email address.',
                style: AppTextStyles.bodySmall,
              ),
              const SizedBox(height: 24),

              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surfaceOf(context),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: AppShadows.card,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Email', style: AppTextStyles.labelBold),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          hintText: 'you@example.com',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Email is required';
                          }
                          if (!v.contains('@') || !v.contains('.')) {
                            return 'Enter a valid email address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      Text('Verification code', style: AppTextStyles.labelBold),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _otpCtrl,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        decoration: const InputDecoration(
                          hintText: '6-digit code',
                          prefixIcon: Icon(Icons.lock_outline),
                          counterText: '',
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'OTP is required';
                          }
                          if (v.trim().length != 6) {
                            return 'Enter the 6-digit code';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      Consumer<AuthProvider>(
                        builder: (context, auth, _) => ElevatedButton(
                          onPressed: auth.isLoading ? null : _handleVerify,
                          child: auth.isLoading
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Verify Email'),
                        ),
                      ),

                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Text(
                            'Did not receive the code?',
                            style: TextStyle(
                              color: cs.onSurface.withOpacity(0.6),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 6),
                          TextButton(
                            onPressed: _cooldown > 0 ? null : _handleResend,
                            child: Text(
                              _cooldown > 0
                                  ? 'Resend in $_cooldown s'
                                  : 'Resend',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18),

              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context)
                      .pushReplacementNamed(AppConstants.loginRoute),
                  child: const Text('Back to Sign In'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
