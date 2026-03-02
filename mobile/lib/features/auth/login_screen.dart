import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import 'auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {

  // _formKey identifies the form for validation purposes.
  // Calling _formKey.currentState!.validate() triggers all
  // TextFormField validators at once.
  final _formKey      = GlobalKey<FormState>();
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool  _obscurePassword = true;

  @override
  void dispose() {
    // Always dispose controllers to prevent memory leaks
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    // First validate all form fields. If any are invalid, stop here.
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final success = await auth.login(
      _emailCtrl.text.trim(),
      _passwordCtrl.text,
    );

    if (!mounted) return;

    if (success) {
      // Navigate to the correct home screen based on role
      switch (auth.userRole) {
        case AppConstants.roleTechnician:
        case AppConstants.roleAdmin:
          Navigator.of(context)
              .pushReplacementNamed(AppConstants.technicianHomeRoute);
          break;
        case AppConstants.roleManager:
          Navigator.of(context)
              .pushReplacementNamed(AppConstants.managerHomeRoute);
          break;
        case AppConstants.roleCustomer:
          Navigator.of(context)
              .pushReplacementNamed(AppConstants.customerHomeRoute);
          break;
      }
    }
    // If login failed the AuthProvider already set errorMessage
    // which is displayed in the error container below.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          // SingleChildScrollView prevents overflow when the keyboard appears
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),

              // ── Header ──────────────────────────────────────────────
              Center(
                child: Column(
                  children: [
                    Container(
                      width:      80,
                      height:     80,
                      decoration: BoxDecoration(
                        color:        AppColors.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.network_check,
                        size:  44,
                        color: AppColors.white,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Welcome Back',
                      style: TextStyle(
                        fontSize:   26,
                        fontWeight: FontWeight.bold,
                        color:      AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Sign in to your ISP Monitor account',
                      style: TextStyle(
                        fontSize: 14,
                        color:    AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // ── Error Message ────────────────────────────────────────
              // Consumer rebuilds only this widget when AuthProvider changes
              Consumer<AuthProvider>(
                builder: (context, auth, _) {
                  if (auth.errorMessage == null) return const SizedBox.shrink();
                  return Container(
                    width:  double.infinity,
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color:        AppColors.offlineLight,
                      borderRadius: BorderRadius.circular(10),
                      border:       Border.all(color: AppColors.offline.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: AppColors.offline, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            auth.errorMessage!,
                            style: const TextStyle(
                              color: AppColors.offline, fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              // ── Login Form ───────────────────────────────────────────
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // Email field
                    const Text('Email Address',
                        style: TextStyle(
                          fontSize:   14,
                          fontWeight: FontWeight.w600,
                          color:      AppColors.textPrimary,
                        )),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller:   _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration:   const InputDecoration(
                        hintText:    'Enter your email',
                        prefixIcon:  Icon(Icons.email_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email address';
                        }
                        if (!value.contains('@')) {
                          return 'Please enter a valid email address';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 20),

                    // Password field
                    const Text('Password',
                        style: TextStyle(
                          fontSize:   14,
                          fontWeight: FontWeight.w600,
                          color:      AppColors.textPrimary,
                        )),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller:     _passwordCtrl,
                      obscureText:    _obscurePassword,
                      decoration:     InputDecoration(
                        hintText:   'Enter your password',
                        prefixIcon: const Icon(Icons.lock_outlined),
                        // Eye icon to show/hide password
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 12),

                    // Forgot password link
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {},
                        child: const Text('Forgot Password?'),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Login button
                    Consumer<AuthProvider>(
                      builder: (context, auth, _) {
                        return ElevatedButton(
                          onPressed: auth.isLoading ? null : _handleLogin,
                          child: auth.isLoading
                              ? const SizedBox(
                                  height: 22,
                                  width:  22,
                                  child:  CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color:       Colors.white,
                                  ),
                                )
                              : const Text('Sign In'),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // ── Quick Login Hint (development only) ──────────────────
              Container(
                padding:    const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color:        AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Test Accounts',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color:      AppColors.primary,
                          fontSize:   13,
                        )),
                    SizedBox(height: 6),
                    Text('Technician: technician@isp.co.ke / Tech1234!',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    Text('Manager:    manager@isp.co.ke / Man1234!',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    Text('Customer:   customer@isp.co.ke / Cust1234!',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}