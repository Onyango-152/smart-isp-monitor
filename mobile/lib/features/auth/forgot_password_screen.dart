import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    setState(() => _isSubmitting = false);
    AppUtils.showSnackbar(
      context,
      'If this email is registered, a reset link will be sent shortly.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        title: const Text('Forgot Password'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reset your password', style: AppTextStyles.heading1),
            const SizedBox(height: 6),
            Text(
              'Enter the email linked to your account. We will send a reset link.',
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceOf(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.dividerOf(context)),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Email Address', style: AppTextStyles.labelBold),
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
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submit,
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Send Reset Link'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
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
    );
  }
}
