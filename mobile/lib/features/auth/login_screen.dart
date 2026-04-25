import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import 'auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {

  final _formKey      = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool  _obscurePassword = true;

  late final AnimationController _animCtrl;
  late final Animation<double>   _fadeAnim;
  late final Animation<Offset>   _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim  = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
        begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().clearError();
      _animCtrl.forward();
    });

    _usernameCtrl.addListener(_clearError);
    _passwordCtrl.addListener(_clearError);
  }

  void _clearError() {
    if (context.read<AuthProvider>().errorMessage != null) {
      context.read<AuthProvider>().clearError();
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final auth    = context.read<AuthProvider>();
    final success = await auth.login(
      _usernameCtrl.text.trim(),
      _passwordCtrl.text,
    );

    if (!mounted) return;
    if (success) {
      Navigator.of(context).pushReplacementNamed(auth.routeForRole);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 72),

                      // Logo
                      Center(
                        child: Container(
                          width:  72,
                          height: 72,
                          decoration: BoxDecoration(
                            color:        AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Icon(
                            Icons.network_check_rounded,
                            size:  38,
                            color: AppColors.primary,
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Title
                      const Center(
                        child: Text(
                          'ISP Monitor',
                          style: TextStyle(
                            fontSize:      30,
                            fontWeight:    FontWeight.w700,
                            color:         Color(0xFF1A1A1A),
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),

                      const SizedBox(height: 6),

                      Center(
                        child: Text(
                          'Sign in to your account',
                          style: TextStyle(
                            fontSize: 15,
                            color:    Colors.grey.shade500,
                          ),
                        ),
                      ),

                      const SizedBox(height: 48),

                      // Error banner
                      Consumer<AuthProvider>(
                        builder: (context, auth, _) {
                          if (auth.errorMessage == null) return const SizedBox.shrink();
                          return _buildErrorBanner(auth.errorMessage!);
                        },
                      ),

                      // Username
                      TextFormField(
                        controller:      _usernameCtrl,
                        keyboardType:    TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        style: const TextStyle(fontSize: 18),
                        decoration: InputDecoration(
                          labelText: 'Username or Email',
                          labelStyle: const TextStyle(fontSize: 16),
                          hintText:  'you@example.com',
                          hintStyle: TextStyle(fontSize: 16, color: Colors.grey.shade400),
                          prefixIcon: const Icon(Icons.person_outline_rounded, size: 24),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: AppColors.primary, width: 2),
                          ),
                          filled:    false,
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 22, horizontal: 20),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Please enter your username or email'
                            : null,
                      ),

                      const SizedBox(height: 20),

                      // Password
                      TextFormField(
                        controller:      _passwordCtrl,
                        obscureText:     _obscurePassword,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _handleLogin(),
                        style: const TextStyle(fontSize: 18),
                        decoration: InputDecoration(
                          labelText:  'Password',
                          labelStyle: const TextStyle(fontSize: 16),
                          hintText:   '••••••••',
                          hintStyle: TextStyle(fontSize: 16, color: Colors.grey.shade400),
                          prefixIcon: const Icon(Icons.lock_outline_rounded, size: 24),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              size: 24,
                            ),
                            onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: AppColors.primary, width: 2),
                          ),
                          filled:    false,
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 22, horizontal: 20),
                        ),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Please enter your password' : null,
                      ),

                      // Forgot password
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => Navigator.of(context)
                              .pushNamed(AppConstants.forgotPasswordRoute),
                          child: Text(
                            'Forgot password?',
                            style: TextStyle(
                              fontSize: 14,
                              color:    AppColors.primary,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Sign in button
                      Consumer<AuthProvider>(
                        builder: (context, auth, _) => SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: auth.isLoading ? null : () {
                              AppUtils.haptic();
                              _handleLogin();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                              textStyle: const TextStyle(
                                fontSize:   16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
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
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Sign up row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Don't have an account?  ",
                            style: TextStyle(
                              fontSize: 14,
                              color:    Colors.grey.shade600,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              AppUtils.hapticSelect();
                              Navigator.of(context)
                                  .pushNamed(AppConstants.registerRoute);
                            },
                            child: Text(
                              'Sign Up',
                              style: TextStyle(
                                fontSize:   14,
                                fontWeight: FontWeight.w600,
                                color:      AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      width:   double.infinity,
      margin:  const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        AppColors.offlineLight,
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(color: AppColors.offline.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.offline, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.offline),
            ),
          ),
        ],
      ),
    );
  }
}
