import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import 'auth_provider.dart';

/// RegisterScreen lets a new user create an account.
///
/// Flow:
///   1.  User fills in the form and picks a role.
///   2.  On submit, [AuthProvider.register] is called.
///   3.  On success the user is taken straight to their role dashboard —
///       no separate login step needed because the API returns tokens on
///       registration.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey          = GlobalKey<FormState>();
  final _usernameCtrl     = TextEditingController();
  final _emailCtrl        = TextEditingController();
  final _firstNameCtrl    = TextEditingController();
  final _lastNameCtrl     = TextEditingController();
  final _passwordCtrl     = TextEditingController();
  final _confirmCtrl      = TextEditingController();

  String _selectedRole     = AppConstants.roleCustomer;
  bool   _obscurePassword  = true;
  bool   _obscureConfirm   = true;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    final auth    = context.read<AuthProvider>();
    final success = await auth.register(
      username:        _usernameCtrl.text.trim(),
      email:           _emailCtrl.text.trim(),
      password:        _passwordCtrl.text,
      passwordConfirm: _confirmCtrl.text,
      role:            _selectedRole,
      firstName:       _firstNameCtrl.text.trim(),
      lastName:        _lastNameCtrl.text.trim(),
    );

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pushReplacementNamed(
        AppConstants.verifyEmailRoute,
        arguments: _emailCtrl.text.trim(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),

              // ── Header ────────────────────────────────────────────────────
              Center(
                child: Column(
                  children: [
                    Container(
                      width:      72,
                      height:     72,
                      decoration: BoxDecoration(
                        color:        AppColors.primary,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        Icons.network_check,
                        size:  40,
                        color: AppColors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Create Account',
                      style: TextStyle(
                        fontSize:   24,
                        fontWeight: FontWeight.bold,
                        color:      cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Join the ISP Monitor platform',
                      style: TextStyle(
                        fontSize: 14,
                        color:    cs.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // ── Error banner ──────────────────────────────────────────────
              Consumer<AuthProvider>(
                builder: (context, auth, _) {
                  if (auth.errorMessage == null) return const SizedBox.shrink();
                  return Container(
                    width:   double.infinity,
                    margin:  const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color:        AppColors.offlineLight,
                      borderRadius: BorderRadius.circular(10),
                      border:       Border.all(
                          color: AppColors.offline.withOpacity(0.4)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline,
                            color: AppColors.offline, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            auth.errorMessage!,
                            style: const TextStyle(
                              color: AppColors.offline, fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              // ── Form ──────────────────────────────────────────────────────
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // Role dropdown
                    Text(
                      'I am a…',
                      style: TextStyle(
                        fontSize:   14,
                        fontWeight: FontWeight.w600,
                        color:      cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: _selectedRole,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: AppConstants.roleCustomer,
                          child: Text('Customer'),
                        ),
                        DropdownMenuItem(
                          value: AppConstants.roleTechnician,
                          child: Text('Technician'),
                        ),
                        DropdownMenuItem(
                          value: AppConstants.roleManager,
                          child: Text('Manager'),
                        ),
                      ],
                      onChanged: (value) => setState(
                          () => _selectedRole = value ?? AppConstants.roleCustomer),
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Please select a role'
                          : null,
                    ),

                    const SizedBox(height: 16),

                    // First name + Last name
                    Row(
                      children: [
                        Expanded(
                          child: _FormField(
                            label:      'First Name',
                            controller: _firstNameCtrl,
                            hint:       'First name',
                            icon:       Icons.badge_outlined,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'First name is required';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _FormField(
                            label:      'Last Name',
                            controller: _lastNameCtrl,
                            hint:       'Last name',
                            icon:       Icons.badge_outlined,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Last name is required';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Username
                    _FormField(
                      label:      'Username',
                      controller: _usernameCtrl,
                      hint:       'Choose a unique username',
                      icon:       Icons.alternate_email,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Username is required';
                        }
                        if (v.trim().length < 3) {
                          return 'At least 3 characters';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // Email
                    _FormField(
                      label:       'Email Address',
                      controller:  _emailCtrl,
                      hint:        'your@email.com',
                      icon:        Icons.email_outlined,
                      inputType:   TextInputType.emailAddress,
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

                    // Password
                    _PasswordField(
                      label:      'Password',
                      controller: _passwordCtrl,
                      hint:       'Minimum 8 characters',
                      obscure:    _obscurePassword,
                      onToggle:   () => setState(
                          () => _obscurePassword = !_obscurePassword),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Password is required';
                        if (v.length < 8) return 'At least 8 characters';
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // Confirm password
                    _PasswordField(
                      label:      'Confirm Password',
                      controller: _confirmCtrl,
                      hint:       'Re-enter your password',
                      obscure:    _obscureConfirm,
                      onToggle:   () => setState(
                          () => _obscureConfirm = !_obscureConfirm),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Please confirm your password';
                        }
                        if (v != _passwordCtrl.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 28),

                    // Register button
                    Consumer<AuthProvider>(
                      builder: (context, auth, _) => ElevatedButton(
                        onPressed: auth.isLoading ? null : _handleRegister,
                        child: auth.isLoading
                            ? const SizedBox(
                                height: 22,
                                width:  22,
                                child:  CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color:       Colors.white,
                                ),
                              )
                            : const Text('Create Account'),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Already have an account ───────────────────────────────────
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Already have an account? ',
                      style: TextStyle(
                        color: cs.onSurface.withOpacity(0.6),
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          Navigator.of(context).pushReplacementNamed(
                            AppConstants.loginRoute,
                          ),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Sign In'),
                    ),
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

// ── Reusable text form field ──────────────────────────────────────────────────
class _FormField extends StatelessWidget {
  final String             label;
  final TextEditingController controller;
  final String             hint;
  final IconData           icon;
  final TextInputType      inputType;
  final String? Function(String?)? validator;

  const _FormField({
    required this.label,
    required this.controller,
    required this.hint,
    required this.icon,
    this.inputType = TextInputType.text,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize:   13,
            fontWeight: FontWeight.w600,
            color:      cs.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller:   controller,
          keyboardType: inputType,
          decoration:   InputDecoration(
            hintText:   hint,
            prefixIcon: Icon(icon),
          ),
          validator: validator,
        ),
      ],
    );
  }
}

// ── Password field with show/hide toggle ──────────────────────────────────────
class _PasswordField extends StatelessWidget {
  final String             label;
  final TextEditingController controller;
  final String             hint;
  final bool               obscure;
  final VoidCallback       onToggle;
  final String? Function(String?)? validator;

  const _PasswordField({
    required this.label,
    required this.controller,
    required this.hint,
    required this.obscure,
    required this.onToggle,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize:   13,
            fontWeight: FontWeight.w600,
            color:      cs.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller:  controller,
          obscureText: obscure,
          decoration:  InputDecoration(
            hintText:   hint,
            prefixIcon: const Icon(Icons.lock_outlined),
            suffixIcon: IconButton(
              icon: Icon(
                obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
              onPressed: onToggle,
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }
}
