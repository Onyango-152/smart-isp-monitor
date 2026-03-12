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
      _navigateByRole(auth.userRole);
    }
  }

  void _navigateByRole(String role) {
    final route = switch (role) {
      AppConstants.roleTechnician ||
      AppConstants.roleAdmin      => AppConstants.technicianHomeRoute,
      AppConstants.roleManager    => AppConstants.managerHomeRoute,
      _                           => AppConstants.customerHomeRoute,
    };
    Navigator.of(context).pushReplacementNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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

              // ── Role picker ───────────────────────────────────────────────
              Text(
                'I am a…',
                style: TextStyle(
                  fontSize:   14,
                  fontWeight: FontWeight.w600,
                  color:      cs.onSurface,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _RoleTile(
                    label:    'Customer',
                    icon:     Icons.person_outline,
                    value:    AppConstants.roleCustomer,
                    selected: _selectedRole == AppConstants.roleCustomer,
                    isDark:   isDark,
                    onTap:    () => setState(
                        () => _selectedRole = AppConstants.roleCustomer),
                  ),
                  const SizedBox(width: 8),
                  _RoleTile(
                    label:    'Technician',
                    icon:     Icons.build_outlined,
                    value:    AppConstants.roleTechnician,
                    selected: _selectedRole == AppConstants.roleTechnician,
                    isDark:   isDark,
                    onTap:    () => setState(
                        () => _selectedRole = AppConstants.roleTechnician),
                  ),
                  const SizedBox(width: 8),
                  _RoleTile(
                    label:    'Manager',
                    icon:     Icons.business_center_outlined,
                    value:    AppConstants.roleManager,
                    selected: _selectedRole == AppConstants.roleManager,
                    isDark:   isDark,
                    onTap:    () => setState(
                        () => _selectedRole = AppConstants.roleManager),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ── Form ──────────────────────────────────────────────────────
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // First name + Last name
                    Row(
                      children: [
                        Expanded(
                          child: _FormField(
                            label:      'First Name',
                            controller: _firstNameCtrl,
                            hint:       'First name',
                            icon:       Icons.badge_outlined,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _FormField(
                            label:      'Last Name',
                            controller: _lastNameCtrl,
                            hint:       'Last name',
                            icon:       Icons.badge_outlined,
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

// ── Role selection tile ────────────────────────────────────────────────────────
class _RoleTile extends StatelessWidget {
  final String  label;
  final IconData icon;
  final String  value;
  final bool    selected;
  final bool    isDark;
  final VoidCallback onTap;

  const _RoleTile({
    required this.label,
    required this.icon,
    required this.value,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg     = selected
        ? (isDark ? AppColors.primaryDarkSurface : AppColors.primarySurface)
        : Theme.of(context).colorScheme.surface;
    final Color border = selected ? AppColors.primary : Colors.transparent;
    final Color fg     = selected
        ? AppColors.primary
        : Theme.of(context).colorScheme.onSurface.withOpacity(0.6);

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding:  const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color:        bg,
            borderRadius: BorderRadius.circular(12),
            border:       Border.all(color: border, width: 1.8),
          ),
          child: Column(
            children: [
              Icon(icon, color: fg, size: 26),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize:   12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color:      fg,
                ),
              ),
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
